import Foundation
import AVFoundation
import UIKit
import CoreVideo

class CameraSession: NSObject, ObservableObject, Identifiable, AVCapturePhotoCaptureDelegate {
    let id = UUID()
    
    @Published var captureSession = AVCaptureSession()
    @Published var capturedImage: CameraImage?
    @Published var error: Error?
    
    private var cameraDevice: AVCaptureDevice?
    private var cameraInput: AVCaptureDeviceInput?
    private var cameraOutput: AVCapturePhotoOutput?
    
    enum CaptureError: Error {
        case cameraNotFound
        case captureSetupFailed
        case accessDenied
    }
    
    func authorizeAndCapture() {
        authorizeAndCapture(useFrontFacingCamera: true)
    }
    
    func authorizeAndCapture(useFrontFacingCamera: Bool) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCaptureSession(
                useFrontFacingCamera: useFrontFacingCamera
            )
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.setupCaptureSession(
                        useFrontFacingCamera: useFrontFacingCamera
                    )
                } else {
                    self.error = CaptureError.accessDenied
                }
            }
        case .denied:
            error = CaptureError.accessDenied
        default:
            // Try anyways
            setupCaptureSession(
                useFrontFacingCamera: useFrontFacingCamera
            )
        }
    }
    
    func capturePhoto() {
        guard
            let cameraOutput = cameraOutput
        else {return}
        let supportsHEVC = AVAssetExportSession
            .allExportPresets()
            .contains(AVAssetExportPresetHEVCHighestQuality)
        let photoSettings = AVCapturePhotoSettings(format: [
            AVVideoCodecKey: supportsHEVC ?
                AVVideoCodecType.hevc : AVVideoCodecType.jpeg
        ])
        photoSettings.isDepthDataDeliveryEnabled = cameraOutput.isDepthDataDeliverySupported
        cameraOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    private func setupCaptureSession(useFrontFacingCamera: Bool) {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        let devicePosition: AVCaptureDevice.Position = useFrontFacingCamera ?
            .front : .back

        guard
            let cameraDevice = CameraDeviceFinder(position: devicePosition).find()
        else {
            captureSession.commitConfiguration()
            error = CaptureError.cameraNotFound
            return
        }
        self.cameraDevice = cameraDevice

        guard
            let cameraInput = try? AVCaptureDeviceInput(device: cameraDevice)
        else {
            captureSession.commitConfiguration()
            error = CaptureError.captureSetupFailed
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
            error = CaptureError.captureSetupFailed
            return
        }
        captureSession.addInput(cameraInput)

        if let oldCameraOutput = self.cameraOutput {
            captureSession.removeOutput(oldCameraOutput)
        }

        let cameraOutput = AVCapturePhotoOutput()

        guard captureSession.canAddOutput(cameraOutput) else {
            captureSession.commitConfiguration()
            error = CaptureError.captureSetupFailed
            return
        }

        captureSession.addOutput(cameraOutput)

        cameraOutput.isDepthDataDeliveryEnabled = cameraOutput.isDepthDataDeliverySupported
        self.cameraOutput = cameraOutput

        captureSession.commitConfiguration()
        captureSession.startRunning()
    }
        
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            print("WARNING: AVCapturePhotoOutput errored: \(error)")
            self.error = error
            return
        }
        guard
            let depthImage = CameraImageProcessor(output: output, photo: photo)
                .process()
        else {
            print("WARNING: Camera image processor failed.")
            return
        }
        
        capturedImage = depthImage
    }
}
