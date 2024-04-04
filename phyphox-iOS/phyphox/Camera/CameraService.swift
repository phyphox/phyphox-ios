//
//  CameraService.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 13.11.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//
//


import AVFoundation
import MetalKit
import CoreMedia
 
@available(iOS 14.0, *)
public class CameraService: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public let session = AVCaptureSession()
    
    private let sessionQueue = DispatchQueue(label: "session queue", attributes: [], autoreleaseFrequency: .workItem)
    
    private let metadataObjectsQueue = DispatchQueue(label: "sample buffer", attributes: [])
    
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    var setupResult: SessionSetupResult = .success
    
    public var alertError: AlertError = AlertError()
    
    var isSessionRunning = false
    
    var isConfigured = false
    
    var configLocked = false
    
    @Published public var shouldShowAlertView = false
    
    @Published public var isCameraUnavailable = true
    
    private var queue =  DispatchQueue(label: "video output queue")
    
    var metalRender : MetalRenderer?
    
    let metalView: MTKView = MTKView()
    
    var image: CGImage?
    
    var flag: Bool = true
    
    var defaultVideoDevice: AVCaptureDevice?
    
    var cameraModel: CameraModel?
    
    var cameraSetting: CameraSettingsModel = CameraSettingsModel()
    
    @Published var zoomScale: CGFloat = 1.0
    
   
    let defaultMinExposureCMTime = CMTime(value: 14, timescale: 1000000, flags: CMTimeFlags(rawValue: 1), epoch: 0)
    let defaultMaxExposureCMTime = CMTime(value: 1, timescale: 1, flags: CMTimeFlags(rawValue: 1), epoch: 0)
    
    // MARK: Device Configuration Properties
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera], mediaType: .video, position: .unspecified)
    
    
    public func checkForPermisssion(){
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            
        case .authorized:
           
            break
        case .notDetermined:
           
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
        default:
            
            setupResult = .notAuthorized
            
            DispatchQueue.main.async {
                self.alertError = AlertError(title: "Camera Access", message: "Phyphox doesn't have access to use your camera, please update your privacy settings.", primaryButtonTitle: "Settings", secondaryButtonTitle: nil, primaryAction: {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                  options: [:], completionHandler: nil)
                    
                }, secondaryAction: nil)
                self.shouldShowAlertView = true
                self.isCameraUnavailable = true
            }
            
            
        }
    }
    
    public func configure(){
       
        sessionQueue.async {
            self.configureSession()
        }
        
    }
    
    @available(iOS 14.0, *)
    func initializeModel(model: CameraModel){
        cameraModel = model
    }
    
    private func changeExposureMode(mode: AVCaptureDevice.ExposureMode){
           lockConfig { () -> () in
               if ((self.defaultVideoDevice?.isExposureModeSupported(mode)) != nil) {
                   self.defaultVideoDevice?.exposureMode = mode
               }
           }
           
       }
       // optical zoom range, normal zoom range.
       // iphone 12 mini: Dual 12MP, wide and ultra wide, wide : f/1,6, ultra wide: f/2.4 120 degree field of view, 2x optical zoom out , digital zoom upto 5x,
       
       func updateZoom(scale: CGFloat){
           lockConfig { () -> () in
               defaultVideoDevice?.videoZoomFactor = max(1.0, min(zoomScale, (defaultVideoDevice?.activeFormat.videoMaxZoomFactor) ?? 1.0))
               zoomScale = scale
           }
       }
       
       
       func lockConfig(complete: () -> ()) {
           if isConfigured {
               configLocked = true
               do{
                   try defaultVideoDevice?.lockForConfiguration()
                   complete()
                   defaultVideoDevice?.unlockForConfiguration()
                   self.postChangeCameraSetting()
                   configLocked = false
               } catch {
                   configLocked = false
                  
               }
               }
           }
       
    func postChangeCameraSetting(){}
        
    func getAvailableOpticalZoomList(maxOpticalZoom_: Int?) -> [Int] {
        guard let maxOpticalZoom = maxOpticalZoom_ else {
            return []
        }
        
        if maxOpticalZoom == 1 {
            return []
        }
        
        if maxOpticalZoom < 5 {
            return [1,2]
        }
        
        if maxOpticalZoom < 10 {
            return [1,2,5]
        }
        
        if maxOpticalZoom < 15 {
            return [1,2,5,10]
        }
        
        return []
    }
    
    func shutterSpeedRange(min: Int, max: Int) -> [Int] {
        let shutterSpeedRange = [1, 2, 4, 8, 15, 30, 60, 125, 250, 500, 1000, 2000, 4000, 8000]
        
        let filteredShutterSpeedRange = shutterSpeedRange.filter{$0 >= min && $0 <= max}
        
        return filteredShutterSpeedRange
    }
    
    func getShutterSpeedRange() -> [Int] {
        let shutters: [Float] = [1, 2, 4, 8, 15, 30, 60, 125, 250, 500, 1000, 2000, 4000, 8000]
        var shutters_available: [Float] = []
            
        let min_seconds = CMTimeGetSeconds((cameraModel?.defaultCamera?.activeFormat.minExposureDuration) ?? defaultMinExposureCMTime)
        let max_seconds = CMTimeGetSeconds((cameraModel?.defaultCamera?.activeFormat.maxExposureDuration) ?? defaultMinExposureCMTime)
            
        for one_shutter in shutters {
            let seconds = 1.0 / Float64(one_shutter)
            if seconds >= min_seconds && seconds <= max_seconds {
                shutters_available.append(one_shutter)
            }
        }
        
        return shutters_available.map { Int($0) }
        
    }
    
    
    func isoRange(min: Int, max: Int) -> [Int] {
        let isoRange = [25, 50, 100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600, 51200]
        
        let filteredIsoRange = isoRange.filter { $0 >= min && $0 <= max }
        
        return filteredIsoRange
    }
    
    func findIsoNearestNumber(input: Int, numbers: [Int]) -> Int {
        var nearestNumber = numbers[0]
        var difference = abs(input - nearestNumber)

        for number in numbers {
            let currentDifference = abs(input - number)
            if currentDifference < difference {
                difference = currentDifference
                nearestNumber = number
            }
        }

        return nearestNumber
    }
    
    func getSelectableValuesForCameraSettings(cameraSettingMode: CameraSettingMode) -> [Int] {
        switch cameraSettingMode {
        case .ZOOM:
            var zoomList : [Float] = []
            if(cameraModel?.cameraSettingsModel.ultraWideCamera == true){
                zoomList.append(0.5)
            }
            
            if(cameraModel?.cameraSettingsModel.maxOpticalZoom != nil ){
                let zoomValue = getAvailableOpticalZoomList(maxOpticalZoom_: cameraModel?.cameraSettingsModel.maxOpticalZoom)
                for value in zoomValue{
                    zoomList.append(Float(value))
                }
                //zoomList.append(Float((cameraModel?.cameraSettingsModel.maxOpticalZoom)! * 3 ))
            }
            return zoomList.map{Int($0)}
           
        case .EXPOSURE:
            return []
        case .AUTO_EXPOSURE:
            return []
        case .SWITCH_LENS:
            return []
        case .ISO:
            return isoRange(min: Int((cameraModel?.cameraSettingsModel.minIso) ?? 30.0), max: Int((cameraModel?.cameraSettingsModel.maxIso) ?? 100.0))
        case .SHUTTER_SPEED:
            return getShutterSpeedRange()
        case .WHITE_BAlANCE:
            return []
        case .NONE:
            return []
        }
    }
    

    func getCameraSettingsInfo(){
        
        cameraModel?.cameraSettingsModel.minIso = cameraModel?.defaultCamera?.activeFormat.minISO ?? 30.0
        cameraModel?.cameraSettingsModel.maxIso = cameraModel?.defaultCamera?.activeFormat.maxISO ?? 100.0
        
       
        cameraModel?.cameraSettingsModel.minShutterSpeed = CMTimeGetSeconds((cameraModel?.defaultCamera?.activeFormat.minExposureDuration) ?? defaultMinExposureCMTime)
        cameraModel?.cameraSettingsModel.maxShutterSpeed = CMTimeGetSeconds((cameraModel?.defaultCamera?.activeFormat.maxExposureDuration) ?? defaultMaxExposureCMTime)
        
        cameraModel?.cameraSettingsModel.apertureValue = (cameraModel?.defaultCamera?.lensAperture) ?? 1.0
        
        //cameraModel?.cameraSettingsModel.minZoom = (cameraModel?.defaultCamera?.minAvailableVideoZoomFactor.rounded().hashValue)!
        //cameraModel?.cameraSettingsModel.maxZoom = (cameraModel?.defaultCamera?.maxAvailableVideoZoomFactor.rounded().hashValue)!
        
        cameraModel?.cameraSettingsModel.maxOpticalZoom = cameraModel?.defaultCamera?.virtualDeviceSwitchOverVideoZoomFactors.last?.intValue ?? 1
        
        if(cameraModel?.defaultCamera?.deviceType == AVCaptureDevice.DeviceType.builtInDualWideCamera ||
           cameraModel?.defaultCamera?.deviceType == AVCaptureDevice.DeviceType.builtInTripleCamera){
            cameraModel?.cameraSettingsModel.ultraWideCamera = true
        }
    }
    
    func changeISO(_ iso: Float) {

        let duration_seconds = (cameraModel?.cameraSettingsModel.currentShutterSpeed) ?? defaultMinExposureCMTime
        
        if (defaultVideoDevice?.isExposureModeSupported(.locked) == true){
            lockConfig { () -> () in
                defaultVideoDevice?.exposureMode = .custom
                defaultVideoDevice?.setExposureModeCustom(duration: duration_seconds , iso: iso, completionHandler: nil)
                cameraModel?.cameraSettingsModel.currentIso = iso
                
            }
        } else {
            print("custom exposure setting not supported")
        }
        
    }
    
    func changeExposureDuration(_ p: Double) {
        let seconds = 1.0 / Float64(p)
        let duration_seconds = CMTimeMakeWithSeconds(seconds, preferredTimescale: 1000*1000*1000 )
        if (defaultVideoDevice?.isExposureModeSupported(.locked) == true){
            lockConfig { () -> () in
                defaultVideoDevice?.exposureMode = .custom
                defaultVideoDevice?.setExposureModeCustom(duration: duration_seconds , iso: AVCaptureDevice.currentISO, completionHandler: nil)
                cameraModel?.cameraSettingsModel.currentShutterSpeed = duration_seconds
            }
        } else {
            print("custom exposure setting not supported")
        }
        
    }
    
    func changeExpoDuration(){
        if (defaultVideoDevice?.isExposureModeSupported(.locked) == true){
            do {
                try defaultVideoDevice?.lockForConfiguration()
                defaultVideoDevice?.exposureMode = .custom
                defaultVideoDevice?.unlockForConfiguration()
            } catch {
                print("Error setting camera zoom: \(error.localizedDescription)")
            }
        }
        else {
            print("custom exposure setting not supported")
        }
    }
    
    func setExposureTo(auto: Bool){
        do {
            try defaultVideoDevice?.lockForConfiguration()
            defaultVideoDevice?.exposureMode = auto ? .autoExpose : .custom
            defaultVideoDevice?.unlockForConfiguration()
        } catch {
            print("Error setting camera zoom: \(error.localizedDescription)")
        }
        print("is already in autoexposure")
    }

    
    private func configureSession(){
        
        if setupResult != .success {
            return
        }
        
        session.beginConfiguration()
        session.sessionPreset = .medium
        
        getCameraSettingsInfo()
        
        
        do {
            // builtInDualWideCamera -m virtualDeviceSwitchOverVideoZoomFactors [2]
            let defaultCameraType = cameraModel?.defaultCamera?.deviceType ?? AVCaptureDevice.DeviceType.builtInWideAngleCamera
            if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                // If a rear dual camera is not available, default to the rear wide angle camera.
                defaultVideoDevice = backCameraDevice
            } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                // If the rear wide angle camera isn't available, default to the front wide angle camera.
                defaultVideoDevice = frontCameraDevice
            }
            
            
            
            cameraModel?.cameraSettingsModel.currentApertureValue = defaultVideoDevice?.lensAperture ?? 1.0
            cameraModel?.cameraSettingsModel.currentIso = defaultVideoDevice?.iso ?? 30.0
            
            print("setting iso ", defaultVideoDevice?.iso ?? 30.0)
            
            cameraModel?.cameraSettingsModel.currentShutterSpeed = (defaultVideoDevice?.exposureDuration)
           
            cameraModel?.cameraSettingsModel.minZoom = Int((defaultVideoDevice?.minAvailableVideoZoomFactor ?? 1.0))
            
            if(defaultVideoDevice?.virtualDeviceSwitchOverVideoZoomFactors.isEmpty == true){
                cameraModel?.cameraSettingsModel.maxZoom = Int((defaultVideoDevice?.maxAvailableVideoZoomFactor ?? 1.0) ) / 10
            } else {
                cameraModel?.cameraSettingsModel.maxZoom = (defaultVideoDevice?.virtualDeviceSwitchOverVideoZoomFactors.last?.intValue ?? 1) * 3
            }
           
            cameraModel?.cameraSettingsModel.maxOpticalZoom = defaultVideoDevice?.virtualDeviceSwitchOverVideoZoomFactors.last?.intValue ?? 1
            
            
            guard let videoDevice = defaultVideoDevice else {
                print("Default video device is unavailable.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
            
            do {
                try defaultVideoDevice?.lockForConfiguration()
                defaultVideoDevice?.videoZoomFactor = max(1.0, min(zoomScale, (defaultVideoDevice?.activeFormat.videoMaxZoomFactor ?? 1.0)))
                defaultVideoDevice?.unlockForConfiguration()
                        } catch {
                            print("Error setting camera zoom: \(error.localizedDescription)")
                        }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                
            } else {
                print("Couldn't add video device input to the session.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
            
            // setup output, add output to our capture session
            let captureOutput = AVCaptureVideoDataOutput()
            
            captureOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)]
            
            captureOutput.alwaysDiscardsLateVideoFrames = true
            
           
            let captureSessionQueue = DispatchQueue(label: "CameraSessionQueue", attributes: [])
            captureOutput.setSampleBufferDelegate(self, queue: captureSessionQueue)
            //captureOutput.alwaysDiscardsLateVideoFrames = true
            if session.canAddOutput(captureOutput) {
                session.addOutput(captureOutput)
            } else {
                print("Error: Cannot add the Output to the session")
            }
            
            
        } catch {
            print("Couldn't create video device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        session.commitConfiguration()
        
        
        self.isConfigured = true
        
        self.start()
        
    }
    
    private func texture(sampleBuffer: CMSampleBuffer?, textureCache: CVMetalTextureCache?, planeIndex: Int = 0, pixelFormat: MTLPixelFormat = .bgra8Unorm) throws -> MTLTexture {
            guard let sampleBuffer = sampleBuffer else {
                throw MetalCameraSessionError.missingSampleBuffer
            }
            guard let textureCache = textureCache else {
                throw MetalCameraSessionError.failedToCreateTextureCache
            }
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                throw MetalCameraSessionError.failedToGetImageBuffer
            }
            
            let isPlanar = CVPixelBufferIsPlanar(imageBuffer)
            let width = isPlanar ? CVPixelBufferGetWidthOfPlane(imageBuffer, planeIndex) : CVPixelBufferGetWidth(imageBuffer)
            let height = isPlanar ? CVPixelBufferGetHeightOfPlane(imageBuffer, planeIndex) : CVPixelBufferGetHeight(imageBuffer)
            
            var imageTexture: CVMetalTexture?
            
            let result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, imageBuffer, nil, pixelFormat, width, height, planeIndex, &imageTexture)

            guard
                let unwrappedImageTexture = imageTexture,
                let texture = CVMetalTextureGetTexture(unwrappedImageTexture),
                result == kCVReturnSuccess
            else {
                throw MetalCameraSessionError.failedToCreateTextureFromImage
            }

            return texture
        }
    
    public func start() {
//        We use our capture session queue to ensure our UI runs smoothly on the main thread.
        sessionQueue.async {
            if !self.isSessionRunning && self.isConfigured {
                switch self.setupResult {
                case .success:
                    self.session.startRunning()
                    self.isSessionRunning = self.session.isRunning
                  
                    if self.session.isRunning {
                        DispatchQueue.main.async {
                            self.isCameraUnavailable = false
                        }
                    }
                    
                case .configurationFailed, .notAuthorized:
                    print("Application not authorized to use camera")

                    DispatchQueue.main.async {
                        self.alertError = AlertError(title: "Camera Error", message: "Camera configuration failed. Either your device camera is not available or its missing permissions", primaryButtonTitle: "Accept", secondaryButtonTitle: nil, primaryAction: nil, secondaryAction: nil)
                        self.shouldShowAlertView = true
                        self.isCameraUnavailable = true
                    }
                }
            }
        }
    }
    
    /// - Tag: ChangeCamera
    public func changeCamera() {
       
        
        sessionQueue.async {
            let currentVideoDevice = self.videoDeviceInput.device
            let currentPosition = currentVideoDevice.position
            
            let preferredPosition: AVCaptureDevice.Position
            let preferredDeviceType: AVCaptureDevice.DeviceType
            
            switch currentPosition {
            case .unspecified, .front:
                preferredPosition = .back
                preferredDeviceType = .builtInWideAngleCamera
                
            case .back:
                preferredPosition = .front
                preferredDeviceType = .builtInWideAngleCamera
                
            @unknown default:
                print("Unknown capture position. Defaulting to back, dual-camera.")
                preferredPosition = .back
                preferredDeviceType = .builtInWideAngleCamera
            }
            let devices = self.videoDeviceDiscoverySession.devices
            var newVideoDevice: AVCaptureDevice? = nil
            
            // First, seek a device with both the preferred position and device type. Otherwise, seek a device with only the preferred position.
            if let device = devices.first(where: { $0.position == preferredPosition && $0.deviceType == preferredDeviceType }) {
                newVideoDevice = device
            } else if let device = devices.first(where: { $0.position == preferredPosition }) {
                newVideoDevice = device
            }
            
            if let videoDevice = newVideoDevice {
                do {
                    let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                    
                    self.session.beginConfiguration()
                    
                    // Remove the existing device input first, because AVCaptureSession doesn't support
                    // simultaneous use of the rear and front cameras.
                    self.session.removeInput(self.videoDeviceInput)
                    
                    if self.session.canAddInput(videoDeviceInput) {
                        self.session.addInput(videoDeviceInput)
                        self.videoDeviceInput = videoDeviceInput
                    } else {
                        self.session.addInput(self.videoDeviceInput)
                    }
                                        
                    
                    self.session.commitConfiguration()
                } catch {
                    print("Error occurred while creating video device input: \(error)")
                }
            }
            
        
        }
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let totalSampleSize = CMSampleBufferGetTotalSampleSize(sampleBuffer)
    }
    
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        let presentationTimestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let seconds = CMTimeGetSeconds(presentationTimestamp)
           
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
            }
        
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        print("Image Resolution: \(width)x\(height)")

        
        self.metalRender?.updateFrame(imageBuffer: imageBuffer, selectionState: MetalRenderer.SelectionStruct(
                x1: cameraModel?.x1 ?? 0, x2: cameraModel?.x2 ?? 0, y1: cameraModel?.y1 ?? 0, y2: cameraModel?.y2 ?? 0, editable: cameraModel?.isOverlayEditable ?? true), time: seconds)
       
    }
        
   
}





