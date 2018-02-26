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
    let gps: [NSDictionary]?
    let audio: [NSDictionary]?
    let bluetooth: [NSDictionary]?
    
    required init(_ inputs: NSDictionary) {
        sensors = getElementsWithKey(inputs, key: "sensor") as! [NSDictionary]?
        gps = getElementsWithKey(inputs, key: "location") as! [NSDictionary]?
        audio = getElementsWithKey(inputs, key: "audio") as! [NSDictionary]?
        bluetooth = getElementsWithKey(inputs, key: "bluetooth") as! [NSDictionary]?
    }
    
    func mapTypeStringToSensorType(_ type: String) -> SensorType? {
        if type == "pressure" {
            return .pressure
        }
        else if type == "accelerometer" {
            return .accelerometer
        }
        else if type == "linear_acceleration" {
            return .linearAcceleration
        }
        else if type == "gyroscope" {
            return .gyroscope
        }
        else if type == "light" {
            return .light
        }
        else if type == "magnetic_field" {
            return .magneticField
        }
        else if type == "proximity" {
            return .proximity
        }
        
        return nil
    }
    
    func sensorTypeFromXML(_ xml: [String: AnyObject]?, key: String) throws -> SensorType? {
        if xml == nil {
            return nil
        }
        
        let typeString = xml![key] as! String?
        
        if typeString == nil {
            throw SerializationError.invalidExperimentFile(message: "Error! Empty sensor type")
        }
        
        let sensorType = mapTypeStringToSensorType(typeString!)
        
        if sensorType == nil {
            throw SerializationError.invalidExperimentFile(message: "Error! Invalid sensor type: \(String(describing: typeString))")
        }
        
        return sensorType
    }
    
    func parse(_ buffers: [String : DataBuffer], analysis: ExperimentAnalysis?) throws -> ([ExperimentSensorInput]?, [ExperimentGPSInput]?, [ExperimentAudioInput]?, [ExperimentBluetoothInput]?) {
        if sensors == nil && gps == nil && audio == nil && bluetooth == nil {
            return (nil, nil, nil, nil)
        }
        
        var sensorsOut: [ExperimentSensorInput]?
        
        if sensors != nil {
            sensorsOut = []
            
            for sensor in sensors! {
                let attributes = sensor[XMLDictionaryAttributesKey] as! [String: String]
                
                let average = boolFromXML(attributes as [String : AnyObject], key: "average", defaultValue: false)
                
                let frequency = floatTypeFromXML(attributes as [String : AnyObject], key: "rate", defaultValue: 0.0) //Hz
                
                let rate = frequency.isNormal ? 1.0/frequency : 0.0
                
                let sensorType = try sensorTypeFromXML(attributes as [String : AnyObject], key: "type")
                
                if sensorType == nil {
                    throw SerializationError.invalidExperimentFile(message: "Error! Sensor type not set")
                }
                
                let outputs = getElementsWithKey(sensor, key: "output") as? [[String: AnyObject]]
                
                guard outputs != nil else {
                    throw SerializationError.invalidExperimentFile(message: "Sensor has no output.")
                }
                
                var xBuffer, yBuffer, zBuffer, accuracyBuffer, tBuffer, absBuffer: DataBuffer?
                
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
                    else if component == "accuracy" {
                        accuracyBuffer = buf
                    }
                    else if component == "t" {
                        tBuffer = buf
                    }
                    else if component == "abs" {
                        absBuffer = buf
                    }
                    else {
                        throw SerializationError.invalidExperimentFile(message: "Error! Invalid sensor parameter: \(String(describing: component))")
                    }
                    
                    //Register for updates
                    if buf != nil && analysis != nil {
                        analysis!.registerSensorBuffer(buf!)
                    }
                }
                
                if average && rate == 0.0 {
                    throw SerializationError.invalidExperimentFile(message: "Error! Averaging is enabled but rate is 0")
                }
                
                let sensor = ExperimentSensorInput(sensorType: sensorType!, calibrated: true, motionSession: MotionSession.sharedSession(), rate: rate, average: average, xBuffer: xBuffer, yBuffer: yBuffer, zBuffer: zBuffer, tBuffer: tBuffer, absBuffer: absBuffer, accuracyBuffer: accuracyBuffer)
                
                sensorsOut!.append(sensor)
            }
        }
        
        var gpsOut: [ExperimentGPSInput]?
        
        if gps != nil {
            gpsOut = []
            
            for gpsi in gps! {             
                let outputs = getElementsWithKey(gpsi, key: "output") as? [[String: AnyObject]]
                
                guard outputs != nil else {
                    throw SerializationError.invalidExperimentFile(message: "GPS has no output.")
                }
                
                var latBuffer, lonBuffer, zBuffer, vBuffer, dirBuffer, accuracyBuffer, zAccuracyBuffer, tBuffer, statusBuffer, satellitesBuffer: DataBuffer?
                
                for output in outputs! {
                    let attributes = output[XMLDictionaryAttributesKey] as! [String: String]
                    
                    let name = output[XMLDictionaryTextKey] as! String
                    
                    let component = attributes["component"]
                    
                    let buf = buffers[name]
                    
                    if component == "lat" {
                        latBuffer = buf
                    }
                    else if component == "lon" {
                        lonBuffer = buf
                    }
                    else if component == "z" {
                        zBuffer = buf
                    }
                    else if component == "v" {
                        vBuffer = buf
                    }
                    else if component == "dir" {
                        dirBuffer = buf
                    }
                    else if component == "accuracy" {
                        accuracyBuffer = buf
                    }
                    else if component == "zAccuracy" {
                        zAccuracyBuffer = buf
                    }
                    else if component == "t" {
                        tBuffer = buf
                    }
                    else if component == "status" {
                        statusBuffer = buf
                    }
                    else if component == "satellites" {
                        satellitesBuffer = buf
                    }
                    else {
                        throw SerializationError.invalidExperimentFile(message: "Error! Invalid GPS parameter: \(String(describing: component))")
                    }
                    
                    //Register for updates
                    if buf != nil && analysis != nil {
                        analysis!.registerSensorBuffer(buf!)
                    }
                }
                
                let sensor = ExperimentGPSInput(latBuffer: latBuffer, lonBuffer: lonBuffer, zBuffer: zBuffer, vBuffer: vBuffer, dirBuffer: dirBuffer, accuracyBuffer: accuracyBuffer, zAccuracyBuffer: zAccuracyBuffer, tBuffer: tBuffer, statusBuffer: statusBuffer, satellitesBuffer: satellitesBuffer)
                
                gpsOut!.append(sensor)
            }
        }
        
        var audioOut: [ExperimentAudioInput]?
        
        if audio != nil {
            audioOut = []
            
            for audioIn in audio! {
                let attributes = audioIn[XMLDictionaryAttributesKey] as! [String: String]?
                
                let sampleRate = intTypeFromXML(attributes as [String : AnyObject]?, key: "rate", defaultValue: UInt(48000))
                
                let output = getElementsWithKey(audioIn, key: "output")!
                
                var outBuffers: [DataBuffer] = []
                outBuffers.reserveCapacity(output.count)
                
                var sampleRateInfoBuffer: DataBuffer? = nil
                
                for out in output {
                    let outAttributes = out[XMLDictionaryAttributesKey] as? [String: String]
                    let bufferName = (out as? String ?? (out as! [String: AnyObject])[XMLDictionaryTextKey] as! String)
                    
                    let buffer = buffers[bufferName]!
                    
                    if analysis != nil {
                        analysis!.registerSensorBuffer(buffer)
                    }
                    
                    if outAttributes?["component"] == "rate" {
                        sampleRateInfoBuffer = buffer
                    } else {
                        outBuffers.append(buffer)
                    }
                }
                
                if outBuffers.count < 1 {
                    continue
                }
                
                let input = ExperimentAudioInput(sampleRate: sampleRate, outBuffer: outBuffers[0], sampleRateInfoBuffer: sampleRateInfoBuffer)
                
                audioOut!.append(input)
            }
        }
        
        var bluetoothOut: [ExperimentBluetoothInput]?
        
        if bluetooth != nil {
            
            
            bluetoothOut = []
            
            for bluetoothIn in bluetooth! {
                let attributes = bluetoothIn[XMLDictionaryAttributesKey] as! [String: String]?
                
                let average = boolFromXML(attributes as [String : AnyObject]?, key: "average", defaultValue: false)
                
                let frequency = floatTypeFromXML(attributes as [String : AnyObject]?, key: "rate", defaultValue: 0.0) //Hz
                let rate = frequency.isNormal ? 1.0/frequency : 0.0
                
                let device = stringFromXML(attributes as [String : AnyObject]?, key: "devicename", defaultValue: "")
                let address = stringFromXML(attributes as [String : AnyObject]?, key: "address", defaultValue: "")
                var separator = stringFromXML(attributes as [String : AnyObject]?, key: "separator", defaultValue: "")
                let protocolStr = stringFromXML(attributes as [String : AnyObject]?, key: "protocol", defaultValue: "")
                
                var outNames: [String] = []
                var i = 0
                var outName = ""
                repeat {
                    i += 1
                    outName = stringFromXML(attributes as [String : AnyObject]?, key: "out\(i)", defaultValue: "")
                    outNames.append(outName)
                } while outName != ""
                
                let serialProtocol: SerialProtocol
                switch protocolStr {
                case "simple":
                    if separator == "" {
                        separator = "\n"
                    }
                    let sepChar = separator.first!
                    serialProtocol = SimpleSerialProtocol(separator: sepChar)
                case "csv":
                    if separator == "" {
                        separator = ","
                    }
                    serialProtocol = CSVSerialProtocol()
                case "json":
                    serialProtocol = JSONSerialProtocol()
                default:
                    throw SerializationError.invalidExperimentFile(message: "Error! Unknown protocol: \(protocolStr)")
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
                    throw SerializationError.invalidExperimentFile(message: "Error! Averaging is enabled but rate is 0")
                }
                
                //TODO: Pass data needed to connect to device
                let input = ExperimentBluetoothInput(rate: rate, average: average, buffers: outBuffers)
                
                bluetoothOut!.append(input)
            }
        }
        
        return ((sensorsOut?.count ?? 0 > 0 ? sensorsOut : nil), (gpsOut?.count ?? 0 > 0 ? gpsOut : nil), (audioOut?.count ?? 0 > 0 ? audioOut : nil), (bluetoothOut?.count ?? 0 > 0 ? bluetoothOut : nil))
    }
}
