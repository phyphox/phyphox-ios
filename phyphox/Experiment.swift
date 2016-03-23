//
//  Experiment.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import AVFoundation

struct ExperimentRequiredPermission : OptionSetType {
    let rawValue: Int
    
    static let None = ExperimentRequiredPermission(rawValue: 0)
    static let Microphone = ExperimentRequiredPermission(rawValue: (1 << 0))
}

final class Experiment : ExperimentAnalysisDelegate {
    var title: String?
    var description: String?
    var category: String?
    
    let icon: ExperimentIcon
    
    var local: Bool
    
    let viewDescriptors: [ExperimentViewCollectionDescriptor]?
    
    let translations: [String: ExperimentTranslation]?
    let sensorInputs: [ExperimentSensorInput]?
    let audioInputs: [ExperimentAudioInput]?
    let output: ExperimentOutput?
    let analysis: ExperimentAnalysis?
    let export: ExperimentExport?
    
    let buffers: ([String: DataBuffer]?, [DataBuffer]?)
    
    let queue: dispatch_queue_t
    
    let requiredPermissions: ExperimentRequiredPermission
    
    private(set) var running = false
    
    init(title: String?, description: String?, category: String?, icon: ExperimentIcon, local: Bool, translations: [String: ExperimentTranslation]?, buffers: ([String: DataBuffer]?, [DataBuffer]?), sensorInputs: [ExperimentSensorInput]?, audioInputs: [ExperimentAudioInput]?, output: ExperimentOutput?, viewDescriptors: [ExperimentViewCollectionDescriptor]?, analysis: ExperimentAnalysis?, export: ExperimentExport?) {
        self.title = title
        self.description = description
        self.category = category
        
        self.icon = icon
        
        self.local = local
        
        self.translations = translations
        
        self.buffers = buffers
        self.sensorInputs = sensorInputs
        self.audioInputs = audioInputs
        self.output = output
        self.viewDescriptors = viewDescriptors
        self.analysis = analysis
        self.export = export
        
        queue = dispatch_queue_create("de.rwth-aachen.phyphox.experiment.queue", DISPATCH_QUEUE_CONCURRENT)
        
        if audioInputs != nil {
            self.requiredPermissions = .Microphone
        }
        else {
            self.requiredPermissions = .None
        }
        
        analysis?.delegate = self
    }
    
    func analysisWillUpdate(_: ExperimentAnalysis) {
    }
    
    func analysisDidUpdate(_: ExperimentAnalysis) {
        if running {
            playAudio()
        }
    }
    
    func willGetActive(dismiss: () -> ()) {
        if self.audioInputs != nil {
            checkAndAskForPermissions(dismiss)
        }
    }
    
    func didGetInactive() {
        
    }
    
    func checkAndAskForPermissions(failed: (Void) -> Void) {
        if requiredPermissions.contains(.Microphone) {
            
            let status = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeAudio)
            
            switch status {
            case .Denied:
                failed()
                let alert = UIAlertController(title: "Microphone Required", message: "This experiment requires access to the Microphone, but the access has been denied. Please enable access to the microphone in Settings->Privacy->Microphone", preferredStyle: .Alert)
                alert.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
                UIApplication.sharedApplication().keyWindow!.rootViewController!.presentViewController(alert, animated: true, completion: nil)
                
            case .Restricted:
                failed()
                let alert = UIAlertController(title: "Microphone Required", message: "This experiment requires access to the Microphone, but the access has been restricted. Please enable access to the microphone in Settings->General->Restrctions->Microphone", preferredStyle: .Alert)
                alert.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
                UIApplication.sharedApplication().keyWindow!.rootViewController!.presentViewController(alert, animated: true, completion: nil)
                
            case .NotDetermined:
                AVCaptureDevice.requestAccessForMediaType(AVMediaTypeAudio, completionHandler: { (allowed) in
                    if !allowed {
                        failed()
                    }
                })
                
            default:
                break
            }
        }
    }
    
    private func playAudio() {
        if ((self.output?.audioOutput) != nil) {
            for audio in (self.output?.audioOutput)! {
                audio.play()
            }
        }
    }
    
    private func stopAudio() {
        if ((self.output?.audioOutput) != nil) {
            for audio in (self.output?.audioOutput)! {
                audio.pause()
            }
        }
    }
    
    private func setUpAudio() {
        let hasOutput = output?.audioOutput.count > 0
        let hasInput = audioInputs?.count > 0
        
        let rate: Double
        
        if hasOutput {
            rate = Double(self.output!.audioOutput.first!.sampleRate)
        }
        else if hasInput {
            rate = Double(audioInputs!.first!.sampleRate)
        }
        else {
            return
        }
        
        ExperimentManager.sharedInstance().setAudioControllerDescription(monoFloatFormatWithSampleRate(Double(rate)), inputEnabled: hasInput, outputEnabled: hasOutput)
        
        do {
            try ExperimentManager.sharedInstance().audioController.start()
        }
        catch let error {
            print("Audio error: \(error)")
        }
    }
    
    private func tearDownAudio() {
        let hasOutput = output?.audioOutput.count > 0
        let hasInput = audioInputs?.count > 0
        
        if hasInput || hasOutput {
            ExperimentManager.sharedInstance().audioController.stop()
        }
    }
    
    func stop() {
        if running {
            if self.sensorInputs != nil {
                for sensor in self.sensorInputs! {
                    sensor.stop()
                }
            }
            
            if audioInputs != nil {
                for input in audioInputs! {
                    input.stopRecording(self)
                }
            }
            
            stopAudio()
            
            tearDownAudio()
            
            running = false
        }
    }
    
    func start() {
        if running {
            return
        }
        
        running = true
        
        setUpAudio()
        
        playAudio()
        
        if audioInputs != nil {
            for input in audioInputs! {
                input.startRecording(self)
            }
        }
        
        if self.sensorInputs != nil {
            for sensor in self.sensorInputs! {
                sensor.start()
            }
        }
    }
}
