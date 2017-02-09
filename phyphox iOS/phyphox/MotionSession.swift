//
//  MotionSession.swift
//  phyphox
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation
import CoreMotion

func ==(x: MotionSessionReceiver, y: MotionSessionReceiver) -> Bool {
    return x === y
}

class MotionSessionReceiver: Hashable {
    var hashValue: Int {
        return unsafeAddressOf(self).hashValue
    }
}

final class MotionSession {
    private lazy var motionManager = CMMotionManager()
    private lazy var altimeter = CMAltimeter()
    
    var calibratedMagnetometer = true
    
    private(set) var altimeterRunning = false
    private(set) var accelerometerRunning = false
    private(set) var gyroscopeRunning = false
    private(set) var magnetometerRunning = false
    private(set) var deviceMotionRunning = false
    private(set) var proximityRunning = false
    
    private var altimeterReceivers: [MotionSessionReceiver: (data: CMAltitudeData?, error: NSError?) -> Void] = [:]
    private var accelerometerReceivers: [MotionSessionReceiver: (data: CMAccelerometerData?, error: NSError?) -> Void] = [:]
    private var gyroscopeReceivers: [MotionSessionReceiver: (data: CMGyroData?, error: NSError?) -> Void] = [:]
    private var magnetometerReceivers: [MotionSessionReceiver: (data: CMMagnetometerData?, error: NSError?) -> Void] = [:]
    private var deviceMotionReceivers: [MotionSessionReceiver: (deviceMotion: CMDeviceMotion?, error: NSError?) -> Void] = [:]
    private var proximityReceivers: [MotionSessionReceiver: (proximityState: Bool) -> Void] = [:]
    
