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

    //Resolves a resource named by a view element: externally loaded experiments deliver their
    //resources in a res folder alongside the XML file, so this one is tried first, with a
    //fallback to the internal images bundled with phyphox (at the moment only hue.png). The
    //fallback allows external experiment files to reuse the bundled images.
    func resolveResource(_ src: String) -> URL? {
        //A resource name comes from the experiment file, which is not trustworthy: refuse any
        //path traversal so a malicious file cannot reach outside its resource folder (relevant
        //especially for the /res endpoint, which serves the resolved file over the network)
        guard !src.components(separatedBy: "/").contains("..") else {
            return nil
        }
        if let file = resourceFolder?.appendingPathComponent(src), FileManager.default.fileExists(atPath: file.path) {
            return file
        }
        let bundled = experimentsBaseURL.appendingPathComponent("res").appendingPathComponent(src)
        if FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }
        return nil
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
    let flashlightOutput: ExperimentFlashlightOutput?
    
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

    init(title: String, stateTitle: String?, description: String?, links: [ExperimentLink], category: String, icon: ExperimentIcon, color: UIColor?, appleBan: Bool, isLink: Bool, translation: ExperimentTranslationCollection?, buffers: [String: DataBuffer], timeReference: ExperimentTimeReference, sensorInputs: [ExperimentSensorInput], depthInput: ExperimentDepthInput?, cameraInput: ExperimentCameraInput?, gpsInputs: [ExperimentGPSInput], audioInputs: [ExperimentAudioInput], audioOutput: ExperimentAudioOutput?, flashlightOutput: ExperimentFlashlightOutput?, bluetoothDevices: [ExperimentBluetoothDevice], bluetoothInputs: [ExperimentBluetoothInput], bluetoothOutputs: [ExperimentBluetoothOutput], networkConnections: [NetworkConnection], viewDescriptors: [ExperimentViewCollectionDescriptor]?, analysis: ExperimentAnalysis, export: ExperimentExport?) {
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
        self.flashlightOutput = flashlightOutput
        
        self.bluetoothDevices = bluetoothDevices
        self.bluetoothInputs = bluetoothInputs
        self.bluetoothOutputs = bluetoothOutputs
        
        self.networkConnections = networkConnections
        
        self.viewDescriptors = viewDescriptors
        self.analysis = analysis
        self.export = export
        
        defer {
            NotificationCenter.default.addObserver(self, selector: #selector(Experiment.endBackgroundSession), name: .endBackgroundMotionSessionNotification, object: nil)
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
        //The queue must be assigned before anything can trigger an analysis run. Input view
        //modules write their initial values (with a user-input trigger) already while the view
        //is being built, i.e. before willBecomeActive - without a queue that run would never
        //execute and its busy flag would block the analysis permanently.
        analysis.queue = queue
    }

    convenience init(file: String, error: String) {
        self.init(title: file, stateTitle: nil, description: error, links: [], category: localize("unknown"), icon: ExperimentIcon.string("!"), color: UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0), appleBan: false, isLink: false, translation: nil, buffers: [:], timeReference: ExperimentTimeReference(), sensorInputs: [], depthInput: nil, cameraInput: nil, gpsInputs: [], audioInputs: [], audioOutput: nil, flashlightOutput: nil, bluetoothDevices: [], bluetoothInputs: [], bluetoothOutputs: [], networkConnections: [], viewDescriptors: nil, analysis: ExperimentAnalysis(modules: [], sleep: 0.0, dynamicSleep: nil, onUserInput: false, requireFill: nil, requireFillThreshold: 1, requireFillDynamic: nil, timedRun: false, timedRunStartDelay: 0.0, timedRunStopDelay: 0.0, timeReference: ExperimentTimeReference(), sensorInputs: [], audioInputs: []), export: nil)
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
    func willBecomeActive(onSuccess: @escaping () -> Void, _ dismiss: @escaping () -> Void) {
        if requiredPermissions != .none {
            checkAndAskForPermissions(onSuccess: onSuccess, dismiss)
        } else {
            onSuccess()
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
                    guard !resource.components(separatedBy: "/").contains("..") else {
                        print("Refusing to save resource with path traversal: \(resource)")
                        continue
                    }
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
    
    //Presents an alert from the top-most presented view controller. These alerts appear outside
    //the sequenced dialog flow of the experiment view (which may show the photosensitivity
    //warning of a flashlight output at the same time), so they have to stack on whatever is
    //already presented instead of failing silently.
    private func presentPermissionAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        var presenter = UIApplication.shared.keyWindow?.rootViewController
        while let presented = presenter?.presentedViewController {
            presenter = presented
        }
        presenter?.present(alert, animated: true, completion: nil)
    }

    //Checks all required permission categories one after the other and reports the overall
    //outcome: onSuccess once every one of them is granted (which may be after the user answered
    //system prompts), so the experiment view can continue its dialog sequence, or failed as
    //soon as one is not, closing the experiment.
    private func checkAndAskForPermissions(onSuccess: @escaping () -> Void, _ failed: @escaping () -> Void) {
        let categories: [ExperimentRequiredPermission] = [.microphone, .location, .motionFitness, .camera].filter { requiredPermissions.contains($0) }
        checkNextPermission(of: categories, onSuccess: onSuccess, failed)
    }

    private func checkNextPermission(of categories: [ExperimentRequiredPermission], onSuccess: @escaping () -> Void, _ failed: @escaping () -> Void) {
        guard let requiredPermission = categories.first else {
            onSuccess()
            return
        }

        //Continue with the remaining categories once this one is granted
        let granted = { self.checkNextPermission(of: Array(categories.dropFirst()), onSuccess: onSuccess, failed) }

        if requiredPermission == .microphone {
            let status = AVCaptureDevice.authorizationStatus(for: AVMediaType.audio)

            switch status {
            case .authorized:
                granted()
            case .denied:
                failed()
                presentPermissionAlert(title: localize("permission_microphone_required"), message: localize("permission_microphone_denied"))
            case .restricted:
                failed()
                presentPermissionAlert(title: localize("permission_microphone_required"), message: localize("permission_microphone_restricted"))
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: AVMediaType.audio, completionHandler: { (allowed) in
                    DispatchQueue.main.async {
                        if allowed {
                            granted()
                        } else {
                            failed()
                        }
                    }
                })
            @unknown default:
                break
            }
        } else if requiredPermission == .location {

            let status = CLLocationManager.authorizationStatus()

            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                granted()
            case .denied:
                failed()
                presentPermissionAlert(title: localize("permission_location_required"), message: localize("permission_location_denied"))
            case .restricted:
                failed()
                presentPermissionAlert(title: localize("permission_location_required"), message: localize("permission_location_restricted"))
            case .notDetermined:
                guard let gpsInput = gpsInputs.first else {
                    granted()
                    return
                }
                //The system prompt for location has no completion handler, so the answer is
                //picked up through the location manager's delegate
                gpsInput.onAuthorizationChange = { [weak gpsInput] newStatus in
                    DispatchQueue.main.async {
                        switch newStatus {
                        case .authorizedAlways, .authorizedWhenInUse:
                            granted()
                        case .denied, .restricted:
                            failed()
                            self.presentPermissionAlert(title: localize("permission_location_required"), message: localize("permission_location_denied"))
                        case .notDetermined:
                            //Reported when the prompt appears - keep waiting for the answer
                            return
                        @unknown default:
                            break
                        }
                        gpsInput?.onAuthorizationChange = nil
                    }
                }
                gpsInput.locationManager.requestWhenInUseAuthorization()
            @unknown default:
                break
            }
        } else if requiredPermission == .motionFitness {
            let status = CMAltimeter.authorizationStatus()
            switch status {
            case .authorized:
                granted()
            case .denied:
                failed()
                presentPermissionAlert(title: localize("permission_motion_required"), message: localize("permission_motion_denied"))
            case .restricted:
                failed()
                presentPermissionAlert(title: localize("permission_motion_required"), message: localize("permission_motion_restricted"))
            case .notDetermined:
                let recorder = CMSensorRecorder()
                DispatchQueue.global().async {
                    recorder.recordAccelerometer(forDuration: 0.1)
                    DispatchQueue.main.async {
                        granted()
                    }
                }
            @unknown default:
                break
            }
        }

        else if requiredPermission == .camera {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
           switch status {
           case .authorized:
               granted()
           case .denied:
               failed()
               presentPermissionAlert(title: localize("permission_camera_required"), message: localize("permission_camera_denied"))
           case .restricted:
               failed()
               presentPermissionAlert(title: localize("permission_camera_required"), message: localize("permission_camera_restricted"))
           case .notDetermined:
               AVCaptureDevice.requestAccess(for: .video, completionHandler: { (allowed) in
                   DispatchQueue.main.async {
                       if allowed {
                           granted()
                       } else {
                           failed()
                       }
                   }
               })
           @unknown default:
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

        flashlightOutput?.start()
        
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

        flashlightOutput?.stop()

        setKeepScreenOn(false)
        
        running = false
        
        if (timeReference.timeMappings.last?.event != .CLEAR) {
            timeReference.registerEvent(event: .PAUSE)
            bluetoothDevices.forEach { $0.writeEventCharacteristic(timeMapping: timeReference.timeMappings.last) }
        }
    }
    
    //The translated names of the clear groups defined by this experiment's buffers, offered to
    //the user for selection when clearing data. The reserved group "_" is never offered.
    var clearGroups: [String] {
        return Set(buffers.values.compactMap { $0.clearGroup }).subtracting(["_"]).sorted()
    }

    func clear(byUser: Bool, clearGroups: [String] = []) {
        stop()
        timeReference.reset()
        hasStarted = false

        for buffer in buffers.values {
            //A user clear spares buffers assigned to a clear group unless the user selected
            //that group. Any other clear (like closing the experiment) resets everything.
            if byUser, let clearGroup = buffer.clearGroup, !clearGroups.contains(clearGroup) {
                continue
            }
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
            flashlightOutput?.updateState()
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

