//
//  ExperimentSensorInput.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import CoreMotion

enum SensorType: String, CaseInsensitiveAttributeDecodable, Equatable, CaseIterable {
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
    case gravity
    case custom
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
        case .gravity:
            return localize("sensorGravity")
        case .custom:
            return localize("sensorVendor")
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

    enum RateStrategy: String, CaseInsensitiveAttributeDecodable, CaseIterable {
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
    
    var calibrated = true //Use calibrated version? Can be switched while update is stopped. Only matters for the types in hasCalibratedAndUncalibratedVersion
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
            abs = nil
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
        
        self.valueBuffer = ValueBuffer(interval: rate, average: average)
    }
    
    //Whether this device has the hardware behind a sensor type; the fusion outputs need device motion
    static func hardwareAvailable(sensorType: SensorType, motionSession: MotionSession) -> Bool {
        switch sensorType {
        case .accelerometer: return motionSession.accelerometerAvailable
        case .gyroscope: return motionSession.gyroAvailable
        case .magneticField: return motionSession.magnetometerAvailable
        case .pressure: return motionSession.altimeterAvailable
        case .proximity: return motionSession.proximityAvailable
        case .light, .temperature, .humidity, .custom: return false
        case .attitude, .linearAcceleration, .gravity: return motionSession.deviceMotionAvailable
        }
    }

    static func verifySensorAvailibility(sensorType: SensorType, motionSession: MotionSession) throws {
        //-phyphoxAssumeSensors and -phyphoxSyntheticSensors (AutomationLaunchOptions) for the simulator: skip only the hardware
        //test, sensor types iOS supports on no device still fail
        if AutomationLaunchOptions.assumeSensors || AutomationLaunchOptions.syntheticSensors {
            switch sensorType {
            case .light, .temperature, .humidity, .custom:
                break
            default:
                return
            }
        }
        
        guard hardwareAvailable(sensorType: sensorType, motionSession: motionSession) else {
            throw SensorError.sensorUnavailable(sensorType)
        }
    }
    
    func verifySensorAvailibility() throws {
        return try ExperimentSensorInput.verifySensorAvailibility(sensorType: self.sensorType, motionSession: motionSession)
    }
    
    //The types that come in a calibrated (CMDeviceMotion, bias-corrected) and an uncalibrated (raw CoreMotion data)
    //version on this device. The accelerometer only exists raw on iOS: the fused userAcceleration + gravity is not a
    //calibration. linear_acceleration, gravity and attitude are fusion outputs with no raw counterpart.
    static func hasCalibratedAndUncalibratedVersion(sensorType: SensorType, motionSession: MotionSession) -> Bool {
        guard motionSession.deviceMotionAvailable else { return false }
        switch sensorType {
        case .magneticField: return motionSession.magnetometerAvailable
        case .gyroscope: return motionSession.gyroAvailable
        default: return false
        }
    }
    
    func hasCalibratedAndUncalibratedVersion() -> Bool {
        return ExperimentSensorInput.hasCalibratedAndUncalibratedVersion(sensorType: sensorType, motionSession: motionSession)
    }
    
    //The format's accuracy encoding (-1 uncalibrated, 1 low, 2 medium, 3 high), the same states Android reports
    private static func accuracyValue(_ accuracy: CMMagneticFieldCalibrationAccuracy) -> Double {
        switch accuracy {
        case .uncalibrated: return -1.0
        case .low: return 1.0
        case .medium: return 2.0
        case .high: return 3.0
        @unknown default: return -2.0
        }
    }
    
    func configureMotionSession() {
        if (sensorType == .magneticField) {
            self.motionSession.calibratedMagnetometer = calibrated
        }
        
        if (sensorType == .attitude) {
            self.motionSession.attitude = true
        }
        if (sensorType == .gravity) {
            self.motionSession.gravity = true
        }
    }
    
    //-phyphoxSyntheticSensors (AutomationLaunchOptions): the simulator has no motion sensors, so a timer stands in for the
    //missing hardware with a constant reading at the requested rate, the way the emulator's virtual sensors do on Android
    private var syntheticTimer: DispatchSourceTimer? = nil

