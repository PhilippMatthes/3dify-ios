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

class PydnetProcessor {
    let model: Pydnet

    required init() {
        self.model = Pydnet()
    }

    enum ProcessingError: Error {
        case originalImageNotCGImageConvertible
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
            let originalCGImage = originalImage.cgImage
        else {
            completion(.failure(ProcessingError.originalImageNotCGImageConvertible))
            return
        }

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

        let bilateralFilter = BilateralFilter(
            diffuse: CIImage(cgImage: originalCGImage),
            depth: CIImage(cgImage: outputCGImage),
            sigmaR: 30,
            sigmaS: 0.05
        )
        guard let filteredImage = bilateralFilter.outputImage else {
            completion(.failure(ProcessingError.filteringFailed))
            return
        }

        guard
            let filteredCGImage = context.createCGImage(
                filteredImage, from: filteredImage.extent
            )
        else {
            completion(.failure(ProcessingError.filteringFailed))
            return
        }

        guard
            let finalCGImage = normalize(cgImage: filteredCGImage)
        else {
            completion(.failure(ProcessingError.normalizationFailed))
            return
        }

        completion(.success(UIImage(cgImage: finalCGImage)))
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

    func normalize(cgImage: CGImage) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        var format = vImage_CGImageFormat(
            bitsPerComponent: UInt32(cgImage.bitsPerComponent),
            bitsPerPixel: UInt32(cgImage.bitsPerPixel),
            colorSpace: Unmanaged.passRetained(colorSpace),
            bitmapInfo: cgImage.bitmapInfo,
            version: 0,
            decode: nil,
            renderingIntent: cgImage.renderingIntent
        )

        var source = vImage_Buffer()
        var result = vImageBuffer_InitWithCGImage(
            &source,
            &format,
            nil,
            cgImage,
            vImage_Flags(kvImageNoFlags)
        )

        guard result == kvImageNoError else { return nil }

        defer { free(source.data) }

        var destination = vImage_Buffer()
        result = vImageBuffer_Init(
            &destination,
            vImagePixelCount(cgImage.height),
            vImagePixelCount(cgImage.width),
            32,
            vImage_Flags(kvImageNoFlags)
        )

        guard result == kvImageNoError else { return nil }

        result = vImageContrastStretch_ARGB8888(
            &source,
            &destination,
            vImage_Flags(kvImageNoFlags)
        )

        guard result == kvImageNoError else { return nil }

        defer { free(destination.data) }

        let finalCGImage = vImageCreateCGImageFromBuffer(
            &destination,
            &format,
            nil,
            nil,
            vImage_Flags(kvImageNoFlags),
            nil
        ).takeRetainedValue()

        return finalCGImage
    }
}
