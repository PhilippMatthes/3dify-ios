//
//  HomeView.swift
//  3Dify
//
//  Created by It's free real estate on 21.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import SwiftUI
import AVFoundation


struct HomeView: View {
    enum SheetType {
        case picker
        case camera
        case aiExplanation
        case inAppPurchase
    }
    
    enum AlertType {
        case loadProductFailed
        case transactionFailed
        case unexpectedError
        case watermarkRemovedSuccessfully
    }
    
    enum ActionSheetType {
        case saveToCameraRoll
    }
    
    @State internal var selectedAnimationRepeatCount: Int = 5
    @State internal var selectedAnimationIntensity: Float = 0.05
    @State internal var selectedBlurIntensity: Float = 0
    @State internal var selectedAnimationInterval: TimeInterval = 8
    @State internal var selectedFocalPoint: Float = 0.5
    @State internal var selectedAnimationTypeRawValue = ImageParallaxAnimationType.horizontalSwitch.rawValue
    
    @State internal var activeSheet: SheetType?
    @State internal var isShowingSheet = false
    
    @State internal var activeActionSheet: ActionSheetType?
    @State internal var isShowingActionSheet = false
    
    @State internal var activeAlert: AlertType?
    @State internal var willShowAlert = false
    @State internal var isShowingAlert = false
    @State internal var isShowingControls = false
    @State internal var isShowingArtificialDepth = false
    @State internal var shouldShowWatermark = !InAppPurchaseOrchestrator.isProductUnlocked
    
    @State internal var loadingState: LoadingState = .hidden
    @State internal var isSavingToVideo = false
    @State internal var loadingText = "Loading..."
            
    @State internal var depthImage: DepthImage
    
    internal var springAnimation: Animation {
        .interpolatingSpring(stiffness: 300.0, damping: 30.0, initialVelocity: 10.0)
    }
    
    internal func handleReceive(of depthImageConvertible: DepthImageConvertible?) {
        guard let depthImageConvertible = depthImageConvertible else {return}
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
    
    internal func onShowPicker() {
        self.activeSheet = .picker
        self.isShowingSheet = true
    }
    
    internal func onShowCamera() {
        self.activeSheet = .camera
        self.isShowingSheet = true
    }
    
    internal func onSaveButtonPressed() {
        UISelectionFeedbackGenerator().selectionChanged()
        self.activeActionSheet = .saveToCameraRoll
        self.isShowingActionSheet = true
    }
    
    internal func handleSaveError() {
        self.loadingText = "Error. Please try again"
        self.loadingState = .failed
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(self.springAnimation) {
                self.loadingState = .hidden
            }
        }
    }
    
