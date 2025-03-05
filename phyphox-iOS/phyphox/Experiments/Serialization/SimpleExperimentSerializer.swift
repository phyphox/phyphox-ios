//
//  SimpleExperimentSerializer.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.04.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation

final class SimpleExperimentSerializer {
    class func writeSimpleExperiment(title: String, rate: Double, sensors: MapSensorType) throws -> String {
        let str = serializeExperiment(title: title, rate: rate, sensors: sensors)
        
        var i = 1
        var t = title
        
        var path: String
        
        let directory = customExperimentsURL.path
        
        if !FileManager.default.fileExists(atPath: directory) {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: false, attributes: nil)
        }
        
        repeat {
            path = (directory as NSString).appendingPathComponent("\(t).phyphox")
            
            t = "\(title)-\(i)"
            i += 1
            
        } while FileManager.default.fileExists(atPath: path)
        
        try str.write(toFile: path, atomically: true, encoding: String.Encoding.utf8)

        ExperimentManager.shared.reloadUserExperiments()
        
        return path
    }
    
    
    class func serializeExperiment(title: String, rate: Double, sensors: MapSensorType) -> String {
        
        let experimentTemplete = SimpleExperimentTemplete(rate: rate)
        
        var containers = experimentTemplete.getContainers(sensors: sensors)
        var input = experimentTemplete.getInputs(sensors: sensors)
        var views = experimentTemplete.getViews(sensors: sensors)
        var export = experimentTemplete.getExports(sensors: sensors)
        
        let simpleExperiment = """
                    <phyphox version=\"1.14\">
                        <title>\(title)</title>
                        <category>\(localize("categoryNewExperiment"))</category>
                        <description>A simple experiment.</description>
                        <color>red</color>
                        <data-containers>
                            \(containers)
                        </data-containers>
                        <input>
                            \(input)
                        </input>
                        <views>
                            \(views)
                        </views>
                        \(experimentTemplete.getAnalysis(sensors: sensors))
                        <export>
                            \(export)
                        </export>
                    </phyphox>
                    """
        
        print(simpleExperiment)
        
        return simpleExperiment
        
    }
}
