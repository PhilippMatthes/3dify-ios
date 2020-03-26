//
//  CardView.swift
//  volume
//
//  Created by It's free real estate on 13.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import SwiftUI

struct CardView<F: ShapeStyle>: View {
    var topLeftCornerRadius: CGFloat = 32
    var topRightCornerRadius: CGFloat = 32
    var nodgeOffset: CGFloat
    @Binding var nodgeHeight: CGFloat
    @Binding var nodgeWidth: CGFloat
    var fill: F
    
    var body: some View {
        GeometryReader { geometry in
            SimilarShape(path: Path { path in
                let frame = geometry.frame(in: .local)
                let centerX = self.nodgeOffset + frame.minX + (frame.maxX - frame.minX) / 2
                let nodgeBottomY = frame.minY + self.nodgeHeight
                
                // Bottom left
                path.move(to: CGPoint(x: frame.minX, y: frame.maxY))
                
                // Top left
                path.addLine(to: CGPoint(x: frame.minX, y: frame.minY))
                
                // Nodge
                path.addLine(to: CGPoint(x: centerX - (self.nodgeWidth / 2), y: frame.minY))
                path.addCurve(
                    to: CGPoint(x: centerX, y: nodgeBottomY),
                    control1: CGPoint(x: centerX - (self.nodgeWidth / 4), y: frame.minY),
                    control2: CGPoint(x: centerX - (self.nodgeWidth / 4), y: nodgeBottomY)
                )
                path.addCurve(
                    to: CGPoint(x: centerX + (self.nodgeWidth / 2), y: frame.minY),
                    control1: CGPoint(x: centerX + (self.nodgeWidth / 4), y: nodgeBottomY),
                    control2: CGPoint(x: centerX + (self.nodgeWidth / 4), y: frame.minY)
                )
                
                
                // Top right
                path.addLine(to: CGPoint(x: frame.maxX, y: frame.minY))
                
                // Bottom right
                path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
                
                // Bottom edge
                path.addLine(to: CGPoint(x: frame.minX, y: frame.maxY))
            })
            .fill(self.fill)
        }
    }
}
