//
//  CameraPreviewView.swift
//  3Dify
//
//  Created by It's free real estate on 28.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    typealias UIViewType = UIView
    
    @EnvironmentObject var orchestrator: CameraViewOrchestrator
    
    private let previewLayer = AVCaptureVideoPreviewLayer()
    
    func makeUIView(context: UIViewRepresentableContext<CameraPreviewView>) -> CameraPreviewView.UIViewType {
        let view = UIView()
            
        previewLayer.session = orchestrator.captureSession
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
        previewLayer.frame = view.frame
        
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ view: UIView, context: UIViewRepresentableContext<CameraPreviewView>) {
        previewLayer.frame = view.frame
    }
}
