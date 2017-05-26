//
//  Experiment.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation
import AVFoundation

struct ExperimentRequiredPermission : OptionSet {
    let rawValue: Int
    
    static let None = ExperimentRequiredPermission(rawValue: 0)
    static let Microphone = ExperimentRequiredPermission(rawValue: (1 << 0))
}

func ==(lhs: Experiment, rhs: Experiment) -> Bool {
    return lhs.stateTitle == rhs.stateTitle && lhs.title == rhs.title && lhs.category == rhs.category && lhs.description == rhs.description
}

final class Experiment : ExperimentAnalysisDelegate, ExperimentAnalysisTimeManager, Equatable {
    fileprivate var title: String
    var stateTitle: String?
    fileprivate var description: String?
    fileprivate var links: [String: String]
    fileprivate var highlightedLinks: [String: String]
    fileprivate var category: String
    
    var localizedTitle: String {
        return translation?.selectedTranslation?.titleString ?? title
    }
    
    var localizedDescription: String? {
        return translation?.selectedTranslation?.descriptionString ?? description
    }
    
    var localizedLinks: [String:String] {
        var allLinks = self.links
        if let translatedLinks = translation?.selectedTranslation?.translatedLinks {
            for (key, value) in translatedLinks {
                allLinks[key] = value
            }
        }
        return allLinks
    }
    
    var localizedHighlightedLinks: [String:String] {
        var allLinks = self.highlightedLinks
        if let translatedLinks = translation?.selectedTranslation?.translatedLinks {
            for (key, _) in allLinks {
                allLinks[key] = translatedLinks[key]
            }
        }
        return allLinks
    }
    
    var localizedCategory: String {
        if stateTitle != nil {
            return NSLocalizedString("save_state_category", comment: "")
        }
        return translation?.selectedTranslation?.categoryString ?? category
    }
    
    let icon: ExperimentIcon
    
    var filePath: String?
    
    var local: Bool
    
    var source: URL? = nil
    var sourceData: Data? = nil
    
    let viewDescriptors: [ExperimentViewCollectionDescriptor]?
    
    let translation: ExperimentTranslationCollection?
    let sensorInputs: [ExperimentSensorInput]?
    let audioInput: ExperimentAudioInput?
    let output: ExperimentOutput?
    let analysis: ExperimentAnalysis?
    let export: ExperimentExport?
    
    let buffers: ([String: DataBuffer]?, [DataBuffer]?)
    
    let queue: DispatchQueue
    
    let requiredPermissions: ExperimentRequiredPermission
    
    fileprivate(set) var running = false
    fileprivate(set) var hasStarted = false
    
    fileprivate(set) var startTimestamp: TimeInterval?
    fileprivate var pauseBegin: TimeInterval = 0.0
    