    private func startSyntheticFeed() -> Bool {
        guard AutomationLaunchOptions.syntheticSensors,
              !ExperimentSensorInput.hardwareAvailable(sensorType: sensorType, motionSession: motionSession) else {
            return false
        }
        let reading: (x: Double, y: Double?, z: Double?, abs: Double?, accuracy: Double?)
        switch sensorType {
        case .accelerometer, .gravity: reading = (1.5, 2.5, 9.3, nil, nil) //at rest but tilted, so the three components differ
        case .pressure: reading = (1013.25, nil, nil, nil, nil)
        case .proximity: reading = (5.0, nil, nil, nil, nil)
        case .magneticField: reading = (0.0, 20.0, -40.0, nil, 3.0)
        case .attitude: reading = (0.0, 0.0, 0.0, 1.0, 3.0)
        case .gyroscope: reading = (0.0, 0.0, 0.0, nil, 0.0)
        default: reading = (0.0, 0.0, 0.0, nil, nil)
        }
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .userInitiated))
        timer.schedule(deadline: .now(), repeating: hardwareRate > 0 ? hardwareRate : max(rate, 0.01))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.ready = true
            self.dataIn(reading.x, y: reading.y, z: reading.z, abs: reading.abs, accuracy: reading.accuracy, t: ProcessInfo.processInfo.systemUptime, error: nil)
        }
        syntheticTimer = timer
        timer.resume()
        return true
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
        
        if startSyntheticFeed() {
            return
        }
        
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
            if calibrated {
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
            } else {
                _ = motionSession.getGyroData(self, interval: hardwareRate, handler: { [unowned self] (data, error) in
                    guard let gyroData = data else {
                        return
                    }
                    
                    let rotation = gyroData.rotationRate
                    
                    // rad/s
                    let x = rotation.x
                    let y = rotation.y
                    let z = rotation.z
                    
                    let t = gyroData.timestamp
                    
                    //0 = uncalibrated raw data, as expected (like the raw magnetometer). CoreMotion reports no calibration
                    //status for the gyroscope, so the calibrated path writes no accuracy at all
                    self.ready = true
                    self.dataIn(x, y: y, z: z, abs: nil, accuracy: 0.0, t: t, error: error)
                    })
            }
            
        case .magneticField:
            if calibrated {
                _ = motionSession.getDeviceMotion(self, interval: hardwareRate, handler: { [unowned self] (deviceMotion, error) in
                    guard let motion = deviceMotion else {
                        return
                    }
                    
                    let field = motion.magneticField.field
                    let accuracy = ExperimentSensorInput.accuracyValue(motion.magneticField.accuracy)
                    
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
                
                //The attitude runs in the magnetic-north frame, so its yaw is only as good as the magnetic calibration; the
                //same status Android reports for its rotation vector
                let accuracy = ExperimentSensorInput.accuracyValue(motion.magneticField.accuracy)
                
                let t = motion.timestamp
                
                self.ready = true
                self.dataIn(x, y: y, z: z, abs: w, accuracy: accuracy, t: t, error: error)
                })
            
        case .gravity:
            _ = motionSession.getDeviceMotion(self, interval: hardwareRate, handler: { [unowned self] (deviceMotion, error) in
                guard let motion = deviceMotion else {
                    return
                }
                
                let gravity = motion.gravity
                
                let x = gravity.x*kG
                let y = gravity.y*kG
                let z = gravity.z*kG
                
                let t = motion.timestamp
                
                self.ready = true
                self.dataIn(x, y: y, z: z, abs: nil, accuracy: nil, t: t, error: error)
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
        
        if let timer = syntheticTimer {
            timer.cancel()
            syntheticTimer = nil
            return
        }
        
        switch sensorType {
        case .accelerometer:
            motionSession.stopAccelerometerUpdates(self)
        case .linearAcceleration:
            motionSession.stopDeviceMotionUpdates(self)
        case .gyroscope:
            if calibrated {
                motionSession.stopDeviceMotionUpdates(self)
            } else {
                motionSession.stopGyroUpdates(self)
            }
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
        case .light, .temperature, .humidity, .custom:
            break
        case .attitude:
            motionSession.stopDeviceMotionUpdates(self)
        case .gravity:
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

        //One atomic group so a remote /get never sees a partial sample (see BufferLock)
        synchronizedBufferWrite([xBuffer, yBuffer, zBuffer, accuracyBuffer, tBuffer, absBuffer]) {
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
                } else {
                    //Assuming that even delayed sensor readings arrive in correct order, we should still use this delayed reading to update the current state
                    lastResult = (x: x, y: y, z: z, abs: abs, accuracy: accuracy)
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
