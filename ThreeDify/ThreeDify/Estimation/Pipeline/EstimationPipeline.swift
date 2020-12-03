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
import CoreGraphics

struct ProcessorResult {
    let depthImage: UIImage
    let description: String

    func evaluate(confidenceInImage image: UIImage) -> EvaluatedProcessorResult? {
        guard
            let originalCGImage = image.cgImage,
            let depthCGImage = depthImage.cgImage
        else { return nil }

        let originalCIImage = CIImage(cgImage: originalCGImage)
        let depthCIImage = CIImage(cgImage: depthCGImage)
        let context = CIContext()
        let originalFilter = SobelFilter(image: originalCIImage)
        let depthFilter = SobelFilter(image: depthCIImage)

        guard
            let originalSobelCGImage = originalFilter
                .outputCGImage(withContext: context),
            let depthSobelCGImage = depthFilter
                .outputCGImage(withContext: context)
        else { return nil }

        let rect = CGRect(origin: .zero, size: image.size)
        UIGraphicsBeginImageContext(image.size)
        UIImage(cgImage: originalSobelCGImage).draw(in: rect)
        UIImage(cgImage: depthSobelCGImage)
            .draw(in: rect, blendMode: .difference, alpha: 1)
        defer { UIGraphicsEndImageContext() }
        guard
            let differenceImage = UIGraphicsGetImageFromCurrentImageContext(),
            let differenceCGImage = differenceImage.cgImage
        else { return nil }

        // Compute the RMS of each pixel value
        var pixelData = [UInt8](
            repeating: 0,
            count: Int(image.size.width) * Int(image.size.height) * 4
        )
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard
            let cgContext = CGContext(
                data: &pixelData,
                width: Int(image.size.width),
                height: Int(image.size.height),
                bitsPerComponent: 8,
                bytesPerRow: 4 * Int(image.size.width),
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            )
        else { return nil }
        cgContext.draw(differenceCGImage, in: rect)

        let pixelDataFloatValues = pixelData.map { Float($0) }
        let pixelDataStride = vDSP_Stride(1)
        let pixelDataLength = vDSP_Length(pixelDataFloatValues.count)
        var rms: Float = .nan
        vDSP_rmsqv(pixelDataFloatValues, pixelDataStride, &rms, pixelDataLength)

        return EvaluatedProcessorResult(result: self, rms: rms)
    }
}


struct EvaluatedProcessorResult {
    let depthImage: UIImage
    let description: String
    let rms: Float

    init(result: ProcessorResult, rms: Float) {
        self.depthImage = result.depthImage
        self.description = result.description
        self.rms = rms
    }
}


class EstimationPipeline {
    private let image: UIImage
    private let fcrnProcessor: FCRNProcessor
    private let pydnetProcessor: PydnetProcessor
    private let fastDepthProcessor: FastDepthProcessor

    private var processors: [DepthProcessor] {
        [fcrnProcessor, pydnetProcessor, fastDepthProcessor]
    }

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
        let dispatchGroup = DispatchGroup()

        var results = [ProcessorResult]()
        for processor in processors {
            dispatchGroup.enter()
            processor.process(originalImage: image) { result in
                defer { dispatchGroup.leave() }
                switch result {
                case .failure(let error):
                    print("WARNING: \(processor.description) error: \(error)")
                case .success(let depthImage):
                    results.append(ProcessorResult(
                        depthImage: depthImage,
                        description: processor.description
                    ))
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            guard
                let combinedDepthImage = self.combine(results: results)
            else {
                completion(.failure(ProcessingError.combinationFailed))
                return
            }
            completion(.success(combinedDepthImage))
        }
    }

    func combine(results: [ProcessorResult]) -> UIImage? {
        guard !results.isEmpty else { return nil }

        let evaluatedResults = results.compactMap { result in
            result.evaluate(confidenceInImage: image)
        }

        guard !evaluatedResults.isEmpty else { return nil }

        let rmsValues = evaluatedResults.map { $0.rms }
        guard
            let maxRMS = rmsValues.max(),
            let minRMS = rmsValues.min(),
            maxRMS != minRMS
        else { return nil }

        let rect = CGRect(origin: .zero, size: image.size)
        UIGraphicsBeginImageContext(image.size)
        for result in evaluatedResults {
            let alpha = CGFloat(1 - (result.rms - minRMS) / (maxRMS - minRMS))
            result.depthImage.draw(
                in: rect,
                blendMode: .normal,
                alpha: alpha
            )

            print("DEBUG: Result of \(result.description) has RMSE \(result.rms) and was mapped to an alpha value of \(alpha).")
        }
        defer { UIGraphicsEndImageContext() }
        guard
            let combinedImage = UIGraphicsGetImageFromCurrentImageContext(),
            let normalizedImage = NormalizationFilter(image: combinedImage)
                .normalize()
        else { return nil}

        return normalizedImage
    }
}
