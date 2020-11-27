//
// 3Dify App
//
// Project website: https://github.com/3dify-app
//
// Authors:
// - Philipp Matthes 2020, Contact: mail@philippmatth.es
//
// Copyright notice: All rights reserved by the authors given above. Do not
// remove or change this copyright notice without confirmation of the authors.
//

import Foundation
import AVFoundation

struct CameraDeviceFinder {
    let position: AVCaptureDevice.Position
    
    func find() -> AVCaptureDevice? {
        findDepthCamera() ?? findRegularCamera()
    }
    
    private func findDepthCamera() -> AVCaptureDevice? {
        if position == .back {
            for deviceType in [
                AVCaptureDevice.DeviceType.builtInTripleCamera,
                AVCaptureDevice.DeviceType.builtInDualCamera
            ] {
                guard let cameraDevice = AVCaptureDevice.default(
                    deviceType,
                    for: .video,
                    position: .back
                ) else { continue }
                return cameraDevice
            }
        } else {
            for deviceType in [
                AVCaptureDevice.DeviceType.builtInTrueDepthCamera
            ] {
                guard let cameraDevice = AVCaptureDevice.default(
                    deviceType,
                    for: .video,
                    position: .front
                ) else { continue }
                return cameraDevice
            }
        }
        return nil
    }
    
    private func findRegularCamera() -> AVCaptureDevice? {
        AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: position
        )
    }
}
