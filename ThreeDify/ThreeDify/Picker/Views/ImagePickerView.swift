//
// 3Dify App
//
// Project website: https://github.com/3dify-app
//
// Authors:
// - It's free real estate 2020, Contact: mail@philippmatth.es
//
// Copyright notice: All rights reserved by the authors given above. Do not
// remove or change this copyright notice without confirmation of the authors.
// 

import SwiftUI

class ImagePickerViewCoordinator: NSObject {
    let parent: ImagePickerView

    init(_ parent: ImagePickerView) {
        self.parent = parent
    }
}

extension ImagePickerViewCoordinator: UINavigationControllerDelegate {
    // Requirement for image picker controller delegate
}

extension ImagePickerViewCoordinator: UIImagePickerControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        parent.presentationMode.wrappedValue.dismiss()
        
        if let uiImage = info[.originalImage] as? UIImage {
            parent.onPickImage(ImagePickerImage(
                diffuseImage: uiImage, depthImage: nil // TODO: Load depth image
            ))
        }
    }
}

struct ImagePickerView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) fileprivate var presentationMode

    let onPickImage: (ImagePickerImage) -> Void

    func makeCoordinator() -> ImagePickerViewCoordinator {
        .init(self)
    }

    func makeUIViewController(
        context: UIViewControllerRepresentableContext<ImagePickerView>
    ) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIImagePickerController,
        context: UIViewControllerRepresentableContext<ImagePickerView>
    ) { /* Protocol Requirement */ }
}
