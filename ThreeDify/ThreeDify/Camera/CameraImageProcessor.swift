import Foundation
import AVFoundation
import UIKit


struct CameraImageProcessor {
    let output: AVCapturePhotoOutput
    let photo: AVCapturePhoto
    
    func process() -> CameraImage? {
        guard
            let photoFileData = photo.fileDataRepresentation(),
            let image = UIImage(data: photoFileData)
        else { return nil }
        
        guard
            let reorientedImage = reorient(image: image)
        else { return nil }
        
        guard
            let depthData = photo.depthData
        else { return .init(diffuseImage: reorientedImage, depthImage: nil) }
        
        // Covert depth data to ui image
        let convertedDepthData = depthData.converting(
            toDepthDataType: kCVPixelFormatType_DisparityFloat32
        )
        var depthMap = convertedDepthData.depthDataMap
        normalize(depthMap: &depthMap)
        let depthCIImage = CIImage(cvPixelBuffer: depthMap)
        let depthPixelBufferWidth = CGFloat(CVPixelBufferGetWidth(depthMap))
        let depthPixelBufferHeight = CGFloat(CVPixelBufferGetHeight(depthMap))
        let depthImageRect = CGRect(
            x: 0, y: 0, width: depthPixelBufferWidth, height: depthPixelBufferHeight
        )
        let depthCIContext = CIContext.init()
        guard
            let depthCGImage = depthCIContext
                .createCGImage(depthCIImage, from: depthImageRect)
        else {
            print("WARNING: Depth map conversion to UIImage failed")
            return .init(diffuseImage: reorientedImage, depthImage: nil)
        }
        // Create the depth UIImage, but make sure it has
        // the same orientation of the input photo
        let depthImage = UIImage(
            cgImage: depthCGImage,
            scale: 1.0,
            orientation: image.imageOrientation
        )
        // Then reorient the depth image as well
        // so that is is aligned with the photo
        let reorientedDepthImage = reorient(image: depthImage)
        return .init(diffuseImage: reorientedImage, depthImage: reorientedDepthImage)
    }
    
    /// Reorient an UIImage such that it is directed upwards.
    private func reorient(image: UIImage) -> UIImage? {
        let radians = 0
        var newSize = CGRect(
            origin: CGPoint.zero,
            size: image.size
        ).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        let context = UIGraphicsGetCurrentContext()!

        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians))
        // Draw the image at its center
        image.draw(in: CGRect(
            x: -image.size.width/2,
            y: -image.size.height/2,
            width: image.size.width,
            height: image.size.height
        ))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    /// Normalize a pixel buffer between 0 and 1.
    private func normalize(depthMap: inout CVPixelBuffer) {
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        CVPixelBufferLockBaseAddress(depthMap, CVPixelBufferLockFlags(rawValue: 0))
        let floatBuffer = unsafeBitCast(
            CVPixelBufferGetBaseAddress(depthMap),
            to: UnsafeMutablePointer<Float>.self
        )

        var minPixel: Float = 1.0
        var maxPixel: Float = 0.0

        for y in 0 ..< height {
            for x in 0 ..< width {
                let pixel = floatBuffer[y * width + x]
                minPixel = min(pixel, minPixel)
                maxPixel = max(pixel, maxPixel)
            }
        }

        let range = maxPixel - minPixel

        for y in 0 ..< height {
            for x in 0 ..< width {
                let pixel = floatBuffer[y * width + x]
                floatBuffer[y * width + x] = (pixel - minPixel) / range
            }
        }

        CVPixelBufferUnlockBaseAddress(depthMap, CVPixelBufferLockFlags(rawValue: 0))
    }
}
