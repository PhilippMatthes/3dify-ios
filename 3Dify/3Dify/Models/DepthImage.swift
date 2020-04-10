//
//  DepthImage.swift
//  3Dify
//
//  Created by It's free real estate on 24.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import Foundation
import UIKit
import Vision


enum DepthPredictor {
    case pydnet
    case fcrn
}


extension MLMultiArray {
    public func doubleMinMaxValue() -> (Double, Double) {
        var minValue = Double.greatestFiniteMagnitude
        var maxValue = -Double.greatestFiniteMagnitude
        
        // Slow version
        for i in 0..<self.count {
            let n = self[i].doubleValue
            minValue = min(n, minValue)
            maxValue = max(n, maxValue)
        }
        
        return (minValue, maxValue)
    }
}


extension UIImage {
    func scaleDepthForPresentation() -> UIImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let cgImage = cgImage else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height

        var rawData = [Float](repeating: 0, count: width * height * 4)
        let bytesPerPixel = 16
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 32

        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.floatComponents.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

        guard let context = CGContext(data: &rawData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo) else { return nil }

        let drawingRect = CGRect(origin: .zero, size: CGSize(width: width, height: height))
        context.draw(cgImage, in: drawingRect)

        for pixel in 0 ..< width * height {
            let baseOffset = pixel * 4
            for offset in baseOffset ..< baseOffset + 3 {
                rawData[offset] = 1.0 - (rawData[offset] * 5)
            }
        }

        return context.makeImage().map {
            UIImage(cgImage: $0, scale: scale, orientation: imageOrientation)
        }
    }
    
    func getPredictedFCRNDepth(completion: @escaping (UIImage?) -> ()) {
        let fcrnModel = FCRN()
        
        guard let cgImage = self.cgImage else {
            completion(nil)
            return
        }
        
        guard let visionModel = try? VNCoreMLModel(for: fcrnModel.model) else {
            completion(nil)
            return
        }
        
        let request = VNCoreMLRequest(model: visionModel) { request, error in
            guard
                error == nil,
                let observations = request.results as? [VNCoreMLFeatureValueObservation],
                let depth = observations.first?.featureValue.multiArrayValue
            else {
                completion(nil)
                return
            }
            
            let minMax = depth.doubleMinMaxValue()
            
            guard let image = depth.cgImage(min: minMax.0, max: minMax.1) else {
                completion(nil)
                return
            }
            
            completion(UIImage(cgImage: image))
        }
        
        request.imageCropAndScaleOption = .scaleFill
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try requestHandler.perform([request])
        } catch {
            completion(nil)
            return
        }
    }
    
    func getPredictedPydnetDepth(completion: @escaping (UIImage?) -> ()) {
        let pydnetModel = OptimizedPydnet()
        guard
            let pixelBuffer = resized(height: 448, width: 640)?
                .toBuffer(pixelFormatType: kCVPixelFormatType_32BGRA),
            let prediction = try? pydnetModel
                .prediction(im0__0: pixelBuffer)
                .PSD__resize__ResizeBilinear__0
        else {
            completion(nil)
            return
        }
        
        let predictionCIImage = CIImage(cvPixelBuffer: prediction)

        guard
            let predictedDepth = UIImage(ciImage: predictionCIImage)
                .rotate(radians: 0)?
                .scaleDepthForPresentation()?
                .blurred(radius: 2)
        else {
            completion(nil)
            return
        }
        
        completion(predictedDepth)
    }
    
    func getPredictedDepth(predictor: DepthPredictor, completion: @escaping (UIImage?) -> ()) {
        DispatchQueue(label: "Depth Prediction Queue", qos: .userInteractive).async {
            switch predictor {
            case .fcrn:
                self.getPredictedFCRNDepth(completion: completion)
            case .pydnet:
                self.getPredictedPydnetDepth(completion: completion)
            }
        }
    }
    
    func resized(height: CGFloat, width: CGFloat) -> UIImage? {
        let rect = CGRect(x: 0.0, y: 0.0, width: width, height: height)
        UIGraphicsBeginImageContext(rect.size)
        self.draw(in:rect)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }
    
    func resizedMaintainingAspectRatio(targetSize: CGSize) -> UIImage? {
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height

        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }

        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)

        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }
    
    func toBuffer(pixelFormatType: OSType) -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(self.size.width), Int(self.size.height), pixelFormatType, attrs, &pixelBuffer)
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
    let diffuse: UIImage
    let depth: UIImage
    let isArtificial: Bool
    
    var aspectRatio: CGFloat {
        return diffuse.size.width / diffuse.size.height
    }
    
    var screenWidth: CGFloat {
        return UIScreen.main.bounds.width
    }
    
    var screenHeight: CGFloat {
        return UIScreen.main.bounds.width / aspectRatio
    }
    
    init(diffuse: UIImage, depth: UIImage, isArtificial: Bool) {
        self.diffuse = diffuse
        self.depth = depth
        self.isArtificial = isArtificial
    }
}

extension DepthImage: Equatable {
    static func == (lhs: DepthImage, rhs: DepthImage) -> Bool {
        return lhs.diffuse == rhs.diffuse
    }
}
