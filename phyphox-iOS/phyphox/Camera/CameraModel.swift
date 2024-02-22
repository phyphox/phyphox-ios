//
//  CameraModel.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 13.11.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

import Foundation
import AVFoundation
import MetalKit


protocol CameraSelectionDelegate {
    var x1: Float { get set }
    var x2: Float { get set }
    var y1: Float { get set }
    var y2: Float { get set }
    var timeReference: ExperimentTimeReference? { get set }
    var zBuffer: DataBuffer? { get set }
    var tBuffer: DataBuffer? { get set }
}

@available(iOS 14.0, *)
protocol CameraViewDelegate {
    var metalView: CameraMetalView { get set }
    var metalRenderer: MetalRenderer { get set }
    var cameraSettingsModel : CameraSettingsModel { get set }
}


@available(iOS 14.0, *)
class CameraSettingsModel: ObservableObject {
    
    var cameraSettingLevel: CameraSettingLevel = .ADVANCE
    
    var cameraSettingMode: CameraSettingMode = .NONE
    
    @Published var maxOpticalZoom: Int = 1
    var ultraWideCamera: Bool = false
    @Published var minZoom: Int = 1
    @Published var maxZoom: Int = 1
    var currentZoom: Int = 1
    
    var minShutterSpeed: Double = 1.0 // min is more less
    var maxShutterSpeed: Double = 1.0 // max is near or less more than 1.0
    @Published var currentShutterSpeed: CMTime?
    
    var minIso: Float = 30.0
    var maxIso: Float = 100.0
    @Published var currentIso: Float = 30.0
    
    var apertureValue: Float = 1.0
    @Published var currentApertureValue: Float = 1.0
    
    var minExposureValue: Float = 0.0
    var maxExposureValue: Float = 1.0
    @Published var currentExposureValue: Float = 0.0
    
    var autoAxposureEnable: Bool = true
    
    var minwhiteBalance: Float = 1.0
    var maxWhiteBalance: Float = 1.0
    @Published var currentWhiteBalance: Float = 1.0
    
    private var zoomScale: Float = 1.0
    
    var service: CameraService?
    
    @available(iOS 14.0, *)
    init(service: CameraService){
        self.service = service
    }
    
    init(){}
    
    
    func getScale() -> CGFloat {
        service?.zoomScale ?? 1.0
        
    }
    
    func setScale(scale: CGFloat) {
       // service.zoomScale = scale
        service?.updateZoom(scale: scale)
    }
    
    func setZoomScale(scale: Float) {
           zoomScale = scale
       }
       
    func getZoomScale() -> Float {
           return zoomScale
    }
    
    func switchCamera(){
        service?.changeCamera()
    }
    
    func getLisOfCameraSettingsValue(cameraSettingMode: CameraSettingMode) -> [Int] {
        service?.getSelectableValuesForCameraSettings(cameraSettingMode: cameraSettingMode) ?? []
    }
   
    
    func autoExposure(auto: Bool) {
        service?.setExposureTo(auto: auto)
    }
    
    func shutterSpeed() {}
    
    func aperture() {}
    
    func iso(value: Float) {
        service?.changeISO(value)
    }
   
    func exposure(value: Double) {
        //service?.changeExpoDuration()
        service?.changeExposureDuration(value)
    }
    
    func zoom() {}
    
    func whiteBalance() {}
    
    var defaultCameraSetting: AVCaptureDevice? {
        
        // Find the built-in Dual Camera, if it exists.
        if let device = AVCaptureDevice.default(.builtInTripleCamera,
                                                for: .video,
                                                position: .back) {
            return device
        }
        
        // Find the built-in Dual Wide Camera, if it exists. (consist of wide and ultra wide camera)
        if let device = AVCaptureDevice.default(.builtInDualWideCamera,
                                                for: .video,
                                                position: .back) {
            return device
        }
        
        // Find the built-in Wide-Angle Camera, if it exists.
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                for: .video,
                                                position: .back) {
            return device
        }
        
        return nil
    }
    
}


@available(iOS 14.0, *)
final class CameraModel: ObservableObject, CameraViewDelegate, CameraSelectionDelegate{

    
    var x1: Float = 0.4
    var x2: Float = 0.6
    var y1: Float = 0.4
    var y2: Float = 0.6
    
    
    private let service = CameraService()
    var metalView =  CameraMetalView()
    var cameraSettingsModel : CameraSettingsModel
   
    var metalRenderer: MetalRenderer
    var session: AVCaptureSession
    
    var timeReference: ExperimentTimeReference?
    var zBuffer: DataBuffer?
    var tBuffer: DataBuffer?
    
    /// The app's default camera.
    var defaultCamera: AVCaptureDevice? {
        
        // Find the built-in Dual Camera, if it exists.
        if let device = AVCaptureDevice.default(.builtInTripleCamera,
                                                for: .video,
                                                position: .back) {
            return device
        }
        
        // Find the built-in Dual Wide Camera, if it exists. (consist of wide and ultra wide camera)
        if let device = AVCaptureDevice.default(.builtInDualWideCamera,
                                                for: .video,
                                                position: .back) {
            return device
        }
        
        // Find the built-in Wide-Angle Camera, if it exists.
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                for: .video,
                                                position: .back) {
            return device
        }
        
        return nil
    }
    
    
    init() {
        self.session = service.session
        self.metalRenderer = MetalRenderer(parent: metalView, renderer: metalView.metalView)
        
        cameraSettingsModel = CameraSettingsModel(service: service)
        
        configure()
        
        initModel(model: self)
    }

    
    func configure(){
        service.checkForPermisssion()
        service.configure()
        
        metalView.metalView.delegate = metalRenderer
        service.metalRender = metalRenderer
    }
    
    func initModel(model: CameraModel){
        service.initializeModel(model: model)
    }
    
    
    func startSession(){
        service.metalRender?.measuring = true
    }
    
    
    func stopSession(){
        service.metalRender?.measuring = false
    }
    
    func endSession(){
        service.session.stopRunning()
    }

    
    func getMetalView() -> MTKView {
        return service.metalView
    }
    
    func getCIImage() -> CGImage {
        return service.image!
    }
    
 
}


enum CameraSettingMode {
    case NONE
    case ZOOM
    case EXPOSURE
    case AUTO_EXPOSURE
    case SWITCH_LENS
    case ISO
    case SHUTTER_SPEED
    case WHITE_BAlANCE
    
}


enum CameraSettingLevel {
    case BASIC // auto exposure ON (Level 1)
    case INTERMEDIATE // auto exposure OFF, only adjust exposure (Level 2)
    case ADVANCE // auto exposure OFF, can adjust ISO, Shutter Speed and Aperture (Level 3)
}
