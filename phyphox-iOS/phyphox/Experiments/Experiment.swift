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

private struct ExperimentRequiredPermission: OptionSet {
    let rawValue: Int
    
    static let none = ExperimentRequiredPermission(rawValue: 0)
    static let microphone = ExperimentRequiredPermission(rawValue: (1 << 0))
    static let location = ExperimentRequiredPermission(rawValue: (1 << 1))
}

protocol ExperimentDelegate: class {
    func experimentWillBecomeActive(_ experiment: Experiment)
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
    private let category: String
    
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

    weak var delegate: ExperimentDelegate?

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
    
    var fontColor: UIColor {
        if color.luminance > 0.7 {
            return UIColor.black
        } else {
            return UIColor.white
        }
    }

    let persistentStorageURL: URL

    var local: Bool = false
    var source: URL?
    
    var appleBan: Bool
    
    let viewDescriptors: [ExperimentViewCollectionDescriptor]?
    
    let translation: ExperimentTranslationCollection?

    let sensorInputTimeReference: SensorInputTimeReference
    let sensorInputs: [ExperimentSensorInput]
    let gpsInputs: [ExperimentGPSInput]
    let audioInputs: [ExperimentAudioInput]
    
    let audioOutput: ExperimentAudioOutput?
    
    let bluetoothDevices: [ExperimentBluetoothDevice]
    let bluetoothInputs: [ExperimentBluetoothInput]
    let bluetoothOutputs: [ExperimentBluetoothOutput]
    
    let analysis: ExperimentAnalysis?
    let export: ExperimentExport?
    
    let buffers: [String: DataBuffer]

    private var requiredPermissions: ExperimentRequiredPermission = .none
    
    private(set) var running = false
    private(set) var hasStarted = false
    
    private(set) var startTimestamp: TimeInterval?
    private var pauseBegin: TimeInterval = 0.0

    private var audioEngine: AudioEngine?

    init(title: String, stateTitle: String?, description: String?, links: [ExperimentLink], category: String, icon: ExperimentIcon, color: UIColor?, persistentStorageURL: URL, appleBan: Bool, translation: ExperimentTranslationCollection?, buffers: [String: DataBuffer], sensorInputTimeReference:SensorInputTimeReference, sensorInputs: [ExperimentSensorInput], gpsInputs: [ExperimentGPSInput], audioInputs: [ExperimentAudioInput], audioOutput: ExperimentAudioOutput?, bluetoothDevices: [ExperimentBluetoothDevice], bluetoothInputs: [ExperimentBluetoothInput], bluetoothOutputs: [ExperimentBluetoothOutput], viewDescriptors: [ExperimentViewCollectionDescriptor]?, analysis: ExperimentAnalysis?, export: ExperimentExport?) {
        self.persistentStorageURL = persistentStorageURL
        self.title = title
        self.stateTitle = stateTitle
        
        self.appleBan = appleBan
        
        self.description = description
        self.links = links

        self.localizedLinks = links.map { ExperimentLink(label: translation?.localize($0.label) ?? $0.label, url: $0.url, highlighted: $0.highlighted) }

        self.category = category
        
        self.icon = icon
        self.rawColor = color
        
        self.translation = translation

        self.buffers = buffers
        self.sensorInputTimeReference = sensorInputTimeReference
        self.sensorInputs = sensorInputs
        self.gpsInputs = gpsInputs
        self.audioInputs = audioInputs
        
        self.audioOutput = audioOutput
        
        self.bluetoothDevices = bluetoothDevices
        self.bluetoothInputs = bluetoothInputs
        self.bluetoothOutputs = bluetoothOutputs
        
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
        
        analysis?.delegate = self
        analysis?.timestampSource = self
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

        delegate?.experimentWillBecomeActive(self)
    }
    
    /**
     Called when the experiment view controller did dismiss.
     */
    func didBecomeInactive() {
        for device in bluetoothDevices {
            device.disconnect()
            device.deviceAddress = nil
        }
        clear()
    }
    
