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

@available(iOS 13.0, *)
class CameraViewModel: ObservableObject {
    @Published var cameraUIDataModel: CameraUIDataModel
    
    init(cameraUIDataModel: CameraUIDataModel) {
        self.cameraUIDataModel = cameraUIDataModel
    }
}


@available(iOS 14.0, *)
struct PhyphoxCameraView: View {
    
    @ObservedObject var viewModel: CameraViewModel
    
    var cameraSelectionDelegate: CameraSelectionDelegate?
    var cameraViewDelegete: CameraViewDelegate?
    
    @State private var panningIndexX: Int = 0
    @State private var panningIndexY: Int = 0
    
    @State private var modelGesture: CameraGestureState = .none
    
    @State var isMaximized = false
    
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

    var resizableState: ResizableViewModuleState =  .normal
  
    var mimimizeCameraButton: some View {
        Button(action: {
            self.isMaximized.toggle()
            viewModel.cameraUIDataModel.cameraIsMaximized.toggle()
            self.cameraViewDelegete?.isOverlayEditable.toggle()
        }, label: {
            Image(systemName: isMaximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                .font(.title2)
                .padding()
        })
    }
    
    
    var body: some View {
        
        let dragGesture = DragGesture()
            .onChanged{ value in
                if(isMaximized){
                    viewState = value.location
                    pannned(locationY: viewState.y, locationX: viewState.x , state: CameraGestureState.begin)
                }
             
            }
            .onEnded{ value in
                if(isMaximized){
                    pannned(locationY: viewState.y, locationX: viewState.x , state: CameraGestureState.end)
                    self.viewState = .zero
                }
            }
        
        
        GeometryReader { reader in
            ZStack {
                
                VStack(alignment: .center, spacing: 5) {
                    
                    HStack(spacing: 0){
                        mimimizeCameraButton
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Preview")
                            .foregroundColor(Color("textColor"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Circle().frame(width: 50, height: 50).opacity(0.0)
                        
                    }
                    
                    ZStack{
                       
                        
                        cameraViewDelegete?.metalView
                            .gesture(dragGesture)
                            .frame(width: !isMaximized ? reader.size.width / 2 : reader.size.width / 1.1 ,
                                   height: !isMaximized ? reader.size.height / 2.5 : reader.size.height / 1.1,
                                   alignment: .topTrailing)
                    
                        
                    }
                }
                
            }//.background(Color.black)
        }
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
struct CameraSettingButton: View {
    let action: () -> Void
    let image: String
    let size: CGFloat
    
    
    var body: some View {
        
        Button(action: {
            action()
        }){
            Circle()
                .foregroundColor(Color.gray.opacity(0.0))
                .frame(width: 45, height: 45, alignment: .center)
                .overlay(
                    Image(image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                )
        }
        
    }
}

@available(iOS 14.0, *)
struct CameraSettingView: View {
    @ObservedObject var cameraSettingModel = CameraSettingsModel()
    var cameraSelectionDelegate: CameraSelectionDelegate?

    @State private var cameraSettingMode: CameraSettingMode = .NONE
    
    @State private var isEditing = false
    @State private var isZooming = false
    
    @State private var rotation: Double = 0.0
    @State private var isFlipped: Bool = false
    @State private var autoExposureOff : Bool = true
    
    @State private var zoomClicked: Bool = false
    
    @State private var isListVisible: Bool = false
    
    @State private var zoomScale: CGFloat = 1.0
    
    

    
    var flipCameraButton: some View {
        CameraSettingButton(action: {
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
        }, image: "flip_camera", size: 30).rotationEffect(.degrees(rotation))
    }
    
    var zoomSlider: some View {
        CameraSettingButton(action: {
            cameraSettingMode = .ZOOM
            isListVisible.toggle()
            zoomClicked = !zoomClicked
        }, image: "ic_zoom", size: 30)
    }
    
    var autoExposure: some View {
         CameraSettingButton(action: {
             cameraSettingMode = .AUTO_EXPOSURE
             autoExposureOff = !autoExposureOff
             isListVisible = false
             zoomClicked = false
             cameraSettingModel.autoExposure(auto: !autoExposureOff)
         }, image: "ic_auto_exposure", size: 25)
    }
    
    var exposureSetting: some View{
        CameraSettingButton(action: {
            cameraSettingMode = .EXPOSURE
            cameraSettingModel.cameraSettingMode = .EXPOSURE
            cameraSettingModel.service?.configure()
            isListVisible.toggle()
            zoomClicked = false
        }, image: "ic_exposure", size: 30)
    }
    
    var isoSetting: some View {
        CameraSettingButton(action: {
            cameraSettingMode = .ISO
            cameraSettingModel.cameraSettingMode = .ISO
            cameraSettingModel.service?.configureSession()
            isListVisible.toggle()
            zoomClicked = false
        }, image: "ic_camera_iso", size: 30)
    }
    
    var shutterSpeedSetting: some View {
        CameraSettingButton(action: {
            cameraSettingMode = .SHUTTER_SPEED
            cameraSettingModel.cameraSettingMode = .SHUTTER_SPEED
            cameraSettingModel.service?.configure()
            isListVisible.toggle()
            zoomClicked = false
        }, image: "ic_shutter_speed", size: 30)
    }
    
    var apertureSetting: some View {
        
        Button(action: {
            cameraSettingMode = .NONE
            isListVisible = false
            zoomClicked = false
        }){
            Circle()
                .foregroundColor(Color.gray.opacity(0.0))
                .frame(width: 45, height: 45, alignment: .center)
                .overlay(
                    Image(systemName: "camera.aperture")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25)
                        .clipShape(Circle())
                )
        }
    
    }

    @State var selectedKey: Double?
    @State var value: Float = 0
  
    
    var body: some View {
        
        Spacer().frame(width: 10.0, height: 40.0)
        
        let exposureSettingLevel = cameraSelectionDelegate?.exposureSettingLevel
   
        if(exposureSettingLevel == 0){
            HStack{}
        } else {
            if(cameraSettingMode == .ISO || cameraSettingMode == .SHUTTER_SPEED){
                Spacer().frame(width: 10.0, height: 40.0)
            } else {
                Spacer().frame(width: 0.0, height:  0.0)
            }
            
            
            HStack {
                
                VStack {
                    flipCameraButton.frame(maxWidth: .infinity)
                    Text(isFlipped ? "Front" : "Back").font(.caption2)
                }
                
                if(exposureSettingLevel == 2){
                    VStack {
                        exposureSetting
                            .opacity(autoExposureOff ? 1.0 : 0.4 )
                            .disabled(autoExposureOff ? false : true).frame(maxWidth: .infinity)
                        
                        Text(String(cameraSettingModel.currentExposureValue))
                            .font(.caption2)
                            .opacity(autoExposureOff ? 1.0 : 0.4 )
                    }
                    
                }
                
                if(exposureSettingLevel == 3){
                    VStack {
                        autoExposure.frame(maxWidth: .infinity)
                        Text(autoExposureOff ? "Off" : "On").font(.caption2)
                    }
                    
                    if((autoExposureOff && cameraSettingModel.isDefaultCamera)){
                        VStack {
                            isoSetting.frame(maxWidth: .infinity).opacity(1.0 )
                            
                            Text(String(Int(cameraSettingModel.currentIso))).font(.caption2)
                                
                        }
                    } else {
                        VStack {
                            isoSetting.frame(maxWidth: .infinity).opacity(0.4 )
                            
                            Text(String(Int(cameraSettingModel.currentIso))).font(.caption2)
                                
                        }
                    }
                    
                    
                    
                    //.disabled((autoExposureOff && cameraSettingModel.isDefaultCamera) ? false : true)
                    
                    
                    VStack {
                        
                        shutterSpeedSetting
                            .opacity((autoExposureOff && cameraSettingModel.isDefaultCamera) ? 1.0 : 0.4 )
                            .disabled((autoExposureOff && cameraSettingModel.isDefaultCamera) ? false : true)
                            .frame(maxWidth: .infinity)
                        
                        let exposureDuration = CMTimeGetSeconds(cameraSettingModel.currentShutterSpeed ?? CMTime(seconds: 30.0, preferredTimescale: 1000))
                        
                        Text("1/" + String(Int((1 / exposureDuration))))
                            .font(.caption2)
                            .opacity((autoExposureOff && cameraSettingModel.isDefaultCamera) ? 1.0 : 0.4 )
                    }
                    
                    VStack {
                        
                        apertureSetting
                            .opacity((autoExposureOff && cameraSettingModel.isDefaultCamera) ? 1.0 : 0.4 )
                            .frame(maxWidth: .infinity)
                            .disabled((autoExposureOff && cameraSettingModel.isDefaultCamera) ? false : true)
                        
                        Text("f/" + String(cameraSettingModel.currentApertureValue))
                            .font(.caption2)
                            .opacity((autoExposureOff && cameraSettingModel.isDefaultCamera) ? 1.0 : 0.4 )
                    }
                }

                VStack {
                    zoomSlider.frame(maxWidth: .infinity)
                    Text("Zoom").font(.caption2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 1)
            .preferredColorScheme(.dark)
            
        }
        
        VStack {
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    if(cameraSettingMode == .ISO || cameraSettingMode == .SHUTTER_SPEED){
                        Spacer().frame(width: 10.0, height: 40.0)
                    } else {
                        Spacer().frame(width: 0.0, height:  0.0)
                    }
                    
                    ForEach(isoValuesWithSelectedFlag.sorted(by: <), id: \.key) { key, value in
                        if(cameraSettingMode == .SHUTTER_SPEED){
                            
                            TextButton(text: "1/" + String(Int(key)),  textColor: (isoValuesWithUserSelectedFlag[key] == 1) ? Color("highlightColor") : Color("buttonBackground"), action:  {
                                let _ = print("selected key ", key)
                                self.updateExposureValue(key: key)
                                cameraSettingModel.shutterSpeed(value: Double(key))
                                
                            }).onAppear{
                                updateExposureValue()
                            }
                        } else if(cameraSettingMode == .ISO){
                            TextButton(text: String(Int(key)),  textColor: (isoValuesWithUserSelectedFlag[key] == 1) ? Color("highlightColor") : Color("buttonBackground"), action:  {
                                self.updateExposureValue(key: key)
                                cameraSettingModel.iso(value: Int(key))
                            }).onAppear{
                                updateExposureValue()
                            }

                        } else if(cameraSettingMode == .EXPOSURE){
                            
                            TextButton(text: String(key) , textColor: (isoValuesWithUserSelectedFlag[key] == 1) ? Color("highlightColor") : Color("buttonBackground"), action:  {
                                self.updateExposureValue(key: key)
                                cameraSettingModel.exposure(value: Float(key))
                                
                            }).onAppear{
                                updateExposureValue()
                            }
                        }
                    }
                }
            }.opacity(!isListVisible ? 0.0 : 1.0)
            
            Spacer().frame(width: 10.0, height: 10.0)
            
            let minZoomValue = cameraSettingModel.service?.getMinimumZoomValue(defaultCamera: true)
            
            let sliderRange: ClosedRange<Double> = {
                let minimumZoom = Double(minZoomValue ?? 1)
                let maximumZoom = Double(cameraSettingModel.service?.getMaxZoom() ?? 3)
                return minimumZoom...maximumZoom
            }()
            

            VStack{
                HStack {
                    
                    ForEach(zoomValuesWithSelectedFlag.sorted(by: <), id: \.key) { key, value in
                    
                        TextButton(text:"\(key)x", textColor: (zoomValuesWithSelectedFlag[key] == 1) ? Color("highlightColor") : Color("buttonBackground"),  action: {
                           
                            self.updateValue(key: key)
                            self.cameraSettingModel.setScale(scale: CGFloat(key))
                            
                        })
                         
                    }
                }.onAppear{
                    let opticalZoomValues = cameraSettingModel.service?.getOpticalZoomList()  ?? []
                    updateValuesWithSelectedIndex(values: opticalZoomValues)
                }
                
                Slider(value:  sliderBinding,
                    in: sliderRange,
                    step: 0.1
                    ) {
                        Text("")
                    }
            minimumValueLabel: {
                Text(String(minZoomValue ?? 1) + "x")
                    }
            maximumValueLabel: {
                        Text("\(cameraSettingModel.maxZoom)x")
                    } 
            onEditingChanged: { editing in
                        isEditing = editing
                    }
                    
            }
            .opacity(zoomClicked ? 1.0 : 0.0)
            .padding(EdgeInsets(top: 5.0, leading: 10.0, bottom: 5.0, trailing: 10.0))
            
        }
        
    }
    
    var sliderBinding: Binding<Double> {
            Binding<Double>(
                get: {
                    return Double(self.cameraSettingModel.getScale())
                },
                set: { newValue in
                    
                    
                    for zoomvValues in zoomValuesWithSelectedFlag.keys{
                        if(newValue > zoomValuesWithSelectedFlag.keys.sorted().last ?? 1.0){
                            zoomValuesWithSelectedFlag[zoomvValues] = 0.0
                        }
                    }
                    
                    
                    self.cameraSettingModel.setScale(scale: CGFloat(newValue))
                }
            )
        }
    
    func findIsoNearestNumber(value: Double, numbers: [Double]) -> Double {
        var nearestNumber: Double?
        var minDifference = Double.infinity

        for number in numbers {
                let difference = abs(number - value)
                if difference < minDifference {
                    minDifference = difference
                    nearestNumber = number
                }
            }

        return nearestNumber ?? 30.0
    }
    
    @State private var isoValuesWithUserSelectedFlag : [Double:Double] = [ : ]
    
    private func updateExposureValue(){
        var currentValue: Double = 1.0
        
        if(cameraSettingMode == .SHUTTER_SPEED){
            currentValue = CMTimeGetSeconds(cameraSettingModel.currentShutterSpeed ?? CMTime(seconds: 30.0, preferredTimescale: 1000)) * 1000
            if shutters.contains(Int(currentValue)){
                // Do nothing
            } else {
                currentValue = findIsoNearestNumber(value: currentValue, numbers: shutters.map{Double($0)})
                
            }
            
        } else if(cameraSettingMode == .ISO){
            currentValue = Double(cameraSettingModel.currentIso)
        } else if(cameraSettingMode == .EXPOSURE){
            currentValue = Double(cameraSettingModel.currentExposureValue)
        }
        
        let cameraSettingsValues = cameraSettingModel.getLisOfCameraSettingsValue(cameraSettingMode: cameraSettingMode)
        print("cameraSettingsValues ", cameraSettingsValues)
            for value in cameraSettingsValues {
               
                if (value == Float(currentValue)) {
                    isoValuesWithUserSelectedFlag[Double(value)] = 1.0
                } else {
                    isoValuesWithUserSelectedFlag[Double(value)] = 0.0
                }
                            
        }
        
    }
    
    
    private var isoValuesWithSelectedFlag: [Double: Double] {
        var dictionary: [Double: Double] = [:]
        
        var currentValue: Double = 1.0
        
        if(cameraSettingMode == .SHUTTER_SPEED){
            currentValue = CMTimeGetSeconds(cameraSettingModel.currentShutterSpeed ?? CMTime(seconds: 30.0, preferredTimescale: 1000)) * 1000
            if shutters.contains(Int(currentValue)){
                // Do nothing
            } else {
                currentValue = findIsoNearestNumber(value: currentValue, numbers: shutters.map{Double($0)})
                
            }
            
        } else if(cameraSettingMode == .ISO){
            currentValue = Double(cameraSettingModel.currentIso)
        } else if(cameraSettingMode == .EXPOSURE){
            currentValue = Double(cameraSettingModel.currentExposureValue)
        }
        
        
        let cameraSettingsValues = cameraSettingModel.getLisOfCameraSettingsValue(cameraSettingMode: cameraSettingMode)
        print("cameraSettingsValues ", cameraSettingsValues)
            for value in cameraSettingsValues {
               
                if (value == Float(currentValue)) {
                    dictionary[Double(value)] = 1.0
                } else {
                    dictionary[Double(value)] = 0.0
                }
                            
        }
        exposureValuesWithSelectedFlag = dictionary
            return dictionary
    }
    
    
    @State private var sliderValue: Double = 0.5
    
    @State var zoomValuesWithSelectedFlag: [Double: Double] = [ 1.0 : 1.0]
    
    @State var exposureValuesWithSelectedFlag: [Double: Double] = [:]
    
    private func updateValue(key: Double) {
        for zoomvValues in zoomValuesWithSelectedFlag.keys{
            if (key == zoomvValues){
                zoomValuesWithSelectedFlag[zoomvValues] = 1.0
            } else{
                zoomValuesWithSelectedFlag[zoomvValues] = 0.0
            }
        }
            
        }
    
    private func updateValuesWithSelectedIndex(values: [Double]) {
        zoomValuesWithSelectedFlag = values.reduce(into: [:]) { result, value in
            if value == 1.0 {
                result[value] = 1.0
            } else {
                result[value] = 0
            }
        }
        }
    
    private func updateExposureValue(key: Double) {
        for zoomvValues in isoValuesWithSelectedFlag.keys{
            if (key == zoomvValues){
                isoValuesWithUserSelectedFlag[zoomvValues] = 1.0
            } else{
                isoValuesWithUserSelectedFlag[zoomvValues] = 0.0
            }
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
    
    @Environment(\.colorScheme) var colorScheme
    var text: String
    var textColor: Color
    var action: () -> Void
    
    @available(iOS 13.0.0, *)
    var body: some View {
        Button(action: action) {
            Text(text)
                .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                .foregroundColor(Color("textColorInsideButton"))
                .background(textColor)
                .cornerRadius(10)
        }
    }
}


