//
//  FFmpegStreamViewController.swift
//  EnableWiFiDemo
//
//  Created by cleanmac on 25/12/24.
//

import UIKit
import CoreMedia
import AVFoundation
import ffmpegkit

final class FFmpegStreamViewController: UIViewController {
    private var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer?
    private var contentsLayer: CALayer?
    
    private var frameWidth: Int = 1920
    private var frameHeight: Int = 1080
    private var framePixelFormat: OSType = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange // Matches yuv420p
    private var lastPresentationTimestamp: CMTime = .zero
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Start retrieving frames
        captureFramesFromGoPro()
        
        if sampleBufferDisplayLayer == nil {
            sampleBufferDisplayLayer = AVSampleBufferDisplayLayer()
            sampleBufferDisplayLayer!.videoGravity = .resizeAspect
            sampleBufferDisplayLayer!.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.width * 1080 / 1920)
            sampleBufferDisplayLayer?.backgroundColor = UIColor.clear.cgColor
            view.layer.addSublayer(sampleBufferDisplayLayer!)
            
            if sampleBufferDisplayLayer!.controlTimebase == nil {
                var timebase: CMTimebase?
                CMTimebaseCreateWithSourceClock(allocator: kCFAllocatorDefault, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
                sampleBufferDisplayLayer!.controlTimebase = timebase
                CMTimebaseSetTime(sampleBufferDisplayLayer!.controlTimebase!, time: CMTime.zero)
                CMTimebaseSetRate(sampleBufferDisplayLayer!.controlTimebase!, rate: 1.0)
            }
            
            if #available(iOS 17, *) {
                sampleBufferDisplayLayer?.sampleBufferRenderer.flush()
                sampleBufferDisplayLayer?.sampleBufferRenderer.flush(removingDisplayedImage: true)
            } else {
                sampleBufferDisplayLayer?.flush()
                sampleBufferDisplayLayer?.flushAndRemoveImage()
            }
        }
        
        if contentsLayer == nil {
            contentsLayer = CALayer()
            contentsLayer!.frame = view.bounds
            contentsLayer?.backgroundColor = UIColor.red.cgColor
            view.layer.addSublayer(contentsLayer!)
        }
        
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        FFmpegKit.cancel()
        if #available(iOS 17, *) {
            sampleBufferDisplayLayer?.sampleBufferRenderer.flush()
            sampleBufferDisplayLayer?.sampleBufferRenderer.flush(removingDisplayedImage: true)
        } else {
            sampleBufferDisplayLayer?.flush()
            sampleBufferDisplayLayer?.flushAndRemoveImage()
        }
    }
    
    func captureFramesFromGoPro() {
        let goProStreamURL = "udp://@:8554"
        
        // Temporary file to store raw video data
        let tempDirectory = FileManager.default.temporaryDirectory
        let rawVideoFileURL = tempDirectory.appendingPathComponent("rawvideo.yuv")
        
        // FFmpeg command to output raw video data to the file
//        let ffmpegCommand = """
//            -i \(goProStreamURL) -f rawvideo -pix_fmt yuv420p -vf fps=30 \(rawVideoFileURL.path)
//            """
        
        let ffmpegCommand = """
        -i \(goProStreamURL) -f rawvideo -pix_fmt nv12 -vf scale=640:360,fps=30 \(rawVideoFileURL.path)
        """
        
        // Execute FFmpeg command
        FFmpegKit.executeAsync(ffmpegCommand) { session in
            guard let returnCode = session?.getReturnCode() else {
                print("FFmpeg session returned no return code")
                return
            }
            
            if ReturnCode.isSuccess(returnCode) {
                print("FFmpeg command succeeded")
            } else {
                print("FFmpeg command failed with return code \(returnCode)")
            }
        }
        
        // Read and process the raw video file
        processRawVideoFile(at: rawVideoFileURL)
    }
    
    func processRawVideoFile(at fileURL: URL) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
                print("Failed to open raw video file")
                return
            }
            
            let bytesPerFrame = self.frameWidth * self.frameHeight * 3 / 2 // For yuv420p
            while true {
                sleep(1)
                autoreleasepool {
                    let frameData = fileHandle.readData(ofLength: bytesPerFrame)
                    if frameData.isEmpty {
                        //break
                        return
                    }
                    
                    self.processFrame(data: frameData)
                }
            }
            
            fileHandle.closeFile()
        }
    }
    
    func processFrame(data: Data) {
        // Create a CVPixelBuffer from raw frame data
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferWidthKey: frameWidth,
            kCVPixelBufferHeightKey: frameHeight,
            kCVPixelBufferPixelFormatTypeKey: framePixelFormat
        ]
        
        let status = CVPixelBufferCreateWithBytes(
            kCFAllocatorDefault,
            frameWidth,
            frameHeight,
            framePixelFormat,
            UnsafeMutableRawPointer(mutating: (data as NSData).bytes),
            frameWidth, // Bytes per row (adjust for pixel format)
            nil,
            nil,
            attrs as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            print("Failed to create CVPixelBuffer")
            return
        }
        
        // Wrap the CVPixelBuffer in a CMSampleBuffer
        var sampleBuffer: CMSampleBuffer?
        var timingInfo = generateTimingInfo()
        
        var videoFormatDesc: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                     imageBuffer: buffer,
                                                     formatDescriptionOut: &videoFormatDesc)
        
        guard let formatDesc = videoFormatDesc else {
            print("Failed to create video format description")
            return
        }
        
        let sampleBufferStatus = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDesc,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        
        if sampleBufferStatus == noErr, let sampleBuffer = sampleBuffer {
            // Successfully created CMSampleBuffer
            DispatchQueue.main.async {
                self.handleSampleBuffer(sampleBuffer)
            }
        } else {
            print("Failed to create CMSampleBuffer")
        }
    }
    
    func generateTimingInfo() -> CMSampleTimingInfo {
        let presentationTimestamp = lastPresentationTimestamp
        lastPresentationTimestamp = CMTimeAdd(lastPresentationTimestamp, CMTime(value: 1, timescale: 30))
        let timingInfo = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30),
                                  presentationTimeStamp: presentationTimestamp,
                                  decodeTimeStamp: .invalid)
        print("Generated timing info: \(timingInfo)")
        return timingInfo
    }
    
    func handleSampleBuffer(_ sbuf: CMSampleBuffer) {
        // Process or display the CMSampleBuffer
        print("Received CMSampleBuffer: \(sbuf)")
        
        //enqueueImage(sbuf)
        
        guard let sampleBufferDisplayLayer, let staticBuffer = createBlueStaticSampleBuffer() else { return }
        
        enqueueImage(staticBuffer)
        
        if #available(iOS 17, *) {
            if sampleBufferDisplayLayer.sampleBufferRenderer.isReadyForMoreMediaData {
                sampleBufferDisplayLayer.sampleBufferRenderer.enqueue(staticBuffer)
            }
        } else {
            if sampleBufferDisplayLayer.isReadyForMoreMediaData {
                sampleBufferDisplayLayer.enqueue(staticBuffer)
            }
        }
        
        sampleBufferDisplayLayer.setNeedsDisplay()
    }
    
    func enqueueImage(_ sbuf: CMSampleBuffer) {
        DispatchQueue.main.async {
            guard let contentsLayer = self.contentsLayer else { return }
            
//            let imageBuffer = CMSampleBufferGetImageBuffer(sbuf)!
//            let ciimage = CIImage(cvPixelBuffer: imageBuffer)
//            let image = self.convert(cmage: ciimage)
            
            guard let image = UIImage(named: "swift-og") else { return }
            
            let cgImage = image.cgImage!
            
            contentsLayer.contents = cgImage
            contentsLayer.contentsGravity = .resizeAspect // Adjust as needed
            contentsLayer.contentsScale = UIScreen.main.scale
            contentsLayer.bounds = self.view.bounds // Ensure it matches the view size
            contentsLayer.setNeedsLayout()
            contentsLayer.setNeedsDisplay()
            contentsLayer.display()
        }
    }

    // Convert CIImage to UIImage
    func convert(cmage: CIImage) -> UIImage {
         let context = CIContext(options: nil)
         let cgImage = context.createCGImage(cmage, from: cmage.extent)!
         let image = UIImage(cgImage: cgImage)
         return image
    }
    
    // Creates a static sample buffer filled with the color blue
    func createBlueStaticSampleBuffer() -> CMSampleBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferWidthKey: 1920,
            kCVPixelBufferHeightKey: 1080,
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ] as CFDictionary

        CVPixelBufferCreate(kCFAllocatorDefault, 1920, 1080, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, attrs, &pixelBuffer)
        guard let buffer = pixelBuffer else { return nil }

        // Fill the buffer with blue color
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        if let lumaBaseAddress = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) {
            // Fill luma plane (Y) - brightness
            memset(lumaBaseAddress, 0x80, CVPixelBufferGetBytesPerRowOfPlane(buffer, 0) * 1080) // Medium brightness
        }
        if let chromaBaseAddress = CVPixelBufferGetBaseAddressOfPlane(buffer, 1) {
            // Convert UnsafeMutableRawPointer to UnsafeMutablePointer<UInt8>
            let chromaPointer = chromaBaseAddress.bindMemory(to: UInt8.self, capacity: CVPixelBufferGetBytesPerRowOfPlane(buffer, 1) * 540)

            let chromaBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
            for row in 0..<540 { // Half height for chroma plane
                let chromaRowPointer = chromaPointer.advanced(by: row * chromaBytesPerRow)
                for col in stride(from: 0, to: chromaBytesPerRow, by: 2) {
                    chromaRowPointer[col] = 0xFF // Cb (Blue)
                    chromaRowPointer[col + 1] = 0x80 // Cr (Neutral Red)
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, .readOnly)

        var sampleBuffer: CMSampleBuffer?
        var formatDescription: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: buffer, formatDescriptionOut: &formatDescription)
        var timing = generateTimingInfo()
        CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: buffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: formatDescription!, sampleTiming: &timing, sampleBufferOut: &sampleBuffer)

        return sampleBuffer
    }
    
}
