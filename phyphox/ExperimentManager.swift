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

final class ExperimentManager: NSObject {
    private(set) var experimentCollections: [ExperimentCollection]
    
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
    
    override init() {
        let timestamp = CFAbsoluteTimeGetCurrent()
        
        let folders = try! NSFileManager.defaultManager().contentsOfDirectoryAtPath(experimentsBaseDirectory)
        
        var experimentCollections: [String: ExperimentCollection] = [:]
        
        for title in folders {
            let path = (experimentsBaseDirectory as NSString).stringByAppendingPathComponent(title)
            
            do {
                let experiment = try ExperimentSerialization.readExperimentFromFile(path)
                
                let category = experiment.category
                
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
        
        super.init()
    }
}
