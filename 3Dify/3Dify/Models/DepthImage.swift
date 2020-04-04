//
//  DepthImage.swift
//  3Dify
//
//  Created by It's free real estate on 24.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import Foundation
import UIKit


extension UIImage {
    static var depthPredictionConverter: DepthToColorMapConverter = {
        let converter = DepthToColorMapConverter()
        converter.prepare(outputRetainedBufferCountHint: 3)
        return converter
    }()
    static let depthPredictionModel = OptimizedPydnet()
    
    func getPredictedDepth() -> UIImage? {
        guard
            let pixelBuffer = resized(height: 448, width: 640)?.toBuffer(),
            let prediction = try? UIImage.depthPredictionModel.prediction(im0__0: pixelBuffer).PSD__resize__ResizeBilinear__0
        else {
            return nil
        }

        let context = CIContext()
        let predictionCIImage = CIImage(cvPixelBuffer: prediction)

        guard
            let displayImage = context.createCGImage(predictionCIImage, from: predictionCIImage.extent),
            let converted = UIImage.depthPredictionConverter.render(image: displayImage),
            let predictedDepth = UIImage(cgImage: converted, scale: 1, orientation: .up)
                .rotate(radians: 0)?.blurred(radius: 3).normalize()
        else {
            return nil
        }
        
        return predictedDepth
    }
    
    func getPredictedDepthAsync(completion: @escaping (UIImage?) -> ()) {
        DispatchQueue(label: "Depth Prediction Queue", qos: .userInteractive).async {
            completion(self.getPredictedDepth())
        }
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
