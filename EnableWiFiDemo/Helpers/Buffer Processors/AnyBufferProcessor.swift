//
//  AnyBufferProcessor.swift
//  EnableWiFiDemo
//
//  Created by cleanmac on 01/12/24.
//

import Foundation
import CoreMedia

protocol AnyBufferProcessor: AnyObject {}

protocol BufferProcessorDelegate: AnyObject {
    func bufferProcessor(_ processor: AnyBufferProcessor, didOutput buffer: CMSampleBuffer)
}
