//
//  ContentView.swift
//  3Dify
//
//  Created by It's free real estate on 21.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var depthImage: DepthImage?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CameraViewControllerRepresentable(onCapture: { depthImage in
                self.depthImage = depthImage
                self.selectedTab = 1
            })
                .tabItem {
                    Image(systemName: "camera.fill")
                    Text("Camera")
                }.tag(0)
            ImageParallaxViewControllerRepresentable(depthImage: $depthImage)
                .tabItem {
                    Image(systemName: "square.stack.3d.down.right")
                    Text("3Dify")
                }.tag(1)
            ImagePickerViewControllerRepresenable(onPicked: { depthImage in
                self.depthImage = depthImage
                self.selectedTab = 1
            })
                .tabItem {
                    Image(systemName: "person.2.square.stack.fill")
                    Text("Pick Image")
                }.tag(2)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
