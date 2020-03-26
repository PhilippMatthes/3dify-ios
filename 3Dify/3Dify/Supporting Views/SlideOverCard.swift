//
//  SlideOverCard.swift
//  3Dify
//
//  Created by It's free real estate on 25.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

enum CardPosition: CGFloat {
    case top = 300
    case middle = 450
    case bottom = 548
}

enum DragState {
    case inactive
    case dragging(translation: CGSize)
    
    var translation: CGSize {
        switch self {
        case .inactive:
            return .zero
        case .dragging(let translation):
            return translation
        }
    }
    
    var isDragging: Bool {
        switch self {
        case .inactive:
            return false
        case .dragging:
            return true
        }
    }
}

struct SlideOverCard<Content: View> : View {
    @GestureState private var dragState = DragState.inactive
    
    @State var position = CardPosition.bottom
    
    var springAnimation: Animation? {
        return self.dragState.isDragging ? nil : .interpolatingSpring(stiffness: 300.0, damping: 30.0, initialVelocity: 10.0)
    }
    
    var offset: CGFloat {
        return min(UIScreen.main.bounds.height - 128, self.position.rawValue + self.dragState.translation.height)
    }
    
    var onOffsetChange: (CGFloat) -> ()
    
    var content: () -> Content
    
    var body: some View {
        let drag = DragGesture()
            .updating($dragState) { drag, state, transaction in
                state = .dragging(translation: drag.translation)
                self.onOffsetChange(self.offset)
            }
            .onEnded() { value in
                self.onDragEnded(drag: value)
                self.onOffsetChange(self.offset)
            }
        
        return Group {
            self.content()
        }
        .offset(y: self.offset)
        .animation(self.springAnimation)
        .gesture(drag)
    }
    
    private func onDragEnded(drag: DragGesture.Value) {
        let verticalDirection = drag.predictedEndLocation.y - drag.location.y
        let cardTopEdgeLocation = self.position.rawValue + drag.translation.height
        let positionAbove: CardPosition
        let positionBelow: CardPosition
        let closestPosition: CardPosition
        
        if cardTopEdgeLocation <= CardPosition.middle.rawValue {
            positionAbove = .top
            positionBelow = .middle
        } else {
            positionAbove = .middle
            positionBelow = .bottom
        }
        
        if (cardTopEdgeLocation - positionAbove.rawValue) < (positionBelow.rawValue - cardTopEdgeLocation) {
            closestPosition = positionAbove
        } else {
            closestPosition = positionBelow
        }
        
        if verticalDirection > 0 {
            self.position = positionBelow
        } else if verticalDirection < 0 {
            self.position = positionAbove
        } else {
            self.position = closestPosition
        }
    }
}