    internal func handleSaveSuccess() {
        self.loadingText = "Finished"
        self.loadingState = .finished
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(self.springAnimation) {
                self.loadingState = .hidden
            }
        }
    }
    
    internal func onSaveToSeparatedImages() {
        UISelectionFeedbackGenerator().selectionChanged()
        self.loadingText = "Saving to camera roll..."
        withAnimation(self.springAnimation) {
            self.loadingState = .loading
        }
        let diffuse = depthImage.diffuse
        guard let depth = depthImage.depth.resized(
            height: diffuse.size.height,
            width: diffuse.size.width
        ) else {
            self.handleSaveError()
            return
        }
        CustomPhotoAlbum.getOrCreate(albumWithName: "3Dify Photos") { album, error in
            guard error == nil, let album = album else {
                self.handleSaveError()
                return
            }
            album.save(image: diffuse) { error in
                guard error == nil else {
                    self.handleSaveError()
                    return
                }
                
                album.save(image: depth) { error in
                    guard error == nil else {
                        self.handleSaveError()
                        return
                    }
                    
                    self.handleSaveSuccess()
                }
            }
        }
    }
    
    internal func onSaveToVideo() {
        UISelectionFeedbackGenerator().selectionChanged()
        guard !self.isSavingToVideo else {return}
        self.isSavingToVideo = true
        withAnimation(self.springAnimation) {
            self.loadingState = .loading
        }
    }
    
    internal func onShowAIExplanation() {
        UISelectionFeedbackGenerator().selectionChanged()
        self.activeSheet = .aiExplanation
        self.isShowingSheet = true
    }
    
    internal func onSaveVideoUpdate(saveState: SaveState) {
        switch saveState {
        case .failed:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            self.handleSaveError()
            self.isSavingToVideo = false
        case .rendering(let progress):
            self.loadingText = "Rendering... \(Int(progress))%"
        case .saving:
            self.loadingText = "Saving to camera roll..."
        case .finished:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            self.handleSaveSuccess()
            self.isSavingToVideo = false
        }
    }
    
    internal func onUnlockInAppPurchase() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        self.shouldShowWatermark = false
        self.willShowAlert = true
        self.isShowingSheet = false
        self.activeAlert = .watermarkRemovedSuccessfully
    }
    
    internal func onUnlockInAppPuchaseFailed(error: InAppPurchaseOrchestratorError?) {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        self.willShowAlert = true
        self.isShowingSheet = false
        switch error {
        case .loadProductFailed:
            self.activeAlert = .loadProductFailed
        case .transactionFailed:
            self.activeAlert = .transactionFailed
        case .unknown:
            self.activeAlert = .unexpectedError
        case .none:
            self.activeAlert = .unexpectedError
        }
    }
    
    internal func onDismissSheet() {
        if self.willShowAlert {
            self.isShowingAlert = true
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
                onShowPicker: self.onShowPicker,
                onShowCamera: self.onShowCamera,
                onSaveButtonPressed: self.onSaveButtonPressed,
                onShowAIExplanation: self.onShowAIExplanation
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
                            isSaving: self.$isSavingToVideo,
                            onSaveVideoUpdate: self.onSaveVideoUpdate
                        )
                        
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
        .sheet(isPresented: self.$isShowingSheet, onDismiss: self.onDismissSheet) {
            if self.activeSheet == .picker {
                ImagePickerView().environmentObject(ImagePickerViewOrchestrator(onCapture: self.handleReceive))
            } else if self.activeSheet == .camera {
                CameraView().environmentObject(CameraViewOrchestrator(onCapture: self.handleReceive))
            } else if self.activeSheet == .aiExplanation {
                AIDepthExplanationView(depthImage: self.$depthImage)
            } else {
                InAppPurchaseView().environmentObject(InAppPurchaseOrchestrator(onUnlocked: self.onUnlockInAppPurchase, onFailed: self.onUnlockInAppPuchaseFailed))
            }
        }
        .actionSheet(isPresented: self.$isShowingActionSheet) {
            switch self.activeActionSheet {
            case .saveToCameraRoll:
                return ActionSheet(
                    title: Text("Save to camera roll?"),
                    message: Text("Please choose from one of the following options."),
                    buttons: [
                        .default(Text("Save as video"), action: {
                            self.onSaveToVideo()
                        }),
                        .default(Text("Save depth image and photo"), action: {
                            self.onSaveToSeparatedImages()
                        }),
                        .cancel(Text("Cancel"))
                    ]
                )
            default:
                return ActionSheet(
                    title: Text("An unexpected error occurred."),
                    message: Text("Please try again later"),
                    buttons: [.default(Text("OK"))]
                )
            }
        }
        .alert(isPresented: self.$isShowingAlert) {
            switch self.activeAlert {
            case .loadProductFailed:
                return Alert(
                    title: Text("There was an error loading the corresponding product."),
                    message: Text("Please try again later!"),
                    dismissButton: .default(Text("OK")) {
                        self.willShowAlert = false
                    }
                )
            case .transactionFailed:
                return Alert(
                    title: Text("Your Purchase was canceled."),
                    message: Text("It seems like you canceled the purchase or we were not able to complete your purchase. Please come back later!"),
                    dismissButton: .default(Text("OK")) {
                        self.willShowAlert = false
                    }
                )
            case .unexpectedError:
                return Alert(
                    title: Text("An unexpected error occurred."),
                    message: Text("Please try again later."),
                    dismissButton: .default(Text("OK")) {
                        self.willShowAlert = false
                    }
                )
            case .none:
                return Alert(
                    title: Text("An unexpected error occurred."),
                    message: Text("Please try again later."),
                    dismissButton: .default(Text("OK")) {
                        self.willShowAlert = false
                    }
                )
            case .watermarkRemovedSuccessfully:
                return Alert(
                    title: Text("The Watermark was removed successfully!"),
                    message: Text("Thank you for your support!"),
                    dismissButton: .default(Text("OK")) {
                        self.willShowAlert = false
                    }
                )
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(isShowingControls: false, depthImage: DepthImage(diffuse: UIImage(named: "mango-image")!, depth: UIImage(named: "mango-depth")!, isArtificial: false))
    }
}
