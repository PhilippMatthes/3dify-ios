//
// 3Dify App
//
// Project website: https://github.com/3dify-app
//
// Authors:
// - It's free real estate 2020, Contact: <#T##email: String##String#>
//
// Copyright notice: All rights reserved by the authors given above. Do not
// remove or change this copyright notice without confirmation of the authors.
// 

import Foundation
import UIKit
import Accelerate

struct NormalizationFilter {
    let image: UIImage

    func normalize() -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

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

        return UIImage(cgImage: finalCGImage)
    }
}
