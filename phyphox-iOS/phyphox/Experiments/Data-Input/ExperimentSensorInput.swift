//
//  ExperimentSensorInput.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import CoreMotion

enum SensorType: String, LosslessStringConvertible, Equatable, CaseIterable {
    case accelerometer
    case gyroscope
    case linearAcceleration = "linear_acceleration"
    case magneticField = "magnetic_field"
    case pressure
    case light
    case proximity
    case temperature
    case humidity
    case attitude
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
        case .attitude:
            return localize("sensorAttitude")
        }
    }
}

enum SensorError : Error {
    case invalidSensorType
    case motionSessionAbsent
    case sensorUnavailable(SensorType)
}

private let kG = -9.81

final class ExperimentSensorInput: MotionSessionReceiver {
    let sensorType: SensorType
    
    let timeReference: ExperimentTimeReference
    
    let sqrt12 = sqrt(0.5)

    enum RateStrategy: String, LosslessStringConvertible {
        case auto
        case request
        case generate
        case limit
    }
    
    var rateStrategy: RateStrategy
    
    var lastEventTooFast: Bool = false
    var lastEventT: TimeInterval? = nil
    var lastResult: (x: Double?, y: Double?, z: Double?, abs: Double?, accuracy: Double?)? = nil
    
    let stride: Int
    var strideCount: Int = 0
    
    /**
     The update frequency of the sensor.
     */
    private(set) var rate: TimeInterval //in s
    
