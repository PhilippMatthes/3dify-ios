//
//  ContentView.swift
//  3Dify
//
//  Created by It's free real estate on 21.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import SwiftUI
import AVFoundation


struct HomeView: View {
    enum Sheet {
        case picker
        case camera
        case aiExplanation
        case inAppPurchase
    }
    
    @State var selectedAnimationRepeatCount: Int = 5
    @State var selectedAnimationIntensity: Float = 0.05
    @State var selectedBlurIntensity: Float = 0
    @State var selectedAnimationInterval: TimeInterval = 8
    @State var selectedFocalPoint: Float = 0.5
    @State var selectedAnimationTypeRawValue = ImageParallaxAnimationType.horizontalSwitch.rawValue
    
    @State var activeSheet: Sheet?
    @State var isShowingSheet = false
    @State var alertTitle: String = "There was an unexpected error."
    @State var alertMessage: String = "Please try again later."
    @State var willShowAlert = false
    @State var isShowingAlert = false
    @State var isShowingControls = false
    @State var isShowingArtificialDepth = false
    @State var shouldShowWatermark = !InAppPurchaseOrchestrator.isProductUnlocked
    
    @State var loadingState: LoadingState = .hidden
    @State var isSaving = false
    @State var loadingText = "Loading..."
            
    @State var depthImage: DepthImage
    
    var springAnimation: Animation {
        .interpolatingSpring(stiffness: 300.0, damping: 30.0, initialVelocity: 10.0)
    }
    
    func handleReceive(of depthImageConvertible: DepthImageConvertible) {
        self.isShowingSheet = false
        self.loadingText = "Loading Photo..."
        self.loadingState = .loading
        DispatchQueue(label: "Fetch Image Queue").async {
            depthImageConvertible.toDepthImage() { depthImage in
                self.loadingState = .hidden
                guard let depthImage = depthImage else {
                    self.loadingText = "Error. Please try again"
                    self.loadingState = .failed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        withAnimation(self.springAnimation) {
                            self.loadingState = .hidden
                        }
                    }
                    return
                }
                self.depthImage = depthImage
                withAnimation {
                    self.isShowingArtificialDepth = depthImage.isArtificial
                    self.isShowingControls = true
                }
            }
        }
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
                            shouldShowWatermark: self.$shouldShowWatermark,
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
                                self.loadingText = "Error. Please try again"
                                self.loadingState = .failed
                                self.isSaving = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
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
                                if self.shouldShowWatermark {
                                    Button(action: {
                                        self.activeSheet = .inAppPurchase
                                        self.isShowingSheet = true
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
                                }
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
        .sheet(isPresented: self.$isShowingSheet, onDismiss: {
            if self.willShowAlert {
                self.isShowingAlert = true
            }
        }) {
            if self.activeSheet == .picker {
                ImagePickerView().environmentObject(ImagePickerViewOrchestrator() {
                    depthImageConvertible in
                    guard let depthImageConvertible = depthImageConvertible else {return}
                    self.handleReceive(of: depthImageConvertible)
                })
            } else if self.activeSheet == .camera {
                CameraView().environmentObject(CameraViewOrchestrator() {
                    depthImageConvertible in
                    guard let depthImageConvertible = depthImageConvertible else {return}
                    self.handleReceive(of: depthImageConvertible)
                })
            } else if self.activeSheet == .aiExplanation {
                AIDepthExplanationView(depthImage: self.$depthImage)
            } else {
                InAppPurchaseView().environmentObject(InAppPurchaseOrchestrator(onUnlocked: {
                    self.shouldShowWatermark = false
                    self.willShowAlert = true
                    self.isShowingSheet = false
                    self.alertTitle = "Watermark removed!"
                    self.alertMessage = "Thank you!"
                }, onFailed: { error in
                    self.willShowAlert = true
                    self.isShowingSheet = false
                    switch error {
                    case .loadProductFailed:
                        self.alertTitle = "There was an error loading the corresponding product."
                        self.alertMessage = "Please try again later!"
                    case .transactionFailed:
                        self.alertTitle = "Your Purchase was canceled."
                        self.alertMessage = "It seems like you canceled the purchase or we were not able to complete your purchase. Please try again later!"
                    case .unknown:
                        self.alertTitle = "An unexpected error occurred."
                        self.alertMessage = "Please try again later."
                    }
                }))
            }
        }
        .alert(isPresented: self.$isShowingAlert) {
            Alert(title: Text(self.alertTitle), message: Text(self.alertMessage), dismissButton: .default(Text("OK")) {
                self.willShowAlert = false
            })
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(isShowingControls: false, depthImage: DepthImage(diffuse: UIImage(named: "mango-image")!, depth: UIImage(named: "mango-depth")!, isArtificial: false))
    }
}
