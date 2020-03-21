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
            let imageData = photo.fileDataRepresentation()
        else {return}
        let convertedDepthData = depthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
        let map = convertedDepthData.depthDataMap
        map.normalize()
        let ciImage = CIImage(cvPixelBuffer: map)
        let depthImageData = UIImage(ciImage: ciImage).jpegData(compressionQuality: 1.0)!
        let depthImage = UIImage(data: depthImageData)
        let image = UIImage(data: imageData)
        
        depthImageView.image = depthImage
        
        let imageViewController = ImageViewController()
        imageViewController.depthImage = depthImage
        imageViewController.image = image
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
