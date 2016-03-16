//
//  Experiment.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

/*
Relevant for asking for permission to access sensors.

http://techcrunch.com/2014/04/04/the-right-way-to-ask-users-for-ios-permissions/?utm_campaign=This%2BWeek%2Bin%2BSwift&utm_medium=web&utm_source=This_Week_in_Swift_73
*/

import Foundation

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
        
        analysis?.delegate = self
    }
    
    func analysisWillUpdate(_: ExperimentAnalysis) {
        if ((self.output?.audioOutput) != nil) {
            for audio in (self.output?.audioOutput)! {
                audio.play()
            }
        }
    }
    
    func analysisDidUpdate(_: ExperimentAnalysis) {
        
    }
    
    class func isValidIdentifier(id: String) -> Bool {
        func charset(cset:NSCharacterSet, containsCharacter c:Character) -> Bool {
            let s = String(c)
            let ix = s.startIndex
            let ix2 = s.endIndex
            let result = s.rangeOfCharacterFromSet(cset, options: NSStringCompareOptions.LiteralSearch, range: ix..<ix2)
            return result != nil
        }
        
        if id.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) == 0 {
            return false
        }
        
        let characterSet = NSCharacterSet.alphanumericCharacterSet()
        for char in id.characters {
            if !charset(characterSet, containsCharacter: char) {
                return false
            }
        }
        
        return true
    }
    
    func stop() {
        if running {
            if self.sensorInputs != nil {
                for sensor in self.sensorInputs! {
                    sensor.stop()
                }
            }
            
            running = false
        }
    }
    
    func start() {
        if running {
            return
        }
        
        running = true
        
        if self.sensorInputs != nil {
            for sensor in self.sensorInputs! {
                sensor.start()
            }
        }
    }
}
