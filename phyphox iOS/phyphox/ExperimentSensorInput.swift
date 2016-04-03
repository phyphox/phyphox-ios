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

private let kG = 9.81

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
    
    private(set) var startTimestamp: NSTimeInterval?
    private var pauseBegin: NSTimeInterval = 0.0
    
    private(set) weak var xBuffer: DataBuffer?
    private(set) weak var yBuffer: DataBuffer?
    private(set) weak var zBuffer: DataBuffer?
    private(set) weak var tBuffer: DataBuffer?
    
    private(set) var motionSession: MotionSession
    
    private let queue = dispatch_queue_create("de.rwth-aachen.phyphox.sensorQueue", DISPATCH_QUEUE_SERIAL)
    
    private class Averaging {
        /**
         The duration of averaging intervals.
         */
        var averagingInterval: NSTimeInterval
        
        /**
         Start of current average mesurement.
         */
        var iterationStartTimestamp: NSTimeInterval?
        
        var x: Double?
        var y: Double?
        var z: Double?
        
        var numberOfUpdates: UInt = 0
        
        init(averagingInterval: NSTimeInterval) {
            self.averagingInterval = averagingInterval
        }
        
        func requiresFlushing(currentT: NSTimeInterval) -> Bool {
            return iterationStartTimestamp != nil && iterationStartTimestamp! + averagingInterval <= currentT
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
    
    private func resetValuesForAveraging() {
        guard let averaging = self.averaging else {
            return
        }
        
        averaging.iterationStartTimestamp = nil
        
        averaging.x = nil
        averaging.y = nil
        averaging.z = nil
        
        averaging.numberOfUpdates = 0
    }
    
    func start() {
        if pauseBegin > 0 {
            startTimestamp! += CFAbsoluteTimeGetCurrent()-pauseBegin
            pauseBegin = 0.0
        }
        
        resetValuesForAveraging()
        
        switch sensorType {
        case .Accelerometer:
            motionSession.getAccelerometerData(effectiveRate, handler: { [unowned self] (data, error) in
                guard let accelerometerData = data else {
                    self.dataIn(nil, y: nil, z: nil, t: nil, error: error)
                    return
                }
                
                let acceleration = accelerometerData.acceleration
                
                // m/s^2
                let x = acceleration.x*kG
                let y = acceleration.y*kG
                let z = acceleration.z*kG
                
                let t = accelerometerData.timestamp
                
                self.dataIn(x, y: y, z: z, t: t, error: error)
                })
            
        case .Gyroscope:
            motionSession.getDeviceMotion(effectiveRate, handler: { [unowned self] (deviceMotion, error) in
                guard let motion = deviceMotion else {
                    self.dataIn(nil, y: nil, z: nil, t: nil, error: error)
                    return
                }
                
                let rotation = motion.rotationRate
                
                // rad/s
                let x = rotation.x
                let y = rotation.y
                let z = rotation.z
                
                let t = motion.timestamp
                
                self.dataIn(x, y: y, z: z, t: t, error: error)
                })
            
        case .MagneticField:
            motionSession.getMagnetometerData(effectiveRate, handler: { [unowned self] (data, error) in
                guard let magnetometerData = data else {
                    self.dataIn(nil, y: nil, z: nil, t: nil, error: error)
                    return
                }
                
                let field = magnetometerData.magneticField
                
                let x = field.x
                let y = field.y
                let z = field.z
                
                let t = magnetometerData.timestamp
                
                self.dataIn(x, y: y, z: z, t: t, error: error)
                })
            
        case .LinearAcceleration:
            motionSession.getDeviceMotion(effectiveRate, handler: { [unowned self] (deviceMotion, error) in
                guard let motion = deviceMotion else {
                    self.dataIn(nil, y: nil, z: nil, t: nil, error: error)
                    return
                }
                
                let acceleration = motion.userAcceleration
                
                // m/s^2
                let x = acceleration.x*kG
                let y = acceleration.y*kG
                let z = acceleration.z*kG
                
                let t = motion.timestamp
                
                self.dataIn(x, y: y, z: z, t: t, error: error)
                })
            
        case .Pressure:
            motionSession.getAltimeterData(effectiveRate, handler: { [unowned self] (data, error) -> Void in
                guard let altimeterData = data else {
                    self.dataIn(nil, y: nil, z: nil, t: nil, error: error)
                    return
                }
                
                let pressure = altimeterData.pressure.doubleValue/10.0 //hPa
                
                let t = altimeterData.timestamp
                
                self.dataIn(pressure, y: nil, z: nil, t: t, error: error)
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
            motionSession.stopDeviceMotionUpdates()
        case .MagneticField:
            motionSession.stopMagnetometerUpdates()
        case .Pressure:
            motionSession.stopAltimeterUpdates()
        case .Light:
            break
        }
    }
    
    private func writeToBuffers(x: Double?, y: Double?, z: Double?, t: NSTimeInterval) {
        if x != nil && self.xBuffer != nil {
            self.xBuffer!.append(x)
        }
        if y != nil && self.yBuffer != nil {
            self.yBuffer!.append(y)
        }
        if z != nil && self.zBuffer != nil {
            self.zBuffer!.append(z)
        }
        
        if self.tBuffer != nil {
            if startTimestamp == nil {
                startTimestamp = t
            }
            
            let relativeT = t-self.startTimestamp!
            
            self.tBuffer!.append(relativeT)
        }
    }
    
    private func dataIn(x: Double?, y: Double?, z: Double?, t: NSTimeInterval?, error: NSError?) {
        
        func dataInSync(x: Double?, y: Double?, z: Double?, t: NSTimeInterval?, error: NSError?) {
            guard error == nil else {
                print("Sensor error: \(error!.localizedDescription)")
                return
            }
            
            if let av = self.averaging {
                if av.iterationStartTimestamp == nil {
                    av.iterationStartTimestamp = t
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
            else {
                writeToBuffers(x, y: y, z: z, t: t!)
            }
            
            if let av = self.averaging {
                if av.requiresFlushing(t!) {
                    let u = Double(av.numberOfUpdates)
                    
                    writeToBuffers((av.x != nil ? av.x!/u : nil), y: (av.y != nil ? av.y!/u : nil), z: (av.z != nil ? av.z!/u : nil), t: t!)
                    
                    self.resetValuesForAveraging()
                }
            }
        }
        
        dispatch_async(queue) {
            autoreleasepool({
                dataInSync(x, y: y, z: z, t: t, error: error)
            })
        }
    }
}
