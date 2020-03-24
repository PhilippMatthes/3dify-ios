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
  }
}


final class CameraViewController: UIViewController {
    let cameraController = CameraController()
    let previewView = UIView()
    let button = UIButton()
    let depthImageView = UIImageView()
    
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
        
        depthImageView.frame = .init(
            x: 0,
            y: 0,
            width: UIScreen.main.bounds.width,
            height: UIScreen.main.bounds.height
        )
        depthImageView.contentMode = .scaleAspectFit
        view.addSubview(depthImageView)
        
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
            let depthData = photo.depthData,
            let colorImageData = photo.fileDataRepresentation(),
            let colorUIImage = UIImage(data: colorImageData)
        else {return}
        
        let convertedDepthData = depthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
        let depthMap = convertedDepthData.depthDataMap
        depthMap.normalize()
        
        let depthCIImage = CIImage(cvPixelBuffer: depthMap)
        
        guard
            let depthImageData = UIImage(ciImage: depthCIImage)
                .jpegData(compressionQuality: 1.0),
            let depthUIImage = UIImage(data: depthImageData)?
                .blurred(radius: 4)
        else {return}
        
        depthImageView.image = depthUIImage
        
        let imageViewController = ImageViewController()
        imageViewController.imageDepth = depthUIImage
        imageViewController.image = colorUIImage
        present(imageViewController, animated: true)
    }
}

extension CameraViewController: UIViewControllerRepresentable {
    public typealias UIViewControllerType = CameraViewController
    
    public func makeUIViewController(
        context: UIViewControllerRepresentableContext<CameraViewController>
    ) -> CameraViewController {
        return CameraViewController()
    }
    
    public func updateUIViewController(_ uiViewController: CameraViewController, context: UIViewControllerRepresentableContext<CameraViewController>) {
        // Do nothing
    }
}
