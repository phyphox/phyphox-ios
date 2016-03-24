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
    private var pauseBegin: NSTimeInterval = 0.0
    
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
        
        var x: Double?
        var y: Double?
        var z: Double?
        
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
        if pauseBegin > 0 {
            startTimestamp += CFAbsoluteTimeGetCurrent()-pauseBegin
            pauseBegin = 0.0
        }
        
        resetValuesForAveraging()
        
        switch sensorType {
        case .Accelerometer:
            motionSession.getAccelerometerValues(effectiveRate, values: self.dataIn)
        case .Gyroscope:
            motionSession.getGyroValues(effectiveRate, values: self.dataIn)
        case .MagneticField:
            motionSession.getMagnetometerValues(effectiveRate, values: self.dataIn)
        case .LinearAcceleration:
            motionSession.getAccelerationFromDeviceMotion(effectiveRate, values: self.dataIn)
        case .Pressure:
            motionSession.getAltimeterValues(effectiveRate, values: { (data: CMAltitudeData?, error: NSError?) -> Void in
                self.dataIn(nil, y: nil, z: data?.relativeAltitude.doubleValue, error: error)
            })
        default:
            break
        }
    }
    
    func stop() {
        pauseBegin = CFAbsoluteTimeGetCurrent()
        
        switch sensorType {
        case .Accelerometer:
            motionSession.stopAccelerometerUpdates()
        case .LinearAcceleration:
            motionSession.stopDeviceMotionUpdates()
        case .Gyroscope:
            motionSession.stopGyroUpdates()
        case .MagneticField:
            motionSession.stopMagnetometerUpdates()
        case .Pressure:
            motionSession.stopAltimeterUpdates()
        case .Light:
            break
        }
    }
    
    func writeToBuffers(x: Double?, y: Double?, z: Double?) {
        if x != nil && xBuffer != nil {
            xBuffer!.append(x)
        }
        if y != nil && yBuffer != nil {
            yBuffer!.append(y)
        }
        if z != nil && zBuffer != nil {
            zBuffer!.append(z)
        }
        
        if tBuffer != nil {
            tBuffer!.append(CFAbsoluteTimeGetCurrent()-startTimestamp)
        }
    }
    
    
    func dataIn(x: Double?, y: Double?, z: Double?, error: NSError?) {
        if (startTimestamp == 0.0) {
            startTimestamp = CFAbsoluteTimeGetCurrent() as NSTimeInterval
        }
        
        if let av = self.averaging { //Recoring average?
            if av.iterationStartTimestamp == 0.0 {
                av.iterationStartTimestamp = CFAbsoluteTimeGetCurrent() as NSTimeInterval
            }
            
            if x != nil {
                if av.x == nil {
                    av.x = x!
                }
                else {
                    av.x! += x!
                }
            }
            
            if y != nil {
                if av.y == nil {
                    av.y = y!
                }
                else {
                    av.y! += y!
                }
            }
            
            if z != nil {
                if av.z == nil {
                    av.z = z!
                }
                else {
                    av.z! += z!
                }
            }
            
            av.numberOfUpdates += 1
        }
        else { //Or raw values?
            writeToBuffers(x, y: y, z: z)
        }
        
        if let av = self.averaging {
            if av.requiresFlushing() {
                let u = Double(av.numberOfUpdates)
                
                writeToBuffers((av.x != nil ? av.x!/u : nil), y: (av.y != nil ? av.y!/u : nil), z: (av.z != nil ? av.z!/u : nil))
                
                self.resetValuesForAveraging()
            }
        }
    }
}
