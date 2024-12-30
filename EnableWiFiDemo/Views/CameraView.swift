/* CameraView.swift/Open GoPro, Version 2.0 (C) Copyright 2021 GoPro, Inc. (http://gopro.com/OpenGoPro). */
/* This copyright was auto-generated on Wed, Sep  1, 2021  5:06:10 PM */

//
//  CameraView.swift
//  EnableWiFiDemo
//

import SwiftUI
import AVKit
import NetworkExtension

struct CameraView: View {
    var peripheral: Peripheral?
    
    @State var isConnected: Bool = false
    @State var streamingURL: String? = nil
    @State var isShowingVideoPlayer: Bool = false
    @State var isShowingMediaList: Bool = false
    
    var player = AVPlayer()
    
    var body: some View {
        VStack {
            Button(action: {
                NSLog("Enabling WiFi...")
                peripheral?.enableWiFi { error in
                    if error != nil {
                        print("\(error!)")
                        return
                    }

                    NSLog("Requesting WiFi settings...")
                    peripheral?.requestWiFiSettings { result in
                        switch result {
                        case .success(let wifiSettings):
                            joinWiFi(with: wifiSettings.SSID, password: wifiSettings.password)
                        case .failure(let error):
                            print("\(error)")
                        }
                    }
                }
            }, label: {
                Text("Enable Wi-Fi")
            })
            
            if isConnected {
                Button(action: {
                    startCameraFeedStreaming()
                }, label: {
                    Text("Stream Video")
                })
                
                Button(action: {
                    isShowingMediaList = true
                }, label: {
                    Text("Media List")
                })
           }
            
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(peripheral?.name ?? "").fontWeight(.bold)
            }
        }.sheet(isPresented: $isShowingVideoPlayer, content: {
                VLCPlayerViewControllerRepresentable()
        }).sheet(isPresented: $isShowingMediaList, content: {
            MediaListView()
        }).onDisappear {
            stopCameraFeedStreaming()
        }
    }

    private func joinWiFi(with SSID: String, password: String) {
        NSLog("Joining WiFi \(SSID)...")
        let configuration = NEHotspotConfiguration(ssid: SSID, passphrase: password, isWEP: false)
        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: SSID)
        configuration.joinOnce = false
        NEHotspotConfigurationManager.shared.apply(configuration) { error in
            guard let error = error else {
                isConnected = true
                NSLog("Joining WiFi succeeded")
                //startTranscode()
                return
            }
            isConnected = false
            NSLog("Joining WiFi failed: \(error)")
        }
    }
    
    private func startTranscode() {
        if let startStreamURL = URL(string: startStreamURL(goProDefaultIPAddress)) {
            let task = URLSession.shared.dataTask(with: startStreamURL) { data, response, error in
                guard error == nil else {
                    return
                }
                
                print("\(#function); Data: \(String(data: data!, encoding: .utf8) ?? "No data")")
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("\(#function); Status Code: \(httpResponse.statusCode)")
                }
                
                streamingURL = liveFeedURL(goProDefaultIPAddress)
            }
            task.resume()
        }
    }
    
    private func startCameraFeedStreaming() {
        defer {
            isShowingVideoPlayer = true
        }
        
        if streamingURL == nil {
            if let startStreamURL = URL(string: startStreamUsingPortURL(goProDefaultIPAddress)) {
                let task = URLSession.shared.dataTask(with: startStreamURL) { data, response, error in
                    guard error == nil else {
                        return
                    }
                    
                    print("\(#function); Data: \(String(data: data!, encoding: .utf8) ?? "No data")")
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        print("\(#function); Status Code: \(httpResponse.statusCode)")
                    }
                    
                    streamingURL = liveFeedURL(goProDefaultIPAddress)
                }
                task.resume()
            }
        }
    }
    
    private func stopCameraFeedStreaming() {
        if let stopStreamURL = URL(string: stopStreamURL(goProDefaultIPAddress)) {
            let task = URLSession.shared.dataTask(with: stopStreamURL) { data, response, error in
                guard error == nil else {
                    return
                }
                
                print("\(#function); Data: \(String(data: data!, encoding: .utf8) ?? "No data")")
                if let response {
                    dump(response)
                }
            }
            task.resume()
        }
    }
}

struct VLCPlayerViewControllerRepresentable: UIViewControllerRepresentable {
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        // Do nothing
    }
    
    func makeUIViewController(context: Context) -> some UIViewController {
        //PreviewStreamViewController()
        FFmpegStreamViewController()
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
    }
}
