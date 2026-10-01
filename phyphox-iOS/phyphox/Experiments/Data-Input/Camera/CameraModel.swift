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
        func onWhiteBalanceChange()
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
    
    //White balance by white point (file format 1.21): the request, the value in effect after clamping, and the flags
    //the camera-gui needs. CameraService pushes this state to the device; the state itself needs no camera.
    var whiteBalanceMode: WhiteBalanceMode = .auto
    var whiteBalanceTemperature: Int = WhiteBalance.defaultTemperature //Kelvin
    var whiteBalanceTint: Float = 0.0 //Duv
    var whiteBalanceTemperatureInEffect: Int = WhiteBalance.defaultTemperature
    var whiteBalanceTintInEffect: Float = 0.0
    var whiteBalanceTemperatureRange: ClosedRange<Int> = WhiteBalance.minTemperature...WhiteBalance.maxTemperature
    var whiteBalanceLockedByFile = false //set by the experiment file: the camera-gui control is disabled
    var whiteBalanceFrozen = false //the automatic result is held by the device
    //Whether the device takes custom gains; without them a temperature falls back to holding the automatic result
    var whiteBalanceGainsSupported = true

    //The lock holds the automatic result for the plain lock, and for a temperature on a camera without custom gains
    var whiteBalanceNeedsLock: Bool {
        return whiteBalanceMode == .locked || (whiteBalanceMode == .temperature && !whiteBalanceGainsSupported)
    }

    //The request against what can be reached; the device may narrow the temperature further when it clamps the gains
    func updateWhiteBalanceInEffect() {
        whiteBalanceTemperatureInEffect = min(max(whiteBalanceTemperatureRange.lowerBound, whiteBalanceTemperature), whiteBalanceTemperatureRange.upperBound)
        whiteBalanceTintInEffect = min(max(-WhiteBalance.maxTint, whiteBalanceTint), WhiteBalance.maxTint)
    }

    //The white balance from the camera input's locked attribute; a lock from the file engages at the first start
    func applyFileWhiteBalance(locked: [String: Float?]) {
        let settings = WhiteBalance.settings(fromLocked: locked)
        whiteBalanceMode = settings.mode
        whiteBalanceTemperature = settings.temperature
        whiteBalanceTint = settings.tint
        whiteBalanceLockedByFile = settings.mode != .auto
        whiteBalanceFrozen = false
        updateWhiteBalanceInEffect()
    }

    //The camera-gui's choice: a lock engages at once, automatic releases it
    func selectWhiteBalanceMode(_ mode: WhiteBalanceMode) {
        whiteBalanceMode = mode
        whiteBalanceFrozen = whiteBalanceNeedsLock
        updateWhiteBalanceInEffect()
    }

    func selectWhiteBalanceTemperature(_ kelvin: Int) {
        whiteBalanceTemperature = kelvin
        updateWhiteBalanceInEffect()
    }

    func selectWhiteBalanceTint(_ duv: Float) {
        whiteBalanceTint = duv
        updateWhiteBalanceInEffect()
    }

    //Engages the lock when the measurement is first started; true when the device has to follow
    func freezeWhiteBalanceAtStart() -> Bool {
        if whiteBalanceFrozen || !whiteBalanceNeedsLock {
            return false
        }
        whiteBalanceFrozen = true
        return true
    }

    //The text of the camera-gui's white balance button: the mode, or the temperature in effect
    var whiteBalanceLabel: String {
        switch whiteBalanceMode {
        case .auto: return localize("wb_auto")
        case .locked: return localize("wb_locked")
        case .temperature: return "\(whiteBalanceTemperatureInEffect) K"
        }
    }

    func whiteBalanceChanged() {
        for changeObserver in changeObservers {
            changeObserver.onWhiteBalanceChange()
        }
    }

    var exposureCompensationRange: ClosedRange<Float>?
    
    var service: CameraService?
        
    var resolution: CGSize? = nil
    var maxFrameDuration = 1.0/30.0
    
    init(service: CameraService){
        self.service = service
    }
    
    init(){}
    
    func registerSettingsObserver(_ observer: SettingsChangeObserver) {
        changeObservers.append(observer)
    }

}


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
        
    var autoExposureEnabled: Bool = true
    var aeStrategy = ExperimentCameraInput.AutoExposureStrategy.mean
    var aeFPSTarget: Double = 0.0
    
    var locked: [String:Float?] = [:]
    
    var feature: CameraFeature = CameraFeature.PHOTOMETRIC

    //User-selected orientation of the device relative to the spectrum in spectroscopy experiments
    var spectrumOrientation: SpectrumOrientation = .landscape

    private let service = CameraService()
    var cameraSettingsModel : CameraSettingsModel
    
    var analyzingRenderer: AnalyzingRenderer
    var session: AVCaptureSession
    
    var timeReference: ExperimentTimeReference?
    var zBuffer: DataBuffer?
    var tBuffer: DataBuffer?
        
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
        //A white balance lock from the file engages at the first start and is never released
        service.freezeWhiteBalanceAtStart()
    }
    
    
    func stopSession(){
        service.analyzingRenderer?.measuring = false
    }
    
    func endSession(){
        service.releaseConfigurationLocks()
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


