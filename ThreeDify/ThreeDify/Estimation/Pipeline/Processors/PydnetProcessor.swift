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
import Accelerate

class PydnetProcessor: DepthProcessor {
    let model: Pydnet

    var description: String {
        return "Pydnet Neural Processor"
    }

    required init() {
        self.model = Pydnet()
    }

    enum ProcessingError: Error {
        case inputPixelBufferCreationFailed
        case inferenceFailed
        case createOutputCGImageFailed
        case filteringFailed
        case normalizationFailed
    }

    func process(
        originalImage: UIImage,
        completion: @escaping (Result<UIImage, Error>) -> Void
    ) {
        guard
            let pixelBuffer = makeInputPixelBuffer(
                fromOriginalImage: originalImage
            )
        else {
            completion(.failure(ProcessingError.inputPixelBufferCreationFailed))
            return
        }

        guard
            let prediction = try? model
                .prediction(im0__0: pixelBuffer)
                .mul__0
        else {
            completion(.failure(ProcessingError.inferenceFailed))
            return
        }

        let context = CIContext()
        let outputImage = CIImage(cvPixelBuffer: prediction)

        guard
            let outputCGImage = context.createCGImage(
                outputImage, from: outputImage.extent
            )
        else {
            completion(.failure(ProcessingError.createOutputCGImageFailed))
            return
        }

        let filteredImage = UIImage(cgImage: outputCGImage)
        guard
            let finalImage = NormalizationFilter(image: filteredImage)
                .normalize()
        else {
            completion(.failure(ProcessingError.normalizationFailed))
            return
        }

        completion(.success(finalImage))
    }

    private func makeInputPixelBuffer(
        fromOriginalImage originalImage: UIImage
    ) -> CVPixelBuffer? {
        // Resize the original image to 384 x 640
        let inputHeight = 384
        let inputWidth = 640
        let rect = CGRect(x: 0, y: 0, width: inputWidth, height: inputHeight)
        UIGraphicsBeginImageContext(rect.size)
        originalImage.draw(in: rect)
        let drawnImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let inputImage = drawnImage else { return nil }

        // Create a new pixel buffer with float32 BGRA pixel format
        var pixelBufferCreationOutput : CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(inputImage.size.width),
            Int(inputImage.size.height),
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
            ] as CFDictionary,
            &pixelBufferCreationOutput
        )
        guard
            status == kCVReturnSuccess,
            let createdPixelBuffer = pixelBufferCreationOutput
        else { return nil }

        return createdPixelBuffer
    }
}
