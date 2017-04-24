//
//  SimpleExperimentSerializer.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.04.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation

final class SimpleExperimentSerializer {
    class func writeSimpleExperiment(title: String, bufferSize: Int, rate: Double, sensors: MapSensorType) throws -> String {
        let str = serializeExperiment(title: title, bufferSize: bufferSize, rate: rate, sensors: sensors)
        
        var i = 1
        var t = title
        
        var path: String
        
        let directory = customExperimentsDirectory
        
        if !FileManager.default.fileExists(atPath: directory) {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: false, attributes: nil)
        }
        
        repeat {
            path = (directory as NSString).appendingPathComponent("\(t).phyphox")
            
            t = "\(title)-\(i)"
            i += 1
            
        } while FileManager.default.fileExists(atPath: path)
        
        try str.write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
        
        ExperimentManager.sharedInstance().loadCustomExperiments()
        
        return str
    }
    
    
    class func serializeExperiment(title: String, bufferSize: Int, rate: Double, sensors: MapSensorType) -> String {
        var containers = ""
        var views = ""
        var export = ""
        var input = ""
        
        //Horrible, but quickest implementation..
        
        if sensors.contains(.Accelerometer) {
            containers += "<container size=\"\(bufferSize)\">accX</container>\n<container size=\"\(bufferSize)\">accY</container>\n<container size=\"\(bufferSize)\">accZ</container>\n<container size=\"\(bufferSize)\">acc_time</container>\n"
            
            input += "<sensor type=\"accelerometer\" rate=\"\(rate)\">\n<output component=\"x\">accX</output>\n<output component=\"y\">accY</output>\n<output component=\"z\">accZ</output>\n<output component=\"t\">acc_time</output>\n</sensor>\n"
            
            views += "<view label=\"Accelerometer\">\n<graph label=\"X\" labelX=\"t (s)\" labelY=\"a (m/s²)\" partialUpdate=\"true\">\n<input axis=\"x\">acc_time</input>\n<input axis=\"y\">accX</input>\n</graph>\n<graph label=\"Y\" labelX=\"t (s)\" labelY=\"a (m/s²)\" partialUpdate=\"true\">\n<input axis=\"x\">acc_time</input>\n<input axis=\"y\">accY</input>\n</graph>\n<graph label=\"Z\" labelX=\"t (s)\" labelY=\"a (m/s²)\" partialUpdate=\"true\">\n<input axis=\"x\">acc_time</input>\n<input axis=\"y\">accZ</input>\n</graph>\n</view>\n"
            
            export += "<set name=\"Accelerometer\">\n<data name=\"Time (s)\">acc_time</data>\n<data name=\"X (m/s^2)\">accX</data>\n<data name=\"Y (m/s^2)\">accY</data>\n<data name=\"Z (m/s^2)\">accZ</data>\n</set>\n"
        }
        
        if sensors.contains(.LinearAccelerometer) {
            containers += "<container size=\"\(bufferSize)\">lin_accX</container>\n<container size=\"\(bufferSize)\">lin_accY</container>\n<container size=\"\(bufferSize)\">lin_accZ</container>\n<container size=\"\(bufferSize)\">lin_acc_time</container>\n"
            
            input += "<sensor type=\"linear_acceleration\" rate=\"\(rate)\">\n<output component=\"x\">lin_accX</output>\n<output component=\"y\">lin_accY</output>\n<output component=\"z\">lin_accZ</output>\n<output component=\"t\">lin_acc_time</output>\n</sensor>\n"
            
            views += "<view label=\"Linear Accelerometer\">\n<graph label=\"X\" labelX=\"t (s)\" labelY=\"a (m/s²)\" partialUpdate=\"true\">\n<input axis=\"x\">lin_acc_time</input>\n<input axis=\"y\">lin_accX</input>\n</graph>\n<graph label=\"Y\" labelX=\"t (s)\" labelY=\"a (m/s²)\" partialUpdate=\"true\">\n<input axis=\"x\">lin_acc_time</input>\n<input axis=\"y\">lin_accY</input>\n</graph>\n<graph label=\"Z\" labelX=\"t (s)\" labelY=\"a (m/s²)\" partialUpdate=\"true\">\n<input axis=\"x\">lin_acc_time</input>\n<input axis=\"y\">lin_accZ</input>\n</graph>\n</view>\n"
            
            export += "<set name=\"Linear Accelerometer\">\n<data name=\"Time (s)\">lin_acc_time</data>\n<data name=\"X (m/s^2)\">lin_accX</data>\n<data name=\"Y (m/s^2)\">lin_accY</data>\n<data name=\"Z (m/s^2)\">lin_accZ</data>\n</set>\n"
        }
        
        if sensors.contains(.Gyroscope) {
            containers += "<container size=\"\(bufferSize)\">gyroX</container>\n<container size=\"\(bufferSize)\">gyroY</container>\n<container size=\"\(bufferSize)\">gyroZ</container>\n<container size=\"\(bufferSize)\">gyro_time</container>\n"
            
            input += "<sensor type=\"gyroscope\" rate=\"\(rate)\">\n<output component=\"x\">gyroX</output>\n<output component=\"y\">gyroY</output>\n<output component=\"z\">gyroZ</output>\n<output component=\"t\">gyro_time</output>\n</sensor>\n"
            
            views += "<view label=\"Gyroscope\">\n<graph label=\"X\" labelX=\"t (s)\" labelY=\"w (rad/s)\" partialUpdate=\"true\">\n<input axis=\"x\">gyro_time</input>\n<input axis=\"y\">gyroX</input>\n</graph>\n<graph label=\"Y\" labelX=\"t (s)\" labelY=\"w (rad/s)\" partialUpdate=\"true\">\n<input axis=\"x\">gyro_time</input>\n<input axis=\"y\">gyroY</input>\n</graph>\n<graph label=\"Z\" labelX=\"t (s)\" labelY=\"w (rad/s)\" partialUpdate=\"true\">\n<input axis=\"x\">gyro_time</input>\n<input axis=\"y\">gyroZ</input>\n</graph>\n</view>\n"
            
            export += "<set name=\"Gyroscope\">\n<data name=\"Time (s)\">gyro_time</data>\n<data name=\"X (rad/s)\">gyroX</data>\n<data name=\"Y (rad/s)\">gyroY</data>\n<data name=\"Z (rad/s)\">gyroZ</data>\n</set>\n"
        }
        
        if sensors.contains(.Magnetometer) {
            containers += "<container size=\"\(bufferSize)\">magX</container>\n<container size=\"\(bufferSize)\">magY</container>\n<container size=\"\(bufferSize)\">magZ</container>\n<container size=\"\(bufferSize)\">mag_time</container>\n"
            
            input += "<sensor type=\"magnetic_field\" rate=\"\(rate)\">\n<output component=\"x\">magX</output>\n<output component=\"y\">magY</output>\n<output component=\"z\">magZ</output>\n<output component=\"t\">mag_time</output>\n</sensor>\n"
            
            views += "<view label=\"Magnetometer\">\n<graph label=\"X\" labelX=\"t (s)\" labelY=\"B (µT)\" partialUpdate=\"true\">\n<input axis=\"x\">mag_time</input>\n<input axis=\"y\">magX</input>\n</graph>\n<graph label=\"Y\" labelX=\"t (s)\" labelY=\"B (µT)\" partialUpdate=\"true\">\n<input axis=\"x\">mag_time</input>\n<input axis=\"y\">magY</input>\n</graph>\n<graph label=\"Z\" labelX=\"t (s)\" labelY=\"B (µT)\" partialUpdate=\"true\">\n<input axis=\"x\">mag_time</input>\n<input axis=\"y\">magZ</input>\n</graph>\n</view>\n"
            
            export += "<set name=\"Magnetometer\">\n<data name=\"Time (s)\">mag_time</data>\n<data name=\"X (µT)\">magX</data>\n<data name=\"Y (µT)\">magY</data>\n<data name=\"Z (µT)\">magZ</data>\n</set>\n"
        }
        
        if sensors.contains(.Barometer) {
            containers += "<container size=\"\(bufferSize)\">baroX</container>\n<container size=\"\(bufferSize)\">baro_time</container>\n"
            
            input += "<sensor type=\"pressure\" rate=\"\(rate)\">\n<output component=\"x\">baroX</output>\n<output component=\"t\">baro_time</output>\n</sensor>\n"
            
            views += "<view label=\"Barometer\">\n<graph label=\"Pressure\" labelX=\"t (s)\" labelY=\"p (hPa)\" partialUpdate=\"true\">\n<input axis=\"x\">baro_time</input>\n<input axis=\"y\">baroX</input>\n</graph>\n</view>\n"
            
            export += "<set name=\"Barometer\">\n<data name=\"Time (s)\">baro_time</data>\n<data name=\"X (hPa)\">baroX</data>\n</set>\n"
        }
        
        if sensors.contains(.Proximity) {
            containers += "<container size=\"\(bufferSize)\">proxX</container>\n<container size=\"\(bufferSize)\">prox_time</container>\n"
            
            input += "<sensor type=\"proximity\" rate=\"\(rate)\">\n<output component=\"x\">proxX</output>\n<output component=\"t\">prox_time</output>\n</sensor>\n"
            
            views += "<view label=\"Proximity\">\n<graph label=\"Proximity\" labelX=\"t (s)\" labelY=\"Distance (cm)\" partialUpdate=\"true\">\n<input axis=\"x\">prox_time</input>\n<input axis=\"y\">proxX</input>\n</graph>\n</view>\n"
            
            export += "<set name=\"Proximity\">\n<data name=\"Time (s)\">prox_time</data>\n<data name=\"Distance (cm)\">proxX</data>\n</set>\n"
        }
        
        let inner = "<data-containers>\n\(containers)</data-containers>\n<input>\n\(input)</input>\n<views>\n\(views)</views>\n<export>\n\(export)</export>"
        
        let outer = "<phyphox version=\"1.0\">\n<title>\(title)</title>\n<category>\(NSLocalizedString("categoryNewExperiment", comment: ""))</category>\n<description>A simple experiment.</description>\n\(inner)\n</phyphox>"
        
        return outer
    }
}
