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
    
    var body: some View {
        Group {
            if let parallaxEnvironment = parallaxEnvironment {
                GeometryReader { proxy in
                    ParallaxView()
                        .environmentObject(parallaxEnvironment)
                }
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
