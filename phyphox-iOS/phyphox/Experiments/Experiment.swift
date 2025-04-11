//
//  Experiment.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import AVFoundation
import CoreLocation
import CoreMotion

private struct ExperimentRequiredPermission: OptionSet {
    let rawValue: Int
    
    static let none = ExperimentRequiredPermission([])
    static let microphone = ExperimentRequiredPermission(rawValue: (1 << 0))
    static let location = ExperimentRequiredPermission(rawValue: (1 << 1))
    static let motionFitness = ExperimentRequiredPermission(rawValue: (1 << 2))
    static let camera = ExperimentRequiredPermission(rawValue: (1 << 3))
}

struct ExperimentLink: Equatable {
    let label: String
    let url: URL
    let highlighted: Bool
}

final class Experiment {
    let title: String
    let stateTitle: String?
    private let description: String?
    private let links: [ExperimentLink]
    let category: String
    let isLink: Bool
    
    var localizedTitle: String {
        return translation?.selectedTranslation?.titleString ?? title
    }
    
    var displayTitle: String {
        return stateTitle ?? localizedTitle
    }
    
    var cleanedFilenameTitle: String {
        let title = displayTitle
        let regex = try! NSRegularExpression(pattern: "[^0-9a-zA-Z \\-_]", options: [])
        let range = NSMakeRange(0, title.count)
        let result = regex.stringByReplacingMatches(in: title, options: [], range: range, withTemplate: "")
        return result
    }
    
    var localizedDescription: String? {
        return translation?.selectedTranslation?.descriptionString ?? description
    }
    
    let localizedLinks: [ExperimentLink]
    
    var localizedCategory: String {
        if source?.path.hasPrefix(savedExperimentStatesURL.path) == true {
            return localize("save_state_category")
        }
        return translation?.selectedTranslation?.categoryString ?? category
    }

    weak var analysisDelegate: ExperimentAnalysisDelegate?

    let icon: ExperimentIcon
    
    let rawColor: UIColor?
    var color: UIColor {
        if let color = rawColor {
            return color
        } else if bluetoothDevices.count > 0 {
            return kBluetooth
        } else {
            return kHighlightColor
        }
    }

    var local: Bool = false
    var source: URL?
    var custom: Bool {
        return !(source?.absoluteString.starts(with: experimentsBaseURL.absoluteString) ?? true)
    }
    var crc32: UInt?
    var localResourceFolder: URL? {
        if let crc32 = crc32 {
            return customExperimentsURL.appendingPathComponent(String(crc32, radix: 16))
        } else {
            return nil
        }
    }
    var resourceFolder: URL? {
        if local && custom {
            return localResourceFolder
        } else {
            return source?.deletingLastPathComponent().appendingPathComponent("res")
        }
    }
    var resources: [String] {
        var res: Set<String> = []
        if let viewDescriptors = viewDescriptors {
            for viewDescriptor in viewDescriptors {
                for view in viewDescriptor.views {
                    if let view = view as? ResourceViewDescriptor {
                        for resource in view.resources {
                            res.insert(resource)
                        }
                    }
                }
            }
        }
        return Array(res)
    }
    
    var appleBan: Bool
    var invalid = false
    
    let timeReference: ExperimentTimeReference
    
    let viewDescriptors: [ExperimentViewCollectionDescriptor]?
    
    let translation: ExperimentTranslationCollection?

    let sensorInputs: [ExperimentSensorInput]
    let depthInput: ExperimentDepthInput?
    let cameraInput: ExperimentCameraInput?
    let gpsInputs: [ExperimentGPSInput]
    let audioInputs: [ExperimentAudioInput]
    
    let audioOutput: ExperimentAudioOutput?
    
    let bluetoothDevices: [ExperimentBluetoothDevice]
    let bluetoothInputs: [ExperimentBluetoothInput]
    let bluetoothOutputs: [ExperimentBluetoothOutput]
    
    let networkConnections: [NetworkConnection]
    
    let analysis: ExperimentAnalysis
    let export: ExperimentExport?
    
    let buffers: [String: DataBuffer]

    private var requiredPermissions: ExperimentRequiredPermission = .none
    
    private(set) var running = false
    private(set) var hasStarted = false

    public var audioEngine: AudioEngine?
    
    private let queue = DispatchQueue(label: "de.rwth-aachen.phyphox.analysis", attributes: [])

