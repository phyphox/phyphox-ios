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
import CoreMedia


@available(iOS 14.0, *)
struct PhyphoxCameraView: View {
     
    var cameraSelectionDelegate: CameraSelectionDelegate?
    var cameraViewDelegete: CameraViewDelegate?
    
    @State private var panningIndexX: Int = 0
    @State private var panningIndexY: Int = 0
    
    @State private var modelGesture: CameraGestureState = .none
    
    @State private var isMinimized = true
    
    @State private var overlayWidth: CGFloat = 50
    @State private var overlayHeight: CGFloat = 50
    
    @State private var scale: CGFloat = 1.0
    @State private var currentPosition: CGSize = .zero
    @State private var newPosition: CGSize = .zero
    
    @State private var height: CGFloat = 200.0
    @State private var width: CGFloat = 200.0
    @State private var startPosition: CGFloat = 0.0
  
    @State private var speed = 50.0

    @State private var viewState = CGPoint.zero

  
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
    
    
    var body: some View {
        
        let dragGesture = DragGesture()
            .onChanged{ value in
                viewState = value.location
                pannned(locationY: viewState.y, locationX: viewState.x , state: CameraGestureState.begin)
            
            }
            .onEnded{ value in
                pannned(locationY: viewState.y, locationX: viewState.x , state: CameraGestureState.end)
                self.viewState = .zero
            }
        
        
        GeometryReader { reader in
            ZStack {
               
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
                        
                        cameraViewDelegete?.metalView
                            .foregroundColor(.gray)
                            .gesture(dragGesture)
                            .foregroundColor(/*@START_MENU_TOKEN@*/.blue/*@END_MENU_TOKEN@*/)
                            .frame(width: !isMinimized ? reader.size.width / 2 : reader.size.width ,
                                   height: !isMinimized ? reader.size.height / 3 : reader.size.height / 1.5,
                                   alignment: .topTrailing)
                    
                        
                        
                    }

                    CameraSettingView(cameraSettingModel: cameraViewDelegete?.cameraSettingsModel ?? CameraSettingsModel()).opacity(isMinimized ? 1.0 : 0.0)
                  
                }
                
            }
        }.background(Color.black)
    }
    
    
    func pannned (locationY: CGFloat, locationX: CGFloat , state: CameraGestureState) {
        
        guard var del = cameraSelectionDelegate else {
            print("camera selection delegate is not accessable")
            return
        }
        
        guard let viewDelegate = cameraViewDelegete else {
            print("camera view delegate is not accessable")
            return
        }
    

        
        let pr = CGPoint(x: locationX / (viewDelegate.metalView.metalView.frame.width ), y: locationY / (viewDelegate.metalView.metalView.frame.height ))
        let ps = pr.applying(viewDelegate.metalRenderer.displayToCameraTransform)
        let x = Float(ps.x)
        let y = Float(ps.y)
        
        if state == .begin {
            let x1Square = (x - del.x1) * (x - del.x1)
            let x2Square = (x - del.x2) * (x - del.x2)
            let y1Square = (y - del.y1) * (y -  del.y1)
            let y2Square = (y - del.y2) * (y - del.y2)
            
            let d11 = x1Square + y1Square
            let d12 = x1Square + y2Square
            let d21 = x2Square + y1Square
            let d22 = x2Square + y2Square
            
            let _:Float = 0.1 // it was 0.01 for depth, after removing it from if else, it worked. Need to come again for this
            if d11 < d12 && d11 < d21 && d11 < d22 {
                panningIndexX = 1
                panningIndexY = 1
            } else if d12 < d21 && d12 < d22 {
                panningIndexX = 1
                panningIndexY = 2
            } else if  d21 < d22 {
                panningIndexX = 2
                panningIndexY = 1
            }  else {
                panningIndexX = 2
                panningIndexY = 2
            }
            
            if panningIndexX == 1 {
                del.x1 = x
            } else if panningIndexX == 2 {
                del.x2 = x
            }
            if panningIndexY == 1 {
                del.y1 = y
            } else if panningIndexY == 2 {
                del.y2 = y
            }
            
        } else if state == .end {
            if panningIndexX == 1 {
                del.x1 = x
            } else if panningIndexX == 2 {
                del.x2 = x
            }
            if panningIndexY == 1 {
                del.y1 = y
            } else if panningIndexY == 2 {
                del.y2 = y
            }
           
        } else {
            
        }
        
        
    }
    
    enum CameraGestureState {
        case begin
        case end
        case none
    }
    
}

@available(iOS 14.0, *)
struct CameraSettingView: View {
    @ObservedObject var cameraSettingModel = CameraSettingsModel()
    
    @State private var cameraSettingMode: CameraSettingMode = .NONE
    
    @State private var isEditing = false
    @State private var isZooming = false
    
    @State private var rotation: Double = 0.0
    @State private var isFlipped: Bool = false
    @State private var autoExposureOff : Bool = true
    
    @State private var zoomClicked: Bool = false
    
