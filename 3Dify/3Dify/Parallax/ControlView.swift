//
//  ControlView.swift
//  3Dify
//
//  Created by It's free real estate on 29.03.20.
//  Copyright © 2020 Philipp Matthes. All rights reserved.
//

import SwiftUI
import UIKit


struct ControlViewDivider: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
        .frame(height: 1)
        .foregroundColor(Color.gray.opacity(0.1))
    }
}



struct ControlView<Content: View>: View {
    @Binding var depthImage: DepthImage
    @Binding var shouldShowDepth: Bool
    @Binding var isShowingArtificialDepth: Bool
    @Binding var isShowingControls: Bool
    @Binding var selectedAnimationInterval: TimeInterval
    @Binding var selectedAnimationIntensity: Float
    @Binding var selectedBlurIntensity: Float
    @Binding var selectedAnimationTypeRawValue: Int
    @Binding var selectedFocalPoint: Float
    
    @State var isShowingSettings = false
    
    var onShowPicker: () -> Void
    var onShowCamera: () -> Void
    var onSaveButtonPressed: () -> Void
    
    var springAnimation: Animation {
        .interpolatingSpring(stiffness: 300.0, damping: 20.0, initialVelocity: 10.0)
    }
    
    var content: () -> Content
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if self.isShowingControls {
                    VStack {
                        HStack {
                            Button(action: self.onShowPicker) {
                                Image(systemName: "cube.box.fill")
                            }
                            Spacer()
                            Button(action: self.onShowCamera) {
                                Image(systemName: "camera.fill")
                            }
                            Spacer()
                            Button(action: {
                                withAnimation {
                                    self.isShowingSettings.toggle()
                                }
                            }) {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundColor(self.isShowingSettings ? Color.yellow : Color.white)
                            }
                        }
                    }
                    .padding(.top, geometry.safeAreaInsets.top + 12)
                    .padding(.bottom, 24)
                    .padding(.horizontal, 24)
                    .background(Color.black)
                    .foregroundColor(Color.white)
                    .transition(.opacity)
                }
                
                ZStack(alignment: .top) {
                    
                    self.content()
                        .padding(.top, self.isShowingSettings ? (UIScreen.main.bounds.height / 2)  - geometry.safeAreaInsets.top - geometry.safeAreaInsets.bottom : 0)
                    
                    if self.isShowingArtificialDepth {
                        HStack {
                            Image(systemName: "wand.and.rays")
                                .resizable()
                                .frame(width: 12, height: 12)
                            Text("AI Depth")
                                .font(.footnote)
                        }
                        .foregroundColor(Color.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.yellow))
                        .padding(.vertical, 8)
                    }
                    
                    if self.isShowingSettings {
                        ScrollView(showsIndicators: false) {
                            ControlViewDivider()
                            
                            ZStack(alignment: .bottom) {
                                Slider(value: self.$selectedAnimationInterval, in: 1...5)
                                .padding(.bottom, 24)
                                HStack {
                                    Text("0.5s").font(.footnote)
                                    Spacer()
                                    Text("5s").font(.footnote)
                                }
                                Text("Animation Interval").font(.footnote)
                            }
                            .padding(.horizontal, 24)
                            
                            ControlViewDivider()
                            
                            ZStack(alignment: .bottom) {
                                Slider(value: self.$selectedAnimationIntensity, in: 0...0.1)
                                .padding(.bottom, 24)
                                HStack {
                                    Text("Weak").font(.footnote)
                                    Spacer()
                                    Text("Strong").font(.footnote)
                                }
                                Text("Animation Intensity").font(.footnote)
                            }
                            .padding(.horizontal, 24)
                            
                            ControlViewDivider()
                            
                            ZStack(alignment: .bottom) {
                                Slider(value: self.$selectedFocalPoint, in: 0...1)
                                .padding(.bottom, 24)
                                HStack {
                                    Text("Far").font(.footnote)
                                    Spacer()
                                    Text("Near").font(.footnote)
                                }
                                Text("Focal Point").font(.footnote)
                            }
                            .padding(.horizontal, 24)
                            
                            ControlViewDivider()
                            
                            ZStack(alignment: .bottom) {
                                Slider(value: self.$selectedBlurIntensity, in: 0...3)
                                .padding(.bottom, 24)
                                HStack {
                                    Text("None").font(.footnote)
                                    Spacer()
                                    Text("Strong").font(.footnote)
                                }
                                Text("Blur Intensity").font(.footnote)
                            }
                            .padding(.horizontal, 24)
                            
                            ControlViewDivider()
                            
                            Picker(selection: self.$selectedAnimationTypeRawValue, label: Text("Animation")) {
                                ForEach(ImageParallaxAnimationType.all, id: \.rawValue) {animationType in
                                    Text(animationType.description)
                                    .tag(animationType.rawValue)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(2)
                            .background(Color.yellow)
                            .cornerRadius(8)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                        }
                        .background(Color(hex: "#222"))
                        .foregroundColor(Color.white)
                        .accentColor(Color.yellow)
                        .frame(height: self.isShowingControls ? (UIScreen.main.bounds.height / 2) : 0)
                    }
                }
                
                if self.isShowingControls && !self.isShowingSettings {
                    HStack {
                        Spacer()
                        Button(action: self.onSaveButtonPressed) {
                            Image(systemName: "square.and.arrow.down.on.square.fill")
                                .foregroundColor(Color.black)
                        }
                        .buttonStyle(CameraButtonStyle())
                        Spacer()
                    }
                    .padding(.bottom, 32 + geometry.safeAreaInsets.bottom)
                    .padding(.top, 32)
                    .padding(12)
                    .background(Color.black)
                    .accentColor(Color.yellow)
                    .foregroundColor(Color.white)
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .edgesIgnoringSafeArea(.vertical)
    }
}

struct ControlView_Previews: PreviewProvider {
    static var previews: some View {
        ControlView(depthImage: .constant(DepthImage(diffuse: UIImage(named: "mango-image")!, depth: UIImage(named: "mango-depth")!, isArtificial: false)),
                    shouldShowDepth: .constant(false),
                    isShowingArtificialDepth: .constant(true),
                    isShowingControls: .constant(true),
                    selectedAnimationInterval: .constant(2),
                    selectedAnimationIntensity: .constant(0.05),
                    selectedBlurIntensity: .constant(5),
                    selectedAnimationTypeRawValue: .constant(0),
                    selectedFocalPoint: .constant(0),
                    isShowingSettings: false,
                    onShowPicker: {},
                    onShowCamera: {},
                    onSaveButtonPressed: {}
        ) {
            VStack {
                HStack {
                    Spacer()
                }
                Spacer()
            }
            .background(Color.yellow)
        }
        .previewDevice(.init(rawValue: "iPhone SE"))
    }
}
