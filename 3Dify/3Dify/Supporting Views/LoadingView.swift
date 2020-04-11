import SwiftUI

struct ProgressCircle: View {
    @State var angle: Double = 0.0
    
    var foreverAnimation: Animation {
        Animation
            .linear(duration: 0.5)
            .repeatForever(autoreverses: false)
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 5)
                .opacity(0.1)
                .foregroundColor(Color.white)
            
            Circle()
                .trim(from: 0.0, to: 0.75)
                .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .foregroundColor(Color.white)
                .rotationEffect(Angle(degrees: self.angle))
                .onAppear {
                    withAnimation {
                        self.angle += 360
                    }
                }
                .animation(foreverAnimation)
        }
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
        Color.black
        .edgesIgnoringSafeArea(.vertical)
        .overlay(
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
                    .background(Color.black)
                    .cornerRadius(12)
                }
            }
        )
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            LoadingView(text: .constant("Failed"), loadingState: .constant(.failed)) {
                VStack {
                    Text("Hello")
                }
            }
            LoadingView(text: .constant("Finished"), loadingState: .constant(.finished)) {
                VStack {
                    Text("Hello")
                }
            }
            LoadingView(text: .constant("Loading..."), loadingState: .constant(.loading)) {
                VStack {
                    Text("Hello")
                }
            }
        }
    }
}
