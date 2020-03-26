//
//  TabBar.swift
//  3Dify
//
//  Created by It's free real estate on 25.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import SwiftUI


struct TabBar: View {
    
    var onTabSelected: ((Int) -> ())? = nil
    
    @Binding var selectedTab: Int {
        didSet {
            onTabSelected?(selectedTab)
        }
    }
    
    var nodgeOffset: CGFloat {
        if selectedTab == 0 {
            return -UIScreen.main.bounds.width / 3
        }
        if selectedTab == 1 {
            return 0
        }
        if selectedTab == 2 {
            return UIScreen.main.bounds.width / 3
        }
        fatalError()
    }
    
    @State var nodgeWidth: CGFloat = 128
    @State var nodgeHeight: CGFloat = 38
    
    var springAnimation: Animation {
        .interpolatingSpring(stiffness: 300.0, damping: 30.0, initialVelocity: 10.0)
    }
    
    var body: some View {
        ZStack {
            VStack {
                Spacer()
                CardView(
                    nodgeOffset: nodgeOffset,
                    nodgeHeight: $nodgeHeight,
                    nodgeWidth: $nodgeWidth,
                    fill: Color.white
                )
                .frame(height: 64)
            }
            HStack {
                Spacer()
                    .frame(width: 34)
                Button(action: {
                    withAnimation(self.springAnimation) {
                        self.selectedTab = 0
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.5))
                            .opacity(selectedTab == 0 ? 1 : 0)
                            .offset(x: 0, y: selectedTab == 0 ? 0 : 42)
                            .frame(width: selectedTab == 0 ? 58 : 42)
                        Circle()
                            .fill(Color.white)
                            .opacity(selectedTab == 0 ? 1 : 0)
                            .offset(x: 0, y: selectedTab == 0 ? 0 : 42)
                            .frame(width: 48)
                        Image(systemName: "camera.fill")
                            .imageScale(.large)
                            .accentColor(selectedTab == 0 ? Color.black : Color.gray.opacity(0.5))
                            .offset(x: 0, y: selectedTab == 0 ? 0 : 28)
                    }
                }
                Spacer()
                Button(action: {
                    withAnimation(self.springAnimation) {
                        self.selectedTab = 1
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.5))
                            .opacity(selectedTab == 1 ? 1 : 0)
                            .offset(x: 0, y: selectedTab == 1 ? 0 : 42)
                            .frame(width: selectedTab == 1 ? 58 : 42)
                        Circle()
                            .fill(Color.white)
                            .opacity(selectedTab == 1 ? 1 : 0)
                            .offset(x: 0, y: selectedTab == 1 ? 0 : 42)
                            .frame(width: 48)
                        Image(systemName: "square.stack.3d.down.right")
                            .imageScale(.large)
                            .accentColor(selectedTab == 1 ? Color.black : Color.gray.opacity(0.5))
                            .offset(x: 0, y: selectedTab == 1 ? 0 : 28)
                    }
                }
                Spacer()
                Button(action: {
                    withAnimation(self.springAnimation) {
                        self.selectedTab = 2
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.5))
                            .opacity(selectedTab == 2 ? 1 : 0)
                            .offset(x: 0, y: selectedTab == 2 ? 0 : 42)
                            .frame(width: selectedTab == 2 ? 58 : 42)
                        Circle()
                            .fill(Color.white)
                            .opacity(selectedTab == 2 ? 1 : 0)
                            .offset(x: 0, y: selectedTab == 2 ? 0 : 42)
                            .frame(width: 48)
                        Image(systemName: "person.2.square.stack.fill")
                            .imageScale(.large)
                            .accentColor(selectedTab == 2 ? Color.black : Color.gray.opacity(0.5))
                            .offset(x: 0, y: selectedTab == 2 ? 0 : 28)
                    }
                }
                Spacer()
                    .frame(width: 34)
            }
        }
        .frame(height: 128)
    }
}

struct TabBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            TabBar(selectedTab: .constant(1))
        }
        .background(Color.red)
        .edgesIgnoringSafeArea(.bottom)
    }
}
