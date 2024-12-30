//
//  VLCPlayerViewController.swift
//  EnableWiFiDemo
//
//  Created by Marchell on 11/27/24.
//

import UIKit
import MobileVLCKit
//import ffmpegkit
import AVFoundation

enum PreviewStreamType {
    case vlc
    case ffmpeg
    case network
}

class PreviewStreamViewController: UIViewController {
    var streamType: PreviewStreamType = .network
    
    private var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer?
    
    private var mediaPlayer: VLCMediaPlayer?
    private var ffmpegBufferProcessor: FFmpegBufferProcessor?
    private var networkBufferProcessor: NetworkBufferProcessor?
    private let udpURL = "udp://@:8554"

    init() {
        super.init(nibName: nil, bundle: nil)

        switch streamType {
        case .ffmpeg:
            ffmpegBufferProcessor = FFmpegBufferProcessor()
        default:
            break
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        switch streamType {
        case .vlc:
            setupStreamUsingVLC()
        case .ffmpeg:
            ffmpegBufferProcessor?.startProcessingStream(from: udpURL)
        case .network:
            networkBufferProcessor?.sendRTSPSetupMessage()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if streamType == .ffmpeg && sampleBufferDisplayLayer == nil {
            setupSampleBufferDisplayLayer()
        } else if streamType == .network {
            networkBufferProcessor = NetworkBufferProcessor(port: 8554)
            networkBufferProcessor?.delegate = self
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        switch streamType {
        case .vlc:
            mediaPlayer?.stop()
        case .ffmpeg:
            ffmpegBufferProcessor?.stopProcessingStream()
        case .network:
            networkBufferProcessor?.cancel()
        }
    }
    
    private func setupStreamUsingVLC() {
        mediaPlayer = VLCMediaPlayer()
        mediaPlayer?.drawable = self.view
        
        if let url = URL(string: udpURL) {
            mediaPlayer?.media = VLCMedia(url: url)
        }
        
        mediaPlayer?.play()
    }
    
    private func setupSampleBufferDisplayLayer() {
        sampleBufferDisplayLayer = AVSampleBufferDisplayLayer()
        sampleBufferDisplayLayer!.videoGravity = .resizeAspect
        sampleBufferDisplayLayer!.frame = view.bounds
        view.layer.addSublayer(sampleBufferDisplayLayer!)
    }
    
    private func enqueueBuffer(_ sbuf: CMSampleBuffer) {
        if #available(iOS 17, *) {
            sampleBufferDisplayLayer?.sampleBufferRenderer.enqueue(sbuf)
        } else {
            sampleBufferDisplayLayer?.enqueue(sbuf)
        }
    }

}

// MARK: - Buffer processor delegate

extension PreviewStreamViewController: BufferProcessorDelegate {
    func bufferProcessor(_ processor: AnyBufferProcessor, didOutput buffer: CMSampleBuffer) {
        enqueueBuffer(buffer)
    }
}

extension PreviewStreamViewController: NetworkBufferProcessorDelegate {
    func bufferProcessor(_ processor: NetworkBufferProcessor, didReceive data: Data) {
        print("\(#function): Received data of size \(data.count)")
    }
}
