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

let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

let savedExperimentStatesURL = documentsURL.appendingPathComponent("Saved-States")
let customExperimentsURL = documentsURL.appendingPathComponent("Experiments")

let fileExtension = "phyphox"

let ExperimentsReloadedNotification = "ExperimentsReloadedNotification"

enum FileError: Error {
    case genericError
}

final class ExperimentManager {
    let audioEngine = AudioEngine()
    
    private var readOnlyExperimentCollections = [ExperimentCollection]()
    private var customExperimentCollections = [ExperimentCollection]()
    
    private var allExperimentCollections: [ExperimentCollection]?
    
    var experimentCollections: [ExperimentCollection] {
        if allExperimentCollections == nil {
            allExperimentCollections = customExperimentCollections
            for experimentCollection in readOnlyExperimentCollections {
                var placed = false
                for (i, targetCollection) in allExperimentCollections!.enumerated() {
                    if (experimentCollection.title == targetCollection.title) {
                        allExperimentCollections![i].experiments += experimentCollection.experiments
                        placed = true
                        break;
                    }
                }
                if !placed {
                    allExperimentCollections! += [experimentCollection]
                }
            }
            
            for experimentCollection in allExperimentCollections! {
                experimentCollection.experiments.sort(by: { $0.experiment.localizedTitle < $1.experiment.localizedTitle})
            }
            
            let sensorCat = NSLocalizedString("categoryRawSensor", comment: "")
            let stateCat = NSLocalizedString("save_state_category", comment: "")
            
            allExperimentCollections?.sort(by: {(a: ExperimentCollection, b: ExperimentCollection) -> Bool in
                if a.title == sensorCat {
                    return true
                }
                if b.title == sensorCat {
                    return false
                }
                if a.title == stateCat {
                    return true
                }
                if b.title == stateCat {
                    return false
                }
                return a.title < b.title
            })
        }
        
        return allExperimentCollections!
    }

    private static let instance = ExperimentManager()

    class func sharedInstance() -> ExperimentManager {
        return instance
    }
    
    func deleteExperiment(_ experiment: Experiment) throws {
        guard let source = experiment.source else { return }
        try FileManager.default.removeItem(at: source)
        try loadCustomExperiments()
    }

    func loadSavedExperiments() throws {
        var lookupTable: [String: ExperimentCollection] = [:]

        guard let experiments = try? FileManager.default.contentsOfDirectory(atPath: savedExperimentStatesURL.path) else {
            return
        }

        customExperimentCollections.removeAll()
        allExperimentCollections = nil

        for file in experiments {
            let url = savedExperimentStatesURL.appendingPathComponent(file)

            guard url.pathExtension == experimentStateFileExtension else { continue }

            let experiment = try ExperimentSerialization.readExperimentFromURL(url)

            let category = experiment.localizedCategory

            if let collection = lookupTable[category] {
                collection.experiments.append((experiment, true))
            }
            else {
                let collection = ExperimentCollection(title: category, experiments: [experiment], customExperiments: true)

                lookupTable[category] = collection
                customExperimentCollections.append(collection)
            }
        }

        NotificationCenter.default.post(name: Notification.Name(rawValue: ExperimentsReloadedNotification), object: nil)
    }

    func loadCustomExperiments() throws {
        var lookupTable: [String: ExperimentCollection] = [:]

        guard let customExperiments = try? FileManager.default.contentsOfDirectory(atPath: customExperimentsURL.path) else {
            return
        }

        customExperimentCollections.removeAll()
        allExperimentCollections = nil

        for file in customExperiments {
            let url = customExperimentsURL.appendingPathComponent(file)

            guard url.pathExtension == fileExtension else { continue }

            let experiment = try ExperimentSerialization.readExperimentFromURL(url)

            let category = experiment.localizedCategory

            if let collection = lookupTable[category] {
                collection.experiments.append((experiment, true))
            }
            else {
                let collection = ExperimentCollection(title: category, experiments: [experiment], customExperiments: true)

                lookupTable[category] = collection
                customExperimentCollections.append(collection)
            }
        }

        NotificationCenter.default.post(name: Notification.Name(rawValue: ExperimentsReloadedNotification), object: nil)
    }

    private func loadExperiments() {
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
                    collection.experiments.append((experiment: experiment, custom: false))
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
        try? loadCustomExperiments()
        try? loadSavedExperiments()
        
        #if DEBUG
            print("Load took \(String(format: "%.2f", (CFAbsoluteTimeGetCurrent()-timestamp)*1000)) ms")
        #endif
    }
}
