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

protocol CameraMetalTextureProvider {
    var cameraImageTextureY: CVMetalTexture? { get }
    var cameraImageTextureCbCr: CVMetalTexture? { get }
    var inFlightSemaphore: DispatchSemaphore { get }
}

@available(iOS 14.0, *)
public class CameraService: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, CameraMetalTextureProvider {
    
    var cameraImageTextureY: CVMetalTexture?
    var cameraImageTextureCbCr: CVMetalTexture?
    let inFlightSemaphore = DispatchSemaphore(value: kMaxBuffersInFlight)

    var cameraImageTextureCache: CVMetalTextureCache!
    
    public let session = AVCaptureSession()
    
    let sessionQueue = DispatchQueue(label: "session queue", attributes: [], autoreleaseFrequency: .workItem)
    
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    var setupResult: SessionSetupResult = .success
    
    public var alertError: AlertError = AlertError()
    
    var isSessionRunning = false
    
    @Published public var shouldShowAlertView = false
    
    @Published public var isCameraUnavailable = true
    
    private var queue =  DispatchQueue(label: "video output queue")
    
    var analyzingRenderer : AnalyzingRenderer?
    
    var defaultVideoDevice: AVCaptureDevice? = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        
    var cameraModelOwner: CameraModelOwner? = nil
    var cameraSettingModel: CameraSettingsModel = CameraSettingsModel()
    
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera], mediaType: .video, position: .unspecified)
    
    let defaultMinExposureCMTime = CMTime(value: 14, timescale: 1000000, flags: CMTimeFlags(rawValue: 1), epoch: 0)
    let defaultMaxExposureCMTime = CMTime(value: 1, timescale: 1, flags: CMTimeFlags(rawValue: 1), epoch: 0)
    
    let shutters = [1, 2, 4, 8, 15, 30, 60, 125, 250, 500, 1000, 2000, 4000, 8000]
    
    var isConfigured = false
    
    
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
    
    public func setupTextures() {
        var textureCache: CVMetalTextureCache?
        if let defaultVideoDevice = analyzingRenderer?.metalDevice {
            CVMetalTextureCacheCreate(nil, nil, defaultVideoDevice, nil, &textureCache)
            cameraImageTextureCache = textureCache
        }
    }
    
    public func configure(){
        //resetCallCount()
        sessionQueue.async {
            self.configureSession()
        }
        
    }

    func setValuesForCameraSettingsList(){
        
        guard let cameraSettingModel = cameraModelOwner?.cameraModel?.cameraSettingsModel else { return }
        
        cameraSettingModel.zoomOpticalLensValues =  getOpticalZoomList()
        cameraSettingModel.exposureValues =  getExposureValues()
        cameraSettingModel.isoValues = getIsoRange(min: (cameraSettingModel.minIso), max: (cameraSettingModel.maxIso))
        cameraSettingModel.shutterSpeedValues =  getShutterSpeedRange()
        
    }
    
    
    func getMaxZoom() -> Int{
        if(self.defaultVideoDevice?.virtualDeviceSwitchOverVideoZoomFactors.isEmpty == true){
            return Int(3)
        } else {
            return (self.defaultVideoDevice?.virtualDeviceSwitchOverVideoZoomFactors.last?.intValue ?? 1) * 3
        }
    }
    
    func setCameraSettinginfo(){
        guard let defaultVideoDevice = self.defaultVideoDevice else { return }
        guard let cameraModel = cameraModelOwner?.cameraModel else { return }
        
        let cameraSettingsModel = cameraModel.cameraSettingsModel
        
        cameraSettingsModel.minZoom = Int((defaultVideoDevice.minAvailableVideoZoomFactor))
        cameraSettingsModel.maxZoom = getMaxZoom()
        cameraSettingsModel.maxOpticalZoom = defaultVideoDevice.virtualDeviceSwitchOverVideoZoomFactors.last?.intValue ?? 1
        
        if defaultVideoDevice.deviceType != .builtInWideAngleCamera { return }
        
        cameraSettingsModel.minIso = defaultVideoDevice.activeFormat.minISO
        cameraSettingsModel.maxIso = defaultVideoDevice.activeFormat.maxISO
        cameraSettingsModel.currentIso = 100
        
        cameraSettingsModel.minShutterSpeed = CMTimeGetSeconds(defaultVideoDevice.activeFormat.minExposureDuration)
        cameraSettingsModel.maxShutterSpeed = CMTimeGetSeconds(defaultVideoDevice.activeFormat.maxExposureDuration)
        
        cameraSettingsModel.apertureValue = defaultVideoDevice.lensAperture
        
        if defaultVideoDevice.deviceType == .builtInDualWideCamera || defaultVideoDevice.deviceType == .builtInTripleCamera {
            cameraSettingsModel.ultraWideCamera = true
        }
        
        cameraSettingsModel.currentApertureValue = defaultVideoDevice.lensAperture
        cameraSettingsModel.currentShutterSpeed = findClosestPredefinedShutterSpeed(for: defaultVideoDevice.exposureDuration)
        
        let minExposure = defaultVideoDevice.minExposureTargetBias
        let maxExposure = defaultVideoDevice.maxExposureTargetBias
        cameraSettingsModel.exposureCompensationRange = minExposure...maxExposure
        
        setValuesForCameraSettingsList()
        
    }
    
   
    public func changeBuiltInCameraDevice(preferredDevice: AVCaptureDevice.DeviceType){
        
        sessionQueue.async {
            let ultraWideDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [preferredDevice], mediaType: .video, position: .back)
            
            let device = ultraWideDeviceDiscoverySession.devices
            
            let newVideoDevice: AVCaptureDevice? = device.first
            
            if(!ultraWideDeviceDiscoverySession.devices.isEmpty){
                
                if let videoDevice = newVideoDevice {
                    do {
                        let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                        
                        self.session.beginConfiguration()
                        
                        self.session.removeInput(self.videoDeviceInput)
                        
                        if self.session.canAddInput(videoDeviceInput) {
                            self.session.addInput(videoDeviceInput)
                            self.videoDeviceInput = videoDeviceInput
                        } else {
                            self.session.addInput(self.videoDeviceInput)
                        }
                        self.defaultVideoDevice = videoDevice
                        self.setBestInputFormat(for: videoDevice)
                    
                        self.setCameraSettinginfo()
                        
                        
                        if(preferredDevice == .builtInWideAngleCamera){
                            self.cameraSettingModel.isDefaultCamera = true
                        } else {
                            self.cameraSettingModel.isDefaultCamera = false
                        }
                        
                        self.analyzingRenderer?.defaultVideoDevice = self.defaultVideoDevice
                        
                        self.session.commitConfiguration()
                    } catch {
                        print("Error occurred while creating video device input: \(error)")
                    }
                    
                }
            }
            
        }
    }
    
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
                    self.defaultVideoDevice = videoDevice
                    self.setBestInputFormat(for: videoDevice)
                                        
                    self.setCameraSettinginfo()
                    
                    self.analyzingRenderer?.defaultVideoDevice = self.defaultVideoDevice
                    
                    
                    self.session.commitConfiguration()
                } catch {
                    print("Error occurred while creating video device input: \(error)")
                }
                
            }
        }
        
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //print("captureOutput didDrop")
    }
    var functionCallCount = 0
    
    // Reset function call count every second to count the frame rate
    func resetCallCount() {
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            print("Function called \(self.functionCallCount) times in the last second")
            self.functionCallCount = 0
            
            self.resetCallCount() // Restart the timer
        }
    }
    
    func createTexture(fromPixelBuffer pixelBuffer: CVImageBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> CVMetalTexture? {
        
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex) // for example 480  //240
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex) // for example 360 //180
        
        var texture: CVMetalTexture? = nil
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, cameraImageTextureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &texture)
        
        if status != kCVReturnSuccess {
            texture = nil
        }
        
        return texture
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        //print("captureOutput didOutput")
        let presentationTimestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let seconds = CMTimeGetSeconds(presentationTimestamp)
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let _ = CVPixelBufferGetWidth(imageBuffer)
        let _ = CVPixelBufferGetHeight(imageBuffer)
       
        functionCallCount += 1
        
        if CVPixelBufferGetPlaneCount(imageBuffer) < 2 {
            print("updateCameraImageTextures less than 2")
            return
        }
        cameraImageTextureY = createTexture(fromPixelBuffer: imageBuffer, pixelFormat: .r8Unorm, planeIndex: 0)
        cameraImageTextureCbCr = createTexture(fromPixelBuffer: imageBuffer, pixelFormat: .rg8Unorm, planeIndex: 1)
        
        guard let cameraImageTextureY = cameraImageTextureY, let cameraImageTextureCbCr = cameraImageTextureCbCr else {
            return
        }
        
        self.analyzingRenderer?.updateFrame(time: seconds,
                cameraImageTextureY: cameraImageTextureY, cameraImageTextureCbCr: cameraImageTextureCbCr
        )
        
    }
    
    //MARK: Camera Configuration
    
    func configureSession(){
        if setupResult != .success {
            return
        }
        
        session.beginConfiguration()
        do {
            // builtInDualWideCamera -m virtualDeviceSwitchOverVideoZoomFactors [2]
            let defaultCameraType = defaultVideoDevice?.deviceType ?? AVCaptureDevice.DeviceType.builtInWideAngleCamera
            print("defaultCameraType ", defaultCameraType)
            if let backCameraDevice = AVCaptureDevice.default(defaultCameraType, for: .video, position: .back) {
                // If a rear dual camera is not available, default to the rear wide angle camera.
                defaultVideoDevice = backCameraDevice
            } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                // If the rear wide angle camera isn't available, default to the front wide angle camera.
                defaultVideoDevice = frontCameraDevice
            }
            
            guard let videoDevice = defaultVideoDevice else {
                print("Default video device is unavailable.")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                        
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                
                setBestInputFormat(for: videoDevice)
                
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
            
            if session.canAddOutput(captureOutput) {
                session.addOutput(captureOutput)
            } else {
                print("Error: Cannot add the Output to the session")
            }
            
            let formatDescription = videoDevice.activeFormat.formatDescription
            let dimension = CMVideoFormatDescriptionGetDimensions(formatDescription)
            
            print("Resolution: \(dimension.width)x\(dimension.height)")
            print("Max frame duration: \(videoDevice.activeVideoMaxFrameDuration)")
            cameraModelOwner?.updateResolution(CGSize(width: Int(dimension.width), height: Int(dimension.height)))
            
            analyzingRenderer?.defaultVideoDevice = defaultVideoDevice
            setCameraSettinginfo()
            
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
    
    func setBestInputFormat(for videoDevice: AVCaptureDevice) {
        //Find best video format with following priority:
        //1. Highest framerate!!!
        //2. Aspect ratio matching the sensor to avoid cropping
        //3. Smaller side of resolution close to small side of screen resolution (optimizing preview quality while maintaining a reasonable amount of detail for data analysis)
        
        var bestFormat: AVCaptureDevice.Format? = nil
        var bestFrameRateRange: AVFrameRateRange? = nil
        var bestAspectRatio: Float? = nil
        var bestHeight: Int32? = nil
        let targetHeight = Int32(min(UIScreen.main.bounds.width, UIScreen.main.bounds.height))
        
        //Find highest resolution for photos as best guess for camera aspect ratio (probably always 4:3 anyway)
        var highestResolution: CMVideoDimensions? = nil
        for format in videoDevice.formats {
            let highRes = format.highResolutionStillImageDimensions
            if highRes.width * highRes.height > (highestResolution?.width ?? 0) * (highestResolution?.height ?? 0) {
                highestResolution = highRes
            }
        }
        let targetAspect = Float(highestResolution?.width ?? 1) / Float(highestResolution?.height ?? 1)
        
        for format in videoDevice.formats {
            for range in format.videoSupportedFrameRateRanges {
                let aspectRatio = Float(format.formatDescription.dimensions.width) / Float(format.formatDescription.dimensions.height)
                let height = format.formatDescription.dimensions.height
                
                //Better framerate always wins
                if range.maxFrameRate > bestFrameRateRange?.maxFrameRate ?? 0 {
                    bestFormat = format
                    bestFrameRateRange = range
                    bestAspectRatio = aspectRatio
                    bestHeight = height
                    continue
                } else if range.maxFrameRate < bestFrameRateRange?.maxFrameRate ?? 0 {
                    continue
                }
                
                //Prefer uncropped aspect ratios
                if abs(aspectRatio - (bestAspectRatio ?? 0.0)) > 0.01 { //else identical within rounding errors
                    if abs(aspectRatio - targetAspect) < abs((bestAspectRatio ?? 0.0) - targetAspect) {
                        bestFormat = format
                        bestFrameRateRange = range
                        bestAspectRatio = aspectRatio
                        bestHeight = height
                        continue
                    } else if abs(aspectRatio - targetAspect) > abs((bestAspectRatio ?? 0.0) - targetAspect) {
                        continue
                    }
                }
                
                //Prefer resolutions with a height close to the screen's width
                if (abs(height - targetHeight) < abs((bestHeight ?? 0) - targetHeight)) {
                    bestFormat = format
                    bestFrameRateRange = range
                    bestAspectRatio = aspectRatio
                    bestHeight = height
                    continue
                }
            }
        }
        print("Best format: \(bestFormat.debugDescription) with frame rate range \(bestFrameRateRange), aspect ratio \(bestAspectRatio), height \(bestHeight)")
        
        if let bestFormat = bestFormat, let bestFrameRateRange = bestFrameRateRange {
            do {
                try videoDevice.lockForConfiguration()
                videoDevice.activeFormat = bestFormat
                videoDevice.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(bestFrameRateRange.maxFrameRate))
                videoDevice.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(bestFrameRateRange.maxFrameRate))
                videoDevice.unlockForConfiguration()
            } catch {
                print("Failed to set best format.")
            }
        }
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
    
    
    //Mark CAmera Setting
    
    var configLocked = false
    
    @Published var zoomScale: CGFloat = 1.0
    
    
    func lockConfig(complete: () -> ()) {
        if isConfigured {
            configLocked = true
            do{
                try defaultVideoDevice?.lockForConfiguration()
                complete()
                defaultVideoDevice?.unlockForConfiguration()
                configLocked = false
            } catch {
                configLocked = false
                
            }
        }
    }
    
    
    func getAvailableDevices(position: AVCaptureDevice.Position?) -> [Dictionary<String, String>]{
        let devices: [AVCaptureDevice]
        if #available(iOS 15.4, *) {
            devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera, .builtInDualWideCamera, .builtInLiDARDepthCamera, .builtInTelephotoCamera, .builtInTripleCamera, .builtInUltraWideCamera, ], mediaType: .video, position: position ?? .back).devices
            
        } else {
            devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera, .builtInDualWideCamera, .builtInTelephotoCamera, .builtInTripleCamera, .builtInUltraWideCamera, ], mediaType: .video, position: position ?? .back).devices
        }
        
        return devices.compactMap { device in
            if #available(iOS 15.4, *), device.deviceType == .builtInLiDARDepthCamera {
                return getNewDevicesName(device: device.deviceType)
            } else {
                return getDevicesName(device: device.deviceType)
            }
        }
        
    }
    
    private func getDevicesName(device: AVCaptureDevice.DeviceType) -> [String: String]{
        return switch(device) {
        case  .builtInDualCamera : ["Dual Camera": "Camera device type that consists of a wide-angle and telephoto camera."]
        case  .builtInDualWideCamera : ["Dual Wide Camera": "Camera device type that consists of two cameras of fixed focal length, one ultrawide angle and one wide angle."]
        case  .builtInTripleCamera : ["Triple Camera":"Camera device type that consists of three cameras of fixed focal length, one ultrawide angle, one wide angle, and one telephoto."]
        case  .builtInTelephotoCamera : ["Telephoto Camera":"Camera device type with a longer focal length than a wide-angle camera"]
        case  .builtInTrueDepthCamera : ["True Depth Camera":"A device that consists of two cameras, one Infrared and one YUV."]
        case  .builtInUltraWideCamera  : ["Ultra Wide Camera":"Camera device type with a shorter focal length than a wide-angle camera."]
        case  .builtInWideAngleCamera : ["Wide Angle Camera":"A default wide-angle camera device type."]
        default : ["not available": ""]
        }
        
    }
    
    
    @available(iOS 15.4, *)
    private func getNewDevicesName(device: AVCaptureDevice.DeviceType) -> [String: String]{
        switch(device) {
        case  .builtInLiDARDepthCamera : return ["LiDAR Depth Camera": "A device that consists of two cameras, one LiDAR and one YUV."]
        default : return ["not available": ""]
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
    
    
    func getAvailableOpticalZoomList(maxOpticalZoom_: Int?) -> [Int] {
        guard let maxOpticalZoom = maxOpticalZoom_ else {
            return []
        }
        
        if maxOpticalZoom == 1 {
            return [1]
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
    
    func getOpticalZoomList() -> [Float] {
        var zoomList: [Double] = []
        
        zoomList.append(getMinimumZoomValue(defaultCamera: false))
        
        if let virtualDeviceZoomFactors = defaultVideoDevice?.virtualDeviceSwitchOverVideoZoomFactors {
            print("virtualDeviceZoomFactors", virtualDeviceZoomFactors)
            if(virtualDeviceZoomFactors.isEmpty){
                zoomList.append(1.0)
            }
            zoomList.append(contentsOf: virtualDeviceZoomFactors.map { Double(truncating: $0) / 2.0 })
        }
        
        
        if #available(iOS 16.0, *) {
            if let secondaryZoomFactors = defaultVideoDevice?.activeFormat.secondaryNativeResolutionZoomFactors {
                print("secondaryZoomFactors ", secondaryZoomFactors)
                zoomList.append(contentsOf: secondaryZoomFactors.map { Double($0) / 2.0 })
            }
        }
        let array = Array(Set(zoomList)) // to make sure there are not duplicate numbers
        return array.sorted().map{Float($0)}
        
    }
    
    func getMinimumZoomValue(defaultCamera: Bool) -> Double {
        
        if(defaultCamera){
            return 1.0
        }
        
        let additionalCameras = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualWideCamera, .builtInTripleCamera, .builtInUltraWideCamera], mediaType: .video, position: .back)
        
        if(!additionalCameras.devices.isEmpty){
            let minZoomFactor = Double(defaultVideoDevice?.minAvailableVideoZoomFactor ?? 2) / 2.0
            if minZoomFactor < 1.0 {
                return Double(String(format: "%.1f", minZoomFactor)) ?? 1.0
            } else {
                return Double(minZoomFactor)
            }
        } else {
            return 1.0
        }
    }
    
    
    func shutterSpeedRange(min: Int, max: Int) -> [Int] {
        let filteredShutterSpeedRange = shutters.filter{$0 >= min && $0 <= max}
        
        return filteredShutterSpeedRange
    }
    
    func getShutterSpeedRange() -> [Float] {
        var shutters_available: [Float] = []
        
        guard let defaultCamera = defaultVideoDevice else { return [] }
        
        let min_seconds = defaultCamera.activeFormat.minExposureDuration.seconds
        let max_seconds = defaultCamera.activeFormat.maxExposureDuration.seconds
        
        for one_shutter in shutters {
            let seconds = 1.0 / Float64(one_shutter)
            if seconds >= min_seconds && seconds <= max_seconds {
                shutters_available.append(Float(one_shutter))
            }
        }
        
        return shutters_available
        
    }
    
    func getNearestValue(value: Int, numbers: [Int]) -> Int{
        
        if(numbers.contains(value)){
            return value
        }
        
        for (index, number) in numbers.enumerated() {
            if(number > value){
                let average = (number + numbers[index - 1])/2
                if(value > average){
                    return number
                } else {
                    return numbers[index - 1]
                }
            }
        }
        return value
    }
    
    
    func findClosestPredefinedShutterSpeed(for currentTime: CMTime) -> CMTime {
        
        var closestCMTime: CMTime = .zero
        
        for (index, _) in shutterSpeeds.enumerated() {
            if(index == shutterSpeeds.count - 1){
                break
            }
            
            let currentIndexSecond = shutterSpeeds[index].seconds
            let nextIndexSecond = shutterSpeeds[index + 1].seconds
            let average = (currentIndexSecond + nextIndexSecond) / 2
            let currentThreshold =  shutterSpeeds[index].seconds - average
          
            let value = nextIndexSecond + currentThreshold
            
            if(currentTime.seconds <= currentIndexSecond && currentTime.seconds >= nextIndexSecond ) {
               
                if(value > currentTime.seconds) {
                    closestCMTime = shutterSpeeds[index + 1]
                    break
                } else {
                    closestCMTime = shutterSpeeds[index]
                    break
                }
            } else {
              continue
            }
        }
        return closestCMTime
    }
    
    func getIsoRange(min: Float, max: Float) -> [Float] {
        let filteredIsoRange = iso.filter { $0 >= Int(min) && $0 <= Int(max) }
        
        return filteredIsoRange.map{Float($0)}
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
    
    
    func changeISO(_ iso: Int) {
        
        let duration_seconds = (cameraModelOwner?.cameraModel?.cameraSettingsModel.currentShutterSpeed) ?? defaultMinExposureCMTime
        
        if (defaultVideoDevice?.isExposureModeSupported(.custom) == true){
            lockConfig { () -> () in
                defaultVideoDevice?.exposureMode = .custom
                defaultVideoDevice?.setExposureModeCustom(duration: duration_seconds , iso: Float(iso), completionHandler: nil)
                cameraModelOwner?.cameraModel?.cameraSettingsModel.currentIso = iso
                
            }
        } else {
            print("custom exposure setting not supported")
        }
        
    }
    
    func changeExposureDuration(_ p: Double) {
        let seconds = 1.0 / Float64(p)
        let duration_seconds = CMTimeMakeWithSeconds(seconds, preferredTimescale: 1000*1000*1000 )
        if (defaultVideoDevice?.isExposureModeSupported(.custom) == true){
            lockConfig { () -> () in
                defaultVideoDevice?.exposureMode = .custom
                defaultVideoDevice?.setExposureModeCustom(duration: duration_seconds , iso: AVCaptureDevice.currentISO, completionHandler: nil)
                cameraModelOwner?.cameraModel?.cameraSettingsModel.currentShutterSpeed = duration_seconds
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
                print("Error setting camera shutter speed: \(error.localizedDescription)")
            }
        }
        else {
            print("custom exposure setting not supported")
        }
    }
    
    private func changeExposureMode(mode: AVCaptureDevice.ExposureMode){
        lockConfig { () -> () in
            if ((self.defaultVideoDevice?.isExposureModeSupported(mode)) != nil) {
                self.defaultVideoDevice?.exposureMode = mode
            }
        }
    }
    
    // the custom setting is not supported in the dual wide camera but it does supports
    // in the wide angle camera. don't support RAW capture and manual controls.
    //  if you want to achieve manual control you have to select wide-angle or telephoto camera.
    // https://developer.apple.com/library/archive/releasenotes/General/WhatsNewIniOS/Articles/iOS10.html
    
    func setExposureTo(auto: Bool){
        print("setExposureTo auto, ", auto)
        
        if(defaultVideoDevice?.isExposureModeSupported(.locked) == true){
            print("locked exposure setting  supported")
        }
        
        if(defaultVideoDevice?.isExposureModeSupported(.autoExpose) == true){
            print("autoexposure exposure setting  supported")
        }
        
        if(defaultVideoDevice?.isExposureModeSupported(.continuousAutoExposure) == true){
            print("continuos auto exposure setting  supported")
        }
        
        if(defaultVideoDevice?.isExposureModeSupported(.custom) == true){
            print("custom exposure setting  supported")
        }
        if(defaultVideoDevice?.isExposureModeSupported(.autoExpose) == true){
            lockConfig { () -> () in
                //defaultVideoDevice?.exposureMode = auto ? .autoExpose :
            }
        } else {
            print("custom exposure setting not supported")
        }
        
    }
    
    func changeExposure(value: Float) {
        
        if (defaultVideoDevice?.isExposureModeSupported(.locked)  == true && defaultVideoDevice?.isExposureModeSupported(.continuousAutoExposure) == true){
            do {
                try defaultVideoDevice?.lockForConfiguration()
                defaultVideoDevice?.exposureMode = .continuousAutoExposure
                defaultVideoDevice!.setExposureTargetBias(value, completionHandler: nil)
                cameraModelOwner?.cameraModel?.cameraSettingsModel.currentExposureValue = value
                defaultVideoDevice?.unlockForConfiguration()
            } catch {
                print("Error setting camera expsoure: \(error.localizedDescription)")
            }
        }
        else {
            print("custom exposure setting not supported")
        }
    }
    
    func getExposureValues() -> [Float] {
        return getExposureValuesFromRange(min: Int(cameraModelOwner?.cameraModel?.cameraSettingsModel.exposureCompensationRange?.lowerBound ?? -8.0),
                                          max: Int(cameraModelOwner?.cameraModel?.cameraSettingsModel.exposureCompensationRange?.upperBound ?? 8.0),
                                          step: 1)
    }
    
    func getExposureValuesFromRange(min: Int, max: Int, step: Float) -> [Float] {
        var exposureValues = [Float]()
        
        for value in min...max {
            let exposureCompensation = Float(value) * step
            let decimalPlaces = 1
            let powerOf10 = pow(10.0, Float(decimalPlaces))
            let roundedNumber = round(exposureCompensation * powerOf10) / powerOf10
            exposureValues.append(roundedNumber)
        }
        
        return exposureValues.filter { (Int($0 * 10) % 5) == 0 }
    }
    
    
    
}
