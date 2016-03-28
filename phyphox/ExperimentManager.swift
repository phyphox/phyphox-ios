//
//  ExperimentManager.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import UIKit

let experimentsBaseDirectory = NSBundle.mainBundle().pathForResource("phyphox-experiments", ofType: nil)!
let fileExtension = "phyphox"

final class ExperimentManager {
    private(set) var experimentCollections = [ExperimentCollection]()
    
    private var adc: AEAudioController?
    private var fltc: AEFloatConverter?
    
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
    
    private static let instance = ExperimentManager() //static => lazy, let => synchronized
    
    class func sharedInstance() -> ExperimentManager {
        return instance
    }
    
    init() {
        let timestamp = CFAbsoluteTimeGetCurrent()
        
        let folders = try! NSFileManager.defaultManager().contentsOfDirectoryAtPath(experimentsBaseDirectory)
        
        var lookupTable: [String: ExperimentCollection] = [:]
        
        for title in folders {
            let path = (experimentsBaseDirectory as NSString).stringByAppendingPathComponent(title)
            
            if (path as NSString).pathExtension != fileExtension {
                continue
            }
            
            do {
                let experiment = try ExperimentSerialization.readExperimentFromFile(path)
                
                let category = experiment.category!
                
                if let collection = lookupTable[category] {
                    collection.experiments!.append(experiment)
                }
                else {
                    let collection = ExperimentCollection(title: category, experiments: [experiment])
                    
                    lookupTable[category] = collection
                    experimentCollections.append(collection)
                }
            }
            catch let error {
                print("Error Caught: \(error)")
            }
        }
        
        #if DEBUG
        print("Load took \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent()-timestamp)*1000)) ms")
        #endif
    }
}
