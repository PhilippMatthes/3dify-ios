//
//  AIDepthExplanationView.swift
//  3Dify
//
//  Created by It's free real estate on 04.04.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import SwiftUI

struct AIDepthExplanationView: View {
    @Binding var depthImage: DepthImage
    @State var normalizedHandlePosition: CGFloat = 1
    
    var foreverAnimation: Animation {
        Animation
            .easeInOut(duration: 5)
            .repeatForever(autoreverses: true)
    }
    
    func offset(
        forFrameWidth frameWidth: CGFloat,
        inFrameWidth contentFrameWidth: CGFloat,
        isCalculatedFromRightEdge: Bool
    ) -> CGFloat {
        let centerPosition = isCalculatedFromRightEdge ? contentFrameWidth - frameWidth / 2 : frameWidth / 2
        let targetPosition = contentFrameWidth / 2
        return targetPosition - centerPosition
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                HStack(spacing: 0) {
                    Image(uiImage: self.depthImage.diffuse)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .offset(x: self.offset(forFrameWidth: self.normalizedHandlePosition * geometry.size.width, inFrameWidth: geometry.size.width, isCalculatedFromRightEdge: false))
                    .frame(width: self.normalizedHandlePosition * geometry.size.width)
                    .clipped()
                        
                    Image(uiImage: self.depthImage.depth)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .offset(x: 0)
                    .offset(x: self.offset(forFrameWidth: (1 - self.normalizedHandlePosition) * geometry.size.width, inFrameWidth: geometry.size.width, isCalculatedFromRightEdge: true))
                    .frame(width: (1 - self.normalizedHandlePosition) * geometry.size.width)
                    .clipped()
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Artificial Depth")
                        .font(.largeTitle)
                    Text("The depth of your photo is generated on-device by an artifical intelligence.")
                        .font(.headline)
                    Text("Use a front facing TrueDepth camera or a back facing camera in Portrait mode, if supported by your device, to experience real depth.")
                        .font(.subheadline)
                }
                .padding(24)
                .foregroundColor(.white)
                .background(Color.black.opacity(0.2))
                .cornerRadius(24)
                .padding(12)
            }
        }
        .onAppear() {
            withAnimation {
                self.normalizedHandlePosition = 0
            }
        }
        .animation(foreverAnimation)
    }
}

struct ExplanationView_Previews: PreviewProvider {
    static var previews: some View {
        AIDepthExplanationView(depthImage: .constant(DepthImage(diffuse: UIImage(named: "mango-image")!, depth: UIImage(named: "mango-depth")!, isArtificial: false)))
    }
}
