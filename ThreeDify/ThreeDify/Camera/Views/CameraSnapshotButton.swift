import SwiftUI

struct CameraSnapshotButton: View {
    @EnvironmentObject private var session: CameraSession
    
    private struct Style: ButtonStyle {
        func makeBody(configuration: Self.Configuration) -> some View {
            configuration.label
                .contentShape(Circle())
                .background(
                    ZStack {
                        Circle()
                        Circle()
                            .fill(Color.black)
                            .padding(configuration.isPressed ? 2 : 4)
                        Circle()
                            .padding(configuration.isPressed ? 12 : 6)
                    }
                    .frame(width: 64, height: 64)
                )
                .animation(.interpolatingSpring(stiffness: 300.0, damping: 20.0, initialVelocity: 10.0))
        }
    }
    
    private func onTap() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        session.capturePhoto()
    }
    
    var body: some View {
        Button(action: onTap) {
            Image(systemName: "camera.viewfinder")
                .resizable()
                .scaledToFit()
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(Self.Style())
    }
}

struct CameraSnapshotButton_Previews: PreviewProvider {
    static var previews: some View {
        CameraSnapshotButton()
            .environmentObject(CameraSession())
    }
}
