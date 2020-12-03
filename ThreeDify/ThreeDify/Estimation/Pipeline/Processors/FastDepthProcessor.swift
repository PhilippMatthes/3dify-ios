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

import UIKit
import Vision

class FastDepthProcessor: DepthProcessor {
    let model: VNCoreMLModel
    let fit: VNImageCropAndScaleOption

    var description: String {
        return "FastDepth Neural Processor"
    }

    required init(fit: VNImageCropAndScaleOption = .scaleFill) throws {
        self.model = try VNCoreMLModel(for: FastDepth().model)
        self.fit = fit
    }

    enum ProcessingError: Error {
        case originalImageNotCGImageConvertible
        case requestFailed
        case inferenceFailed
        case normalizationFailed
        case filteringFailed
    }

    func process(
        originalImage: UIImage,
        completion: @escaping (Result<UIImage, Error>) -> Void
    ) {
        guard
            let originalCGImage = originalImage.cgImage
        else {
            completion(.failure(ProcessingError.originalImageNotCGImageConvertible))
            return
        }

        let context = CIContext()

        let request = VNCoreMLRequest(model: model) { request, error in
            guard
                error == nil,
                let observations = request.results as? [VNCoreMLFeatureValueObservation],
                let rawOutput = observations.first?.featureValue.multiArrayValue,
                let output = try? rawOutput.reshaped(to: [1, 224, 224])
            else {
                completion(.failure(ProcessingError.inferenceFailed))
                return
            }

            guard
                let normalizedCGImage = self.normalizedCGImage(output: output)
            else {
                completion(.failure(ProcessingError.normalizationFailed))
                return
            }

            let bilateralFilter = BilateralFilter(
                diffuse: CIImage(cgImage: originalCGImage),
                depth: CIImage(cgImage: normalizedCGImage),
                sigmaR: 30,
                sigmaS: 0.02
            )
            guard
                let filteredCGImage = bilateralFilter.outputCGImage(withContext: context)
            else {
                completion(.failure(ProcessingError.filteringFailed))
                return
            }

            completion(.success(UIImage(cgImage: filteredCGImage)))
        }

        request.imageCropAndScaleOption = fit

        let handler = VNImageRequestHandler(
            cgImage: originalCGImage, options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            completion(.failure(ProcessingError.requestFailed))
            return
        }
    }

    private func normalizedCGImage(output: MLMultiArray) -> CGImage? {
        let height = 224
        let width = 224

        var minValue: Double = .greatestFiniteMagnitude
        var maxValue: Double = 0

        for y in 0 ..< height {
            for x in 0 ..< width {
                let index = y * height + x
                let value = output[index].doubleValue
                minValue = min(minValue, value)
                maxValue = max(maxValue, value)
            }
        }

        // The output needs to be inverted, therefore
        // use maxValue as the minimum and vice versa
        return output.cgImage(min: maxValue, max: minValue)
    }
}
