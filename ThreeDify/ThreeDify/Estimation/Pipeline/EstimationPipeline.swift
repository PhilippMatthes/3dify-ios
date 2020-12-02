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
import Accelerate

class EstimationPipeline {
    private let image: UIImage
    private let fcrnProcessor: FCRNProcessor
    private let pydnetProcessor: PydnetProcessor
    private let fastDepthProcessor: FastDepthProcessor

    enum ProcessingError: Error {
        case combinationFailed
    }

    init(image: UIImage) throws {
        self.image = image

        fcrnProcessor = try FCRNProcessor()
        pydnetProcessor = PydnetProcessor()
        fastDepthProcessor = try FastDepthProcessor()
    }

    func estimate(completion: @escaping (Result<UIImage, Error>) -> Void) {
        var fcrnDepthImage: UIImage?
        var pydnetImage: UIImage?
        var fastDepthImage: UIImage?

        let dispatchGroup = DispatchGroup()

        dispatchGroup.enter()
        fcrnProcessor.process(originalImage: image) { result in
            defer { dispatchGroup.leave() }
            switch result {
            case .failure(let error):
                print("WARNING: FCRN Processor encountered error: \(error)")
            case .success(let depthImage):
                fcrnDepthImage = depthImage
            }
        }

        dispatchGroup.enter()
        pydnetProcessor.process(originalImage: image) { result in
            defer { dispatchGroup.leave() }
            switch result {
            case .failure(let error):
                print("WARNING: Pydnet processor encountered error: \(error)")
            case .success(let depthImage):
                pydnetImage = depthImage
            }
        }

        dispatchGroup.enter()
        fastDepthProcessor.process(originalImage: image) { result in
            defer { dispatchGroup.leave() }
            switch result {
            case .failure(let error):
                print("WARNING: FastDepth encountered error: \(error)")
            case .success(let depthImage):
                fastDepthImage = depthImage
            }
        }

        dispatchGroup.notify(queue: .main) {
            guard
                let combinedDepthImage = self.combine(
                    fcrnDepthImage: fcrnDepthImage,
                    pydnetImage: pydnetImage,
                    fastDepthImage: fastDepthImage
                )
            else {
                completion(.failure(ProcessingError.combinationFailed))
                return
            }
            completion(.success(combinedDepthImage))
        }
    }

    func combine(
        fcrnDepthImage: UIImage?,
        pydnetImage: UIImage?,
        fastDepthImage: UIImage?
    ) -> UIImage? {
        guard
            let originalCGImage = image.cgImage,
            let fcrnDepthImage = fcrnDepthImage,
            let fcrnDepthCGImage = fcrnDepthImage.cgImage,
            let pydnetImage = pydnetImage,
            let pydnetCGImage = pydnetImage.cgImage,
            let fastDepthImage = fastDepthImage,
            let fastDepthCGImage = fastDepthImage.cgImage
        else { return nil }

        let originalCIImage = CIImage(cgImage: originalCGImage)
        let fcrnDepthCIImage = CIImage(cgImage: fcrnDepthCGImage)
        let pydnetDepthCIImage = CIImage(cgImage: pydnetCGImage)
        let fastDepthDepthCIImage = CIImage(cgImage: fastDepthCGImage)

        let context = CIContext()

        let originalFilter = SobelFilter(image: originalCIImage)
        let fcrnFilter = SobelFilter(image: fcrnDepthCIImage)
        let pydnetFilter = SobelFilter(image: pydnetDepthCIImage)
        let fastDepthFilter = SobelFilter(image: fastDepthDepthCIImage)

        guard
            let originalSobelCGImage = originalFilter.outputCGImage(withContext: context),
            let fcrnSobelCGImage = fcrnFilter.outputCGImage(withContext: context),
            let pydnetSobelCGImage = pydnetFilter.outputCGImage(withContext: context),
            let fastDepthSobelCGImage = fastDepthFilter.outputCGImage(withContext: context)
        else { return nil }

        let originalSobelCIImage = CIImage(cgImage: originalSobelCGImage)
        let fcrnSobelCIImage = CIImage(cgImage: fcrnSobelCGImage)
        let pydnetSobelCIImage = CIImage(cgImage: pydnetSobelCGImage)
        let fastDepthSobelCIImage = CIImage(cgImage: fastDepthSobelCGImage)

        let fusionFilter = FusionFilter(
            originalImageSobelImage: originalSobelCIImage,
            fcrnDepthImage: fcrnDepthCIImage,
            fcrnDepthSobelImage: fcrnSobelCIImage,
            pydnetDepthImage: pydnetDepthCIImage,
            pydnetDepthSobelImage: pydnetSobelCIImage,
            fastDepthDepthImage: fastDepthDepthCIImage,
            fastDepthDepthSobelImage: fastDepthSobelCIImage
        )

        guard
            let fusionCGImage = fusionFilter.outputCGImage(withContext: context)
        else { return nil }

        return UIImage(cgImage: fusionCGImage)
    }
}
