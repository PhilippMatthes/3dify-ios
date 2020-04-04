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


struct HomeView: View {
    enum Sheet {
        case picker
        case camera
        case aiExplanation
    }
    
    @State var selectedAnimationRepeatCount: Int = 5
    @State var selectedAnimationIntensity: Float = 0.05
    @State var selectedBlurIntensity: Float = 0
    @State var selectedAnimationInterval: TimeInterval = 2
    @State var selectedFocalPoint: Float = 0
    @State var selectedAnimationTypeRawValue = ImageParallaxAnimationType.horizontalSwitch.rawValue
    
    @State var activeSheet: Sheet?
    @State var isShowingSheet = false
    @State var isShowingControls = false
    @State var isShowingArtificialDepth = false
    
    @State var loadingState: LoadingState = .hidden
    @State var isSaving = false
    @State var loadingText = "Loading..."
            
    @State var depthImage: DepthImage
    
    var springAnimation: Animation {
        .interpolatingSpring(stiffness: 300.0, damping: 30.0, initialVelocity: 10.0)
    }
    
    var body: some View {
        LoadingView(text: self.$loadingText, loadingState: self.$loadingState) {
            ControlView(
                depthImage: self.$depthImage,
                isShowingArtificialDepth: self.$isShowingArtificialDepth,
                isShowingControls: self.$isShowingControls,
                selectedAnimationInterval: self.$selectedAnimationInterval,
                selectedAnimationIntensity: self.$selectedAnimationIntensity,
                selectedBlurIntensity: self.$selectedBlurIntensity,
                selectedAnimationTypeRawValue: self.$selectedAnimationTypeRawValue,
                selectedFocalPoint: self.$selectedFocalPoint,
                onShowPicker: {
                    self.activeSheet = .picker
                    self.isShowingSheet = true
                },
                onShowCamera: {
                    self.activeSheet = .camera
                    self.isShowingSheet = true
                },
                onSaveVideo: {
                    guard !self.isSaving else {return}
                    UISelectionFeedbackGenerator().selectionChanged()
                    self.isSaving = true
                    withAnimation(self.springAnimation) {
                        self.loadingState = .loading
                    }
                },
                onShowAIExplanation: {
                    self.activeSheet = .aiExplanation
                    self.isShowingSheet = true
                }
            ) {
                GeometryReader { geometry in
                    ZStack {
                        MetalParallaxViewBestFitContainer(
                            selectedAnimationInterval: self.$selectedAnimationInterval,
                            selectedAnimationIntensity: self.$selectedAnimationIntensity,
                            selectedFocalPoint: self.$selectedFocalPoint,
                            selectedBlurIntensity: self.$selectedBlurIntensity,
                            selectedAnimationTypeRawValue: self.$selectedAnimationTypeRawValue,
                            depthImage: self.$depthImage,
                            isPaused: self.$isShowingSheet,
                            isSaving: self.$isSaving
                        ) { saveState in
                            switch saveState {
                            case .failed:
                                UINotificationFeedbackGenerator().notificationOccurred(.error)
                                self.loadingText = "Error"
                                self.loadingState = .failed
                                self.isSaving = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                    withAnimation(self.springAnimation) {
                                        self.loadingState = .hidden
                                    }
                                }
                            case .rendering(let progress):
                                self.loadingText = "Rendering... \(Int(progress))%"
                            case .saving:
                                self.loadingText = "Saving to camera roll..."
                            case .finished:
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                self.loadingText = "Finished"
                                self.loadingState = .finished
                                self.isSaving = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                    withAnimation(self.springAnimation) {
                                        self.loadingState = .hidden
                                    }
                                }
                            }
                        }
                        
                        if !self.isShowingControls {
                            VStack {
                                Spacer()
                                Text("3Dify")
                                    .font(.system(size: 100))
                                    .foregroundColor(Color.white)
                                Button(action: {
                                    print("Remove watermark")
                                }) {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "eye.slash.fill")
                                        Text("Remove watermark")
                                        Spacer()
                                    }
                                }
                                .foregroundColor(Color.black)
                                .padding(.horizontal, 32)
                                .buttonStyle(FatButtonStyle())
                                Button(action: {
                                    self.activeSheet = .picker
                                    self.isShowingSheet = true
                                }) {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "cube.box.fill")
                                        Text("Pick an existing photo")
                                        Spacer()
                                    }
                                }
                                .foregroundColor(Color.black)
                                .padding(.horizontal, 32)
                                .buttonStyle(FatButtonStyle())
                                Button(action: {
                                    self.activeSheet = .camera
                                    self.isShowingSheet = true
                                }) {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "camera.fill")
                                        Text("Take a new photo")
                                        Spacer()
                                    }
                                }
                                .foregroundColor(Color.white)
                                .padding(.horizontal, 32)
                                .padding(.bottom, 108)
                                .buttonStyle(OutlinedFatButtonStyle())
                            }
                            .frame(
                                width: geometry.frame(in: .local).width,
                                height: geometry.frame(in: .local).height
                            )
                        }
                    }
                }
            }
        }
        .sheet(isPresented: self.$isShowingSheet) {
            if self.activeSheet == .picker {
                ImagePickerView().environmentObject(ImagePickerViewOrchestrator() {
                    depthImage in
                    guard let depthImage = depthImage else {return}
                    self.depthImage = depthImage
                    self.isShowingSheet = false
                    withAnimation {
                        self.isShowingArtificialDepth = depthImage.isArtificial
                        self.isShowingControls = true
                    }
                })
            } else if self.activeSheet == .camera {
                CameraView().environmentObject(CameraViewOrchestrator() {
                    depthImage in
                    guard let depthImage = depthImage else {return}
                    self.depthImage = depthImage
                    self.isShowingSheet = false
                    withAnimation {
                        self.isShowingArtificialDepth = depthImage.isArtificial
                        self.isShowingControls = true
                    }
                })
            } else {
                AIDepthExplanationView(depthImage: self.$depthImage)
            }
        }
        .background(Color.black)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(isShowingControls: false, depthImage: DepthImage(diffuse: UIImage(named: "mango-image")!, depth: UIImage(named: "mango-depth")!, isArtificial: false))
    }
}
