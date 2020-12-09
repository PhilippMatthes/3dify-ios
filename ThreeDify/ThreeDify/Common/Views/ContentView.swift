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

struct ContentView: View {
    @State private var parallaxEnvironment: ParallaxViewEnvironment?

    @State private var isProcessing = false
    @State private var processingFailure: ProcessingFailure?

    struct ProcessingFailure: Identifiable {
        let description: String

        init(description: String) {
            self.description = description
        }

        init(error: Error) {
            self.description = error.localizedDescription
        }

        var id: String { description }
    }

    private func onSelect<I>(image: I) where I: SelectionImage {
        if let depthImage = image.depthImage {
            // The selected image contains depth information
            parallaxEnvironment = .init(parallaxImage: ParallaxImage(
                diffuseMap: image.diffuseImage, depthMap: depthImage
            ))
            return
        }

        let queue = DispatchQueue(label: "inference", qos: .userInitiated)

        // Run inference and estimate the depth map
        isProcessing = true
        queue.async {
            do {
                try EstimationPipeline(image: image.diffuseImage).estimate { newResults in

                } completion: { result in
                    defer { isProcessing = false }
                    switch result {
                    case .success(let depthImage):
                        parallaxEnvironment = .init(parallaxImage: ParallaxImage(
                            diffuseMap: image.diffuseImage, depthMap: depthImage
                        ))
                    case .failure(let error):
                        processingFailure = .init(error: error)
                    }
                }
            } catch let error {
                processingFailure = .init(error: error)
            }
        }
    }

    var body: some View {
        NavigationView {
            if let environment = parallaxEnvironment {
                ParallaxView().environmentObject(environment)
            } else {
                VStack {
                    Spacer()
                    NavigationLink(destination: CameraView(onCaptureImage: onSelect)) {
                        Text("Camera")
                    }
                    Spacer()
                    NavigationLink(destination: ImagePickerView(onPickImage: onSelect)) {
                        Text("Pick Image")
                    }
                    Spacer()
                }
            }
        }
        .alert(item: $processingFailure) { failure in
            Alert(
                title: Text("Image processing failed."),
                message: Text("Failure: \(failure.description)"),
                dismissButton: .default(Text("Ok"))
            )
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
