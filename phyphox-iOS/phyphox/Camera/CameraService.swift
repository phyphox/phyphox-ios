//
//  CameraService.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 13.11.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//
//263a


import AVFoundation
import MetalKit
import CoreMedia

@available(iOS 13.0, *)
public class CameraService: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public let session = AVCaptureSession()
    
    private let sessionQueue = DispatchQueue(label: "session queue", attributes: [], autoreleaseFrequency: .workItem)
    
    private let metadataObjectsQueue = DispatchQueue(label: "sample buffer", attributes: [])
    
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    var setupResult: SessionSetupResult = .success
    
    weak var delegate: CameraCaptureHelperDelegate?
    
    public var alertError: AlertError = AlertError()
    
    var isSessionRunning = false
    
    var isConfigured = false
    
    @Published public var shouldShowAlertView = false
    
    @Published public var isCameraUnavailable = true
    
    private var queue =  DispatchQueue(label: "video output queue")
    
    var metalRender : MetalRenderer?
    
    let metalView: MTKView = MTKView()
    
    var image: CGImage?
    
    var flag: Bool = true
    
    var defaultVideoDevice: AVCaptureDevice?
    
    @Published var zoomScale: CGFloat = 1.0
    
    // MARK: Device Configuration Properties
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera], mediaType: .video, position: .unspecified)
    
    
    public func checkForPermisssion(){
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            
        case .authorized:
            print("CameraService: checkForPermission:  is authorizes")
            break
        case .notDetermined:
            print("CameraService: checkForPermission:  is notDetermined")
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
        default:
            print("CameraService: checkForPermission:  is default")
            setupResult = .notAuthorized
            
            DispatchQueue.main.async {
                self.alertError = AlertError(title: "Camera Access", message: "SwiftCamera doesn't have access to use your camera, please update your privacy settings.", primaryButtonTitle: "Settings", secondaryButtonTitle: nil, primaryAction: {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                  options: [:], completionHandler: nil)
                    
                }, secondaryAction: nil)
                self.shouldShowAlertView = true
                self.isCameraUnavailable = true
            }
            
            
        }
    }
    
    public func configure(){
        print("CameraService: configure")
        sessionQueue.async {
            self.configureSession()
        }
        
    }
    
    public func setUpMetal(){
        
        metalRender = CameraMetalView().makeCoordinator()
    
        
        //metalView.backgroundColor = UIColor.clear
        
        //metalRender = MetalRenderer(renderer: metalView)
        //metalView.delegate = metalRender
        
       // metalRender?.drawRectResized(size: metalView.bounds.size)
        
        
        
    }
    
    
    private func configureSession(){
        
        if setupResult != .success {
            return
        }
        
        session.beginConfiguration()
        session.sessionPreset = .medium
        

        
        do {
            
            if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
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
            
            do {
                try defaultVideoDevice?.lockForConfiguration()
                defaultVideoDevice?.videoZoomFactor = max(1.0, min(zoomScale, (defaultVideoDevice?.activeFormat.videoMaxZoomFactor)!))
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
            
       
            //captureOutput.videoSettings =
           
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
        
        print("CameraService: session configured")
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
                    print("CameraService: session running")
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
        print("CameraService: didDrop Total Sample Size: \(totalSampleSize)")
        
        print("CameraService: didDrop captureOutput sampleBuffer totalSampleSize", sampleBuffer.totalSampleSize)
        
    }
    
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("imagebuffer is nil")
            return
        }
        
        self.metalRender?.updateFrame(imageBuffer: imageBuffer, selectionState: MetalRenderer.SelectionStruct(x1: 0.4, x2: 0.6, y1: 0.4, y2: 0.6, editable: true))
        
        let isPlanar = CVPixelBufferIsPlanar(imageBuffer)
        let width = isPlanar ? CVPixelBufferGetWidthOfPlane(imageBuffer, 0) : CVPixelBufferGetWidth(imageBuffer)
        print("imagebuffer width: ", width)
        let height = isPlanar ? CVPixelBufferGetHeightOfPlane(imageBuffer, 1) : CVPixelBufferGetHeight(imageBuffer)
        print("imagebuffer height: ", height)
            }
        
    private let context = CIContext()
    
    // MARK: Sample buffer to UIImage conversion
        private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
           
            //context.render(ciImage, to: imageBuffer)
            
            //print("CameraSerivce: after Render: imagebuffer: ", imageBuffer.    )
            self.metalRender?.updateFrame(imageBuffer: imageBuffer, selectionState: MetalRenderer.SelectionStruct(x1: 0.4, x2: 0.6, y1: 0.4, y2: 0.6, editable: true))
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
            //print("imageBuffer: bytes per row: ",imageBuffer)
            return UIImage(cgImage: cgImage)
        }
    
    
    func convert(cmage:CIImage) -> UIImage {
        let context:CIContext = CIContext.init(options: nil)
        let cgImage:CGImage = context.createCGImage(cmage, from: cmage.extent)!
        let image:UIImage = UIImage.init(cgImage: cgImage)
        return image
    }
}

protocol CameraCaptureHelperDelegate: class
{
    @available(iOS 13.0, *)
    func newCameraImage(_ cameraCaptureHelper: CameraService, image: CIImage)
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

