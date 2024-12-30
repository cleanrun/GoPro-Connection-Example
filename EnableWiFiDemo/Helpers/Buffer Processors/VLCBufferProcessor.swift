//
//  VLCBufferProcessor.swift
//  EnableWiFiDemo
//
//  Created by cleanmac on 01/12/24.
//

import Foundation
import MobileVLCKit
import CoreMedia

final class VLCBufferProcessor: NSObject, AnyBufferProcessor {
    weak var delegate: BufferProcessorDelegate?
    
    private var mediaPlayer: VLCMediaPlayer?
    
    func startStreaming(from udpURL: String, drawable: UIView?) {
        mediaPlayer = VLCMediaPlayer()
        
        guard let mediaPlayer, let url = URL(string: udpURL) else { return }
        
        mediaPlayer.media = VLCMedia(url: url)
        mediaPlayer.delegate = self
        
        if let drawable {
            mediaPlayer.drawable = drawable
        }
        
        mediaPlayer.media?.addOptions([
            "vout": "fake",
            "no-video-title-show": true
        ])
        
        mediaPlayer.play()
    }
    
    func stopStreaming() {
        mediaPlayer?.stop()
        mediaPlayer = nil
    }
}

// MARK: - Private methods

private extension VLCBufferProcessor {
    func setupVideoCallbacks() {
        guard let mediaPlayer else { return }
        
        
    }
}

// MARK: - Media player delegate

extension VLCBufferProcessor: VLCMediaPlayerDelegate {
    
}
