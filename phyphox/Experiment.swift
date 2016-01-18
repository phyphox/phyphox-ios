//
//  Experiment.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class Experiment {
    var title: String
    var description: String
    var category: String
    
    let icon: ExperimentIcon
    
    var local: Bool
    
    let viewDescriptors: [ExperimentViewCollectionDescriptor]
    
    let translations: [String: ExperimentTranslation]?
    let sensorInputs: [ExperimentSensorInput]?
    let audioInputs: [ExperimentAudioInput]?
    let output: ExperimentOutput?
    let analysis: ExperimentAnalysis?
    let export: ExperimentExport?
    
    let queue: dispatch_queue_t
    
    init(title: String, description: String, category: String, icon: ExperimentIcon, local: Bool, translations: [String: ExperimentTranslation]?, sensorInputs: [ExperimentSensorInput]?, audioInputs: [ExperimentAudioInput]?, output: ExperimentOutput?, viewDescriptors: [ExperimentViewCollectionDescriptor], analysis: ExperimentAnalysis?, export: ExperimentExport?) {
        self.title = title
        self.description = description
        self.category = category
        
        self.icon = icon
        
        self.local = local
        
        self.translations = translations
        self.sensorInputs = sensorInputs
        self.audioInputs = audioInputs
        self.output = output
        self.viewDescriptors = viewDescriptors
        self.analysis = analysis
        self.export = export
        
        queue = dispatch_queue_create("de.rwth-aachen.phyphox.experiment.queue." + NSUUID().UUIDString, DISPATCH_QUEUE_CONCURRENT)
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
    
    func start() {
        if self.sensorInputs != nil {
                for sensor in self.sensorInputs! {
                    try! sensor.start()
                }
            }
    }
}
