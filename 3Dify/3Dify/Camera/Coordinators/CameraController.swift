//
//  CameraController.swift
//  3Dify
//
//  Created by It's free real estate on 21.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation


class CameraCoordinator: NSObject {
    var captureSession: AVCaptureSession?
    var cameraDevice: AVCaptureDevice?
    var cameraInput: AVCaptureDeviceInput?
    var cameraOutput: AVCapturePhotoOutput?
    
    var captureDelegate: AVCapturePhotoCaptureDelegate?
    
    func prepare(completion: @escaping () -> ()) {
        let captureSession = AVCaptureSession()
        self.captureSession = captureSession
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo
        
        guard
            let cameraDevice = AVCaptureDevice.default(
                .builtInDualCamera,
                for: .video,
                position: .unspecified
            )
        else {return}
        self.cameraDevice = cameraDevice
        
        guard
            let cameraInput = try? AVCaptureDeviceInput(device: cameraDevice)
        else {return}
        self.cameraInput = cameraInput
        
        guard
            captureSession.canAddInput(cameraInput)
        else {return}
        
        captureSession.addInput(cameraInput)
        
        let cameraOutput = AVCapturePhotoOutput()
        
        guard captureSession.canAddOutput(cameraOutput) else {return}
        
        captureSession.addOutput(cameraOutput)

        cameraOutput.isDepthDataDeliveryEnabled = cameraOutput.isDepthDataDeliverySupported
        self.cameraOutput = cameraOutput
        
        captureSession.commitConfiguration()
        captureSession.startRunning()
        
        completion()
    }
    
    func capturePhoto() {
        guard
            let captureDelegate = captureDelegate,
            let cameraOutput = cameraOutput,
            cameraOutput.isDepthDataDeliverySupported
        else {return}
        let photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        photoSettings.isDepthDataDeliveryEnabled = true
        cameraOutput.capturePhoto(with: photoSettings, delegate: captureDelegate)
    }
    
    func displayPreview(on view: UIView) {
        guard
            let captureSession = self.captureSession,
            captureSession.isRunning
        else {return}
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
        previewLayer.frame = view.frame

        view.layer.insertSublayer(previewLayer, at: 0)
    }
}
