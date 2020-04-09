//
//  CameraPreviewView.swift
//  3Dify
//
//  Created by It's free real estate on 28.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import SwiftUI
import AVFoundation


class CaptureVideoPreviewView: UIView {
    private let previewLayer = AVCaptureVideoPreviewLayer()
    
    init(frame: CGRect, session: AVCaptureSession) {
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
        super.init(frame: frame)
        
        layer.addSublayer(previewLayer)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        previewLayer.frame = self.bounds
    }
}


struct CameraPreviewView: UIViewRepresentable {
    typealias UIViewType = UIView
    
    @EnvironmentObject var orchestrator: CameraViewOrchestrator
        
    func makeUIView(context: UIViewRepresentableContext<CameraPreviewView>) -> CameraPreviewView.UIViewType {
        return CaptureVideoPreviewView(frame: .zero, session: orchestrator.captureSession)
    }
    
    func updateUIView(_ view: UIView, context: UIViewRepresentableContext<CameraPreviewView>) {
        // Do nothing
    }
}