    func saveLocally(quiet: Bool, presenter: UINavigationController?) throws {
        guard let source = self.source else { throw FileError.genericError }
        
        if !FileManager.default.fileExists(atPath: customExperimentsURL.path) {
            try FileManager.default.createDirectory(atPath: customExperimentsURL.path, withIntermediateDirectories: false, attributes: nil)
        }
        
        var i = 1
        
        var experimentURL = customExperimentsURL.appendingPathComponent(title).appendingPathExtension(experimentFileExtension)
        
        while FileManager.default.fileExists(atPath: experimentURL.path) {
            experimentURL = customExperimentsURL.appendingPathComponent(title + "-\(i)").appendingPathExtension(experimentFileExtension)
            
            i += 1
        }
        
        func moveFile(from fileURL: URL) throws {
            try FileManager.default.copyItem(at: fileURL, to: experimentURL)
            
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
        }
    }
    
    private func startAudio() throws {
        if audioOutput != nil || !audioInputs.isEmpty {
            audioEngine = AudioEngine(audioOutput: audioOutput, audioInput: audioInputs.first)
            try audioEngine?.startEngine()
        }
    }
    
    private func stopAudio() {
        audioEngine?.stopEngine()
        audioEngine = nil
    }
    
    func start() throws {
        guard !running else {
            return
        }
        
        for device in bluetoothDevices {
            if !device.prepareForStart() {
                return
            }
        }
        
        if pauseBegin > 0 {
            startTimestamp! += CFAbsoluteTimeGetCurrent()-pauseBegin
            pauseBegin = 0.0
        }
        
        if startTimestamp == nil {
            startTimestamp = CFAbsoluteTimeGetCurrent()
        }
        
        running = true

        try? FileManager.default.createDirectory(at: persistentStorageURL, withIntermediateDirectories: false, attributes: nil)

        for buffer in buffers.values {
            buffer.open()
        }

        hasStarted = true

        UIApplication.shared.isIdleTimerDisabled = true
        
        try startAudio()
        
        sensorInputTimeReference.t0 = nil
        sensorInputs.forEach { $0.start() }
        gpsInputs.forEach { $0.start() }
        bluetoothInputs.forEach { $0.start() }
        
        analysis?.running = true
        analysis?.setNeedsUpdate()
    }
    
    func stop() {
        guard running else {
            return
        }
        
        analysis?.running = false
        
        pauseBegin = CFAbsoluteTimeGetCurrent()
        
        sensorInputs.forEach { $0.stop() }
        gpsInputs.forEach { $0.stop() }
        bluetoothInputs.forEach { $0.stop() }
        
        try? stopAudio()
        
        UIApplication.shared.isIdleTimerDisabled = false
        
        running = false
    }
    
    func clear() {
        stop()
        pauseBegin = 0.0
        startTimestamp = nil
        hasStarted = false

        try? FileManager.default.removeItem(at: persistentStorageURL)

        for buffer in buffers.values {
            if !buffer.attachedToTextField {
                buffer.clear()
            }
        }

        sensorInputs.forEach { $0.clear() }
        gpsInputs.forEach { $0.clear() }

        for buffer in buffers.values {
            buffer.close()
        }
    }
}

extension Experiment: ExperimentAnalysisDelegate {
    func analysisWillUpdate(_: ExperimentAnalysis) {
    }

    func analysisDidUpdate(_: ExperimentAnalysis) {
        if running {
            audioEngine?.play()
            for bluetoothOutput in bluetoothOutputs {
                bluetoothOutput.send()
            }
        }
    }
}

extension Experiment: ExperimentAnalysisTimestampSource {
    func getCurrentTimestamp() -> TimeInterval {
        guard let startTimestamp = startTimestamp else { return 0.0 }

        return CFAbsoluteTimeGetCurrent() - startTimestamp
    }
}

extension Experiment {
    func metadataEqual(to rhs: Experiment?) -> Bool {
        guard let rhs = rhs else { return false }
        return title == rhs.title && category == rhs.category && description == rhs.description
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
            lhs.gpsInputs == rhs.gpsInputs &&
            lhs.audioInputs == rhs.audioInputs &&
            lhs.audioOutput == rhs.audioOutput &&
            lhs.bluetoothDevices == rhs.bluetoothDevices &&
            lhs.bluetoothInputs == rhs.bluetoothInputs &&
            lhs.bluetoothOutputs == rhs.bluetoothOutputs &&
            lhs.viewDescriptors == rhs.viewDescriptors &&
            lhs.analysis == rhs.analysis &&
            lhs.export == rhs.export &&
            lhs.stateTitle == rhs.stateTitle &&
            lhs.appleBan == rhs.appleBan
    }
}

