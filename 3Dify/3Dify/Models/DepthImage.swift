//
//  DepthImage.swift
//  3Dify
//
//  Created by It's free real estate on 24.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import Foundation
import UIKit


internal extension UIImage {
    func resized(height: CGFloat, width: CGFloat) -> UIImage? {
      let rect = CGRect(x: 0.0, y: 0.0, width: width, height: height)
      UIGraphicsBeginImageContext(rect.size)
      self.draw(in:rect)
      let img = UIGraphicsGetImageFromCurrentImageContext()
      UIGraphicsEndImageContext()
      return img
    }
    
    func toBuffer() -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(self.size.width), Int(self.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard (status == kCVReturnSuccess) else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(self.size.width), height: Int(self.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

        context?.translateBy(x: 0, y: self.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)

        UIGraphicsPushContext(context!)
        self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

        return pixelBuffer
    }
}


struct DepthImage {
    static let photoDepthConverter = DepthToColorMapConverter()
    
    let diffuse: UIImage
    let predictedDepth: UIImage
    let trueDepth: UIImage?
    
    init(diffuse: UIImage, trueDepth: UIImage?) {
        let model = OptimizedPydnet()
        let pixelBuffer = diffuse.resized(height: 448, width: 640)?.toBuffer()
        
        let prediction = try? model.prediction(im0__0: pixelBuffer!).PSD__resize__ResizeBilinear__0
        let predictionCIImage = CIImage(cvPixelBuffer: prediction!)
        
        DepthImage.photoDepthConverter.prepare(outputRetainedBufferCountHint: 3)
        let context = CIContext()
        let displayImage = context.createCGImage(predictionCIImage, from: predictionCIImage.extent)!
        let converted = DepthImage.photoDepthConverter.render(image: displayImage)!
        let predictedDepth = UIImage(cgImage: converted, scale: 1, orientation: .up).rotate(radians: 0)!
        
        self.diffuse = diffuse
        self.predictedDepth = predictedDepth
        self.trueDepth = trueDepth
    }
    
    static
    
    func buffer(from image: UIImage) -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.size.width), Int(image.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard (status == kCVReturnSuccess) else {
        return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

        context?.translateBy(x: 0, y: image.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)

        UIGraphicsPushContext(context!)
        image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

        return pixelBuffer
    }
}
