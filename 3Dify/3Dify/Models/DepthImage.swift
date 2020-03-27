//
//  DepthImage.swift
//  3Dify
//
//  Created by It's free real estate on 24.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import Foundation
import UIKit

struct DepthImage {
    static var photoDepthConverter: DepthToColorMapConverter = {
        let converter = DepthToColorMapConverter()
        converter.prepare(outputRetainedBufferCountHint: 3)
        return converter
    }()
    static let model = OptimizedPydnet()
    
    let diffuse: UIImage
    let predictedDepth: UIImage
    let trueDepth: UIImage?
    
    init?(diffuse: UIImage, trueDepth: UIImage?) {
        guard
            let pixelBuffer = diffuse.resized(height: 448, width: 640)?.toBuffer(),
            let prediction = try? DepthImage.model.prediction(im0__0: pixelBuffer).PSD__resize__ResizeBilinear__0
        else {return nil}
        
        let context = CIContext()
        let predictionCIImage = CIImage(cvPixelBuffer: prediction)
        
        guard
            let displayImage = context.createCGImage(predictionCIImage, from: predictionCIImage.extent),
            let converted = DepthImage.photoDepthConverter.render(image: displayImage),
            let predictedDepth = UIImage(cgImage: converted, scale: 1, orientation: .up)
                .blurred(radius: 4)
                .rotate(radians: 0)?
                .normalize()
        else {return nil}
        
        self.diffuse = diffuse
        self.predictedDepth = predictedDepth
        self.trueDepth = trueDepth
    }
}
