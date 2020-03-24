//
//  CameraViewController.swift
//  3Dify
//
//  Created by It's free real estate on 21.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI
import AVFoundation
import SpriteKit


internal extension UIImage {
    func blurred(radius: CGFloat) -> UIImage {
        let ciContext = CIContext(options: nil)
        guard let cgImage = cgImage else { return self }
        let inputImage = CIImage(cgImage: cgImage)
        guard let ciFilter = CIFilter(name: "CIGaussianBlur") else { return self }
        ciFilter.setValue(inputImage, forKey: kCIInputImageKey)
        ciFilter.setValue(radius, forKey: "inputRadius")
        guard let resultImage = ciFilter.value(forKey: kCIOutputImageKey) as? CIImage else { return self }
        guard let cgImage2 = ciContext.createCGImage(resultImage, from: inputImage.extent) else { return self }
        return UIImage(cgImage: cgImage2)
    }
    
    func fixOrientation() -> UIImage? {
        if self.imageOrientation == UIImage.Orientation.up {
            return self
        }

        UIGraphicsBeginImageContext(self.size)
        self.draw(in: CGRect(origin: .zero, size: self.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage
    }
}


internal extension CVPixelBuffer {
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
    
    return
  }
}


final class CameraViewController: UIViewController {
    let cameraController = CameraController()
    let previewView = UIView()
    let button = UIButton()
    
    private let onCapture: ((DepthImage) -> ())
    
    init(onCapture: @escaping ((DepthImage) -> ())) {
        self.onCapture = onCapture
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        previewView.frame = .init(
            x: 0,
            y: 0,
            width: UIScreen.main.bounds.width,
            height: UIScreen.main.bounds.height
        )
        previewView.contentMode = .scaleAspectFit
        view.addSubview(previewView)
        
        button.frame = .init(x: 12, y: 12, width: 128, height: 32)
        button.setTitle("Capture", for: .normal)
        button.backgroundColor = .blue
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        view.addSubview(button)
        
        cameraController.captureDelegate = self
        cameraController.prepare() {
            self.cameraController.displayPreview(on: self.previewView)
        }
    }
    
    @objc func capturePhoto() {
        cameraController.capturePhoto()
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard
            error == nil,
            let colorImageData = photo.fileDataRepresentation(),
            let image = UIImage(data: colorImageData),
            let depthData = photo.depthData
        else {return}
        
        let convertedDepthData = depthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
        let depthMap = convertedDepthData.depthDataMap
        depthMap.normalize()
        
        guard
            let depthMapImage = UIImage(pixelBuffer: depthMap),
            let depthCGImage = depthMapImage.cgImage,
            let rotatedDepthImage = UIImage(cgImage: depthCGImage, scale: 1.0, orientation: image.imageOrientation)
                .rotate(radians: 0),
            let rotatedImage = image.rotate(radians: 0)
        else {return}
                
        onCapture(DepthImage(diffuse: rotatedImage, depth: rotatedDepthImage))
    }
}

struct CameraViewControllerRepresentable: UIViewControllerRepresentable {
    public typealias UIViewControllerType = CameraViewController
    
    let onCapture: ((DepthImage) -> ())
    
    public func makeUIViewController(
        context: UIViewControllerRepresentableContext<CameraViewControllerRepresentable>
    ) -> CameraViewController {
        return CameraViewController(onCapture: onCapture)
    }
    
    public func updateUIViewController(_ uiViewController: CameraViewController, context: UIViewControllerRepresentableContext<CameraViewControllerRepresentable>) {
        // Do nothing
    }
}