    private func makeQueue() -> NSOperationQueue {
        let q = NSOperationQueue()
        
        q.maxConcurrentOperationCount = 1 //FIFO/serial queue
        q.qualityOfService = .UserInitiated
        
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
    
    func getAltimeterData(receiver: MotionSessionReceiver, interval: NSTimeInterval = 0.1, handler: (data: CMAltitudeData?, error: NSError?) -> Void) -> Bool {
        if altimeterAvailable {
            altimeterReceivers[receiver] = handler
            
            if !altimeterRunning {
                altimeterRunning = true
                
                altimeter.startRelativeAltitudeUpdatesToQueue(makeQueue(), withHandler: { [unowned self] (data, error) in
                    for (_, h) in self.altimeterReceivers {
                        h(data: data, error: error)
                    }
                    })
            }
            
            return true
        }
        
        return false
    }
    
    func stopAltimeterUpdates(receiver: MotionSessionReceiver) {
        altimeterReceivers.removeValueForKey(receiver)
        
        if altimeterReceivers.count == 0 && altimeterRunning {
            altimeterRunning = false
            self.altimeter.stopRelativeAltitudeUpdates()
        }
    }
    
    
    //MARK: - Accelerometer
    
    var accelerometerAvailable: Bool {
        return motionManager.accelerometerAvailable
    }
    
    func getAccelerometerData(receiver: MotionSessionReceiver, interval: NSTimeInterval = 0.1, handler: (data: CMAccelerometerData?, error: NSError?) -> Void) -> Bool {
        if accelerometerAvailable {
            accelerometerReceivers[receiver] = handler
            
            if !accelerometerRunning {
                accelerometerRunning = true
                
                motionManager.accelerometerUpdateInterval = interval
                motionManager.startAccelerometerUpdatesToQueue(makeQueue(), withHandler: { [unowned self] (data, error) in
                    for (_, h) in self.accelerometerReceivers {
                        h(data: data, error: error)
                    }
                    })
            }
            
            return true
        }
        
        return false
    }
    
    func stopAccelerometerUpdates(receiver: MotionSessionReceiver) {
        accelerometerReceivers.removeValueForKey(receiver)
        
        if accelerometerReceivers.count == 0 && accelerometerRunning {
            accelerometerRunning = false
            self.motionManager.stopAccelerometerUpdates()
        }
    }
    
    //MARK: - Gyroscope
    
    var gyroAvailable: Bool {
        return motionManager.gyroAvailable
    }
    
    func getGyroData(receiver: MotionSessionReceiver, interval: NSTimeInterval = 0.1, handler: (data: CMGyroData?, error: NSError?) -> Void) -> Bool {
        if gyroAvailable {
            gyroscopeReceivers[receiver] = handler
            
            if !gyroscopeRunning {
                gyroscopeRunning = true
                
                motionManager.gyroUpdateInterval = interval
                motionManager.startGyroUpdatesToQueue(makeQueue(), withHandler: { [unowned self] (data, error) in
                    for (_, h) in self.gyroscopeReceivers {
                        h(data: data, error: error)
                    }
                    })
            }
            
            return true
        }
        
        return false
    }
    
    func stopGyroUpdates(receiver: MotionSessionReceiver) {
        gyroscopeReceivers.removeValueForKey(receiver)
        
        if gyroscopeReceivers.count == 0 && gyroscopeRunning {
            gyroscopeRunning = false
            self.motionManager.stopGyroUpdates()
        }
    }
    
    
    //MARK: - Magnetometer
    
    var magnetometerAvailable: Bool {
        return motionManager.magnetometerAvailable
    }
    
    func getMagnetometerData(receiver: MotionSessionReceiver, interval: NSTimeInterval = 0.1, handler: (data: CMMagnetometerData?, error: NSError?) -> Void) -> Bool {
        if magnetometerAvailable {
            magnetometerReceivers[receiver] = handler
            
            if !magnetometerRunning {
                magnetometerRunning = true
                
                motionManager.magnetometerUpdateInterval = interval
                motionManager.startMagnetometerUpdatesToQueue(makeQueue(), withHandler: { [unowned self] (data, error) in
                    for (_, h) in self.magnetometerReceivers {
                        h(data: data, error: error)
                    }
                    })
            }
            
            return true
        }
        
        return false
    }
    
    func stopMagnetometerUpdates(receiver: MotionSessionReceiver) {
        magnetometerReceivers.removeValueForKey(receiver)
        
        if magnetometerReceivers.count == 0 && magnetometerRunning {
            magnetometerRunning = false
            motionManager.stopMagnetometerUpdates()
        }
    }
    
    //MARK: - Device Motion
    
    var deviceMotionAvailable: Bool {
        return motionManager.deviceMotionAvailable
    }
    
    func getDeviceMotion(receiver: MotionSessionReceiver, interval: NSTimeInterval = 0.1, handler: (deviceMotion: CMDeviceMotion?, error: NSError?) -> Void) -> Bool {
        if deviceMotionAvailable {
            deviceMotionReceivers[receiver] = handler
            
            if !deviceMotionRunning {
                deviceMotionRunning = true
                
                motionManager.deviceMotionUpdateInterval = interval
                motionManager.showsDeviceMovementDisplay = true
                if calibratedMagnetometer {
                    motionManager.startDeviceMotionUpdatesUsingReferenceFrame(.XArbitraryCorrectedZVertical, toQueue: makeQueue(), withHandler: { [unowned self] (motion, error) in
                        for (_, h) in self.deviceMotionReceivers {
                            h(deviceMotion: motion, error: error)
                        }
                        })
                } else {
                    motionManager.startDeviceMotionUpdatesToQueue(makeQueue(), withHandler: { [unowned self] (motion, error) in
                        for (_, h) in self.deviceMotionReceivers {
                            h(deviceMotion: motion, error: error)
                        }
                        })
                }
            }
            
            return true
        }
        
        return false
    }
    
    func stopDeviceMotionUpdates(receiver: MotionSessionReceiver) {
        deviceMotionReceivers.removeValueForKey(receiver)
        
        if deviceMotionReceivers.count == 0 && deviceMotionRunning {
            deviceMotionRunning = false
            motionManager.stopDeviceMotionUpdates()
        }
    }
    
    //MARK: - Proximity sensor
    
    var proximityAvailable: Bool {
        let device = UIDevice.currentDevice()
        device.proximityMonitoringEnabled = true
        let available = device.proximityMonitoringEnabled
        device.proximityMonitoringEnabled = false
        return available
    }
    
    @objc func proximityChanged(notification: NSNotification) {
        let state = (notification.object as! UIDevice).proximityState
        for (_, h) in self.proximityReceivers {
            h(proximityState: state)
        }
    }
    
    func getProximityData(receiver: MotionSessionReceiver, interval: NSTimeInterval = 0.1, handler: (proximity: Bool) -> Void) -> Bool {
        if proximityAvailable {
            proximityReceivers[receiver] = handler
            
            if !proximityRunning {
                proximityRunning = true
                
                let device = UIDevice.currentDevice()
                device.proximityMonitoringEnabled = true
                NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(proximityChanged), name: "UIDeviceProximityStateDidChangeNotification", object: device)
                proximityChanged(NSNotification(name: "First value", object: device))
            }
            
            return true
        }
        
        return false
    }
    
    func stopProximityUpdates(receiver: MotionSessionReceiver) {
        proximityReceivers.removeValueForKey(receiver)
        print("Stopping")
        if proximityReceivers.count == 0 && proximityRunning {
            print("Full stop")
            proximityRunning = false
            NSNotificationCenter.defaultCenter().removeObserver(self)
            UIDevice.currentDevice().proximityMonitoringEnabled = false
        }
    }
    
}
