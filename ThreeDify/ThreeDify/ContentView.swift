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

    @State private var image = UIImage(named: "test_7")!

    private func runInference() {
        try! EstimationPipeline(image: image).estimate { result in
            switch result {
            case .success(let depthImage):
                parallaxEnvironment = .init(depthImage: DepthImage(diffuseMap: image, depthMap: depthImage))
            case .failure(let error):
                fatalError(error.localizedDescription)
            }
        }
    }
    
    var body: some View {
        Group {
            if let parallaxEnvironment = parallaxEnvironment {
                GeometryReader { proxy in
                    ParallaxView()
                        .environmentObject(parallaxEnvironment)
                }
            } else {
                ProgressView()
                    .onAppear(perform: runInference)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
