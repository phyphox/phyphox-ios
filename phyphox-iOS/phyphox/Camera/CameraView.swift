//
//  CameraView.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 13.11.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

import Foundation
import SwiftUI
import Combine


@available(iOS 14.0, *)
struct PhyphoxCameraView: View {
     
    @StateObject var model = CameraModel()
    
    @State private var isMinimized = true
    
    @State private var overlayWidth: CGFloat = 50
    @State private var overlayHeight: CGFloat = 50
    
    @State private var scale: CGFloat = 1.0
    @State private var currentPosition: CGSize = .zero
    @State private var newPosition: CGSize = .zero
    
    @State private var height: CGFloat = 200.0
    @State private var width: CGFloat = 200.0
    @State private var startPosition: CGFloat = 0.0
    
    @State private var rotation: Double = 0.0
    @State private var isFlipped: Bool = false
    @State private var autoExposureOff : Bool = true
    
    @State private var zoomClicked: Bool = false
    
    
    var mimimizeCameraButton: some View {
        Button(action: {
            self.isMinimized.toggle()
        }, label: {
            Image(systemName: isMinimized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                .font(.title2)
                .padding()
                .background(Color.black)
                .foregroundColor(.white)
        })
    }
    
    
    var flipCameraButton: some View {
        Button(action: {
            if(isFlipped){
                withAnimation(Animation.linear(duration: 0.3)) {
                    self.rotation = -90.0
                }
                isFlipped = false
            } else {
                withAnimation(Animation.linear(duration: 0.3)) {
                    self.rotation = 90.0
                }
                isFlipped = true
            }
            
            model.switchCamera()
        }, label: {
            Circle()
                .opacity(isMinimized ? 1.0 : 0.0)
                .foregroundColor(Color.gray.opacity(0.0))
                .frame(width: 45, height: 45, alignment: .center)
                .overlay(
                    Image("flip_camera")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .rotationEffect(.degrees(rotation))
                        .clipShape(/*@START_MENU_TOKEN@*/Circle()/*@END_MENU_TOKEN@*/)
                        )

        })
    }
    
    @State private var zoomScale: CGFloat = 1.0
    
    var zoomSlider: some View {
        Button(action: {
            zoomClicked = !zoomClicked
            model.zoom()
        }, label: {
            Circle()
                .opacity(isMinimized ? 1.0 : 0.0)
                .foregroundColor(Color.gray.opacity(0.0))
                .frame(width: 45, height: 45, alignment: .center)
                .overlay(
                    Image("ic_zoom")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .clipShape(/*@START_MENU_TOKEN@*/Circle()/*@END_MENU_TOKEN@*/))
                       
        })
    }
    
    var autoExposure: some View {
        Button(action: {
            autoExposureOff = !autoExposureOff
            model.autoExposure()
        }, label: {
            Circle()
                .opacity(isMinimized ? 1.0 : 0.0)
                .foregroundColor(Color.gray.opacity(0.0))
                .frame(width: 45, height: 45, alignment: .center)
                .overlay(
                    Image("ic_auto_exposure")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25))
                        
        })
    }
    
    
    var isoSetting: some View {
        Button(action: {
            model.iso()
        }, label: {
            Circle()
                .opacity(isMinimized ? 1.0 : 0.0)
                .foregroundColor(Color.gray.opacity(0.0))
                .frame(width: 45, height: 45, alignment: .center)
                .overlay(
                    Image("ic_camera_iso")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .clipShape(/*@START_MENU_TOKEN@*/Circle()/*@END_MENU_TOKEN@*/))
                       
        })
    }
    
    var shutterSpeedSetting: some View {
        Button(action: {
            model.shutterSpeed()
        }, label: {
            Circle()
                .opacity(isMinimized ? 1.0 : 0.0)
                .foregroundColor(Color.gray.opacity(0.0))
                .frame(width: 45, height: 45, alignment: .center)
                .overlay(
                    Image("ic_shutter_speed")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .clipShape(/*@START_MENU_TOKEN@*/Circle()/*@END_MENU_TOKEN@*/))
        })
    }
    
