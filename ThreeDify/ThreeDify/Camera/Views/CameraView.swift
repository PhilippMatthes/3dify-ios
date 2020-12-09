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

struct CameraView: View {
    @Environment(\.presentationMode) private var presentationMode

    private let session = CameraSession()

    let onCaptureImage: (CameraImage) -> Void
    
    var body: some View {
        ZStack(alignment: .bottom) {
            CameraPreviewView()
            CameraSnapshotButton()
                .padding(.bottom, 48)
        }
        .environmentObject(session)
        .onAppear(perform: session.authorizeAndCapture)
        .onChange(of: session.capturedImage, perform: { image in
            guard let image = image else { return }
            presentationMode.wrappedValue.dismiss()
            onCaptureImage(image)
        })
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView() { _ in }
    }
}
