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

@available(iOS 14.0, *)
class CameraSettingsModel {
    let updateLock = DispatchSemaphore(value: 1)
    func safeAccess(_ block: () -> Void) {
        updateLock.wait()
        defer {
            updateLock.signal()
        }
        block()
    }
    
    protocol SettingsChangeObserver {
        func onShutterSpeedChange(newValue: CMTime)
        func onIsoChange(newValue: Int)
        func onApertureChange(newValue: Float)
    }
    
    struct ZoomParameters {
        var cameras: [Float: AVCaptureDevice.DeviceType]
        var zoomPresets: [Float]
        var minZoom: Float
        var maxZoom: Float
    }
    
    var changeObservers: [SettingsChangeObserver] = []
    
    private var currentCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    var cameraPosition: AVCaptureDevice.Position {
        get {
            return currentCamera?.position ?? .unspecified
        }
    }
    func changeCamera(_ newCamera: AVCaptureDevice) {
        safeAccess {
            self.currentCamera = newCamera
            service?.setCameraSettinginfo()
        }
    }
    func getCamera() -> AVCaptureDevice? {
        return currentCamera
    }
    
    var zoomParameters: [AVCaptureDevice.Position: ZoomParameters] = [
        .front: ZoomParameters(
            cameras: [1.0: .builtInWideAngleCamera],
            zoomPresets: [1.0, 2.0], minZoom: 1.0, maxZoom: 4.0
        ),
        .back: ZoomParameters(
            cameras: [1.0: .builtInWideAngleCamera],
            zoomPresets: [1.0, 2.0], minZoom: 1.0, maxZoom: 4.0
        )]
    var currentZoomParameters: ZoomParameters {
        get {
            return self.zoomParameters[cameraPosition] ?? ZoomParameters(
                cameras: [1.0: .builtInWideAngleCamera],
                zoomPresets: [1.0, 2.0], minZoom: 1.0, maxZoom: 4.0
            )
        }
    }
    var currentZoom: Float = 1
    
    var shutterSpeedValues: [Float] = []
    var minShutterSpeed: CMTime = CMTime(value: 1, timescale: 1000)
    var maxShutterSpeed: CMTime = CMTime(value: 1, timescale: 1)
    var currentShutterSpeed: CMTime = CMTime(value: 1, timescale: 30) {
        didSet {
            for changeObserver in changeObservers {
                changeObserver.onShutterSpeedChange(newValue: currentShutterSpeed)
            }
        }
    }
    
    var isoValues: [Float] = []
    var minIso: Float = 30.0
    var maxIso: Float = 100.0
    var currentIso: Int = 30 {
        didSet {
            for changeObserver in changeObservers {
                changeObserver.onIsoChange(newValue: currentIso)
            }
        }
    }
    
    var apertureValue: Float = 1.0
    var currentApertureValue: Float = 1.0 {
        didSet {
            for changeObserver in changeObservers {
                changeObserver.onApertureChange(newValue: currentApertureValue)
            }
        }
    }
    
    var exposureValues: [Float] = []
    var minExposureValue: Float = 0.0
    var maxExposureValue: Float = 1.0
    var currentExposureValue: Float = 0.0
    
    let whiteBalanceColorTemperaturePresets:[(label: String, temperature: Float?)] = [
        ("auto",            nil),
        ("incandescent", 2600.0),
        ("fluorescent",  4200.0),
        ("daylight",     5600.0),
        ("cloudy",       6500.0)
    ]
    var currentWhiteBalancePreset: Int = 0
    
    var exposureCompensationRange: ClosedRange<Float>?
    
    var service: CameraService?
        
    var resolution: CGSize? = nil
    var maxFrameDuration = 1.0/30.0
    
    @available(iOS 14.0, *)
    init(service: CameraService){
        self.service = service
    }
    
    init(){}
    
    func registerSettingsObserver(_ observer: SettingsChangeObserver) {
        changeObservers.append(observer)
    }

}


@available(iOS 14.0, *)
final class CameraModel {
    
    var x1: Float = 0.4
    var x2: Float = 0.6
    var y1: Float = 0.4
    var y2: Float = 0.6
    
    var selectionArea: CGRect {
        get {
            return CGRect(x: CGFloat(min(x1, x2)), y: CGFloat(min(y1, y2)), width: CGFloat(abs(x2-x1)), height: CGFloat(abs(y2-y1)))
        }
    }
    
    var absoluteSelectionArea: CGRect? {
        get {
            guard let res = cameraSettingsModel.resolution else {
                return nil
            }
            let sel = selectionArea
            return CGRect(x: sel.minX * res.width, y: sel.minY * res.height, width: sel.maxX * res.width, height: sel.maxY * res.height)
        }
    }
    
    var exposureSettingLevel = CameraSettingLevel.ADVANCE
    
    var autoExposureEnabled: Bool = true
    var aeStrategy = ExperimentCameraInput.AutoExposureStrategy.mean
    
    var locked: [String:Float?] = [:]
    
    private let service = CameraService()
    var cameraSettingsModel : CameraSettingsModel
    
    var analyzingRenderer: AnalyzingRenderer
    var session: AVCaptureSession
    
    var timeReference: ExperimentTimeReference?
    var zBuffer: DataBuffer?
    var tBuffer: DataBuffer?
    
    var isOverlayEditable: Bool = false
    
    init(owner: CameraModelOwner) {
        self.service.cameraModelOwner = owner
        
        self.session = service.session
        
        self.analyzingRenderer = AnalyzingRenderer(inFlightSemaphore: service.inFlightSemaphore)
        
        cameraSettingsModel = CameraSettingsModel(service: service)
                
        configure()
    }
    
    func getTextureProvider() -> CameraMetalTextureProvider? {
        return service
    }
    
    func configure(){
        service.checkForPermisssion()
        service.configure()
        service.analyzingRenderer = analyzingRenderer
        analyzingRenderer.exposureStatisticsListener = service
        service.setupTextures()
    }
    
    func startSession(queue: DispatchQueue){
        service.analyzingRenderer?.queue = queue
        service.analyzingRenderer?.measuring = true
    }
    
    
    func stopSession(){
        service.analyzingRenderer?.measuring = false
    }
    
    func endSession(){
        service.session.stopRunning()
    }
}

enum CameraSettingMode {
    case NONE
    case ZOOM
    case EXPOSURE
    case ISO
    case SHUTTER_SPEED
    case WHITE_BALANCE
    
}


