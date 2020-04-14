import SwiftUI
import UIKit


struct ProgressCircle: UIViewRepresentable {
    func makeUIView(context: UIViewRepresentableContext<ProgressCircle>) -> UIActivityIndicatorView {
        return UIActivityIndicatorView(style: .large)
    }
    
    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
        // Do nothing
    }
}


enum LoadingState {
    case hidden
    case loading
    case failed
    case finished
}


struct LoadingView<Content: View>: View {
    @Binding var text: String
    @Binding var loadingState: LoadingState
    var content: () -> Content
    
    var body: some View {
        ZStack {
            self.content()
                .blur(radius: loadingState == .hidden ? 0 : 32)
                .allowsHitTesting(loadingState == .hidden)
            
            if loadingState != .hidden {
                ZStack(alignment: .center) {
                    if loadingState == .loading {
                        ProgressCircle()
                        .frame(width: 64, height: 64)
                        .padding(24)
                    }
                    if loadingState == .failed {
                        Image(systemName: "exclamationmark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                    }
                    if loadingState == .finished {
                        Image(systemName: "checkmark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                    }
                    VStack {
                        Text(text)
                        .padding(.top, 108)
                        .padding(12)
                    }
                }
                .frame(width: 256)
                .foregroundColor(Color.white)
                .background(BlurView(style: .dark))
                .cornerRadius(12)
            }
        }
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            LoadingView(text: .constant("Failed"), loadingState: .constant(.failed)) {
                Text("Hello")
            }
            LoadingView(text: .constant("Finished"), loadingState: .constant(.finished)) {
                Text("Hello")
            }
            LoadingView(text: .constant("Loading..."), loadingState: .constant(.loading)) {
                Text("Hello")
            }
        }
    }
}
