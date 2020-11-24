import SwiftUI

struct ContentView: View {
    @State private var parallaxEnvironment: ParallaxViewEnvironment?
    
    var body: some View {
        Group {
            if let parallaxEnvironment = parallaxEnvironment {
                ParallaxView().environmentObject(parallaxEnvironment)
            } else {
                ProgressView()
            }
        }
        .onAppear(perform: {
            parallaxEnvironment = .init(depthImage: DepthImage(
                diffuseMap: UIImage(named: "6_diffuse")!,
                depthMap: UIImage(named: "6_depth")!
            ))
        })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