    @State private var isListVisible: Bool = false
    
    
    var flipCameraButton: some View {
        Button(action: {
            cameraSettingMode = .SWITCH_LENS
            isListVisible = false
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
            
            cameraSettingModel.switchCamera()
        }, label: {
            Circle()
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
            cameraSettingMode = .ZOOM
            isListVisible.toggle()
            zoomClicked = !zoomClicked
        }, label: {
            Circle()
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
            cameraSettingMode = .AUTO_EXPOSURE
            autoExposureOff = !autoExposureOff
            isListVisible = false
            zoomClicked = false
            cameraSettingModel.autoExposure(auto: !autoExposureOff)
        }, label: {
            Circle()
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
            cameraSettingMode = .ISO
            isListVisible.toggle()
            zoomClicked = false
        }, label: {
            Circle()
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
            cameraSettingMode = .SHUTTER_SPEED
            isListVisible.toggle()
            zoomClicked = false
        }, label: {
            Circle()
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
            cameraSettingMode = .NONE
            isListVisible = false
            zoomClicked = false
        }, label: {
            Circle()
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

    
    var body: some View {
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
            
                Text(String(Int(cameraSettingModel.currentIso))).font(.caption2)
                    .opacity(autoExposureOff ? 1.0 : 0.4 )
            }
            
              
            VStack(spacing: 0) {
                
                shutterSpeedSetting
                    .opacity(autoExposureOff ? 1.0 : 0.4 )
                    .frame(maxWidth: .infinity)
                    .disabled(autoExposureOff ? false : true)
                let exposureDuration = CMTimeGetSeconds(cameraSettingModel.currentShutterSpeed ?? CMTime(seconds: 30.0, preferredTimescale: 1000))
                Text("1/" + String(Int((1 / exposureDuration))))
                    .font(.caption2)
                    .opacity(autoExposureOff ? 1.0 : 0.4 )
            }
            
           
                
            VStack(spacing: 0) {
                
                apertureSetting
                    .opacity(autoExposureOff ? 1.0 : 0.4 )
                    .frame(maxWidth: .infinity)
                    .disabled(autoExposureOff ? false : true)
                
                Text("f/" + String(cameraSettingModel.currentApertureValue))
                    .font(.caption2)
                    .opacity(autoExposureOff ? 1.0 : 0.4 )
            }
           
            
            VStack(spacing: 0) {
                
                zoomSlider
                    .frame(maxWidth: .infinity)
                
                Text("Zoom").font(.caption2)
            }
           
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 1)
        .preferredColorScheme(.dark)
        
        
        VStack {
            var cameraSettingsValues = cameraSettingModel.getLisOfCameraSettingsValue(cameraSettingMode: cameraSettingMode)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(cameraSettingsValues , id: \.self) { title in
                        if(cameraSettingMode == .SHUTTER_SPEED){
                            TextButton(text: "1/" + String(title)) {
                                cameraSettingModel.exposure(value: Double(title))
                                
                            }
                        } else if(cameraSettingMode == .ISO){
                            TextButton(text: String(title)) {
                                //cameraSettingModel.exposure(value: Double(title))
                                cameraSettingModel.iso(value: Float(title))
                            }

                        }
                                            }
                }
            }.opacity(!isListVisible ? 0.0 : 1.0)
            
            Spacer().frame(width: 10.0, height: 10.0)
            
            let sliderRange: ClosedRange<Double> = Double(1)...Double((cameraSettingModel.defaultCameraSetting?.virtualDeviceSwitchOverVideoZoomFactors.last?.intValue ?? 1) * 3)

            Slider(
                value:  Binding(get: {
                    Double(self.cameraSettingModel.getScale())
                }, set: { newValue in
                    self.cameraSettingModel.setScale(scale: CGFloat(newValue))
                }),
                in: sliderRange,
                step: 0.1
                ) {
                    Text("")
                } minimumValueLabel: {
                    Text(String(cameraSettingModel.minZoom))
                } maximumValueLabel: {
                    Text(String(cameraSettingModel.maxZoom))
                } onEditingChanged: { editing in
                    isEditing = editing
                }.opacity(zoomClicked ? 1.0 : 0.0)
        }
        
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

@available(iOS 13.0.0, *)
struct TextButton: View {
    var text: String
    var action: () -> Void
    
    @available(iOS 13.0.0, *)
    var body: some View {
        Button(action: action) {
            Text(text)
                .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                .foregroundColor(.black)
                .background(Color.white)
                .cornerRadius(10)
        }
    }
}

@available(iOS 14.0, *)
class PhyphoxCameraHostingController: UIHostingController<PhyphoxCameraView>{
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented. Use init(rootView:) instead.")
        }
    
    init(){
        super.init(rootView: PhyphoxCameraView())
    }
        
        override func viewDidLoad() {
            super.viewDidLoad()
            // Additional setup if needed
        }
    
    func getUIView() -> UIView {
            return self.view
        }
}




