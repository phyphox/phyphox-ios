//
//  MotionSession.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation
import CoreMotion

class MotionSessionReceiver: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(Unmanaged.passUnretained(self).toOpaque().hashValue)
    }
}

extension MotionSessionReceiver: Equatable {
    static func ==(x: MotionSessionReceiver, y: MotionSessionReceiver) -> Bool {
        return x === y
    }
}

final class MotionSession {
    private lazy var motionManager = CMMotionManager()
    private lazy var altimeter = CMAltimeter()

    var calibratedMagnetometer = false
    var attitude = false
    var gravity = false

    private(set) var altimeterRunning = false
    private(set) var accelerometerRunning = false
    private(set) var gyroscopeRunning = false
    private(set) var magnetometerRunning = false
    private(set) var deviceMotionRunning = false
    private(set) var proximityRunning = false

    private var altimeterReceivers: [MotionSessionReceiver: (_ data: CMAltitudeData?, _ error: NSError?) -> Void] = [:]
    private var accelerometerReceivers: [MotionSessionReceiver: (_ data: CMAccelerometerData?, _ error: NSError?) -> Void] = [:]
    private var gyroscopeReceivers: [MotionSessionReceiver: (_ data: CMGyroData?, _ error: NSError?) -> Void] = [:]
    private var magnetometerReceivers: [MotionSessionReceiver: (_ data: CMMagnetometerData?, _ error: NSError?) -> Void] = [:]
    private var deviceMotionReceivers: [MotionSessionReceiver: (_ deviceMotion: CMDeviceMotion?, _ error: NSError?) -> Void] = [:]
    private var proximityReceivers: [MotionSessionReceiver: (_ proximityState: Bool) -> Void] = [:]
    
    //The receiver dictionaries are changed from the main thread while CoreMotion delivers on its own queue. Every access goes through this lock; the handlers iterate a snapshot.
    private let receiverLock = NSLock()
    
    private func withReceivers<T>(_ body: () -> T) -> T {
        receiverLock.lock()
        defer { receiverLock.unlock() }
        return body()
    }
    
    public func resetConfig() {
        calibratedMagnetometer = false
        attitude = false
        gravity = false
    }

    private func makeQueue() -> OperationQueue {
        let q = OperationQueue()

        q.maxConcurrentOperationCount = 1 //FIFO/serial queue
        q.qualityOfService = .userInitiated

        return q
    }

    private static let instance = MotionSession()

    class func sharedSession() -> MotionSession {
        return instance
    }

    //MARK: - Altimeter

    var altimeterAvailable: Bool {
        return CMAltimeter.isRelativeAltitudeAvailable()
    }

    func getAltimeterData(_ receiver: MotionSessionReceiver, interval: TimeInterval = 0.1, handler: @escaping (_ data: CMAltitudeData?, _ error: NSError?) -> Void) -> Bool {
        if altimeterAvailable {
            withReceivers { altimeterReceivers[receiver] = handler }

            if !altimeterRunning {
                altimeterRunning = true

                altimeter.startRelativeAltitudeUpdates(to: makeQueue(), withHandler: { [unowned self] (data, error) in
                    for h in self.withReceivers({ Array(self.altimeterReceivers.values) }) {
                        h(data, error as NSError?)
                    }
                })
            }

            return true
        }

        return false
    }

    func stopAltimeterUpdates(_ receiver: MotionSessionReceiver) {
        let noReceiversLeft = withReceivers { () -> Bool in
            altimeterReceivers.removeValue(forKey: receiver)
            return altimeterReceivers.isEmpty
        }

        if noReceiversLeft && altimeterRunning {
            altimeterRunning = false
            self.altimeter.stopRelativeAltitudeUpdates()
        }
    }


    //MARK: - Accelerometer

    var accelerometerAvailable: Bool {
        return motionManager.isAccelerometerAvailable
    }

    func getAccelerometerData(_ receiver: MotionSessionReceiver, interval: TimeInterval = 0.1, handler: @escaping (_ data: CMAccelerometerData?, _ error: NSError?) -> Void) -> Bool {
        if accelerometerAvailable {
            withReceivers { accelerometerReceivers[receiver] = handler }

            if !accelerometerRunning {
                accelerometerRunning = true

                motionManager.accelerometerUpdateInterval = interval
                motionManager.startAccelerometerUpdates(to: makeQueue(), withHandler: { [unowned self] (data, error) in
                    for h in self.withReceivers({ Array(self.accelerometerReceivers.values) }) {
                        h(data, error as NSError?)
                    }
                })
            }

            return true
        }

        return false
    }

    func stopAccelerometerUpdates(_ receiver: MotionSessionReceiver) {
        let noReceiversLeft = withReceivers { () -> Bool in
            accelerometerReceivers.removeValue(forKey: receiver)
            return accelerometerReceivers.isEmpty
        }

        if noReceiversLeft && accelerometerRunning {
            accelerometerRunning = false
            self.motionManager.stopAccelerometerUpdates()
        }
    }

    //MARK: - Gyroscope

    var gyroAvailable: Bool {
        return motionManager.isGyroAvailable
    }

    func getGyroData(_ receiver: MotionSessionReceiver, interval: TimeInterval = 0.1, handler: @escaping (_ data: CMGyroData?, _ error: NSError?) -> Void) -> Bool {
        if gyroAvailable {
            withReceivers { gyroscopeReceivers[receiver] = handler }

            if !gyroscopeRunning {
                gyroscopeRunning = true

                motionManager.gyroUpdateInterval = interval
                motionManager.startGyroUpdates(to: makeQueue(), withHandler: { [unowned self] (data, error) in
                    for h in self.withReceivers({ Array(self.gyroscopeReceivers.values) }) {
                        h(data, error as NSError?)
                    }
                })
            }

            return true
        }

        return false
    }

