//
//  ExperimentSensorInput.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import CoreMotion

enum SensorType: String, LosslessStringConvertible, Equatable {
    case accelerometer
    case gyroscope
    case linearAcceleration = "linear_acceleration"
    case magneticField = "magnetic_field"
    case pressure
    case light
    case proximity
    case temperature
    case humidity
}

extension SensorType {
    func getLocalizedName() -> String {
        switch self {
        case .accelerometer:
            return localize("sensorAccelerometer")
        case .gyroscope:
            return localize("sensorGyroscope")
        case .humidity:
            return localize("sensorHumidity")
        case .light:
            return localize("sensorLight")
        case .linearAcceleration:
            return localize("sensorLinearAcceleration")
        case .magneticField:
            return localize("sensorMagneticField")
        case .pressure:
            return localize("sensorPressure")
        case .proximity:
            return localize("sensorProximity")
        case .temperature:
            return localize("sensorTemperature")
        }
    }
}

enum SensorError : Error {
    case invalidSensorType
    case motionSessionAbsent
    case sensorUnavailable(SensorType)
}

class SensorInputTimeReference {
    public var t0: TimeInterval? = nil
}

private let kG = -9.81

final class ExperimentSensorInput: MotionSessionReceiver {
    let sensorType: SensorType
    let sensorInputTimeReference: SensorInputTimeReference
    var localInputTimeReference: TimeInterval?
    
    /**
     The update frequency of the sensor.
     */
    private(set) var rate: TimeInterval //in s
    
    var effectiveRate: TimeInterval {
            if averaging != nil {
                return 0.0
            }
            else {
                return rate
            }
    }
    
    var calibrated = true //Use calibrated version? Can be switched while update is stopped. Currently only used for magnetometer
    var ready = false //Used by some sensors to figure out if there is valid data arriving. Most of them just set this to true when the first reading arrives.
    
    private(set) weak var xBuffer: DataBuffer?
    private(set) weak var yBuffer: DataBuffer?
    private(set) weak var zBuffer: DataBuffer?
    private(set) weak var tBuffer: DataBuffer?
    private(set) weak var absBuffer: DataBuffer?
    private(set) weak var accuracyBuffer: DataBuffer?
    
    private(set) var motionSession: MotionSession
    
    private let queue = DispatchQueue(label: "de.rwth-aachen.phyphox.sensorQueue", attributes: [])
    
    private class Averaging {
        /**
         The duration of averaging intervals.
         */
        var averagingInterval: TimeInterval
        
        /**
         Start of current average mesurement.
         */
        var iterationStartTimestamp: TimeInterval?
        
        var x: Double?
        var y: Double?
        var z: Double?
        
        var accuracy: Double?
        
        var numberOfUpdates: UInt = 0
        
        init(averagingInterval: TimeInterval) {
            self.averagingInterval = averagingInterval
        }
        
        func requiresFlushing(_ currentT: TimeInterval) -> Bool {
            return iterationStartTimestamp != nil && iterationStartTimestamp! + averagingInterval <= currentT
        }
    }
    
    /**
     Information on averaging. Set to `nil` to disable averaging.
     */
    private var averaging: Averaging?
    
    let ignoreUnavailable: Bool
    
    var recordingAverages: Bool {
            return averaging != nil
    }
    
    init(sensorType: SensorType, sensorInputTimeReference: SensorInputTimeReference, calibrated: Bool, motionSession: MotionSession, rate: TimeInterval, average: Bool, ignoreUnavailable: Bool, xBuffer: DataBuffer?, yBuffer: DataBuffer?, zBuffer: DataBuffer?, tBuffer: DataBuffer?, absBuffer: DataBuffer?, accuracyBuffer: DataBuffer?) {
        self.sensorType = sensorType
        self.sensorInputTimeReference = sensorInputTimeReference
        self.rate = rate
        self.calibrated = calibrated
        
        self.ignoreUnavailable = ignoreUnavailable
        
        self.xBuffer = xBuffer
        self.yBuffer = yBuffer
        self.zBuffer = zBuffer
        self.tBuffer = tBuffer
        self.absBuffer = absBuffer
        self.accuracyBuffer = accuracyBuffer
        
        self.motionSession = motionSession
        
        if (sensorType == .magneticField) {
            self.motionSession.calibratedMagnetometer = calibrated
        }
        
        if average {
            self.averaging = Averaging(averagingInterval: rate)
        }
    }
    
