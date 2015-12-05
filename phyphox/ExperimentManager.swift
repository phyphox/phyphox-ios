//
//  ExperimentManager.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import UIKit

var experimentsBaseDirectory = NSBundle.mainBundle().pathForResource("Experiments", ofType: nil)!
var fileExtension = "phyphox"

final class ExperimentManager: NSObject {
    private (set) var experimentCollections: [ExperimentCollection] = []
    
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
        let folders = try! NSFileManager.defaultManager().contentsOfDirectoryAtPath(experimentsBaseDirectory)
        
        for title in folders {
            let folder = (experimentsBaseDirectory as NSString).stringByAppendingPathComponent(title)
            
            let files = try! NSFileManager.defaultManager().contentsOfDirectoryAtPath(folder)
            
            var experiments: [Experiment] = []
            
            for file in files {
                if (file as NSString).pathExtension == fileExtension {
                    let path = (folder as NSString).stringByAppendingPathComponent(file)
                    
                    do {
                        let experiment = try ExperimentSerialization.readExperimentFromFile(path)
                        
                        experiments.append(experiment)
                    }
                    catch _ {
                        
                    }
                }
            }
            
            if experiments.count > 0 {
                experimentCollections.append(ExperimentCollection(title: title, experiments: experiments))
            }
        }
        
        super.init()
    }
}
