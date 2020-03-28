//
//  ContentView.swift
//  3Dify
//
//  Created by It's free real estate on 21.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import SwiftUI
import AVFoundation


struct FatButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(configuration.isPressed ? 0.5 : 0.9))
        )
        .animation(.interpolatingSpring(stiffness: 300.0, damping: 20.0, initialVelocity: 10.0))
    }
}

struct OutlinedFatButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
        .padding(14)
        .overlay(RoundedRectangle(cornerRadius: 24)
        .stroke(Color.white.opacity(configuration.isPressed ? 0.5 : 0.9), lineWidth: 2))
        .animation(.interpolatingSpring(stiffness: 300.0, damping: 20.0, initialVelocity: 10.0))
    }
}


struct ContentView: View {
    enum AnimationState {
        case homeScreen
        case editScreen
    }
    
    @State private var captureSession = AVCaptureSession()
    @State private var didCommitImage = false
    @State private var isShowingImagePicker = false
    @State private var isShowingCamera = false
    
    @State var depthImage: DepthImage?
    
    func commitImage() {
        withAnimation {
            self.didCommitImage = true
        }
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    ImageParallaxView(depthImage: self.$depthImage)
                    .background(Color.red)
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    
                    VStack {
                        Spacer()
                        Text("3Dify")
                            .font(.system(size: 100))
                            .foregroundColor(Color.white)
                        Button(action: {self.isShowingImagePicker = true}) {
                            HStack {
                                Spacer()
                                Image(systemName: "cube.box.fill")
                                Text("Pick an existing photo")
                                Spacer()
                            }
                        }
                        .foregroundColor(Color.black)
                        .padding(.horizontal, 48)
                        .buttonStyle(FatButtonStyle())
                        .sheet(isPresented: self.$isShowingImagePicker, onDismiss: self.commitImage) {
                            ImagePickerView(image: self.$depthImage)
                        }
                        Button(action: {self.isShowingCamera = true}) {
                            HStack {
                                Spacer()
                                Image(systemName: "camera.fill")
                                Text("Take a new photo")
                                Spacer()
                            }
                        }
                        .foregroundColor(Color.white)
                        .padding(.horizontal, 48)
                        .padding(.bottom, 108)
                        .buttonStyle(OutlinedFatButtonStyle())
                        .sheet(isPresented: self.$isShowingCamera, onDismiss: self.commitImage) {
                            CameraView(
                                captureSession: self.captureSession
                            ).environmentObject(CameraView.Coordinator(captureSession: self.captureSession) { depthImage in
                                guard let depthImage = depthImage else {return}
                                self.depthImage = depthImage
                                self.isShowingCamera = false
                            })
                        }
                    }.frame(width: geometry.frame(in: .local).width, height: geometry.frame(in: .local).height)
                }
            }.edgesIgnoringSafeArea(.all)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(depthImage: DepthImage(diffuse: UIImage(named: "mango-image")!, trueDepth: UIImage(named: "mango-depth")!))
    }
}
