//
//  ExperimentManager.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import UIKit

let experimentsBaseDirectory = NSBundle.mainBundle().pathForResource("phyphox-experiments", ofType: nil)!
let customExperimentsDirectory = (NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first! as NSString).stringByAppendingPathComponent("Experiments")
let fileExtension = "phyphox"

let ExperimentsReloadedNotification = "ExperimentsReloadedNotification"

enum FileError: ErrorType {
    case GenericError
}

final class ExperimentManager {
    private var readOnlyExperimentCollections = [ExperimentCollection]()
    private var customExperimentCollections = [ExperimentCollection]()
    
    private var allExperimentCollections: [ExperimentCollection]?
    
    var experimentCollections: [ExperimentCollection] {
        if allExperimentCollections == nil {
            allExperimentCollections = customExperimentCollections
            for experimentCollection in readOnlyExperimentCollections {
                var placed = false
                for (i, targetCollection) in allExperimentCollections!.enumerate() {
                    if (experimentCollection.title == targetCollection.title) {
                        allExperimentCollections![i].experiments! += experimentCollection.experiments!
                        placed = true
                        break;
                    }
                }
                if !placed {
                    allExperimentCollections! += [experimentCollection]
                }
            }
            
            for experimentCollection in allExperimentCollections! {
                experimentCollection.experiments?.sortInPlace({$0.experiment.localizedTitle < $1.experiment.localizedTitle})
            }
            
            let sensorCat = NSLocalizedString("categoryRawSensor", comment: "")
            
            allExperimentCollections?.sortInPlace({(a: ExperimentCollection, b: ExperimentCollection) -> Bool in
                if a.title == sensorCat {
                    return true
                }
                if b.title == sensorCat {
                    return false
                }
                return a.title < b.title
            })
        }
        
        return allExperimentCollections!
    }
    
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
    
    func deleteExperiment(experiment: Experiment) throws {
        if let path = experiment.filePath {
            try NSFileManager.defaultManager().removeItemAtPath(path)
            loadCustomExperiments()
        }
        else {
            throw FileError.GenericError
        }
    }
    
    func loadCustomExperiments() {
        var lookupTable: [String: ExperimentCollection] = [:]
        
        let customExperiments = try? NSFileManager.defaultManager().contentsOfDirectoryAtPath(customExperimentsDirectory)
        
        customExperimentCollections.removeAll()
        allExperimentCollections = nil
        
        if customExperiments != nil {
            for custom in customExperiments! {
                let path = (customExperimentsDirectory as NSString).stringByAppendingPathComponent(custom)
                
                if (path as NSString).pathExtension != fileExtension {
                    continue
                }
                
                do {
                    let experiment = try ExperimentSerialization.readExperimentFromFile(path)
                    experiment.filePath = path
                    
                    let category = experiment.localizedCategory
                    
                    if let collection = lookupTable[category] {
                        collection.experiments!.append((experiment: experiment, custom: true))
                    }
                    else {
                        let collection = ExperimentCollection(title: category, experiments: [experiment], customExperiments: true)
                        
                        lookupTable[category] = collection
                        customExperimentCollections.append(collection)
                    }
                }
                catch let error {
                    print("Error reading custom experiment: \(error)")
                }
            }
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(ExperimentsReloadedNotification, object: nil)
    }
    
    private func loadExperiments() {
        let folders = try! NSFileManager.defaultManager().contentsOfDirectoryAtPath(experimentsBaseDirectory)
        
        var lookupTable: [String: ExperimentCollection] = [:]
        
        readOnlyExperimentCollections.removeAll()
        allExperimentCollections = nil
        
        for title in folders {
            let path = (experimentsBaseDirectory as NSString).stringByAppendingPathComponent(title)
            
            if (path as NSString).pathExtension != fileExtension {
                continue
            }
            
            do {
                let experiment = try ExperimentSerialization.readExperimentFromFile(path)
                
                let category = experiment.localizedCategory
                
                if let collection = lookupTable[category] {
                    collection.experiments!.append((experiment: experiment, custom: false))
                }
                else {
                    let collection = ExperimentCollection(title: category, experiments: [experiment], customExperiments: false)
                    
                    lookupTable[category] = collection
                    readOnlyExperimentCollections.append(collection)
                }
            }
            catch let error {
                print("Error reading experiment: \(error)")
            }
        }
    }
    
    init() {
        let timestamp = CFAbsoluteTimeGetCurrent()
        
        loadExperiments()
        loadCustomExperiments()
        
        #if DEBUG
            print("Load took \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent()-timestamp)*1000)) ms")
        #endif
    }
}