public enum MetalCameraSessionState {
    case ready
    case streaming
    case stopped
    case waiting
    case error
}

public enum MetalCameraPixelFormat {
    case rgb
    case yCbCr
    
    var coreVideoType: OSType {
        switch self {
        case .rgb:
            return kCVPixelFormatType_32BGRA
        case .yCbCr:
            return kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        }
    }
}

/**
 Streaming error
 */
public enum MetalCameraSessionError: Error {
    /**
     * Streaming errors
     *///
    case noHardwareAccess
    case failedToAddCaptureInputDevice
    case failedToAddCaptureOutput
    case requestedHardwareNotFound
    case inputDeviceNotAvailable
    case captureSessionRuntimeError
    
    /**
     * Conversion errors
     *///
    case failedToCreateTextureCache
    case missingSampleBuffer
    case failedToGetImageBuffer
    case failedToCreateTextureFromImage
    case failedToRetrieveTimestamp
    
    /**
     Indicates if the error is related to streaming the media.
     
     - returns: True if the error is related to streaming, false otherwise
     */
    public func isStreamingError() -> Bool {
        switch self {
        case .noHardwareAccess, .failedToAddCaptureInputDevice, .failedToAddCaptureOutput, .requestedHardwareNotFound, .inputDeviceNotAvailable, .captureSessionRuntimeError:
            return true
        default:
            return false
        }
    }
    
    public var localizedDescription: String {
        switch self {
        case .noHardwareAccess:
            return "Failed to get access to the hardware for a given media type"
        case .failedToAddCaptureInputDevice:
            return "Failed to add a capture input device to the capture session"
        case .failedToAddCaptureOutput:
            return "Failed to add a capture output data channel to the capture session"
        case .requestedHardwareNotFound:
            return "Specified hardware is not available on this device"
        case .inputDeviceNotAvailable:
            return "Capture input device cannot be opened, probably because it is no longer available or because it is in use"
        case .captureSessionRuntimeError:
            return "AVCaptureSession runtime error"
        case .failedToCreateTextureCache:
            return "Failed to initialize texture cache"
        case .missingSampleBuffer:
            return "No sample buffer to convert the image from"
        case .failedToGetImageBuffer:
            return "Failed to retrieve an image buffer from camera's output sample buffer"
        case .failedToCreateTextureFromImage:
            return "Failed to convert the frame to a Metal texture"
        case .failedToRetrieveTimestamp:
            return "Failed to retrieve timestamp from the sample buffer"
        }
    }
}

