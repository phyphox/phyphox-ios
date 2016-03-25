//
//  ExperimentManager.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import UIKit

var experimentsBaseDirectory = NSBundle.mainBundle().pathForResource("phyphox-experiments", ofType: nil)!
var fileExtension = "phyphox"

final class ExperimentManager {
    private(set) var experimentCollections: [ExperimentCollection]
    
    private var adc: AEAudioController?
    private var fltc: AEFloatConverter?
    private var _gridCalculator: XWilkinson?
    
    var gridCalculator: XWilkinson {
        get {
            if _gridCalculator == nil {
                _gridCalculator = XWilkinson.base10()
                _gridCalculator!.clipToBounds = true
                _gridCalculator!.loose = true
            }
            
            return _gridCalculator!
        }
    }
    
    var floatConverter: AEFloatConverter {
        get {
            return fltc!
        }
    }
    
    var audioController: AEAudioController {
        get {
            return adc!
        }
    }
    
    func setAudioControllerDescription(audioDescription: AudioStreamBasicDescription, inputEnabled: Bool, outputEnabled: Bool) -> AEAudioController {
        if adc == nil {
            var bitmask = AEAudioControllerOptionAllowMixingWithOtherApps.rawValue
            
            if inputEnabled {
                bitmask |= AEAudioControllerOptionEnableInput.rawValue
            }
            
            if outputEnabled {
                bitmask |= AEAudioControllerOptionEnableOutput.rawValue
            }
            
            adc = AEAudioController(audioDescription: audioDescription, options: AEAudioControllerOptions(bitmask))
            
            fltc = AEFloatConverter(sourceFormat: audioDescription)
        }
        else {
            fltc = AEFloatConverter(sourceFormat: audioDescription)
            
            do {
                try adc!.setAudioDescription(audioDescription, inputEnabled: inputEnabled, outputEnabled: outputEnabled)
            }
            catch let error {
                print("Audio controller error: \(error)")
            }
        }
        
        return adc!
    }
    
    class func sharedInstance() -> ExperimentManager {
        struct Singleton {
            static var token: dispatch_once_t = 0
            static var instance: ExperimentManager? = nil
        }
        
        dispatch_once(&Singleton.token) { () -> Void in
            Singleton.instance = ExperimentManager()
        }
        
        return Singleton.instance!
    }
    
    init() {
        let timestamp = CFAbsoluteTimeGetCurrent()
        
        let folders = try! NSFileManager.defaultManager().contentsOfDirectoryAtPath(experimentsBaseDirectory)
        
        var experimentCollections: [String: ExperimentCollection] = [:]
        
        for title in folders {
            let path = (experimentsBaseDirectory as NSString).stringByAppendingPathComponent(title)
            
            do {
                let experiment = try ExperimentSerialization.readExperimentFromFile(path)
                
                let category = experiment.category!
                
                if let collection = experimentCollections[category] {
                    collection.experiments!.append(experiment)
                }
                else {
                    let collection = ExperimentCollection(title: category, experiments: [experiment])
                    
                    experimentCollections[category] = collection
                }
            }
            catch let error {
                print("Error Caught: \(error)")
            }
        }
        
        self.experimentCollections = Array(experimentCollections.values)
        
        print("Load took \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent()-timestamp)*1000)) ms")
    }
}
