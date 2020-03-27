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
    let cameraCoordinator = CameraCoordinator()
    
    @State var selectedTab = 0
    @State var depthImage: DepthImage?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if selectedTab == 0 {
                CameraViewControllerRepresentable(cameraCoordinator: cameraCoordinator, onCapture: { depthImage in
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    self.depthImage = depthImage
                    self.selectedTab = 1
                })
            } else if selectedTab == 1 {
                ImageParallaxView(depthImage: $depthImage)
            } else if selectedTab == 2 {
                ImagePickerViewControllerRepresenable(onPicked: { depthImage in
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    self.depthImage = depthImage
                    self.selectedTab = 1
                })
            }
            
            TabBar(onTabSelected: { tab in
                UISelectionFeedbackGenerator().selectionChanged()
                if (tab == 0 && self.selectedTab == 0) {
                    self.cameraCoordinator.capturePhoto()
                }
                self.selectedTab = tab
            }, selectedTab: self.$selectedTab)
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(selectedTab: 2)
    }
}
