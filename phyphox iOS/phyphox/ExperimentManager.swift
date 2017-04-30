//
//  ExperimentManager.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import UIKit

let experimentsBaseDirectory = Bundle.main.path(forResource: "phyphox-experiments", ofType: nil)!
let customExperimentsDirectory = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! as NSString).appendingPathComponent("Experiments")
let fileExtension = "phyphox"

let ExperimentsReloadedNotification = "ExperimentsReloadedNotification"

enum FileError: Error {
    case genericError
}

final class ExperimentManager {
    let audioEngine = AudioEngine()
    
    fileprivate var readOnlyExperimentCollections = [ExperimentCollection]()
    fileprivate var customExperimentCollections = [ExperimentCollection]()
    
    fileprivate var allExperimentCollections: [ExperimentCollection]?
    
    var experimentCollections: [ExperimentCollection] {
        if allExperimentCollections == nil {
            allExperimentCollections = customExperimentCollections
            for experimentCollection in readOnlyExperimentCollections {
                var placed = false
                for (i, targetCollection) in allExperimentCollections!.enumerated() {
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
                experimentCollection.experiments?.sort(by: {$0.experiment.localizedTitle < $1.experiment.localizedTitle})
            }
            
            let sensorCat = NSLocalizedString("categoryRawSensor", comment: "")
            
            allExperimentCollections?.sort(by: {(a: ExperimentCollection, b: ExperimentCollection) -> Bool in
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
    
    
    fileprivate static let instance = ExperimentManager() //static => lazy, let => synchronized
    
    class func sharedInstance() -> ExperimentManager {
        return instance
    }
    
    func deleteExperiment(_ experiment: Experiment) throws {
        if let path = experiment.filePath {
            try FileManager.default.removeItem(atPath: path)
            loadCustomExperiments()
        }
        else {
            throw FileError.genericError
        }
    }
    
    func loadCustomExperiments() {
        var lookupTable: [String: ExperimentCollection] = [:]
        
        let customExperiments = try? FileManager.default.contentsOfDirectory(atPath: customExperimentsDirectory)
        
        customExperimentCollections.removeAll()
        allExperimentCollections = nil
        
        if customExperiments != nil {
            for custom in customExperiments! {
                let path = (customExperimentsDirectory as NSString).appendingPathComponent(custom)
                
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
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: ExperimentsReloadedNotification), object: nil)
    }
    
    fileprivate func loadExperiments() {
        let folders = try! FileManager.default.contentsOfDirectory(atPath: experimentsBaseDirectory)
        
        var lookupTable: [String: ExperimentCollection] = [:]
        
        readOnlyExperimentCollections.removeAll()
        allExperimentCollections = nil
        
        for title in folders {
            let path = (experimentsBaseDirectory as NSString).appendingPathComponent(title)
            
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
