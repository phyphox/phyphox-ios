//
//  ExperimentInputsParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 10.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import UIKit

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
    
    enum OutputType {
        case Buffer
    }
    
    func mapTypeStringToOutputType(type: String) -> OutputType? {
        if type == "buffer" {
            return OutputType.Buffer
        }
        
        return nil
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
    
    func parse(buffers: [String : DataBuffer]) -> [SensorInput]? {
        if sensors == nil {
            return nil
        }
        
        let motionSession = MotionSession()
        
        var sensorsOut: [SensorInput] = []
        
        for sensor in sensors! {
            let attributes = sensor[XMLDictionaryAttributesKey] as! NSDictionary
            let outputs = getElementsWithKey(sensor, key: "output")!
            
            let typeString = attributes["type"] as! String!
            
            if typeString == nil {
                print("Error! Empty sensor type")
                continue
            }
            
            let sensorType = mapTypeStringToSensorType(typeString)
            
            if sensorType == nil {
                print("Error! Invalid sensor type: \(typeString)")
                continue
            }
            
            let bufferSizeString = attributes["buffer"] as! String?
            
            var bufferSize = 10000 //Default
            
            if bufferSizeString != nil {
                if let convert = Int(bufferSizeString!) {
                    bufferSize = convert
                }
            }
        
            var xBuffer, yBuffer, zBuffer, tBuffer: DataBuffer?
            
            for output in outputs {
                let attributes = output[XMLDictionaryAttributesKey] as! NSDictionary
                let typeString = attributes["type"] as! String?
                
                var outputType: OutputType!
                
                if typeString != nil {
                    outputType = mapTypeStringToOutputType(typeString!)
                    
                    if outputType == nil {
                        print("Error! Invalid output type: \(typeString)")
                        continue
                    }
                }
                else { //Fallback to default value
                    outputType = OutputType.Buffer
                }
                
                let name = output[XMLDictionaryTextKey] as! String
                
                let parameter = attributes["parameter"] as! String
                
                if outputType == .Buffer {
                    if parameter == "x" {
                        xBuffer = buffers[name]
                        xBuffer?.size = bufferSize
                    }
                    else if parameter == "y" {
                        yBuffer = buffers[name]
                        yBuffer?.size = bufferSize
                    }
                    else if parameter == "z" {
                        zBuffer = buffers[name]
                        zBuffer?.size = bufferSize
                    }
                    else if parameter == "t" {
                        tBuffer = buffers[name]
                        tBuffer?.size = bufferSize
                    }
                    else {
                        print("Error! Invalid sensor parameter: \(parameter)")
                        continue
                    }
                }
            }
            
            let sensor = SensorInput(sensorType: sensorType!, motionSession: motionSession, frequency: 0.01, averagingInterval: nil, xBuffer: xBuffer, yBuffer: yBuffer, zBuffer: zBuffer, tBuffer: tBuffer)
            
            sensorsOut.append(sensor)
            
        }
        
        if sensorsOut.count == 0 {
            return nil
        }
        
        return sensorsOut
    }
}