    var apertureSetting: some View {
        Button(action: {
            model.shutterSpeed()
        }, label: {
            Circle()
                .opacity(isMinimized ? 1.0 : 0.0)
                .foregroundColor(Color.gray.opacity(0.0))
                .frame(width: 45, height: 45, alignment: .center)
                .overlay(
                    Image(systemName: "camera.aperture")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25)
                        .clipShape(/*@START_MENU_TOKEN@*/Circle()/*@END_MENU_TOKEN@*/)
                        .foregroundColor(.white))
        })
    }
    
    @State private var speed = 50.0
    @State private var isEditing = false
    
    @State private var isZooming = false
    
    
    var body: some View {
        GeometryReader { reader in
            ZStack {
                //UIColor(named: "")?.edgesIgnoringSafeArea(.all)
                
                VStack(alignment: .center, spacing: 5) {
                    
                    HStack(spacing: 0){
                        mimimizeCameraButton
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Preview")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Circle().frame(width: 50, height: 50).opacity(0.0)
                        
                        
                    }
                
                    ZStack{
                        
                        model.metalView
                            .foregroundColor(.gray)
                            .onAppear{
                                model.configure()
                            }
                            .foregroundColor(/*@START_MENU_TOKEN@*/.blue/*@END_MENU_TOKEN@*/)
                            .frame(width: !isMinimized ? reader.size.width / 2 : reader.size.width ,
                                   height: !isMinimized ? reader.size.height / 3 : reader.size.height / 1.5,
                                   alignment: .topTrailing)
                    
                        
                        
                            
                        
                    }
                  
                    HStack {
                        
                        VStack(spacing: 0) {
                            flipCameraButton
                                .frame(maxWidth: .infinity)
                            
                            Text(isFlipped ? "Front" : "Back")
                                .font(.caption2)
                        }
                        
                            
                        VStack(spacing: 0) {
                            autoExposure
                                .frame(maxWidth: .infinity)
                            
                            Text(autoExposureOff ? "Off" : "On")
                                .font(.caption2)
                            
                        }
                        
                        
                           
                        VStack(spacing: 0) {
                            
                            isoSetting
                                .opacity(autoExposureOff ? 1.0 : 0.4 )
                                .frame(maxWidth: .infinity)
                                .disabled(autoExposureOff ? false : true)
                        
                            Text("100").font(.caption2)
                                .opacity(autoExposureOff ? 1.0 : 0.4 )
                        }
                        
                        
                          
                        VStack(spacing: 0) {
                            
                            shutterSpeedSetting
                                .opacity(autoExposureOff ? 1.0 : 0.4 )
                                .frame(maxWidth: .infinity)
                                .disabled(autoExposureOff ? false : true)
                            
                            Text("1/60")
                                .font(.caption2)
                                .opacity(autoExposureOff ? 1.0 : 0.4 )
                        }
                        
                       
                            
                        VStack(spacing: 0) {
                            
                            apertureSetting
                                .opacity(autoExposureOff ? 1.0 : 0.4 )
                                .frame(maxWidth: .infinity)
                                .disabled(autoExposureOff ? false : true)
                            
                            Text("f/1.85")
                                .font(.caption2)
                                .opacity(autoExposureOff ? 1.0 : 0.4 )
                        }
                       
                        
                        VStack(spacing: 0) {
                            
                            zoomSlider
                                .opacity(isMinimized ? 1.0 : 0.0)
                                .frame(maxWidth: .infinity)
                            
                            Text("Zoom").font(.caption2)
                        }
                        
                           
                        
                            
                        
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(isMinimized ? 1.0 : 0.0)
                    .padding(.horizontal, 1)
                    .preferredColorScheme(.dark)
                    
                    
                    Spacer().frame(width: 10.0, height: 20.0)
                   
                    
                    
                    VStack {
                        Slider(
                            value:  Binding(get: {
                                Double(self.model.getScale())
                            }, set: { newValue in
                                self.model.setScale(scale: CGFloat(newValue))
                            }),
                                in: 0...100,
                                step: 1
                            ) {
                                Text("Speed")
                            } minimumValueLabel: {
                                Text("0")
                            } maximumValueLabel: {
                                Text("100")
                            } onEditingChanged: { editing in
                                isEditing = editing
                            }.opacity(isMinimized ? 1.0 : 0.0)
                        
                    }.opacity(zoomClicked ? 1.0 : 0.0)
                    
                }
                
            }
        }.background(Color.black)
    }
    
}


struct PhyphoxCameraView_Previews: PreviewProvider {
    @available(iOS 13.0, *)
    static var previews: some View {
        if #available(iOS 14.0, *) {
            PhyphoxCameraView()
        } else {
            // Fallback on earlier versions
        }
    }
}

public struct AlertError {
    public var title: String = ""
    public var message: String = ""
    public var primaryButtonTitle = "Accept"
    public var secondaryButtonTitle: String?
    public var primaryAction: (() -> ())?
    public var secondaryAction: (() -> ())?
    
    public init(title: String = "", message: String = "", primaryButtonTitle: String = "Accept", secondaryButtonTitle: String? = nil, primaryAction: (() -> ())? = nil, secondaryAction: (() -> ())? = nil) {
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
        self.primaryButtonTitle = primaryButtonTitle
        self.secondaryAction = secondaryAction
    }
}