    var hardwareRate: TimeInterval {
        if rateStrategy == .generate || rateStrategy == .limit {
            return 0.0
        } else {
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
    
    private var queue: DispatchQueue?
    
    private class ValueBuffer {
        /**
         The duration of averaging intervals.
         */
        var interval: TimeInterval
        var average: Bool
        
        /**
         Start of current average mesurement.
         */
        var iterationStartTimestamp: TimeInterval?
        
        var x: Double?
        var y: Double?
        var z: Double?
        var abs: Double?
        
        var accuracy: Double?
        
        var numberOfUpdates: UInt = 0
        
        init(interval: TimeInterval, average: Bool) {
            self.interval = interval
            self.average = average
        }
        
        func addValue(x: Double?, y: Double?, z: Double?, abs: Double?, accuracy: Double?, timestamp: TimeInterval) {
            if iterationStartTimestamp == nil {
                iterationStartTimestamp = timestamp
            }
            
            if x != nil {
                if self.x == nil || !average {
                    self.x = x!
                } else {
                    self.x! += x!
                }
            }
            
            if y != nil {
                if self.y == nil || !average {
                    self.y = y!
                }
                else {
                    self.y! += y!
                }
            }
            
            if z != nil {
                if self.z == nil || !average {
                    self.z = z!
                }
                else {
                    self.z! += z!
                }
            }
            
            if abs != nil {
                if self.abs == nil || !average {
                    self.abs = abs!
                }
                else {
                    self.abs! += abs!
                }
            }
            
            if accuracy != nil {
                if self.accuracy == nil || !average {
                    self.accuracy = accuracy!
                }
                else {
                    self.accuracy! = min(accuracy!, self.accuracy!)
                }
            }
            
            numberOfUpdates += 1
        }
        
        func getResult() -> (x: Double?, y: Double?, z: Double?, abs: Double?, accuracy: Double?) {
            if average {
                let u: Double = Double(numberOfUpdates)
                return (x: (x != nil ? x!/u : nil), y: (y != nil ? y!/u : nil), z: (z != nil ? z!/u : nil), abs: (abs != nil ? abs!/u : nil), accuracy: accuracy)
            } else {
                return (x: x, y: y, z: z, abs: abs, accuracy: accuracy)
            }
        }
        
        func requiresFlushing(_ currentT: TimeInterval) -> Bool {
            return numberOfUpdates > 0 && iterationStartTimestamp != nil && iterationStartTimestamp! + interval <= currentT
        }
        
        func reset(nextIntervalStart: TimeInterval?) {
            iterationStartTimestamp = nextIntervalStart
            
            x = nil
            y = nil
            z = nil
            accuracy = nil
            
            numberOfUpdates = 0
        }
    }
    
    /**
     Information on averaging. Set to `nil` to disable averaging.
     */
    private var valueBuffer: ValueBuffer
    
    let ignoreUnavailable: Bool
    
    init(sensorType: SensorType, timeReference: ExperimentTimeReference, calibrated: Bool, motionSession: MotionSession, rate: TimeInterval, rateStrategy: RateStrategy, average: Bool, stride: Int, ignoreUnavailable: Bool, xBuffer: DataBuffer?, yBuffer: DataBuffer?, zBuffer: DataBuffer?, tBuffer: DataBuffer?, absBuffer: DataBuffer?, accuracyBuffer: DataBuffer?) {
        self.sensorType = sensorType
        self.timeReference = timeReference
        self.rate = rate
        self.rateStrategy = rateStrategy
        self.stride = stride
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
        
        if (sensorType == .attitude) {
            self.motionSession.attitude = true
        }
        
        self.valueBuffer = ValueBuffer(interval: rate, average: average)
    }
    
    static func verifySensorAvailibility(sensorType: SensorType, motionSession: MotionSession) throws {
        //The following line is used by the UI test to automatically generate screenshots for the App Store using fastlane. The UI test sets the argument "screenshot" and we will then ignore sensor tests as otherwise the generated screenshots in the simulator will show almost all sensors as missing
        if ProcessInfo.processInfo.arguments.contains("screenshot") {
            if sensorType != .light {
                return
            }
        }
        
        switch sensorType {
        case .accelerometer:
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
        case .attitude, .linearAcceleration:
            guard motionSession.deviceMotionAvailable else {
                throw SensorError.sensorUnavailable(sensorType)
            }
        }
    }
    
    func verifySensorAvailibility() throws {
        return try ExperimentSensorInput.verifySensorAvailibility(sensorType: self.sensorType, motionSession: motionSession)
    }
    
    func start(queue: DispatchQueue) {
        self.queue = queue
        
        do {
            try verifySensorAvailibility()
        } catch SensorError.sensorUnavailable(_) {
            return
        } catch {}
        
        strideCount = 0
        lastEventTooFast = false
        lastEventT = nil
        lastResult = nil
        valueBuffer.reset(nextIntervalStart: nil)
        
        switch sensorType {
        case .accelerometer:
            _ = motionSession.getAccelerometerData(self, interval: hardwareRate, handler: { [unowned self] (data, error) in
                guard let accelerometerData = data else {
                    return
                }
                
                let acceleration = accelerometerData.acceleration
                
                // m/s^2
                let x = acceleration.x*kG
                let y = acceleration.y*kG
                let z = acceleration.z*kG
                
                let t = accelerometerData.timestamp
                
                self.ready = true
                self.dataIn(x, y: y, z: z, abs: nil, accuracy: nil, t: t, error: error)
                })
            
        case .gyroscope:
            _ = motionSession.getDeviceMotion(self, interval: hardwareRate, handler: { [unowned self] (deviceMotion, error) in
                guard let motion = deviceMotion else {
                    return
                }
                
                let rotation = motion.rotationRate
                
                // rad/s
                let x = rotation.x
                let y = rotation.y
                let z = rotation.z
                
                let t = motion.timestamp
                
                self.ready = true
                self.dataIn(x, y: y, z: z, abs: nil, accuracy: nil, t: t, error: error)
                })
            
        case .magneticField:
            if calibrated {
                _ = motionSession.getDeviceMotion(self, interval: hardwareRate, handler: { [unowned self] (deviceMotion, error) in
                    guard let motion = deviceMotion else {
                        return
                    }
                    
                    let field = motion.magneticField.field
                    
                    let accuracy: Double
                    switch motion.magneticField.accuracy {
                    case .uncalibrated: accuracy = -1.0
                    case .low: accuracy = 1.0
                    case .medium: accuracy = 2.0
                    case .high: accuracy = 3.0
                    @unknown default:
                        accuracy = -2.0
                    }
                    
                    let x = field.x
                    let y = field.y
                    let z = field.z
                    
                    if !self.ready && x == 0 && y == 0 && z == 0 {
                        return
                    }
                    
                    let t = motion.timestamp
                    
                    self.ready = true
                    self.dataIn(x, y: y, z: z, abs: nil, accuracy: accuracy, t: t, error: error)
                    })
            } else {
                _ = motionSession.getMagnetometerData(self, interval: hardwareRate, handler: { [unowned self] (data, error) in
                    guard let magnetometerData = data else {
                        return
                    }
                    
                    let field = magnetometerData.magneticField
                    
                    let x = field.x
                    let y = field.y
                    let z = field.z
                    
                    let t = magnetometerData.timestamp
                    
                    self.ready = true
                    self.dataIn(x, y: y, z: z, abs: nil, accuracy: 0.0, t: t, error: error)
                    })
            }
        case .linearAcceleration:
            _ = motionSession.getDeviceMotion(self, interval: hardwareRate, handler: { [unowned self] (deviceMotion, error) in
                guard let motion = deviceMotion else {
                    return
                }
                
                let acceleration = motion.userAcceleration
                
                // m/s^2
                let x = acceleration.x*kG
                let y = acceleration.y*kG
                let z = acceleration.z*kG
                
                let t = motion.timestamp
                
                self.ready = true
                self.dataIn(x, y: y, z: z, abs: nil, accuracy: nil, t: t, error: error)
                })
            
        case .pressure:
            _ = motionSession.getAltimeterData(self, interval: hardwareRate, handler: { [unowned self] (data, error) -> Void in
                guard let altimeterData = data else {
                    return
                }
                
                let pressure = altimeterData.pressure.doubleValue*10.0 //hPa
                
                let t = altimeterData.timestamp
                
                self.ready = true
                self.dataIn(pressure, y: nil, z: nil, abs: nil, accuracy: nil, t: t, error: error)
                })
        case .proximity:
            _ = motionSession.getProximityData(self, interval: hardwareRate, handler: { [unowned self] (state) -> Void in
                
                let distance = state ? 0.0 : 5.0 //Estimate in cm
                
                self.ready = true
                self.dataIn(distance, y: nil, z: nil, abs: nil, accuracy: nil, t: ProcessInfo.processInfo.systemUptime, error: nil)
                })
            
        case .attitude:
            _ = motionSession.getDeviceMotion(self, interval: hardwareRate, handler: { [unowned self] (deviceMotion, error) in
                guard let motion = deviceMotion else {
                    return
                }
                
                let attitude = motion.attitude
                
                // Quaternion: transform x north to y north to match Android orientation
                let w = self.sqrt12*(attitude.quaternion.w - attitude.quaternion.z)
                let x = self.sqrt12*(attitude.quaternion.x - attitude.quaternion.y)
                let y = self.sqrt12*(attitude.quaternion.y + attitude.quaternion.x)
                let z = self.sqrt12*(attitude.quaternion.z + attitude.quaternion.w)
                
                let t = motion.timestamp
                
                self.ready = true
                self.dataIn(x, y: y, z: z, abs: w, accuracy: nil, t: t, error: error)
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
        case .attitude:
            motionSession.stopDeviceMotionUpdates(self)
        }
    }
    
    func clear() {

    }
    
    private func writeToBuffers(_ x: Double?, y: Double?, z: Double?, abs: Double?, accuracy: Double?, t: TimeInterval) {
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
        
        if let absBuffer = absBuffer {
            if let abs = abs {
                absBuffer.append(abs)
            } else if let x = x {
                if let y = y, let z = z {
                    absBuffer.append(sqrt(x*x + y*y + z*z))
                } else {
                    absBuffer.append(x)
                }
            }
        }
    }
    
    private func flush(t: TimeInterval, data: (x: Double?, y: Double?, z: Double?, abs: Double?, accuracy: Double?)) {
        strideCount += 1
        if strideCount >= stride {
            writeToBuffers(data.x, y: data.y, z: data.z, abs: data.abs, accuracy: data.accuracy, t: t)
            strideCount = 0
        }
    }
    
    private func dataIn(_ x: Double, y: Double?, z: Double?, abs: Double?, accuracy: Double?, t: TimeInterval, error: NSError?) {
        
        func dataInSync(_ x: Double, y: Double?, z: Double?, abs: Double?, accuracy: Double?, t: TimeInterval, error: NSError?) {
            guard error == nil else {
                print("Sensor error: \(error!.localizedDescription)")
                return
            }
            
            let relativeT = timeReference.getExperimentTimeFromEvent(eventTime: t)
                        
            switch rateStrategy {
            case .auto:
                flush(t: relativeT, data: (x: x, y: y, z: z, abs: abs, accuracy: accuracy))
                if let lastT = lastEventT, relativeT - lastT < rate * 0.9 {
                    if lastEventTooFast {
                        rateStrategy = .generate
                    }
                    lastEventTooFast = true
                } else {
                    lastEventTooFast = false
                }
                lastEventT = relativeT
            case .generate:
                if lastResult == nil {
                    valueBuffer.addValue(x: x, y: y, z: z, abs: abs, accuracy: accuracy, timestamp: relativeT)
                    lastResult = valueBuffer.getResult()
                } else if valueBuffer.iterationStartTimestamp != nil && (valueBuffer.iterationStartTimestamp! + rate < relativeT) {
                    while (valueBuffer.iterationStartTimestamp! + 2*rate < relativeT) {
                        flush(t: valueBuffer.iterationStartTimestamp! + rate, data: lastResult!)
                        valueBuffer.iterationStartTimestamp! += rate
                    }
                    if valueBuffer.numberOfUpdates > 0 {
                        lastResult = valueBuffer.getResult()
                        flush(t: valueBuffer.iterationStartTimestamp! + rate, data: lastResult!)
                        valueBuffer.reset(nextIntervalStart: valueBuffer.iterationStartTimestamp! + rate)
                    }
                    valueBuffer.addValue(x: x, y: y, z: z, abs: abs, accuracy: accuracy, timestamp: relativeT)
                }
            case .limit:
                valueBuffer.addValue(x: x, y: y, z: z, abs: abs, accuracy: accuracy, timestamp: relativeT)
                if (valueBuffer.requiresFlushing(relativeT)) {
                    flush(t: relativeT, data: valueBuffer.getResult())
                    valueBuffer.reset(nextIntervalStart: relativeT)
                }
            case .request:
                flush(t: relativeT, data: (x: x, y: y, z: z, abs: abs, accuracy: accuracy))
            }
 
        }
        
        queue?.async {
            autoreleasepool(invoking: {
                dataInSync(x, y: y, z: z, abs: abs, accuracy: accuracy, t: t, error: error)
            })
        }
    }
    
    public func updateGeneratedRate() {
        if valueBuffer.iterationStartTimestamp == nil || lastResult == nil || rateStrategy != .generate {
            return
        }
        let now = timeReference.getExperimentTime()
        while (valueBuffer.iterationStartTimestamp! + 2*rate <= now) {
            flush(t: valueBuffer.iterationStartTimestamp! + rate, data: lastResult!)
            valueBuffer.iterationStartTimestamp! += rate
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