    func verifySensorAvailibility() throws {
        //The following line is used by the UI test to automatically generate screenshots for the App Store using fastlane. The UI test sets the argument "screenshot" and we will then ignore sensor tests as otherwise the generated screenshots in the simulator will show almost all sensors as missing
        if ProcessInfo.processInfo.arguments.contains("screenshot") {
            if sensorType != .light {
                return
            }
        }
        
        switch sensorType {
        case .accelerometer, .linearAcceleration:
            guard motionSession.accelerometerAvailable else {
                throw SensorError.sensorUnavailable(sensorType)
            }
            break;
        case .gyroscope:
            guard motionSession.gyroAvailable else {
                throw SensorError.sensorUnavailable(sensorType)
            }
            break;
        case .magneticField:
            guard motionSession.magnetometerAvailable else {
                throw SensorError.sensorUnavailable(sensorType)
            }
            break;
        case .pressure:
            guard motionSession.altimeterAvailable else {
                throw SensorError.sensorUnavailable(sensorType)
            }
            break;
        case .proximity:
            guard motionSession.proximityAvailable else {
                throw SensorError.sensorUnavailable(sensorType)
            }
        case .light, .temperature, .humidity:
            throw SensorError.sensorUnavailable(sensorType)
        }
    }
    
    private func resetValuesForAveraging() {
        guard let averaging = averaging else {
            return
        }
        
        averaging.iterationStartTimestamp = nil
        
        averaging.x = nil
        averaging.y = nil
        averaging.z = nil
        averaging.accuracy = nil
        
        averaging.numberOfUpdates = 0
    }
    
    func start() {
        
        do {
            try verifySensorAvailibility()
        } catch SensorError.sensorUnavailable(_) {
            return
        } catch {}
        
        localInputTimeReference = nil
        resetValuesForAveraging()
        
        switch sensorType {
        case .accelerometer:
            _ = motionSession.getAccelerometerData(self, interval: effectiveRate, handler: { [unowned self] (data, error) in
                guard let accelerometerData = data else {
                    self.dataIn(nil, y: nil, z: nil, accuracy: nil, t: nil, error: error)
                    return
                }
                
                let acceleration = accelerometerData.acceleration
                
                // m/s^2
                let x = acceleration.x*kG
                let y = acceleration.y*kG
                let z = acceleration.z*kG
                
                let t = accelerometerData.timestamp
                
                self.ready = true
                self.dataIn(x, y: y, z: z, accuracy: nil, t: t, error: error)
                })
            
        case .gyroscope:
            _ = motionSession.getDeviceMotion(self, interval: effectiveRate, handler: { [unowned self] (deviceMotion, error) in
                guard let motion = deviceMotion else {
                    self.dataIn(nil, y: nil, z: nil, accuracy: nil, t: nil, error: error)
                    return
                }
                
                let rotation = motion.rotationRate
                
                // rad/s
                let x = rotation.x
                let y = rotation.y
                let z = rotation.z
                
                let t = motion.timestamp
                
                self.ready = true
                self.dataIn(x, y: y, z: z, accuracy: nil, t: t, error: error)
                })
            
        case .magneticField:
            if calibrated {
                _ = motionSession.getDeviceMotion(self, interval: effectiveRate, handler: { [unowned self] (deviceMotion, error) in
                    guard let motion = deviceMotion else {
                        self.dataIn(nil, y: nil, z: nil, accuracy: nil, t: nil, error: error)
                        return
                    }
                    
                    let field = motion.magneticField.field
                    
                    let accuracy: Double
                    switch motion.magneticField.accuracy {
                    case .uncalibrated: accuracy = -1.0
                    case .low: accuracy = 1.0
                    case .medium: accuracy = 2.0
                    case .high: accuracy = 3.0
                    }
                    
                    let x = field.x
                    let y = field.y
                    let z = field.z
                    
                    if !self.ready && x == 0 && y == 0 && z == 0 {
                        return
                    }
                    
                    let t = motion.timestamp
                    
                    self.ready = true
                    self.dataIn(x, y: y, z: z, accuracy: accuracy, t: t, error: error)
                    })
            } else {
                _ = motionSession.getMagnetometerData(self, interval: effectiveRate, handler: { [unowned self] (data, error) in
                    guard let magnetometerData = data else {
                        self.dataIn(nil, y: nil, z: nil, accuracy: nil, t: nil, error: error)
                        return
                    }
                    
                    let field = magnetometerData.magneticField
                    
                    let x = field.x
                    let y = field.y
                    let z = field.z
                    
                    let t = magnetometerData.timestamp
                    
                    self.ready = true
                    self.dataIn(x, y: y, z: z, accuracy: 0.0, t: t, error: error)
                    })
            }
        case .linearAcceleration:
            _ = motionSession.getDeviceMotion(self, interval: effectiveRate, handler: { [unowned self] (deviceMotion, error) in
                guard let motion = deviceMotion else {
                    self.dataIn(nil, y: nil, z: nil, accuracy: nil, t: nil, error: error)
                    return
                }
                
                let acceleration = motion.userAcceleration
                
                // m/s^2
                let x = acceleration.x*kG
                let y = acceleration.y*kG
                let z = acceleration.z*kG
                
                let t = motion.timestamp
                
                self.ready = true
                self.dataIn(x, y: y, z: z, accuracy: nil, t: t, error: error)
                })
            
        case .pressure:
            _ = motionSession.getAltimeterData(self, interval: effectiveRate, handler: { [unowned self] (data, error) -> Void in
                guard let altimeterData = data else {
                    self.dataIn(nil, y: nil, z: nil, accuracy: nil, t: nil, error: error)
                    return
                }
                
                let pressure = altimeterData.pressure.doubleValue*10.0 //hPa
                
                let t = altimeterData.timestamp
                
                self.ready = true
                self.dataIn(pressure, y: nil, z: nil, accuracy: nil, t: t, error: error)
                })
        case .proximity:
            _ = motionSession.getProximityData(self, interval: effectiveRate, handler: { [unowned self] (state) -> Void in
                
                let distance = state ? 0.0 : 5.0 //Estimate in cm
                
                self.ready = true
                self.dataIn(distance, y: nil, z: nil, accuracy: nil, t: nil, error: nil)
                })
            
        default:
            break
        }
    }
    
