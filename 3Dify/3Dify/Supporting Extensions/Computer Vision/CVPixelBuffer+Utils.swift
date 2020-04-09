
import CoreVideo
import CoreImage

extension CVPixelBuffer {
    func transformedImage(targetSize: CGSize, rotationAngle: CGFloat) -> CIImage? {
        let image = CIImage(cvPixelBuffer: self, options: [:])
        let scaleFactor = Float(targetSize.width) / Float(image.extent.width)
        return image.transformed(by: CGAffineTransform(rotationAngle: rotationAngle)).applyingFilter("CIBicubicScaleTransform", parameters: ["inputScale": scaleFactor])
    }
    
    func normalize() {

      let width = CVPixelBufferGetWidth(self)
      let height = CVPixelBufferGetHeight(self)

      CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
      let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(self), to: UnsafeMutablePointer<Float>.self)

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

      CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
    }
}
