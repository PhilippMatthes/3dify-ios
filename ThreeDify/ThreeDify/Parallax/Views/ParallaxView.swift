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

struct ParallaxView: View {
    @EnvironmentObject private var environment: ParallaxViewEnvironment
    
    private var wrappedView: some View {
        ParallaxMetalViewRepresentable()
    }
    
    var body: some View {
        GeometryReader { geometry in
            let frame = geometry.frame(in: .local)
            let viewAspectRatio = frame.size.height / frame.size.width
            let imageHeight = environment.parallaxImage.diffuseMap.size.height
            let imageWidth = environment.parallaxImage.diffuseMap.size.width
            let imageAspectRatio = imageHeight / imageWidth
            
            if imageAspectRatio > viewAspectRatio {
                let bestFitWidth = frame.width
                let bestFitHeight = frame.width * imageAspectRatio
                wrappedView.frame(width: bestFitWidth, height: bestFitHeight)
            } else {
                let bestFitWidth = frame.height / imageAspectRatio
                let bestFitHeight = frame.height
                wrappedView.frame(width: bestFitWidth, height: bestFitHeight)
            }
        }
    }
}

fileprivate struct ParallaxMetalViewRepresentable: UIViewRepresentable {
    @EnvironmentObject private var environment: ParallaxViewEnvironment
    
    func makeUIView(
        context: UIViewRepresentableContext<ParallaxMetalViewRepresentable>
    ) -> ParallaxMetalView {
        ParallaxMetalView(environment: environment)
    }
    
    func updateUIView(
        _ view: ParallaxMetalView,
        context: UIViewRepresentableContext<ParallaxMetalViewRepresentable>
    ) {
        if view.environment != environment {
            view.environment = environment
        }
    }
}
