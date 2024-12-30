//
//  MediaListView.swift
//  EnableWiFiDemo
//
//  Created by Marchell on 11/27/24.
//

import SwiftUI
import AVKit

struct MediaListView: View {
    @StateObject var viewModel = MediaListViewModel()
    
    var body: some View {
        List {
            ForEach(viewModel.filesList) { mediaFile in
                ZStack {
                    HStack() {
                        Text("\(mediaFile.directory ?? "Unknown Directory")/\(mediaFile.name)")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .renderingMode(.template)
                            .foregroundColor(.gray)
                    }
                    Button(action: {
                        viewModel.downloadFile(file: mediaFile)
                    }, label: {
                        EmptyView()
                    })
                }
            }
        }.onAppear {
            viewModel.getAllFiles()
        }.sheet(isPresented: $viewModel.isShowingVideoPlayer, content: {
            if let currentLocalURL = viewModel.currentLocalURL {
                VideoPlayerView(url: currentLocalURL)
            }
        })
    }
    
    
}

final class MediaListViewModel: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var filesList: [MediaFile] = []
    @Published var isShowingVideoPlayer: Bool = false
    @Published var currentLocalURL: URL?
    
    func getAllFiles() {
        if let mediaListURL = URL(string: mediaListURL(goProDefaultIPAddress)) {
            let task = URLSession.shared.dataTask(with: mediaListURL) { data, response, error in
                guard error == nil else {
                    print("\(#function); Error: \(error!.localizedDescription)")
                    return
                }
                
                print("\(#function); Data: \(String(data: data!, encoding: .utf8) ?? "No data")")
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("\(#function); Status Code: \(httpResponse.statusCode)")
                }
                
                do {
                    self.filesList.removeAll()
                    
                    let mediaList = try JSONDecoder().decode(MediaList.self, from: data!)
                    mediaList.medias.forEach { mediaDirectory in
                        let files = mediaDirectory.files.map {
                            MediaFile(mediaFile: $0, directory: mediaDirectory.directory)
                        }
                        self.filesList.append(contentsOf: files)
                    }
                } catch {
                    print("\(#function); Decode error: \(error.localizedDescription)")
                }
                
            }
            task.resume()
        }
    }
    
    func downloadFile(file: MediaFile) {
        guard let directory = file.directory else { return }
        
        if let downloadURL = URL(string: mediaDownloadURL(goProDefaultIPAddress, directory, file.name)) {
            let task = URLSession.shared.downloadTask(with: downloadURL) { localURL, response, error in
                guard error == nil else {
                    print("\(#function); Error: \(error!.localizedDescription)")
                    return
                }
                
                if let localURL {
                    let documentsDirectory = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                    let saveDirectory = documentsDirectory.appendingPathComponent(file.name)
                    print("\(#function); Moving file to = \(saveDirectory.absoluteString)")
                    
                    do {
                        try FileManager.default.removeItem(at: saveDirectory)
                        try FileManager.default.moveItem(at: localURL, to: saveDirectory)
                        self.currentLocalURL = saveDirectory
                        self.isShowingVideoPlayer = true
                    } catch {
                        print("\(#function); Error: \(error.localizedDescription)")
                    }
                    
                }
            }
            //task.delegate = self
            task.resume()
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        print("Download progress: \(Float(totalBytesWritten) / Float(totalBytesExpectedToWrite))")
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        currentLocalURL = location
        
        let documentsDirectory = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let saveDirectory = documentsDirectory.appendingPathComponent("file1.mp4")
        
        do {
            try FileManager.default.moveItem(at: location, to: saveDirectory)
        } catch {
            print("didFinishDownloadingTo error \(error.localizedDescription)")
        }
        
        isShowingVideoPlayer = true
    }
}

struct VideoPlayerView: View {
    let videoURL: URL
    @State private var player = AVPlayer()
    
    init(url: URL) {
        self.videoURL = url
    }
    
    var body: some View {
        VideoPlayer(player: player)
            .edgesIgnoringSafeArea(.all)
            .navigationBarBackButtonHidden()
            .onAppear {
                player = AVPlayer(url: videoURL)
                player.play()
            }
            .onDisappear {
                player.pause()
            }
    }
}

#Preview {
    MediaListView()
}
