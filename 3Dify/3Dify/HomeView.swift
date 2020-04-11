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
    @State internal var selectedAnimationInterval: TimeInterval = 4
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
    @State internal var isSavingToPhotos = false
    @State internal var loadingText = "Loading..."
            
    @State internal var depthImage: DepthImage
    
    @State internal var shouldShowDepth = false
    
    @State internal var imageScale: CGFloat = 1
    
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
        self.shouldShowDepth = false
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
        guard !self.isSavingToVideo && !self.isSavingToPhotos else {return}
        self.isSavingToPhotos = true
        withAnimation(self.springAnimation) {
            self.loadingState = .loading
        }
    }
    
    internal func onSavePhotosUpdate(saveState: SaveState) {
        switch saveState {
        case .failed:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            self.handleSaveError()
            self.isSavingToPhotos = false
        case .rendering(let progress):
            self.loadingText = "Rendering... \(Int(progress))%"
        case .saving:
            self.loadingText = "Saving to camera roll..."
        case .finished:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            self.handleSaveSuccess()
            self.isSavingToPhotos = false
        }
    }
    
    internal func onSaveToVideo() {
        UISelectionFeedbackGenerator().selectionChanged()
        guard !self.isSavingToVideo && !self.isSavingToPhotos else {return}
        self.isSavingToVideo = true
        withAnimation(self.springAnimation) {
            self.loadingState = .loading
        }
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
    
    internal func willOpenInAppPurchaseView() {
        self.activeSheet = .inAppPurchase
        self.isShowingSheet = true
    }
    
    internal func willOpenImagePicker() {
        self.activeSheet = .picker
        self.isShowingSheet = true
    }
    
    internal func willOpenCamera() {
        self.activeSheet = .camera
        self.isShowingSheet = true
    }
    
    var body: some View {
        LoadingView(text: self.$loadingText, loadingState: self.$loadingState) {
            ControlView(
                depthImage: self.$depthImage,
                shouldShowDepth: self.$shouldShowDepth,
                isShowingArtificialDepth: self.$isShowingArtificialDepth,
                isShowingControls: self.$isShowingControls,
                selectedAnimationInterval: self.$selectedAnimationInterval,
                selectedAnimationIntensity: self.$selectedAnimationIntensity,
                selectedBlurIntensity: self.$selectedBlurIntensity,
                selectedAnimationTypeRawValue: self.$selectedAnimationTypeRawValue,
                selectedFocalPoint: self.$selectedFocalPoint,
                shouldShowWatermark: self.$shouldShowWatermark,
                onShowPicker: self.onShowPicker,
                onShowCamera: self.onShowCamera,
                onSaveButtonPressed: self.onSaveButtonPressed,
                willOpenInAppPurchaseView: self.willOpenInAppPurchaseView
            ) {
                GeometryReader { geometry in
                    ZStack {
                        MetalParallaxViewBestFitContainer(
                            shouldShowDepth: self.$shouldShowDepth,
                            shouldShowWatermark: self.$shouldShowWatermark,
                            selectedAnimationInterval: self.$selectedAnimationInterval,
                            selectedAnimationIntensity: self.$selectedAnimationIntensity,
                            selectedFocalPoint: self.$selectedFocalPoint,
                            selectedBlurIntensity: self.$selectedBlurIntensity,
                            selectedAnimationTypeRawValue: self.$selectedAnimationTypeRawValue,
                            depthImage: self.$depthImage,
                            isPaused: self.$isShowingSheet,
                            isSavingToVideo: self.$isSavingToVideo,
                            isSavingToPhotos: self.$isSavingToPhotos,
                            onSaveVideoUpdate: self.onSaveVideoUpdate,
                            onSavePhotosUpdate: self.onSavePhotosUpdate
                        )
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    guard self.isShowingControls else {return}
                                    self.imageScale *= value
                                }
                                .onEnded { _ in
                                    guard self.isShowingControls else {return}
                                    withAnimation {
                                        self.imageScale = 1
                                    }
                                }
                        )
                        .onTapGesture {
                            self.shouldShowDepth.toggle()
                        }
                        .scaleEffect(self.imageScale)
                        
//                        Image("7_diffuse").resizable().scaledToFill()
                        
                        if !self.isShowingControls {
                            
                            VStack(alignment: .center) {
                                Text("3Dify")
                                .font(.system(size: 100))
                                .fontWeight(.ultraLight)
                                .foregroundColor(Color.white)
                                .shadow(radius: 24)
                                .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                Text("Transform your Photos into awesome 3D videos")
                                .font(.system(size: 16))
                                .fontWeight(.semibold)
                                .foregroundColor(Color.white)
                                .shadow(radius: 24)
                                .multilineTextAlignment(.center)
                                
                                Spacer().frame(minHeight: 24)
                                
                                Button(action: self.willOpenImagePicker) {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "cube.box.fill")
                                        .frame(width: 24, height: 24)
                                        Text("Pick an existing photo")
                                        Spacer()
                                    }
                                }
                                .foregroundColor(Color.black)
                                .buttonStyle(OutlinedFatButtonStyle(cornerRadius: 16))
                                .shadow(radius: 24)
                                .background(LinearGradient(gradient: Gradients.clouds, startPoint: .topLeading, endPoint: .bottomTrailing).cornerRadius(16))
                                
                                Button(action: self.willOpenCamera) {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "camera.fill")
                                        .frame(width: 24, height: 24)
                                        Text("Take a new photo")
                                        Spacer()
                                    }
                                }
                                .foregroundColor(Color.black)
                                .buttonStyle(OutlinedFatButtonStyle(cornerRadius: 16))
                                .shadow(radius: 24)
                                .background(LinearGradient(gradient: Gradients.clouds, startPoint: .topLeading, endPoint: .bottomTrailing).cornerRadius(16))

                                Spacer()
                                    .frame(minHeight: 168)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 128)
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
        HomeView(
            depthImage: DepthImage(
                diffuse: UIImage(named: "0_diffuse")!,
                depth: UIImage(named: "0_depth")!,
                isArtificial: true
            )
        )
    }
}
