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


enum CameraCaptureFailure {
    case cameraNotFound
    case captureSetupFailed
}


enum DepthCameraPriority {
    case force
    case prefer
    case reject
}


class CameraViewOrchestrator: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    public let onCapture: (DepthImage?) -> ()
        
    public let captureSession: AVCaptureSession
    
    private var cameraDevice: AVCaptureDevice?
    private var cameraInput: AVCaptureDeviceInput?
    private var cameraOutput: AVCapturePhotoOutput?

    init(onCapture: @escaping (DepthImage?) -> ()) {
        self.onCapture = onCapture
        self.captureSession = AVCaptureSession()
        super.init()
    }
    
    private func getDevice(
        withPosition position: AVCaptureDevice.Position,
        useDepthCamera: Bool
    ) -> AVCaptureDevice? {
        if !useDepthCamera {
            return AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: position
            )
        } else {
            if position == .back {
                for deviceType in [
                    AVCaptureDevice.DeviceType.builtInTripleCamera,
                    AVCaptureDevice.DeviceType.builtInDualCamera
                ] {
                    guard let cameraDevice = AVCaptureDevice.default(
                        deviceType,
                        for: .video,
                        position: .back
                    ) else {continue}
                    return cameraDevice
                }
            } else {
                for deviceType in [
                    AVCaptureDevice.DeviceType.builtInTrueDepthCamera
                ] {
                    guard let cameraDevice = AVCaptureDevice.default(
                        deviceType,
                        for: .video,
                        position: .back
                    ) else {continue}
                    return cameraDevice
                }
            }
        }
        return nil
    }
    
    func startCapturing(
        useFrontFacingCamera: Bool,
        useDepthCamera: Bool,
        completion: @escaping (CameraCaptureFailure?) -> ()
    ) {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo
        
        let devicePosition: AVCaptureDevice.Position = useFrontFacingCamera ? .front : .back
        
        guard
            let cameraDevice = getDevice(
                withPosition: devicePosition,
                useDepthCamera: useDepthCamera
            )
        else {
            captureSession.commitConfiguration()
            completion(.cameraNotFound)
            return
        }
        self.cameraDevice = cameraDevice
        
        guard
            let cameraInput = try? AVCaptureDeviceInput(device: cameraDevice)
        else {
            captureSession.commitConfiguration()
            completion(.captureSetupFailed)
            return
        }
        
        if let oldCameraInput = self.cameraInput {
            captureSession.removeInput(oldCameraInput)
        }
        
        self.cameraInput = cameraInput
        
        guard
            captureSession.canAddInput(cameraInput)
        else {
            captureSession.commitConfiguration()
            completion(.captureSetupFailed)
            return
        }
        captureSession.addInput(cameraInput)
        
        if let oldCameraOutput = self.cameraOutput {
            captureSession.removeOutput(oldCameraOutput)
        }
        
        let cameraOutput = AVCapturePhotoOutput()
        
        guard captureSession.canAddOutput(cameraOutput) else {
            captureSession.commitConfiguration()
            completion(.captureSetupFailed)
            return
        }
        
        captureSession.addOutput(cameraOutput)
        
        if useDepthCamera && !cameraOutput.isDepthDataDeliverySupported {
            captureSession.commitConfiguration()
            completion(.cameraNotFound)
            return
        }

        cameraOutput.isDepthDataDeliveryEnabled = cameraOutput.isDepthDataDeliverySupported
        self.cameraOutput = cameraOutput
        
        captureSession.commitConfiguration()
        captureSession.startRunning()
        completion(nil)
    }
    
    func capturePhoto() {
        guard
            let cameraOutput = cameraOutput
        else {return}
        let supportsHEVC = AVAssetExportSession
            .allExportPresets()
            .contains(AVAssetExportPresetHEVCHighestQuality)
        let photoSettings = AVCapturePhotoSettings(format: [
            AVVideoCodecKey: supportsHEVC ? AVVideoCodecType.hevc : AVVideoCodecType.jpeg
        ])
        photoSettings.isDepthDataDeliveryEnabled = cameraOutput.isDepthDataDeliverySupported
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
            let rotatedImage = image.rotate(radians: 0)
        else {return}
        
        if let depthData = photo.depthData {
            let convertedDepthData = depthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
            let depthMap = convertedDepthData.depthDataMap
            depthMap.normalize()
            
            guard
                let depthMapImage = UIImage(pixelBuffer: depthMap),
                let depthCGImage = depthMapImage.cgImage,
                let rotatedDepthImage = UIImage(cgImage: depthCGImage, scale: 1.0, orientation: image.imageOrientation)
                    .rotate(radians: 0)
            else {return}
            
            let depthImage = DepthImage(diffuse: rotatedImage, depth: rotatedDepthImage, isArtificial: false)
            
            onCapture(depthImage)
        } else {
            guard let depth = image.getPredictedDepth() else {return}
            let depthImage = DepthImage(diffuse: rotatedImage, depth: depth, isArtificial: true)
            onCapture(depthImage)
        }
    }
}



