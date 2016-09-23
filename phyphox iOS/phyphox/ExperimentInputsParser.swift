//
//  ExperimentInputsParser.swift
//  phyphox
//
//  Created by Jonas Gessner on 10.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation

final class ExperimentInputsParser: ExperimentMetadataParser {
    let sensors: [NSDictionary]?
    let audio: [NSDictionary]?
    let bluetooth: [NSDictionary]?
    
    required init(_ inputs: NSDictionary) {
        sensors = getElementsWithKey(inputs, key: "sensor") as! [NSDictionary]?
        audio = getElementsWithKey(inputs, key: "audio") as! [NSDictionary]?
        bluetooth = getElementsWithKey(inputs, key: "bluetooth") as! [NSDictionary]?
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
            return .MagneticField
        }
        
        return nil
    }
    
    func sensorTypeFromXML(xml: [String: AnyObject]?, key: String) throws -> SensorType? {
        if xml == nil {
            return nil
        }
        
        let typeString = xml![key] as! String?
        
        if typeString == nil {
            throw SerializationError.InvalidExperimentFile(message: "Error! Empty sensor type")
        }
        
        let sensorType = mapTypeStringToSensorType(typeString!)
        
        if sensorType == nil {
            throw SerializationError.InvalidExperimentFile(message: "Error! Invalid sensor type: \(typeString)")
        }
        
        return sensorType
    }
    
    func parse(buffers: [String : DataBuffer], analysis: ExperimentAnalysis?) throws -> ([ExperimentSensorInput]?, [ExperimentAudioInput]?, [ExperimentBluetoothInput]?) {
        if sensors == nil && audio == nil && bluetooth == nil {
            return (nil, nil, nil)
        }
        
        var sensorsOut: [ExperimentSensorInput]?
        
        if sensors != nil {
            sensorsOut = []
            
            for sensor in sensors! {
                let attributes = sensor[XMLDictionaryAttributesKey] as! [String: String]
                
                let average = boolFromXML(attributes, key: "average", defaultValue: false)
                
                let frequency = floatTypeFromXML(attributes, key: "rate", defaultValue: 0.0) //Hz
                
                let rate = isnormal(frequency) ? 1.0/frequency : 0.0
                
                let sensorType = try sensorTypeFromXML(attributes, key: "type")
                
                if sensorType == nil {
                    throw SerializationError.InvalidExperimentFile(message: "Error! Sensor type not set")
                }
                
                let outputs = getElementsWithKey(sensor, key: "output") as? [[String: AnyObject]]
                
                guard outputs != nil else {
                    throw SerializationError.InvalidExperimentFile(message: "Sensor has no output.")
                }
                
                var xBuffer, yBuffer, zBuffer, tBuffer: DataBuffer?
                
                for output in outputs! {
                    let attributes = output[XMLDictionaryAttributesKey] as! [String: String]
                    
                    let name = output[XMLDictionaryTextKey] as! String
                    
                    let component = attributes["component"]
                    
                    let buf = buffers[name]
                    
                    if component == "x" {
                        xBuffer = buf
                    }
                    else if component == "y" {
                        yBuffer = buf
                    }
                    else if component == "z" {
                        zBuffer = buf
                    }
                    else if component == "t" {
                        tBuffer = buf
                    }
                    else {
                        throw SerializationError.InvalidExperimentFile(message: "Error! Invalid sensor parameter: \(component)")
                    }
                    
                    //Register for updates
                    if buf != nil && analysis != nil {
                        analysis!.registerSensorBuffer(buf!)
                    }
                }
                
                if average && rate == 0.0 {
                    throw SerializationError.InvalidExperimentFile(message: "Error! Averaging is enabled but rate is 0")
                }
                
                let sensor = ExperimentSensorInput(sensorType: sensorType!, motionSession: MotionSession.sharedSession(), rate: rate, average: average, xBuffer: xBuffer, yBuffer: yBuffer, zBuffer: zBuffer, tBuffer: tBuffer)
                
                sensorsOut!.append(sensor)
            }
        }
        
        var audioOut: [ExperimentAudioInput]?
        
        if audio != nil {
            audioOut = []
            
            for audioIn in audio! {
                let attributes = audioIn[XMLDictionaryAttributesKey] as! [String: String]?
                
                let sampleRate = intTypeFromXML(attributes, key: "rate", defaultValue: UInt(48000))
                
                let output = getElementsWithKey(audioIn, key: "output")!
                
                var outBuffers: [DataBuffer] = []
                outBuffers.reserveCapacity(output.count)
                
                for out in output {
                    let bufferName = (out as? String ?? (out as! [String: AnyObject])[XMLDictionaryTextKey] as! String)
                    
                    let buffer = buffers[bufferName]!
                    
                    if analysis != nil {
                        analysis!.registerSensorBuffer(buffer)
                    }
                    
                    outBuffers.append(buffer)
                }
                
                let input = ExperimentAudioInput(sampleRate: sampleRate, outBuffers: outBuffers)
                
                audioOut!.append(input)
            }
        }
        
        var bluetoothOut: [ExperimentBluetoothInput]?
        
        if bluetooth != nil {
            
            
            bluetoothOut = []
            
            for bluetoothIn in bluetooth! {
                let attributes = bluetoothIn[XMLDictionaryAttributesKey] as! [String: String]?
                
                let average = boolFromXML(attributes, key: "average", defaultValue: false)
                
                let frequency = floatTypeFromXML(attributes, key: "rate", defaultValue: 0.0) //Hz
                let rate = isnormal(frequency) ? 1.0/frequency : 0.0
                
                let device = stringFromXML(attributes, key: "devicename", defaultValue: "")
                let address = stringFromXML(attributes, key: "address", defaultValue: "")
                var separator = stringFromXML(attributes, key: "separator", defaultValue: "")
                let protocolStr = stringFromXML(attributes, key: "protocol", defaultValue: "")
                
                var outNames: [String] = []
                var i = 0
                var outName = ""
                repeat {
                    i += 1
                    outName = stringFromXML(attributes, key: "out\(i)", defaultValue: "")
                    outNames.append(outName)
                } while outName != ""
                
                let serialProtocol: SerialProtocol
                switch protocolStr {
                case "simple":
                    if separator == "" {
                        separator = "\n"
                    }
                    let sepChar = separator.characters.first!
                    serialProtocol = SimpleSerialProtocol(separator: sepChar)
                case "csv":
                    if separator == "" {
                        separator = ","
                    }
                    serialProtocol = CSVSerialProtocol()
                case "json":
                    serialProtocol = JSONSerialProtocol()
                default:
                    throw SerializationError.InvalidExperimentFile(message: "Error! Unknown protocol: \(protocolStr)")
                }
                
                let outputs = getElementsWithKey(bluetoothIn, key: "output") as! [[String: AnyObject]]
                
                var outBuffers: [DataBuffer] = []
                
                for output in outputs {
                    let attributes = output[XMLDictionaryAttributesKey] as! [String: String]
                    
                    let name = output[XMLDictionaryTextKey] as! String
                    
                    let buf = buffers[name]
                    
                    //Register for updates
                    if buf != nil && analysis != nil {
                        outBuffers.append(buf!)
//TODO?                        analysis!.registerBluetoothBuffer(buf!)
                    }
                }
                
                if average && rate == 0.0 {
                    throw SerializationError.InvalidExperimentFile(message: "Error! Averaging is enabled but rate is 0")
                }
                
                //TODO: Pass data needed to connect to device
                let input = ExperimentBluetoothInput(rate: rate, average: average, buffers: outBuffers)
                
                bluetoothOut!.append(input)
            }
        }
        
        return ((sensorsOut?.count > 0 ? sensorsOut : nil), (audioOut?.count > 0 ? audioOut : nil), (bluetoothOut?.count > 0 ? bluetoothOut : nil))
    }
}