    init(title: String, stateTitle: String?, description: String?, links: [ExperimentLink], category: String, icon: ExperimentIcon, color: UIColor?, appleBan: Bool, isLink: Bool, translation: ExperimentTranslationCollection?, buffers: [String: DataBuffer], timeReference: ExperimentTimeReference, sensorInputs: [ExperimentSensorInput], depthInput: ExperimentDepthInput?, cameraInput: ExperimentCameraInput?, gpsInputs: [ExperimentGPSInput], audioInputs: [ExperimentAudioInput], audioOutput: ExperimentAudioOutput?, bluetoothDevices: [ExperimentBluetoothDevice], bluetoothInputs: [ExperimentBluetoothInput], bluetoothOutputs: [ExperimentBluetoothOutput], networkConnections: [NetworkConnection], viewDescriptors: [ExperimentViewCollectionDescriptor]?, analysis: ExperimentAnalysis, export: ExperimentExport?) {
        self.title = title
        self.stateTitle = stateTitle
        
        self.appleBan = appleBan
        
        self.isLink = isLink
        
        self.description = description
        self.links = links

        self.localizedLinks = links.map { ExperimentLink(label: translation?.localizeString($0.label) ?? $0.label, url: translation?.localizeLink($0.label, fallback: $0.url) ?? $0.url, highlighted: $0.highlighted) }

        self.category = category
        
        self.icon = icon
        self.rawColor = color
        
        self.translation = translation

        self.timeReference = timeReference
        
        self.buffers = buffers
        self.sensorInputs = sensorInputs
        self.depthInput = depthInput
        self.cameraInput = cameraInput
        self.gpsInputs = gpsInputs
        self.audioInputs = audioInputs
        
        self.audioOutput = audioOutput
        
        self.bluetoothDevices = bluetoothDevices
        self.bluetoothInputs = bluetoothInputs
        self.bluetoothOutputs = bluetoothOutputs
        
        self.networkConnections = networkConnections
        
        self.viewDescriptors = viewDescriptors
        self.analysis = analysis
        self.export = export
        
        defer {
            NotificationCenter.default.addObserver(self, selector: #selector(Experiment.endBackgroundSession), name: NSNotification.Name(rawValue: EndBackgroundMotionSessionNotification), object: nil)
        }
        
        if !audioInputs.isEmpty {
            requiredPermissions.insert(.microphone)
        }
        
        if !gpsInputs.isEmpty {
            requiredPermissions.insert(.location)
        }
        
        if (cameraInput != nil) {
            requiredPermissions.insert(.camera)
        }
        
        if (depthInput != nil) {
            requiredPermissions.insert(.camera)
        }
        
        if #available(iOS 17.4, *){
            for sensorInput in sensorInputs {
                if sensorInput.sensorType == .pressure {
                    requiredPermissions.insert(.motionFitness)
                    break
                }
            }
        }
        
        
        analysis.delegate = self
    }

