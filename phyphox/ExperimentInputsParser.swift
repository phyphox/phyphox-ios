//
//  ExperimentInputsParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 10.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
//TODO: Audio
final class ExperimentInputsParser: ExperimentMetadataParser {
    let sensors: [NSDictionary]?
    let audio: [NSDictionary]?
    
    required init(_ inputs: NSDictionary) {
        sensors = getElementsWithKey(inputs, key: "sensor") as! [NSDictionary]?
        audio = getElementsWithKey(inputs, key: "audio") as! [NSDictionary]?
    }
    
    func parse() -> AnyObject {
        fatalError("Unavailable")
    }
    
    func mapTypeStringToSensorType(type: String) -> SensorType? {
        if type == "pressure" {
            return .Pressure
        }
        else if type == "accelerometer" {
            return .Accelerometer
        }
        else if type == "linear_acceleration" {
            return .LinearAcceleration
        }
        else if type == "gyroscope" {
            return .Gyroscope
        }
        else if type == "light" {
            return .Light
        }
        else if type == "magnetic_field" {
            return .Light
        }
        
        return nil
    }
    
    func sensorTypeFromXML(xml: [String: AnyObject]?, key: String) -> SensorType? {
        if xml == nil {
            return nil
        }
        
        let typeString = xml![key] as! String?
        
        if typeString == nil {
            print("Error! Empty sensor type")
            return nil
        }
        
        let sensorType = mapTypeStringToSensorType(typeString!)
        
        if sensorType == nil {
            print("Error! Invalid sensor type: \(typeString)")
            return nil
        }
        
        return sensorType
    }
    
    func parse(buffers: [String : DataBuffer]) -> [SensorInput]? {
        if sensors == nil {
            return nil
        }
        
        let motionSession = MotionSession()
        
        var sensorsOut: [SensorInput] = []
        
        for sensor in sensors! {
            let attributes = sensor[XMLDictionaryAttributesKey] as! [String: String]
            
            let average = boolFromXML(attributes, key: "average", defaultValue: false)
            
            let frequency = doubleFromXML(attributes, key: "rate", defaultValue: 0.0) //in Hz
            
            let sensorType = sensorTypeFromXML(attributes, key: "type")
            
            if sensorType == nil {
                continue
            }
            
            let outputs = getElementsWithKey(sensor, key: "output")!
            
            var xBuffer, yBuffer, zBuffer, tBuffer: DataBuffer?
            
            for output in outputs {
                let attributes = output[XMLDictionaryAttributesKey] as! [String: String]
                
                let name = output[XMLDictionaryTextKey] as! String
                
                let component = attributes["component"]
                
                if component == "x" {
                    xBuffer = buffers[name]
                }
                else if component == "y" {
                    yBuffer = buffers[name]
                }
                else if component == "z" {
                    zBuffer = buffers[name]
                }
                else if component == "t" {
                    tBuffer = buffers[name]
                }
                else {
                    print("Error! Invalid sensor parameter: \(component)")
                    continue
                }
            }
            
            if average && frequency == 0.0 {
                print("Error! Averaging is enabled but frequency is 0")
            }
            
            let sensor = SensorInput(sensorType: sensorType!, motionSession: motionSession, frequency: frequency, averagingInterval: (average && frequency > 0.0 ? 1.0/frequency : nil), xBuffer: xBuffer, yBuffer: yBuffer, zBuffer: zBuffer, tBuffer: tBuffer)
            
            sensorsOut.append(sensor)
        }
        
        if sensorsOut.count == 0 {
            return nil
        }
        
        return sensorsOut
    }
}
