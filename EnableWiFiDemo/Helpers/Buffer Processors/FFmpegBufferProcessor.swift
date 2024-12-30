//
//  BufferProcessor.swift
//  EnableWiFiDemo
//
//  Created by cleanmac on 01/12/24.
//

import Foundation
import CoreMedia
import AVFoundation
import ffmpegkit


final class FFmpegBufferProcessor: AnyBufferProcessor {
    weak var delegate: BufferProcessorDelegate?
    
    private var pipePath: String = NSTemporaryDirectory() + "ffmpeg_pipe"
    private var isProcessing: Bool = false
    private var videoWidth = 1920
    private var videoHeight = 1080
    private let pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
    
    init() {
        setupPipe()
    }
    
    deinit {
        cleanupPipe()
    }
    
    private func setupPipe() {
        do {
            if FileManager.default.fileExists(atPath: pipePath) {
                try FileManager.default.removeItem(atPath: pipePath)
            }
            
            let result = mkfifo(pipePath.cString(using: .utf8), 0o644)
            if result != 0 {
                print("\(#function); Pipe creation failed.")
                return
            }
        } catch {
            print("\(#function); Setup pipe error: \(error.localizedDescription)")
        }
    }
    
    private func cleanupPipe() {
        do {
            try FileManager.default.removeItem(atPath: pipePath)
        } catch {
            print("\(#function); Cleanup pipe error: \(error.localizedDescription)")
        }
    }
    
    func startProcessingStream(from udpURL: String) {
        guard !isProcessing else {
            print("\(#function); Already processing stream.")
            return
        }
        
        isProcessing = true
        let command = """
        -i \(udpURL) -f rawvideo -pix_fmt nv12 \(pipePath)
        """
        
        FFmpegKit.executeAsync(command) { [weak self] session in
            let returnCode = session?.getReturnCode()
            if ReturnCode.isSuccess(returnCode) {
                print("\(#function); FFmpeg session completed.")
            } else {
                print("\(#function); FFmpeg session error: \(String(describing: session?.getFailStackTrace())).")
            }
            
            self?.isProcessing = false
        }
        
        readFromPipe()
    }
    
    func stopProcessingStream() {
        isProcessing = false
        FFmpegKit.cancel()
    }
}

// MARK: - Private methods

private extension FFmpegBufferProcessor {
    func readFromPipe() {
        DispatchQueue.global(qos: .background).async { [unowned self] in
            guard let fileHandle = FileHandle(forReadingAtPath: self.pipePath) else {
                print("\(#function); Fail to read file handle from pipe path.")
                return
            }
            
            autoreleasepool {
                while self.isProcessing {
                    let frameSize = self.videoWidth * self.videoHeight * 3 / 2
                    let rawData = fileHandle.readData(ofLength: frameSize)
                    
                    if rawData.isEmpty {
                        print("\(#function); Pipe closed / no more data to read.")
                        break
                    }
                    
                    self.handleRawFrameData(rawData)
                }
                
                fileHandle.closeFile()
            }
        }
    }
    
    func handleRawFrameData(_ data: Data) {
        let width = 1920
        let height = 1080
        
        guard let pixelBuffer = createPixelBuffer(from: data, width: width, height: height) else {
            print("\(#function); Failed to create pixel buffer")
            return
        }
        
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30), presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
        guard let sampleBuffer = createSampleBuffer(from: pixelBuffer, timing: &timing) else {
            print("\(#function); Failed to create sample buffer")
            return
        }
        
        delegate?.bufferProcessor(self, didOutput: sampleBuffer)
    }
    
    func createPixelBuffer(from rawFrame: Data, width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ]
        
        CVPixelBufferCreate(kCFAllocatorDefault,
                            width,
                            height,
                            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                            attributes as CFDictionary,
                            &pixelBuffer)
        
        guard let pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let yPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
        let uvPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)
        
        rawFrame.withUnsafeBytes { rawBuffer in
            let baseAddress = rawBuffer.baseAddress!
            memcpy(yPlane, baseAddress, width * height)
            memcpy(uvPlane, baseAddress.advanced(by: width * height), width * height / 2)
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        
        return pixelBuffer
    }
    
    func createSampleBuffer(from pixelBuffer: CVPixelBuffer, timing: inout CMSampleTimingInfo) -> CMSampleBuffer? {
        var sampleBuffer: CMSampleBuffer?
        var formatDescription: CMVideoFormatDescription?
        
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &formatDescription)
        
        guard let formatDescription else {
            return nil
        }
        
        CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
                                                 imageBuffer: pixelBuffer,
                                                 formatDescription: formatDescription,
                                                 sampleTiming: &timing,
                                                 sampleBufferOut: &sampleBuffer)
        
        return sampleBuffer
    }
}
