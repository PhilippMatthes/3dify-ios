//
//  CameraView.swift
//  3Dify
//
//  Created by It's free real estate on 28.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Photos

struct CameraButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .contentShape(Circle())
            .background(
                ZStack {
                    Circle()
                    Circle()
                        .fill(Color.black)
                        .padding(configuration.isPressed ? 2 : 4)
                    Circle()
                        .padding(configuration.isPressed ? 12 : 6)
                }
                .frame(width: 64, height: 64)
            )
            .animation(.interpolatingSpring(stiffness: 300.0, damping: 20.0, initialVelocity: 10.0))
    }
}


class CameraViewOrchestrator: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    public let onCapture: (DepthImage?) -> ()
    
    public var captureSession: AVCaptureSession!
    
    private var cameraDevice: AVCaptureDevice?
    private var cameraInput: AVCaptureDeviceInput?
    private var cameraOutput: AVCapturePhotoOutput?

    init(onCapture: @escaping (DepthImage?) -> ()) {
        self.captureSession = AVCaptureSession()
        self.onCapture = onCapture
        
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
    }
    
    func capturePhoto() {
        guard
            let cameraOutput = cameraOutput,
            cameraOutput.isDepthDataDeliverySupported
        else {return}
        let photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        photoSettings.isDepthDataDeliveryEnabled = true
        cameraOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
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
        
        let depthImage = DepthImage(diffuse: rotatedImage, trueDepth: rotatedDepthImage)
        
        onCapture(depthImage)
    }
}



struct CameraView: View {
    @GestureState private var cameraButtonIsPressed = false
    
    @EnvironmentObject var orchestrator: CameraViewOrchestrator

    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(Color.clear)
                .background(Color.black)
            .edgesIgnoringSafeArea(.all)
            
            
            VStack(spacing: 0) {
                CameraPreviewView(captureSession: orchestrator.captureSession)
                    .background(Color(hex: "#222222"))
                VStack {
                    Button(action: {
                        UISelectionFeedbackGenerator().selectionChanged()
                        self.orchestrator.capturePhoto()
                    }) {
                        Text("")
                    }
                    .frame(width: 64, height: 64)
                    .buttonStyle(CameraButtonStyle())
                }
                .padding(18)
                .foregroundColor(Color.white)
            }
        }
    }
}

struct CameraView_Previews: PreviewProvider {    
    static var previews: some View {
        CameraView().environmentObject(CameraViewOrchestrator() {
            _ in
        })
    }
}
