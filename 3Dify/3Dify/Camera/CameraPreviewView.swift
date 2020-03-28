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
    
    public var captureSession: AVCaptureSession
    
    private let previewLayer = AVCaptureVideoPreviewLayer()
    
    func makeUIView(context: UIViewRepresentableContext<CameraPreviewView>) -> CameraPreviewView.UIViewType {
        let view = UIView()
            
        previewLayer.session = captureSession
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
        previewLayer.frame = view.frame
        
        view.layer.insertSublayer(previewLayer, at: 0)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<CameraPreviewView>) {
        previewLayer.frame = uiView.frame
    }
}
