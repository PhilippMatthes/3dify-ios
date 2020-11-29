//
// 3Dify App
//
// Project website: https://github.com/3dify-app
//
// Authors:
// - It's free real estate 2020, Contact: mail@philippmatth.es
//
// Copyright notice: All rights reserved by the authors given above. Do not
// remove or change this copyright notice without confirmation of the authors.
// 

import Foundation
import UIKit

class EstimationPipeline {
    let image: UIImage
    let fcrnProcessor: FCRNProcessor
    let pydnetProcessor: PydnetProcessor

    enum ProcessingError: Error {
        case combinationFailed
    }

    init(image: UIImage) throws {
        self.image = image
        fcrnProcessor = try FCRNProcessor()
        pydnetProcessor = PydnetProcessor()
    }

    func estimate(completion: @escaping (Result<UIImage, Error>) -> Void) {
        fcrnProcessor.process(originalImage: image) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let fcrnDepthImage):
                self.pydnetProcessor.process(originalImage: self.image) { result in
                    switch result {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success(let pydnetDepthImage):
                        guard
                            let combinedDepthImage =
                                self.combine(
                                    fcrnDepthImage: fcrnDepthImage,
                                    pydnetDepthImage: pydnetDepthImage
                                )
                        else {
                            completion(.failure(ProcessingError.combinationFailed))
                            return
                        }
                        completion(.success(combinedDepthImage))
                    }
                }
            }
        }
    }

    func combine(fcrnDepthImage: UIImage, pydnetDepthImage: UIImage) -> UIImage? {
        UIGraphicsBeginImageContext(image.size)
        fcrnDepthImage.draw(in: CGRect(origin: .zero, size: image.size))
        pydnetDepthImage.draw(
            in: CGRect(origin: .zero, size: image.size),
            blendMode: .normal,
            alpha: 0.5
        )
        let combinedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return combinedImage
    }
}