    func stopGyroUpdates(_ receiver: MotionSessionReceiver) {
        let noReceiversLeft = withReceivers { () -> Bool in
            gyroscopeReceivers.removeValue(forKey: receiver)
            return gyroscopeReceivers.isEmpty
        }

        if noReceiversLeft && gyroscopeRunning {
            gyroscopeRunning = false
            self.motionManager.stopGyroUpdates()
        }
    }


    //MARK: - Magnetometer

    var magnetometerAvailable: Bool {
        return motionManager.isMagnetometerAvailable
    }

    func getMagnetometerData(_ receiver: MotionSessionReceiver, interval: TimeInterval = 0.1, handler: @escaping (_ data: CMMagnetometerData?, _ error: NSError?) -> Void) -> Bool {
        if magnetometerAvailable {
            withReceivers { magnetometerReceivers[receiver] = handler }

            if !magnetometerRunning {
                magnetometerRunning = true

                motionManager.magnetometerUpdateInterval = interval
                motionManager.startMagnetometerUpdates(to: makeQueue(), withHandler: { [unowned self] (data, error) in
                    for h in self.withReceivers({ Array(self.magnetometerReceivers.values) }) {
                        h(data, error as NSError?)
                    }
                })
            }

            return true
        }

        return false
    }

    func stopMagnetometerUpdates(_ receiver: MotionSessionReceiver) {
        let noReceiversLeft = withReceivers { () -> Bool in
            magnetometerReceivers.removeValue(forKey: receiver)
            return magnetometerReceivers.isEmpty
        }

        if noReceiversLeft && magnetometerRunning {
            magnetometerRunning = false
            motionManager.stopMagnetometerUpdates()
        }
    }

    //MARK: - Device Motion

    var deviceMotionAvailable: Bool {
        return motionManager.isDeviceMotionAvailable
    }

    func getDeviceMotion(_ receiver: MotionSessionReceiver, interval: TimeInterval = 0.1, handler: @escaping (_ deviceMotion: CMDeviceMotion?, _ error: NSError?) -> Void) -> Bool {
        if deviceMotionAvailable {
            withReceivers { deviceMotionReceivers[receiver] = handler }

            if !deviceMotionRunning {
                deviceMotionRunning = true

                motionManager.deviceMotionUpdateInterval = interval
                motionManager.showsDeviceMovementDisplay = true
                if motionManager.isMagnetometerAvailable && (calibratedMagnetometer || attitude || gravity) {
                    motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: makeQueue(), withHandler: { [unowned self] (motion, error) in
                        for h in self.withReceivers({ Array(self.deviceMotionReceivers.values) }) {
                            h(motion, error as NSError?)
                        }
                    })
                } else {
                    motionManager.startDeviceMotionUpdates(to: makeQueue(), withHandler: { [unowned self] (motion, error) in
                        for h in self.withReceivers({ Array(self.deviceMotionReceivers.values) }) {
                            h(motion, error as NSError?)
                        }
                    })
                }
            }

            return true
        }

        return false
    }

    func stopDeviceMotionUpdates(_ receiver: MotionSessionReceiver) {
        let noReceiversLeft = withReceivers { () -> Bool in
            deviceMotionReceivers.removeValue(forKey: receiver)
            return deviceMotionReceivers.isEmpty
        }

        if noReceiversLeft && deviceMotionRunning {
            deviceMotionRunning = false
            motionManager.stopDeviceMotionUpdates()
        }
    }

    //MARK: - Proximity sensor

    var proximityAvailableChecked: Bool? = nil
    
    var proximityAvailable: Bool {
        if let oldAvailable = proximityAvailableChecked {
            return oldAvailable //Do not check again as these frequent checks interfere with turning on the sensor for the actual measurement.
        }

        let device = UIDevice.current
        device.isProximityMonitoringEnabled = true
        let available = device.isProximityMonitoringEnabled
        device.isProximityMonitoringEnabled = false
        proximityAvailableChecked = available //Remember result for next time
        return available
    }

    @objc func proximityChanged(_ notification: Notification) {
        let state = (notification.object as! UIDevice).proximityState
        for h in self.withReceivers({ Array(self.proximityReceivers.values) }) {
            h(state)
        }
    }

    func getProximityData(_ receiver: MotionSessionReceiver, interval: TimeInterval = 0.1, handler: @escaping (_ proximity: Bool) -> Void) -> Bool {
        if proximityAvailable {
            withReceivers { proximityReceivers[receiver] = handler }

            if !proximityRunning {
                proximityRunning = true

                let device = UIDevice.current
                device.isProximityMonitoringEnabled = true
                NotificationCenter.default.addObserver(self, selector: #selector(proximityChanged), name: NSNotification.Name(rawValue: "UIDeviceProximityStateDidChangeNotification"), object: device)
                proximityChanged(Notification(name: Notification.Name(rawValue: "First value"), object: device))
            }

            return true
        }

        return false
    }

    func stopProximityUpdates(_ receiver: MotionSessionReceiver) {
        let noReceiversLeft = withReceivers { () -> Bool in
            proximityReceivers.removeValue(forKey: receiver)
            return proximityReceivers.isEmpty
        }
        if noReceiversLeft && proximityRunning {
            proximityRunning = false
            NotificationCenter.default.removeObserver(self)
            UIDevice.current.isProximityMonitoringEnabled = false
        }
    }
}
