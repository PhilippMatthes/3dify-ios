//
//  View+BackgroundIgnoringSafeArea.swift
//  3Dify
//
//  Created by It's free real estate on 12.04.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import Foundation
import SwiftUI

extension View {
    @inlinable public func background<Background>(
        _ background: Background,
        edgesIgnoringSafeArea edges: Edge.Set
    ) -> some View where Background : View {
        return background
        .edgesIgnoringSafeArea(edges)
        .overlay(self)
    }
}