    init(title: String, stateTitle: String?, description: String?, links: [String:String], highlightedLinks: [String:String], category: String, icon: ExperimentIcon, local: Bool, translation: ExperimentTranslationCollection?, buffers: ([String: DataBuffer]?, [DataBuffer]?), sensorInputs: [ExperimentSensorInput]?, audioInput: ExperimentAudioInput?, output: ExperimentOutput?, viewDescriptors: [ExperimentViewCollectionDescriptor]?, analysis: ExperimentAnalysis?, export: ExperimentExport?) {
        self.title = title
        self.stateTitle = stateTitle
        self.description = description
        self.links = links
        self.highlightedLinks = highlightedLinks
        self.category = category
        
        self.icon = icon
        
        self.local = local
        
        self.translation = translation

        self.buffers = buffers
        self.sensorInputs = sensorInputs
        self.audioInput = audioInput
        self.output = output
        self.viewDescriptors = viewDescriptors
        self.analysis = analysis
        self.export = export
        
        queue = DispatchQueue(label: "de.rwth-aachen.phyphox.experiment.queue", attributes: DispatchQueue.Attributes.concurrent)
        
        defer {
            NotificationCenter.default.addObserver(self, selector: #selector(Experiment.endBackgroundSession), name: NSNotification.Name(rawValue: EndBackgroundMotionSessionNotification), object: nil)
        }
        
        if audioInput != nil {
            self.requiredPermissions = .Microphone
        }
        else {
            self.requiredPermissions = .None
        }
        
        self.analysis?.delegate = self
        self.analysis?.timeManager = self
    }
    
    dynamic func endBackgroundSession() {
        stop()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func getCurrentTimestamp() -> TimeInterval {
        return startTimestamp != nil ? CFAbsoluteTimeGetCurrent()-startTimestamp! : 0.0
    }
    
    func analysisWillUpdate(_: ExperimentAnalysis) {
        audioInput?.receiveData()
    }
    
    func analysisDidUpdate(_: ExperimentAnalysis) {
        for buffer in buffers.1! {
            buffer.sendAnalysisCompleteNotification()
        }
        if running {
            self.output?.audioOutput?.play()
        }
    }
    
    /**
     Called when the experiment view controller will be presented.
     */
    func willGetActive(_ dismiss: @escaping () -> ()) {
        if self.audioInput != nil {
            checkAndAskForPermissions(dismiss)
        }
    }
    
    /**
     Called when the experiment view controller did dismiss.
     */
    func didBecomeInactive() {
        self.clear()
    }
    
    func checkAndAskForPermissions(_ failed: @escaping (Void) -> Void) {
        if requiredPermissions.contains(.Microphone) {
            
            let status = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeAudio)
            
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
                AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeAudio, completionHandler: { (allowed) in
                    if !allowed {
                        failed()
                    }
                })
                
            default:
                break
            }
        }
    }
    
    fileprivate func startAudio() throws {
        try ExperimentManager.sharedInstance().audioEngine.startEngine(playback: self.output?.audioOutput, record: self.audioInput)
        self.output?.audioOutput?.play()
    }
    
    fileprivate func stopAudio() {
        ExperimentManager.sharedInstance().audioEngine.stopEngine()
    }
    
    func start() throws {
        guard !running else {
            return
        }
        
        if pauseBegin > 0 {
            startTimestamp! += CFAbsoluteTimeGetCurrent()-pauseBegin
            pauseBegin = 0.0
        }
        
        if startTimestamp == nil {
            startTimestamp = CFAbsoluteTimeGetCurrent()
        }
        
        running = true
        hasStarted = true
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        try startAudio()
        
        if self.sensorInputs != nil {
            for sensor in self.sensorInputs! {
                sensor.start()
            }
        }
        
        analysis?.running = true
        if (analysis != nil && !analysis!.onUserInput) {
            analysis?.setNeedsUpdate()
        }
    }
    
    func stop() {
        guard running else {
            return
        }
        
        analysis?.running = false
        
        pauseBegin = CFAbsoluteTimeGetCurrent()
        
        if self.sensorInputs != nil {
            for sensor in self.sensorInputs! {
                sensor.stop()
            }
        }
        
        stopAudio()
        
        UIApplication.shared.isIdleTimerDisabled = false
        
        running = false
    }
    
    func clear() {
        stop()
        pauseBegin = 0.0
        startTimestamp = nil
        hasStarted = false
        
        if buffers.1 != nil {
            for buffer in buffers.1! {
                if !buffer.attachedToTextField {
                    buffer.clear()
                } else {
                    //Edit fields are not cleared to retain user input, but we need to mark its content as new, as this now is "new data" for the now empty experiment. (Otherwise analysis with onUserInput=true will not update after clearing the data.) For most of these experiments clearing the data does not make sense anyway, but who know what future experiments with this setting might look like...
                    buffer.sendUpdateNotification()
                }
            }
        }
        
        if self.sensorInputs != nil {
            for sensor in self.sensorInputs! {
                sensor.clear()
            }
        }
    }
}
