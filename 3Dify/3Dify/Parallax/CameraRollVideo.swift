

//
//  VideoConverter.swift
//

import Foundation
import AVFoundation
import UIKit
import Photos


open class CameraRollVideo: NSObject {
    internal let temporaryFileURL: URL
    internal let assetWriter: AVAssetWriter
    internal let writeInput: AVAssetWriterInput
    internal let bufferAdaptor: AVAssetWriterInputPixelBufferAdaptor
    internal let videoSettings: [String : Any]
    internal let frameTime: CMTime
    internal let mediaInputQueue: DispatchQueue
    internal var currentFrame: Int64
    
    public init?(width: Int, height: Int, frameRate: Int32 = 30) {
        guard
            let path = NSSearchPathForDirectoriesInDomains(
                .documentDirectory,
                .userDomainMask,
                true
            ).first
        else {
            return nil
        }
        
        let temporaryFilePath = "\(path)/temporary_video.mp4"
        temporaryFileURL =  URL(fileURLWithPath: temporaryFilePath)
        
        if(FileManager.default.fileExists(atPath: temporaryFilePath)) {
            guard (try? FileManager.default.removeItem(
                atPath: temporaryFilePath
            )) != nil else {
                return nil
            }
        }

        guard let assetWriter = try? AVAssetWriter(
            url: temporaryFileURL,
            fileType: AVFileType.mp4
        ) else {return nil}
        
        self.assetWriter = assetWriter

        self.videoSettings = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
        
        self.writeInput = AVAssetWriterInput(
            mediaType: AVMediaType.video,
            outputSettings: videoSettings
        )
        
        guard self.assetWriter.canAdd(self.writeInput) else {
            return nil
        }

        self.assetWriter.add(self.writeInput)
        
        let bufferAttributes:[String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB)
        ]
        
        self.bufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: self.writeInput,
            sourcePixelBufferAttributes: bufferAttributes
        )
        
        self.frameTime = CMTimeMake(value: 1, timescale: frameRate)
        self.currentFrame = 0
        
        self.mediaInputQueue = DispatchQueue(label: "Media Input Queue")
        
        super.init()
    }
    
    open func startWriting() {
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: CMTime.zero)
    }
    
    open func append(cgImage: CGImage) {
        autoreleasepool {
            guard let sampleBuffer = self.newPixelBufferFrom(cgImage: cgImage) else {
                return
            }
            let lastTime = CMTimeMake(value: currentFrame, timescale: self.frameTime.timescale)
            let presentTime = CMTimeAdd(lastTime, self.frameTime)
            self.bufferAdaptor.append(sampleBuffer, withPresentationTime: presentTime)
            self.currentFrame += 1
        }
    }
    
    open func finishWriting(completion: @escaping (URL) -> ()) {
        writeInput.markAsFinished()
        assetWriter.finishWriting {
            completion(self.temporaryFileURL)
        }
    }
    
    internal func newPixelBufferFrom(cgImage:CGImage) -> CVPixelBuffer? {
        let options:[String: Any] = [kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true]
        var pxbuffer:CVPixelBuffer?
        let frameWidth = self.videoSettings[AVVideoWidthKey] as! Int
        let frameHeight = self.videoSettings[AVVideoHeightKey] as! Int

        let status = CVPixelBufferCreate(kCFAllocatorDefault, frameWidth, frameHeight, kCVPixelFormatType_32ARGB, options as CFDictionary?, &pxbuffer)
        guard status == kCVReturnSuccess && pxbuffer != nil else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pxbuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pxdata = CVPixelBufferGetBaseAddress(pxbuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pxdata, width: frameWidth, height: frameHeight, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pxbuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        guard context != nil else {
            return nil
        }

        context!.concatenate(CGAffineTransform.identity)
        context!.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        CVPixelBufferUnlockBaseAddress(pxbuffer!, CVPixelBufferLockFlags(rawValue: 0))
        return pxbuffer
    }
}