    convenience init(file: String, error: String) {
        self.init(title: file, stateTitle: nil, description: error, links: [], category: localize("unknown"), icon: ExperimentIcon.string("!"), color: UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0), appleBan: false, isLink: false, translation: nil, buffers: [:], timeReference: ExperimentTimeReference(), sensorInputs: [], depthInput: nil, cameraInput: nil, gpsInputs: [], audioInputs: [], audioOutput: nil, bluetoothDevices: [], bluetoothInputs: [], bluetoothOutputs: [], networkConnections: [], viewDescriptors: nil, analysis: ExperimentAnalysis(modules: [], sleep: 0.0, dynamicSleep: nil, onUserInput: false, requireFill: nil, requireFillThreshold: 1, requireFillDynamic: nil, timedRun: false, timedRunStartDelay: 0.0, timedRunStopDelay: 0.0, timeReference: ExperimentTimeReference(), sensorInputs: [], audioInputs: []), export: nil)
        invalid = true;
    }
    
    @objc private func endBackgroundSession() {
        stop()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /**
     Called when the experiment view controller will be presented.
     */
    func willBecomeActive(_ dismiss: @escaping () -> Void) {
        if requiredPermissions != .none {
            checkAndAskForPermissions(dismiss, locationManager: gpsInputs.first?.locationManager)
        }
        analysis.queue = queue
        analysis.setNeedsUpdate(isPreRun: true)
    }
    
    /**
     Called when the experiment view controller did dismiss.
     */
    func didBecomeInactive() {
        for device in bluetoothDevices {
            device.disconnect()
            device.deviceAddress = nil
        }
        for networkConnection in networkConnections {
            networkConnection.disconnect()
            networkConnection.specificAddress = nil
        }
        clear(byUser: false)
    }
    
    func saveLocally(quiet: Bool, presenter: UINavigationController?) throws {
        guard let source = self.source else { throw FileError.genericError }

        if !FileManager.default.fileExists(atPath: customExperimentsURL.path) {
            try FileManager.default.createDirectory(atPath: customExperimentsURL.path, withIntermediateDirectories: false, attributes: nil)
        }
        
        var i = 1
        let cleanedTitle = title.replacingOccurrences(of: "/", with: "")
        var experimentURL = customExperimentsURL.appendingPathComponent(cleanedTitle).appendingPathExtension(experimentFileExtension)

        while FileManager.default.fileExists(atPath: experimentURL.path) {
            experimentURL = customExperimentsURL.appendingPathComponent(cleanedTitle + "-\(i)").appendingPathExtension(experimentFileExtension)
            
            i += 1
        }

        func moveFile(from fileURL: URL) throws {
            try FileManager.default.copyItem(at: fileURL, to: experimentURL)
            
            if self.resources.count > 0, let localResourceFolder = localResourceFolder, let resourceFolder = resourceFolder {
                try FileManager.default.createDirectory(at: localResourceFolder, withIntermediateDirectories: false)
                for resource in self.resources {
                    do {
                        try FileManager.default.copyItem(at: resourceFolder.appendingPathComponent(resource), to: localResourceFolder.appendingPathComponent(resource))
                    } catch {
                        print("Could not save \(resource).")
                    }
                }
            }
            
            self.source = experimentURL
            local = true
            
            mainThread {
                
                if !quiet, let controller = presenter {
                    let confirmation = UIAlertController(title: localize("save_locally"), message: localize("save_locally_done"), preferredStyle: .alert)
                    
                    confirmation.addAction(UIAlertAction(title: localize("ok"), style: .default, handler: nil))
                    controller.present(confirmation, animated: true, completion: nil)
                }
            }
        }

        if source.isFileURL {
            try moveFile(from: source)
        }
        else {
            URLSession.shared.downloadTask(with: source, completionHandler: { location, _, _ in
                guard let location = location else { return }
                
                try? moveFile(from: location)
            }).resume()
        }
    }
    
    private func checkAndAskForPermissions(_ failed: @escaping () -> Void, locationManager: CLLocationManager?) {
        if requiredPermissions.contains(.microphone) {
            let status = AVCaptureDevice.authorizationStatus(for: AVMediaType.audio)
            
            switch status {
            case .denied:
                failed()
                let alert = UIAlertController(title: "Microphone Required", message: "This experiment requires access to the Microphone, but the access has been denied. Please enable access to the microphone in Settings->Privacy->Microphone", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                UIApplication.shared.keyWindow!.rootViewController!.present(alert, animated: true, completion: nil)
                
            case .restricted:
                failed()
                let alert = UIAlertController(title: "Microphone Required", message: "This experiment requires access to the Microphone, but the access has been restricted. Please enable access to the microphone in Settings->General->Restrctions->Microphone", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                UIApplication.shared.keyWindow!.rootViewController!.present(alert, animated: true, completion: nil)
                
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: AVMediaType.audio, completionHandler: { (allowed) in
                    if !allowed {
                        failed()
                    }
                })
                
            default:
                break
            }
        } else if requiredPermissions.contains(.location) {
            
            let status = CLLocationManager.authorizationStatus()
            
            switch status {
            case .denied:
                failed()
                let alert = UIAlertController(title: "Location/GPS Required", message: "This experiment requires access to the location (GPS), but the access has been denied. Please enable access to the location in Settings->Privacy->Location Services", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                UIApplication.shared.keyWindow!.rootViewController!.present(alert, animated: true, completion: nil)
                
            case .restricted:
                failed()
                let alert = UIAlertController(title: "Location/GPS Required", message: "This experiment requires access to the location (GPS), but the access has been restricted. Please enable access to the location in Settings->General->Restrctions->Location Services", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                UIApplication.shared.keyWindow!.rootViewController!.present(alert, animated: true, completion: nil)
                
            case .notDetermined:
                locationManager?.requestWhenInUseAuthorization()
                break
                
            default:
                break
            }
        } else if requiredPermissions.contains(.motionFitness) {
            print("Motion and Fitness permission required.")
            let status = CMAltimeter.authorizationStatus()
            switch status {
            case .denied:
                failed()
                let alert = UIAlertController(title: "iOS >= 17.4 issue", message: "This experiment requires access to the pressure sensor. Normally, this would not require a permission, but iOS 17.4 introduced a bug that requires additional permissions. The access has been denied. Please enable the Motion and Fitness permission in Settings->Privacy->Motion and Fitness", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                UIApplication.shared.keyWindow!.rootViewController!.present(alert, animated: true, completion: nil)
            case .restricted:
                failed()
                let alert = UIAlertController(title: "iOS >= 17.4 issue", message: "This experiment requires access to the pressure sensor. Normally, this would not require a permission, but iOS 17.4 introduced a bug that requires additional permissions. The access has been restricted. Please enable the Motion and Fitness permission in Settings->Privacy->Motion and Fitness", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                UIApplication.shared.keyWindow!.rootViewController!.present(alert, animated: true, completion: nil)
                
            case .notDetermined:
                let recorder = CMSensorRecorder()
                DispatchQueue.global().async {
                    recorder.recordAccelerometer(forDuration: 0.1)
                }
                break
                
            default:
                break
            }
        }
        
        else if requiredPermissions.contains(.camera) {
           print("Camera permission required.")
            let status = AVCaptureDevice.authorizationStatus(for: .video)
           switch status {
           case .denied:
               failed()
               let alert = UIAlertController(title: "Camera required", message: "This experiment requires access to the camera sensor. but the access has been denied. Please enable access to the camera in Settings->Privacy->Camera", preferredStyle: .alert)
               alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
               UIApplication.shared.keyWindow!.rootViewController!.present(alert, animated: true, completion: nil)
           case .restricted:
               failed()
               let alert = UIAlertController(title: "Camera required", message: "This experiment requires access to the camera sensor. but the access has been denied. Please enable access to the camera in Settings->Privacy->Camera", preferredStyle: .alert)
               alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
               UIApplication.shared.keyWindow!.rootViewController!.present(alert, animated: true, completion: nil)
               
           case .notDetermined:
               AVCaptureDevice.requestAccess(for: .video, completionHandler: { (allowed) in
                   if !allowed {
                       failed()
                   }
               })
               break
               
           default:
               break
           }
       }
    }
    
    public func startAudio(countdown: Bool, stopExperimentDelegate: StopExperimentDelegate) throws {
        if audioEngine != nil { //Do not start twice. It could have been already started for a beeping countdown.
            audioEngine?.beepOnly = countdown
            return
        }
        if audioOutput != nil || !audioInputs.isEmpty || countdown {
            audioEngine = AudioEngine(audioOutput: audioOutput ?? (countdown ? ExperimentAudioOutput(sampleRate: 48000, loop: false, normalize: true, directSource: nil, tones: [], noise: nil) : nil), audioInput: audioInputs.first)
            audioEngine?.stopExperimentDelegate = stopExperimentDelegate
            audioEngine?.beepOnly = countdown
            try audioEngine?.startEngine()
        }
    }
    
    private func stopAudio() {
        audioEngine?.stopEngine()
        audioEngine = nil
    }
    
    func setKeepScreenOn(_ keepOn: Bool) {
        UIApplication.shared.isIdleTimerDisabled = keepOn
        if UserDefaults.standard.bool(forKey: "proximityLock") {
            (UIApplication.shared.delegate as! AppDelegate).lockPortrait = keepOn
            UIDevice.current.isProximityMonitoringEnabled = keepOn
        }
    }
    
    func start(stopExperimentDelegate: StopExperimentDelegate) throws {
        guard !running else {
            return
        }
        
        for device in bluetoothDevices {
            if !device.prepareForStart() {
                return
            }
        }

        timeReference.registerEvent(event: .START)
        bluetoothDevices.forEach { $0.writeEventCharacteristic(timeMapping: timeReference.timeMappings.last) }

        running = true

        hasStarted = true

        setKeepScreenOn(true)
        
        try startAudio(countdown: false, stopExperimentDelegate: stopExperimentDelegate)
        
        MotionSession.sharedSession().resetConfig()
        sensorInputs.forEach{ $0.configureMotionSession() }
        sensorInputs.forEach { $0.start(queue: queue) }
        try depthInput?.start(queue: queue)
        try cameraInput?.start(queue: queue)
        gpsInputs.forEach { $0.start(queue: queue) }
        bluetoothInputs.forEach { $0.start(queue: queue) }
        networkConnections.forEach { $0.start() }

        analysis.running = true
        analysis.queue = queue
        analysis.setNeedsUpdate()
    }
    
    func stop() {
        guard running else {
            return
        }
        
        analysis.running = false
                
        sensorInputs.forEach { $0.stop() }
        depthInput?.stop()
        cameraInput?.stop()
        gpsInputs.forEach { $0.stop() }
        bluetoothInputs.forEach { $0.stop() }
        networkConnections.forEach { $0.stop() }
        
        stopAudio()
        
        setKeepScreenOn(false)
        
        running = false
        
        if (timeReference.timeMappings.last?.event != .CLEAR) {
            timeReference.registerEvent(event: .PAUSE)
            bluetoothDevices.forEach { $0.writeEventCharacteristic(timeMapping: timeReference.timeMappings.last) }
        }
    }
    
    func clear(byUser: Bool) {
        stop()
        timeReference.reset()
        hasStarted = false

        for buffer in buffers.values {
            if !buffer.attachedToTextField {
                buffer.clear(reset: true)
            }
        }

        sensorInputs.forEach { $0.clear() }
        depthInput?.clear()
        cameraInput?.clear()
        gpsInputs.forEach { $0.clear() }
        
        if byUser {
            analysis.setNeedsUpdate(isPreRun: true)
        }
    }
}

extension Experiment: ExperimentAnalysisDelegate {
    func analysisWillUpdate(_ analysis: ExperimentAnalysis) {
        analysisDelegate?.analysisWillUpdate(analysis)
        for networkConnection in networkConnections {
            networkConnection.pushDataToBuffers()
        }
    }

    func analysisDidUpdate(_ analysis: ExperimentAnalysis) {
        analysisDelegate?.analysisDidUpdate(analysis)
        if running {
            audioEngine?.play()
            for bluetoothOutput in bluetoothOutputs {
                bluetoothOutput.send()
            }
            for networkConnection in networkConnections {
                networkConnection.pushDataToBuffers()
                networkConnection.doExecute()
            }
        }
    }
    
    func analysisSkipped(_ analysis: ExperimentAnalysis) {
        analysisDelegate?.analysisSkipped(analysis)
    }
}

extension Experiment {
    func metadataEqual(to rhs: Experiment?) -> Bool {
        guard let rhs = rhs else { return false }
        return localizedTitle == rhs.localizedTitle &&
            localizedCategory == rhs.localizedCategory &&
            localizedDescription == rhs.localizedDescription &&
            icon == rhs.icon &&
            color == rhs.color &&
            stateTitle == rhs.stateTitle &&
            appleBan == rhs.appleBan &&
            isLink == rhs.isLink &&
            localizedLinks == rhs.localizedLinks
    }
}

extension Experiment: Equatable {
    static func ==(lhs: Experiment, rhs: Experiment) -> Bool {
        return lhs.title == rhs.title &&
            lhs.localizedDescription == rhs.localizedDescription &&
            lhs.localizedLinks == rhs.localizedLinks &&
            lhs.localizedCategory == rhs.localizedCategory &&
            lhs.icon == rhs.icon &&
            lhs.color == rhs.color &&
            lhs.local == rhs.local &&
            lhs.translation == rhs.translation &&
            lhs.buffers == rhs.buffers &&
            lhs.sensorInputs.elementsEqual(rhs.sensorInputs, by: { (l, r) -> Bool in
                ExperimentSensorInput.valueEqual(lhs: l, rhs: r)
            }) &&
            lhs.depthInput == rhs.depthInput &&
            lhs.gpsInputs == rhs.gpsInputs &&
            lhs.audioInputs == rhs.audioInputs &&
            lhs.audioOutput == rhs.audioOutput &&
            lhs.bluetoothDevices == rhs.bluetoothDevices &&
            lhs.bluetoothInputs == rhs.bluetoothInputs &&
            lhs.bluetoothOutputs == rhs.bluetoothOutputs &&
            lhs.networkConnections == rhs.networkConnections &&
            lhs.viewDescriptors == rhs.viewDescriptors &&
            lhs.analysis == rhs.analysis &&
            lhs.export == rhs.export &&
            lhs.stateTitle == rhs.stateTitle &&
            lhs.appleBan == rhs.appleBan &&
            lhs.isLink == rhs.isLink
    }
}

