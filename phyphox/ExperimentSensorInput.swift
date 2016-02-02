//
//  ExperimentSensorInput.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import CoreMotion

enum SensorType {
    case Accelerometer
    case Gyroscope
    case LinearAcceleration
    case MagneticField
    case Pressure
    case Light
}

enum SensorError : ErrorType {
    case InvalidSensorType
    case MotionSessionAbsent
    case SensorUnavailable(SensorType)
}

final class ExperimentSensorInput {
    let sensorType: SensorType
    
    /**
     The update frequency of the sensor.
     */
    private(set) var rate: NSTimeInterval //in s
    var effectiveRate: NSTimeInterval {
        get {
            if self.averaging != nil {
                return 0.0
            }
            else {
                return rate
            }
        }
    }
    
    private(set) var startTimestamp: NSTimeInterval = 0.0 //in s
    
    private(set) weak var xBuffer: DataBuffer?
    private(set) weak var yBuffer: DataBuffer?
    private(set) weak var zBuffer: DataBuffer?
    private(set) weak var tBuffer: DataBuffer?
    
    private(set) var motionSession: MotionSession
    
    private class Averaging {
        /**
         The duration of averaging intervals.
         */
        var averagingInterval: NSTimeInterval
        
        /**
         Start of current average mesurement.
         */
        var iterationStartTimestamp: NSTimeInterval = 0.0
        
        var x: Double = 0.0
        var y: Double = 0.0
        var z: Double = 0.0
        
        var numberOfUpdates: Int = 0
        
        init(averagingInterval: NSTimeInterval) {
            self.averagingInterval = averagingInterval
        }
        
        func requiresFlushing() -> Bool {
            return iterationStartTimestamp + averagingInterval <= CFAbsoluteTimeGetCurrent()
        }
    }
    
    /**
     Information on averaging. Set to `nil` to disable averaging.
     */
    private var averaging: Averaging?
    
    var recordingAverages: Bool {
        get {
            return self.averaging != nil
        }
    }
    
    init(sensorType: SensorType, motionSession: MotionSession, rate: NSTimeInterval, average: Bool, xBuffer: DataBuffer?, yBuffer: DataBuffer?, zBuffer: DataBuffer?, tBuffer: DataBuffer?) {
        self.sensorType = sensorType
        self.rate = rate
        
        self.xBuffer = xBuffer
        self.yBuffer = yBuffer
        self.zBuffer = zBuffer
        self.tBuffer = tBuffer
        
        self.motionSession = motionSession
        
        if average {
            self.averaging = Averaging(averagingInterval: rate)
        }
    }
    
    func verifySensorAvailibility() throws {
        switch sensorType {
        case .Accelerometer, .LinearAcceleration:
            guard motionSession.accelerometerAvailable else {
                throw SensorError.SensorUnavailable(sensorType)
            }
            break;
        case .Gyroscope:
            guard motionSession.gyroAvailable else {
                throw SensorError.SensorUnavailable(sensorType)
            }
            break;
        case .MagneticField:
            guard motionSession.magnetometerAvailable else {
                throw SensorError.SensorUnavailable(sensorType)
            }
            break;
        case .Pressure:
            guard motionSession.altimeterAvailable else {
                throw SensorError.SensorUnavailable(sensorType)
            }
            break;
        case .Light:
            throw SensorError.SensorUnavailable(sensorType)
        }
    }
    
    func resetValuesForAveraging() {
        guard let averaging = self.averaging else {
            return
        }
        
        averaging.iterationStartTimestamp = 0.0
        
        averaging.x = 0.0
        averaging.y = 0.0
        averaging.z = 0.0
        
        averaging.numberOfUpdates = 0
    }
    
    func start() {
        startTimestamp = 0.0
        
        resetValuesForAveraging()
        
        switch sensorType {
        case .Accelerometer:
            motionSession.getAccelerometerValues(effectiveRate, values: self.dataIn)
            break;
        case .Gyroscope:
            motionSession.getGyroValues(effectiveRate, values: self.dataIn)
            break;
        case .MagneticField:
            motionSession.getMagnetometerValues(effectiveRate, values: self.dataIn)
            break;
        case .LinearAcceleration:
            motionSession.getAccelerationFromDeviceMotion(effectiveRate, values: self.dataIn)
            break;
        case .Pressure:
            motionSession.getAltimeterValues(effectiveRate, values: { (data: CMAltitudeData?, error: NSError?) -> Void in
                self.dataIn(nil, y: nil, z: data?.relativeAltitude.doubleValue, error: error)
            })
            break;
        default:
            break;
        }
    }
    
    func stop() {
        switch sensorType {
        case .Accelerometer, .LinearAcceleration:
            motionSession.stopAccelerometerUpdates()
            break;
        case .Gyroscope:
            motionSession.stopGyroUpdates()
            break;
        case .MagneticField:
            motionSession.stopMagnetometerUpdates()
            break;
        case .Pressure:
            motionSession.stopAltimeterUpdates()
            break;
        case .Light:
            break;
        }
    }
    
    func writeToBuffers(x: Double, y: Double, z: Double) {
        if let xBuffer = self.xBuffer {
            xBuffer.append(x)
        }
        if let yBuffer = self.yBuffer {
            yBuffer.append(y)
        }
        if let zBuffer = self.zBuffer {
            zBuffer.append(z)
        }
        
        if let tBuffer = self.tBuffer {
            tBuffer.append(CFAbsoluteTimeGetCurrent()-startTimestamp)
        }
    }
    
    
    func dataIn(x: Double?, y: Double?, z: Double?, error: NSError?) {
        if (startTimestamp == 0.0) {
            startTimestamp = CFAbsoluteTimeGetCurrent() as NSTimeInterval
        }
        
        if x != nil { //if x, y or z is not nil then all of them are not nil
            if let av = self.averaging { //Recoring average?
                if av.iterationStartTimestamp == 0.0 {
                    av.iterationStartTimestamp = CFAbsoluteTimeGetCurrent() as NSTimeInterval
                }
                
                av.x += x!
                av.y += y!
                av.z += z!
                
                av.numberOfUpdates++
            }
            else { //Or raw values?
                writeToBuffers(x!, y: y!, z: z!)
            }
        }
        
        if let av = self.averaging {
            if av.requiresFlushing() {
                let u = Double(av.numberOfUpdates)
                
                writeToBuffers(av.x/u, y: av.y/u, z: av.z/u)
                
                self.resetValuesForAveraging()
            }
        }
    }
}
