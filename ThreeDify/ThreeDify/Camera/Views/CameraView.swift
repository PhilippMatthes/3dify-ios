import SwiftUI

struct CameraView: View {
    private let session = CameraSession()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            CameraPreviewView()
            CameraSnapshotButton()
                .padding(.bottom, 48)
        }
        .environmentObject(session)
        .onAppear(perform: session.authorizeAndCapture)
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
    }
}
