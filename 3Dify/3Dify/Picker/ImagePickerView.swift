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


struct ImagePickerView: UIViewControllerRepresentable {
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePickerView

        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let asset = info[UIImagePickerController.InfoKey.phAsset] as? PHAsset else {
                parent.presentationMode.wrappedValue.dismiss()
                return
            }
            
            asset.requestDepthImage() {
                depthImage in
                self.parent.image = depthImage
                self.parent.presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    @Environment(\.presentationMode) var presentationMode
    @Binding var image: DepthImage?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePickerView>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePickerView>) {
        // Do nothing
    }
}
