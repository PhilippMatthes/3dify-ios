//
//  ImagePicker.swift
//  3Dify
//
//  Created by It's free real estate on 28.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Photos


class ImagePickerViewOrchestrator: NSObject, ObservableObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public let onCapture: (DepthImage?) -> ()
    
    init(onCapture: @escaping (DepthImage?) -> ()) {
        self.onCapture = onCapture
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        guard let asset = info[UIImagePickerController.InfoKey.phAsset] as? PHAsset else {
            onCapture(nil)
            return
        }
        
        asset.requestDepthImage() {
            depthImage in
            self.onCapture(depthImage)
        }
    }
}


struct ImagePickerView: UIViewControllerRepresentable {
    @EnvironmentObject var orchestrator: ImagePickerViewOrchestrator
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePickerView>) -> UIViewController {
        let status = PHPhotoLibrary.authorizationStatus()
        if status != .authorized {
            PHPhotoLibrary.requestAuthorization() {status in}
        }
        
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        picker.delegate = orchestrator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: UIViewControllerRepresentableContext<ImagePickerView>) {
        // Do nothing
    }
}
