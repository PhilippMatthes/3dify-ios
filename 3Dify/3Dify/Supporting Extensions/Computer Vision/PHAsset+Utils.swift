//
//  PHAsset+Utils.swift
//  3Dify
//
//  Created by It's free real estate on 25.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import Foundation
import Photos
import UIKit

extension PHAsset {
    func getURL(completionHandler : @escaping ((_ responseURL : URL?) -> Void)){
        if self.mediaType == .image {
            let options: PHContentEditingInputRequestOptions = PHContentEditingInputRequestOptions()
            options.canHandleAdjustmentData = {(adjustmeta: PHAdjustmentData) -> Bool in
                return true
            }
            self.requestContentEditingInput(with: options, completionHandler: {(contentEditingInput: PHContentEditingInput?, info: [AnyHashable : Any]) -> Void in
                completionHandler(contentEditingInput?.fullSizeImageURL)
            })
        } else if self.mediaType == .video {
            let options: PHVideoRequestOptions = PHVideoRequestOptions()
            options.version = .original
            PHImageManager.default().requestAVAsset(forVideo: self, options: options, resultHandler: {(asset: AVAsset?, audioMix: AVAudioMix?, info: [AnyHashable : Any]?) -> Void in
                if let urlAsset = asset as? AVURLAsset {
                    let localVideoUrl: URL = urlAsset.url as URL
                    completionHandler(localVideoUrl)
                } else {
                    completionHandler(nil)
                }
            })
        }
    }
    
    func requestDepthImage(completion: @escaping (DepthImage?) -> Void) {
        self.getURL() {url in
            guard let url = url else {
                completion(nil)
                return
            }
            
            PHAsset.requestDepthImage(forUrl: url, completion: completion)
        }
    }
    
    static func requestDepthImage(forUrl url: URL, completion: @escaping (DepthImage?) -> ()) {
        guard
            let image = UIImage(contentsOfFile: url.path),
            let rotatedImage = image.rotate(radians: 0),
            let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil)
        else {
            completion(nil)
            return
        }
        
        
        guard let disparityPixelBuffer = imageSource.getDisparityData()?
            .converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
            .depthDataMap else {
            rotatedImage.getPredictedDepthAsync() { aiDepth in
                if let aiDepth = aiDepth {
                    completion(DepthImage(diffuse: rotatedImage, depth: aiDepth, isArtificial: true))
                } else {
                    completion(nil)
                }
            }
            return
        }
        
        disparityPixelBuffer.normalize()
        
        guard
            let depthMapImage = UIImage(pixelBuffer: disparityPixelBuffer),
            let depthCGImage = depthMapImage.cgImage,
            let rotatedDepthImage = UIImage(cgImage: depthCGImage, scale: 1.0, orientation: image.imageOrientation)
                .rotate(radians: 0)
        else {
            rotatedImage.getPredictedDepthAsync() { aiDepth in
                if let aiDepth = aiDepth {
                    completion(DepthImage(diffuse: rotatedImage, depth: aiDepth, isArtificial: true))
                } else {
                    completion(nil)
                }
            }
            return
        }
        
        completion(DepthImage(diffuse: rotatedImage, depth: rotatedDepthImage, isArtificial: false))
    }
}