    func stop() {
        
        do {
            try verifySensorAvailibility()
        } catch SensorError.sensorUnavailable(_) {
            return
        } catch {}
        
        ready = false
        
        switch sensorType {
        case .accelerometer:
            motionSession.stopAccelerometerUpdates(self)
        case .linearAcceleration:
            motionSession.stopDeviceMotionUpdates(self)
        case .gyroscope:
            motionSession.stopDeviceMotionUpdates(self)
        case .magneticField:
            if calibrated {
                motionSession.stopDeviceMotionUpdates(self)
            } else {
                motionSession.stopMagnetometerUpdates(self)
            }
        case .pressure:
            motionSession.stopAltimeterUpdates(self)
        case .proximity:
            motionSession.stopProximityUpdates(self)
        case .light, .temperature, .humidity:
            break
        }
    }
    
    func clear() {

    }
    
    private func writeToBuffers(_ x: Double?, y: Double?, z: Double?, accuracy: Double?, t: TimeInterval) {
        func tryAppend(value: Double?, to buffer: DataBuffer?) {
            guard let value = value, let buffer = buffer else { return }

            buffer.append(value)
        }

        tryAppend(value: x, to: xBuffer)
        tryAppend(value: y, to: yBuffer)
        tryAppend(value: z, to: zBuffer)

        tryAppend(value: accuracy, to: accuracyBuffer)
        
        if let tBuffer = tBuffer {
            tBuffer.append(t)
        }
        
        if let x = x, let y = y, let z = z, let absBuffer = absBuffer {
            absBuffer.append(sqrt(x*x + y*y + z*z))
        }
    }
    
    private func dataIn(_ x: Double?, y: Double?, z: Double?, accuracy: Double?, t: TimeInterval?, error: NSError?) {
        
        func dataInSync(_ x: Double?, y: Double?, z: Double?, accuracy: Double?, t: TimeInterval?, error: NSError?) {
            guard error == nil else {
                print("Sensor error: \(error!.localizedDescription)")
                return
            }
            
            let relativeT: TimeInterval
            if let t = t {
                if sensorInputTimeReference.t0 == nil {
                    sensorInputTimeReference.t0 = t - (tBuffer?.last ?? 0.0)
                }
                
                relativeT = t-(sensorInputTimeReference.t0 ?? 0.0)
            } else {
                let localT = CFAbsoluteTimeGetCurrent()
                if localInputTimeReference == nil {
                    localInputTimeReference = localT - (tBuffer?.last ?? 0.0)
                }
                relativeT = localT-(localInputTimeReference ?? 0.0)
            }
            
            if let av = averaging {
                if av.iterationStartTimestamp == nil {
                    av.iterationStartTimestamp = relativeT
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
                
                if accuracy != nil {
                    if av.accuracy == nil {
                        av.accuracy = accuracy!
                    }
                    else {
                        av.accuracy! = min(accuracy!, av.accuracy!)
                    }
                }
                
                av.numberOfUpdates += 1
            }
            else {
                writeToBuffers(x, y: y, z: z, accuracy: accuracy, t: relativeT)
            }
            
            if let av = averaging {
                if av.requiresFlushing(relativeT) && av.numberOfUpdates > 0 {
                    let u = Double(av.numberOfUpdates)
                    
                    writeToBuffers((av.x != nil ? av.x!/u : nil), y: (av.y != nil ? av.y!/u : nil), z: (av.z != nil ? av.z!/u : nil), accuracy: av.accuracy, t: relativeT)
                    
                    resetValuesForAveraging()
                    av.iterationStartTimestamp = relativeT
                }
            }
        }
        
        queue.async {
            autoreleasepool(invoking: {
                dataInSync(x, y: y, z: z, accuracy: accuracy, t: t, error: error)
            })
        }
    }
}

extension ExperimentSensorInput {
    static func valueEqual(lhs: ExperimentSensorInput, rhs: ExperimentSensorInput) -> Bool {
        return lhs.sensorType == rhs.sensorType &&
            lhs.rate == rhs.rate &&
            lhs.xBuffer == rhs.xBuffer &&
            lhs.yBuffer == rhs.yBuffer &&
            lhs.zBuffer == rhs.zBuffer &&
            lhs.tBuffer == rhs.tBuffer &&
            lhs.absBuffer == rhs.absBuffer &&
            lhs.accuracyBuffer == rhs.accuracyBuffer
    }
}
