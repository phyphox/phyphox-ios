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
public class CameraService: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, CameraMetalTextureProvider, ExposureStatisticsListener {
    
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
    
    public var shouldShowAlertView = false
    
    public var isCameraUnavailable = true
    
    private var queue =  DispatchQueue(label: "video output queue")
    
    var analyzingRenderer : AnalyzingRenderer?
    
    var defaultVideoDevice: AVCaptureDevice? = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        
    var cameraModelOwner: CameraModelOwner? = nil
    
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
        
        cameraSettingsModel.minShutterSpeed = defaultVideoDevice.activeFormat.minExposureDuration
        cameraSettingsModel.maxShutterSpeed = defaultVideoDevice.activeFormat.maxExposureDuration
        
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
    
    func newExposureStatistics(minRGB: Double, maxRGB: Double, meanLuma: Double) {
        guard let cameraModel = cameraModelOwner?.cameraModel else {
            return
        }
        if !cameraModel.autoExposureEnabled {
            return
        }
        var adjust = 1.0
        var targetExposure = Double(0.5 * pow(2.0, cameraModel.cameraSettingsModel.currentExposureValue))
        if targetExposure > 0.95 {
            targetExposure = 0.95
        }
        
        let framerate = min(1.0/cameraModel.cameraSettingsModel.maxFrameDuration, Double(cameraModel.cameraSettingsModel.currentShutterSpeed.timescale) / Double(cameraModel.cameraSettingsModel.currentShutterSpeed.value))
        let speedfactor = 30.0/framerate
        
        switch cameraModel.aeStrategy {
        case .mean:
            adjust = 1.0 - speedfactor * 0.1 * (meanLuma - targetExposure)
        case .avoidUnderexposure:
            if minRGB > 0.2 {
                adjust = 1.0 - speedfactor * 0.1 * (meanLuma - targetExposure)
            } else if minRGB > 0.1 {
                adjust = 1.0 - speedfactor * 0.1 * (minRGB - 0.25)
            } else {
                adjust = 1.0 - speedfactor * 0.2 * (minRGB - 0.25)
            }
        case .avoidOverexposure:
            if maxRGB < 0.8 {
                adjust = 1.0 - speedfactor * 0.1 * (meanLuma - targetExposure)
            } else if maxRGB < 0.9 {
                adjust = 1.0 - speedfactor * 0.1 * (maxRGB - 0.75)
            } else {
                adjust = 1.0 - speedfactor * 0.2 * (maxRGB - 0.75)
            }
        }
        
        let (shutter, iso) = calculateAdjustedExposure(adjust: adjust, state: cameraModel.cameraSettingsModel)
        
        changeExposureDurationIso(duration: shutter, iso: iso)
    }
    
    func calculateAdjustedExposure(adjust: Double, state: CameraSettingsModel) -> (shutter: CMTime, iso: Int) {
        let shutterTarget = state.maxFrameDuration
        let shutterUsabilityLimit = CMTime(value: 1, timescale: 15)
        
        var iso = state.currentIso
        var shutter = state.currentShutterSpeed
        
        func isoShutterRating(iso: Int, shutter: CMTime) -> Double {
            let isoPenalty = abs(log(Double(iso)/50.0)/log(2.0)) //Prefer ISO 100
            let shutterPenalty = 10*abs(log(shutter.seconds/shutterTarget)/log(2.0)) //Strongly prefer shutter time of maxFrameDuration
            let slowExposurePenalty = shutter.seconds > shutterTarget ? 1000.0 : 0.0 //Big penalty for exposure times that reduce the frame rate
            return isoPenalty + shutterPenalty + slowExposurePenalty
        }
        
        var shutterOption = shutter
        var isoOption = iso
        var optionRating = isoShutterRating(iso: iso, shutter: shutter) + 10000 //Old value is only a fallback
        for isoCandidate in state.isoValues {
            let thisIso = Int(isoCandidate)
            let idealShutter = shutter.seconds * adjust * Double(iso) / Double(isoCandidate)
            if idealShutter < state.minShutterSpeed.seconds || idealShutter > state.maxShutterSpeed.seconds {
                continue
            }
            let thisShutter = CMTime(value: Int64(idealShutter*1_000_000_000), timescale: 1_000_000_000)
            let rating = isoShutterRating(iso: thisIso, shutter: thisShutter)
            if rating < optionRating {
                shutterOption = thisShutter
                isoOption = thisIso
                optionRating = rating
            }
        }
        shutter = shutterOption
        iso = isoOption
        if shutter.seconds > state.maxShutterSpeed.seconds {
            shutter = state.maxShutterSpeed
        }
        if shutter.seconds > shutterUsabilityLimit.seconds {
            shutter = shutterUsabilityLimit
        }
        if shutter.seconds < state.minShutterSpeed.seconds {
            shutter = state.minShutterSpeed
        }

        return (shutter, iso)
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
                            self.cameraModelOwner?.cameraModel?.cameraSettingsModel.isDefaultCamera = true
                        } else {
                            self.cameraModelOwner?.cameraModel?.cameraSettingsModel.isDefaultCamera = false
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
            
            captureOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            
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
            cameraModelOwner?.cameraModel?.cameraSettingsModel.maxFrameDuration = videoDevice.activeVideoMaxFrameDuration.seconds
            
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
    
    var zoomScale: CGFloat = 1.0
    
    
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
    
    func changeIso(_ iso: Int) {
        guard let cameraSettingModel = cameraModelOwner?.cameraModel?.cameraSettingsModel else { return }
        changeExposureDurationIso(duration: cameraSettingModel.currentShutterSpeed, iso: iso)
    }
    
    func changeExposureDuration(_ duration: CMTime) {
        guard let cameraSettingModel = cameraModelOwner?.cameraModel?.cameraSettingsModel else { return }
        changeExposureDurationIso(duration: duration, iso: cameraSettingModel.currentIso)
    }
    
    func changeExposureDurationIso(duration: CMTime, iso: Int) {
        guard let cameraSettingModel = cameraModelOwner?.cameraModel?.cameraSettingsModel else { return }
        if (defaultVideoDevice?.isExposureModeSupported(.custom) == true){
            lockConfig { () -> () in
                defaultVideoDevice?.exposureMode = .custom
                defaultVideoDevice?.setExposureModeCustom(duration: duration , iso: Float(iso), completionHandler: nil)
                cameraSettingModel.currentShutterSpeed = duration
                cameraSettingModel.currentIso = iso
            }
        } else {
            print("custom exposure setting not supported")
        }
    }
    
    func setExposureTo(auto: Bool){
        cameraModelOwner?.cameraModel?.autoExposureEnabled = auto
    }
    
    func changeExposure(value: Float) {
        guard let cameraSettingsModel = cameraModelOwner?.cameraModel?.cameraSettingsModel else { return }

        if !(cameraModelOwner?.cameraModel?.autoExposureEnabled ?? false) {
            let adjust = pow(2.0, value - cameraSettingsModel.currentExposureValue)
            let (shutter, iso) = calculateAdjustedExposure(adjust: Double(adjust), state: cameraSettingsModel)
            changeExposureDurationIso(duration: shutter, iso: iso)
        }
        cameraSettingsModel.currentExposureValue = value
    }
    
    func getExposureValues() -> [Float] {
        //Since we use our own AE implementation, we can offer any selection of exposure compensation presets. However, since in practice our AE is applied to a selected area only mild corrections should be necessary.
        return [-1.0, -0.7, -0.3, 0.0, 0.3, 0.7, 1.0]
    }
}
