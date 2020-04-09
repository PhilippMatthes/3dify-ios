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


class HeatmapViewPistProcessor {
    func convertTo2DArray(from heatmaps: MLMultiArray) -> Array<Array<Double>> {
        guard heatmaps.shape.count >= 3 else {
            print("Error: heatmap's shape is invalid. \(heatmaps.shape)")
            return []
        }
        
        let _ /*keypoint_number*/ = heatmaps.shape[0].intValue
        let heatmap_w = heatmaps.shape[1].intValue
        let heatmap_h = heatmaps.shape[2].intValue
        
        var convertedHeatmap: Array<Array<Double>> = Array(repeating: Array(repeating: 0.0, count: heatmap_w), count: heatmap_h)
        
        var minimumValue = Double.greatestFiniteMagnitude
        var maximumValue = -Double.greatestFiniteMagnitude
        
        for i in 0 ..< heatmap_w {
            for j in 0 ..< heatmap_h {
                let index = i * (heatmap_h) + j
                let confidence = heatmaps[index].doubleValue
                guard confidence > 0 else { continue }
                convertedHeatmap[j][i] = confidence
                
                if minimumValue > confidence {
                    minimumValue = confidence
                }
                if maximumValue < confidence {
                    maximumValue = confidence
                }
            }
        }
        
        let minmaxGap = maximumValue - minimumValue
        for i in 0 ..< heatmap_w {
            for j in 0 ..< heatmap_h {
                convertedHeatmap[j][i] = (convertedHeatmap[j][i] - minimumValue) / minmaxGap
            }
        }
        return convertedHeatmap
    }
    
    func convertToImage(from heatmaps: MLMultiArray, targetSize size: CGSize) -> UIImage? {
        let heatmap = convertTo2DArray(from: heatmaps)
        
        return UIGraphicsImageRenderer(size: size).image { context in
            let heatmap_w = heatmap.count
            let heatmap_h = heatmap.first?.count ?? 0
            let width = size.width / CGFloat(heatmap_w)
            let height = size.height / CGFloat(heatmap_h)
            
            for j in  0 ..< heatmap_h {
                for i in 0 ..< heatmap_w {
                    let value = heatmap[i][j]
                    var alpha = CGFloat(value)
                    if alpha > 1 {
                        alpha = 1
                    } else if alpha < 0 {
                        alpha = 0
                    }
                    
                    let rect = CGRect(x: CGFloat(i) * width, y: CGFloat(j) * height, width: width, height: height)
                    
                    let color = UIColor(white: 1 - alpha, alpha: 1)
                    let bpath = UIBezierPath(rect: rect)
                    
                    color.set()
                    bpath.fill()
                }
            }
        }
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
                let heatmap = observations.first?.featureValue.multiArrayValue,
                let image = HeatmapViewPistProcessor()
                    .convertToImage(from: heatmap, targetSize: self.size)?
                    .blurred(radius: 16)
            else {
                completion(nil)
                return
            }
            
            completion(image)
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