struct CameraView: View {
    @GestureState private var cameraButtonIsPressed = false
    
    @State private var isCapturingDepth = true
    @State private var isUsingFrontfacingCamera = false
    
    @EnvironmentObject var orchestrator: CameraViewOrchestrator

    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(Color.clear)
                .background(Color.black)
            .edgesIgnoringSafeArea(.all)
            
            
            VStack(spacing: 0) {
                CameraPreviewView().environmentObject(orchestrator)
                    .background(Color(hex: "#222222"))
                HStack {
                    Button(action: {
                        let isCapturingDepth = self.isCapturingDepth
                        self.orchestrator.startCapturing(
                            useFrontFacingCamera: self.isUsingFrontfacingCamera,
                            useDepthCamera: !isCapturingDepth
                        ) { (failure) in
                            if let failure = failure {
                                // Notify user of error
                                print(failure)
                            } else {
                                // Successfully switched depth preference
                                self.isCapturingDepth = !isCapturingDepth
                            }
                        }
                    }) {
                        Image(systemName: "rectangle.stack.person.crop.fill")
//                        .foregroundColor(self.isCapturingDepth ? .yellow : .white)
                    }
                    Spacer()
                    Button(action: {
                        UISelectionFeedbackGenerator().selectionChanged()
                        self.orchestrator.capturePhoto()
                    }) {
                        Image(systemName: "camera.viewfinder")
                        .foregroundColor(.black)
                    }
                    .frame(width: 64, height: 64)
                    .buttonStyle(CameraButtonStyle())
                    Spacer()
                    Button(action: {
                        let isUsingFrontfacingCamera = self.isUsingFrontfacingCamera
                        self.orchestrator.startCapturing(
                            useFrontFacingCamera: !isUsingFrontfacingCamera,
                            useDepthCamera: self.isCapturingDepth
                        ) { (failure) in
                            if let failure = failure {
                                // Notify user of error
                                print(failure)
                            } else {
                                // Successfully switched camera
                                self.isUsingFrontfacingCamera = !isUsingFrontfacingCamera
                            }
                        }
                    }) {
                        Image(systemName: "camera.rotate.fill")
//                        .foregroundColor(self.isCapturingDepth ? .yellow : .white)
                    }
                }
                .padding(24)
                .foregroundColor(Color.white)
            }
        }.onAppear() {
            self.orchestrator.startCapturing(
                useFrontFacingCamera: false,
                useDepthCamera: true
            ) { failure in
                if failure != nil {
                    self.orchestrator.startCapturing(
                        useFrontFacingCamera: false,
                        useDepthCamera: false
                    ) { failure in
                        if failure != nil {
                            self.orchestrator.startCapturing(
                                useFrontFacingCamera: false,
                                useDepthCamera: false
                            ) { failure in
                                if let failure = failure {
                                    // Unexpected error
                                    print(failure)
                                } else {
                                    // Successfully chose non depth front facing camera
                                    self.isCapturingDepth = false
                                    self.isUsingFrontfacingCamera = true
                                }
                            }
                        } else {
                            // Successfully chose non depth back facing camera
                            self.isCapturingDepth = false
                            self.isUsingFrontfacingCamera = false
                        }
                    }
                } else {
                    // Successfully chosen depth back facing camera
                    self.isCapturingDepth = true
                    self.isUsingFrontfacingCamera = false
                }
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
