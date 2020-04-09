//
//  DepthImageConvertible.swift
//  3Dify
//
//  Created by It's free real estate on 07.04.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import Foundation
import Photos
import UIKit


protocol DepthImageConvertible {
    func toDepthImage(completion: @escaping (DepthImage?) -> ())
}

extension PHAsset: DepthImageConvertible {
    func toDepthImage(completion: @escaping (DepthImage?) -> ()) {
        requestDepthImage(completion: completion)
    }
}

extension DepthImage: DepthImageConvertible {
    func toDepthImage(completion: @escaping (DepthImage?) -> ()) {
        completion(self)
    }
}

extension UIImage: DepthImageConvertible {
    func toDepthImage(completion: @escaping (DepthImage?) -> ()) {
        getPredictedDepth(predictor: .fcrn) { depthImage in
            guard let depthImage = depthImage else {
                completion(nil)
                return
            }
            completion(DepthImage(diffuse: self, depth: depthImage, isArtificial: true))
        }
    }
}
