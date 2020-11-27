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

import SwiftUI
import AVFoundation

class CameraVideoPreviewLayerView: UIView {
    let previewLayer = AVCaptureVideoPreviewLayer()
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

struct CameraPreviewView: UIViewRepresentable {
    @EnvironmentObject private var session: CameraSession
    
    func makeUIView(
        context: UIViewRepresentableContext<CameraPreviewView>
    ) -> CameraVideoPreviewLayerView {
        let view = CameraVideoPreviewLayerView()
        view.previewLayer.session = session.captureSession
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.connection?.videoOrientation = .portrait
        view.layer.addSublayer(view.previewLayer)
        return view
    }
    
    func updateUIView(
        _ view: CameraVideoPreviewLayerView,
        context: UIViewRepresentableContext<CameraPreviewView>
    ) {
        if view.previewLayer.session != session.captureSession {
            view.previewLayer.session = session.captureSession
        }
    }
}
