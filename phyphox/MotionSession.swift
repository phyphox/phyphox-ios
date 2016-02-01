//
//  MotionSession.swift
//  phyphox
//  The original Github repository is https://github.com/MHaroonBaig/MotionKit
//
//  Created by Jonas Gessner on 05.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import CoreMotion

final class MotionSession {
    private let manager = CMMotionManager()
    private var altimeter: CMAltimeter?
    
    var altimeterAvailable: Bool {
        get {
            return CMAltimeter.isRelativeAltitudeAvailable()
        }
    }
    
    func getAltimeterValues(interval: NSTimeInterval = 0.1, values: ((data: CMAltitudeData?, error: NSError?) -> Void)) -> Bool {
        if altimeterAvailable {
            if altimeter == nil {
                altimeter = CMAltimeter()
            }
            
            altimeter!.startRelativeAltitudeUpdatesToQueue(NSOperationQueue(), withHandler: values)
            
            return true
        }
        
        return false
    }
    
    /*
    *  getAccelerometerValues:interval:values:
    *
    *  Discussion:
    *   Starts accelerometer updates, providing data to the given handler through the given queue.
    *   Note that when the updates are stopped, all operations in the
    *   given NSOperationQueue will be cancelled. You can access the retrieved values either by a
    *   Trailing Closure or through a Delgate.
    */
    var accelerometerAvailable: Bool {
        get {
            return manager.accelerometerAvailable
        }
    }
    
    func getAccelerometerValues (interval: NSTimeInterval = 0.1, values: ((x: Double?, y: Double?, z: Double?, error: NSError?) -> Void)) -> Bool {
        var valX: Double?
        var valY: Double?
        var valZ: Double?
        
        if accelerometerAvailable {
            manager.accelerometerUpdateInterval = interval//max(0.01, interval)
            let q = NSOperationQueue()
            q.qualityOfService = .Utility
            manager.startAccelerometerUpdatesToQueue(q) {
                (data: CMAccelerometerData?, error: NSError?) in
                
                //                if let isError = error {
                //                    NSLog("Error: %@", isError)
                //                }
                
                if (data != nil) {
                    valX = data!.acceleration.x
                    valY = data!.acceleration.y
                    valZ = data!.acceleration.z
                }
                
                values(x: valX,y: valY,z: valZ, error: error)
                //                let absoluteVal = sqrt(valX * valX + valY * valY + valZ * valZ)
                //                self.delegate?.retrieveAccelerometerValues!(valX, y: valY, z: valZ, absoluteValue: absoluteVal)
            }
            
            return true
        }
        
        return false
    }
    
    /*
    *  getGyroValues:interval:values:
    *
    *  Discussion:
    *   Starts gyro updates, providing data to the given handler through the given queue.
    *   Note that when the updates are stopped, all operations in the
    *   given NSOperationQueue will be cancelled. You can access the retrieved values either by a
    *   Trailing Closure or through a Delegate.
    */
    
    var gyroAvailable: Bool {
        get {
            return manager.gyroAvailable
        }
    }
    
    func getGyroValues (interval: NSTimeInterval = 0.1, values: ((x: Double?, y: Double?, z:Double?, error: NSError?) -> Void)) -> Bool {
        if gyroAvailable {
            manager.gyroUpdateInterval = interval
            
            var valX: Double?
            var valY: Double?
            var valZ: Double?
            
            manager.startGyroUpdatesToQueue(NSOperationQueue()) {
                (data: CMGyroData?, error: NSError?) in
                if data != nil {
                    valX = data!.rotationRate.x
                    valY = data!.rotationRate.y
                    valZ = data!.rotationRate.z
                }
                
                values(x: valX, y: valY, z: valZ, error: error)
            }
            
            return true
        }
        
        return false
    }
    
    /*
    *  getMagnetometerValues:interval:values:
    *
    *  Discussion:
    *   Starts magnetometer updates, providing data to the given handler through the given queue.
    *   You can access the retrieved values either by a Trailing Closure or through a Delegate.
    */
    var magnetometerAvailable: Bool {
        get {
            return manager.magnetometerAvailable
        }
    }
    
    @available(iOS, introduced=5.0)
    func getMagnetometerValues (interval: NSTimeInterval = 0.1, values: ((x: Double?, y:Double?, z:Double?, error: NSError?) -> Void)) -> Bool {
        var valX: Double?
        var valY: Double?
        var valZ: Double?
        
        if manager.magnetometerAvailable {
            manager.magnetometerUpdateInterval = interval
            manager.startMagnetometerUpdatesToQueue(NSOperationQueue()){
                (data: CMMagnetometerData?, error: NSError?) in
                
                //                if let isError = error{
                //                    NSLog("Error: %@", isError)
                //                }
                
                if (data != nil) {
                    valX = data!.magneticField.x
                    valY = data!.magneticField.y
                    valZ = data!.magneticField.z
                }
                
                values(x: valX, y: valY, z: valZ, error: error)
                //                let absoluteVal = sqrt(valX * valX + valY * valY + valZ * valZ)
                //                self.delegate?.retrieveMagnetometerValues!(valX, y: valY, z: valZ, absoluteValue: absoluteVal)
            }
            
            return true
        }
        
        return false
    }
    
    /*  MARK :- DEVICE MOTION APPROACH STARTS HERE  */
    
    /*
    *  getDeviceMotionValues:interval:values:
    *
    *  Discussion:
    *   Starts device motion updates, providing data to the given handler through the given queue.
    *   Uses the default reference frame for the device. Examine CMMotionManager's
    *   attitudeReferenceFrame to determine this. You can access the retrieved values either by a
    *   Trailing Closure or through a Delegate.
    */
    var deviceMotionAvailable: Bool {
        get {
            return manager.deviceMotionAvailable
        }
    }
    
    func getDeviceMotionObject (interval: NSTimeInterval = 0.1, values: ((deviceMotion: CMDeviceMotion?, error: NSError?) -> Void)) -> Bool {
        
        if deviceMotionAvailable{
            manager.deviceMotionUpdateInterval = interval
            manager.startDeviceMotionUpdatesToQueue(NSOperationQueue(), withHandler: values)
            
            return true
        }
        
        return false
    }
    
    
    /*
    *   getAccelerationFromDeviceMotion:interval:values:
    *   You can retrieve the processed user accelaration data from the device motion from this method.
    */
    func getAccelerationFromDeviceMotion (interval: NSTimeInterval = 0.1, values: ((x:Double?, y:Double?, z:Double?, error: NSError?) -> Void)) -> Bool {
        var valX: Double?
        var valY: Double?
        var valZ: Double?
        
        if deviceMotionAvailable {
            manager.deviceMotionUpdateInterval = interval
            manager.startDeviceMotionUpdatesToQueue(NSOperationQueue()){
                (data: CMDeviceMotion?, error: NSError?) in
                
                //                if let isError = error{
                //                    NSLog("Error: %@", isError)
                //                }
                if (data != nil) {
                    valX = data!.userAcceleration.x
                    valY = data!.userAcceleration.y
                    valZ = data!.userAcceleration.z
                }
                
                values(x: valX, y: valY, z: valZ, error: error)
                
                //                self.delegate?.getAccelerationValFromDeviceMotion!(valX, y: valY, z: valZ)
            }
            
            return true
        }
        
        return false
    }
    
    /*
    *   getGravityAccelerationFromDeviceMotion:interval:values:
    *   You can retrieve the processed gravitational accelaration data from the device motion from this
    *   method.
    */
    func getGravityAccelerationFromDeviceMotion (interval: NSTimeInterval = 0.1, values: ((x:Double?, y:Double?, z:Double?, error: NSError?) -> Void)) -> Bool {
        var valX: Double?
        var valY: Double?
        var valZ: Double?
        
        if deviceMotionAvailable{
            manager.deviceMotionUpdateInterval = interval
            manager.startDeviceMotionUpdatesToQueue(NSOperationQueue()){
                (data: CMDeviceMotion?, error: NSError?) in
                
                //                if let isError = error{
                //                    NSLog("Error: %@", isError)
                //                }
                if data != nil {
                    valX = data!.gravity.x
                    valY = data!.gravity.y
                    valZ = data!.gravity.z
                }
                
                values(x: valX, y: valY, z: valZ, error: error)
                
                //                var absoluteVal = sqrt(valX * valX + valY * valY + valZ * valZ)
                //                self.delegate?.getGravityAccelerationValFromDeviceMotion!(valX, y: valY, z: valZ)
            }
            
            return true
        }
        
        return false
    }
    
    
    /*
    *   getAttitudeFromDeviceMotion:interval:values:
    *   You can retrieve the processed attitude data from the device motion from this
    *   method.
    */
    func getAttitudeFromDeviceMotion (interval: NSTimeInterval = 0.1, values: ((attitude: CMAttitude?, error: NSError?) -> Void)) -> Bool {
        
        if deviceMotionAvailable{
            manager.deviceMotionUpdateInterval = interval
            manager.startDeviceMotionUpdatesToQueue(NSOperationQueue()){
                (data: CMDeviceMotion?, error: NSError?) in
                
                //                if let isError = error{
                //                    NSLog("Error: %@", isError)
                //                }
                values(attitude: data?.attitude, error: error)
                
                //                self.delegate?.getAttitudeFromDeviceMotion!(data?.attitude)
            }
            
            return true
        }
        
        return false
    }
    
    /*
    *   getRotationRateFromDeviceMotion:interval:values:
    *   You can retrieve the processed rotation data from the device motion from this
    *   method.
    */
    func getRotationRateFromDeviceMotion (interval: NSTimeInterval = 0.1, values: ((x:Double?, y:Double?, z:Double?, error: NSError?) -> Void)) -> Bool {
        var valX: Double?
        var valY: Double?
        var valZ: Double?
        
        if deviceMotionAvailable {
            manager.deviceMotionUpdateInterval = interval
            manager.startDeviceMotionUpdatesToQueue(NSOperationQueue()){
                (data: CMDeviceMotion?, error: NSError?) in
                
                //                if let isError = error{
                //                    NSLog("Error: %@", isError)
                //                }
                if data != nil {
                    valX = data!.rotationRate.x
                    valY = data!.rotationRate.y
                    valZ = data!.rotationRate.z
                }
                
                values(x: valX, y: valY, z: valZ, error: error)
                
                //                var absoluteVal = sqrt(valX * valX + valY * valY + valZ * valZ)
                //                self.delegate?.getRotationRateFromDeviceMotion!(valX, y: valY, z: valZ)
            }
            
            return true
        }
        
        return false
    }
    
    
    /*
    *   getMagneticFieldFromDeviceMotion:interval:values:
    *   You can retrieve the processed magnetic field data from the device motion from this
    *   method.
    */
    func getMagneticFieldFromDeviceMotion (interval: NSTimeInterval = 0.1, values: ((x:Double?, y:Double?, z:Double?, accuracy: Int32?, error: NSError?) -> Void)) -> Bool {
        var valX: Double?
        var valY: Double?
        var valZ: Double?
        
        var valAccuracy: Int32?
        
        if deviceMotionAvailable {
            manager.deviceMotionUpdateInterval = interval
            manager.startDeviceMotionUpdatesToQueue(NSOperationQueue()){
                (data: CMDeviceMotion?, error: NSError?) in
                
                //                if let isError = error{
                //                    NSLog("Error: %@", isError)
                //                }
                
                if (data != nil) {
                    valX = data!.magneticField.field.x
                    valY = data!.magneticField.field.y
                    valZ = data!.magneticField.field.z
                    valAccuracy = data!.magneticField.accuracy.rawValue
                }
                
                values(x: valX, y: valY, z: valZ, accuracy: valAccuracy, error: error)
                
                //                self.delegate?.getMagneticFieldFromDeviceMotion!(valX, y: valY, z: valZ)
            }
            
            return true
        }
        
        return false
    }
    
    /*
    *  stopAccelerometerUpdates
    *
    *  Discussion:
    *   Stop accelerometer updates.
    */
    func stopAccelerometerUpdates(){
        self.manager.stopAccelerometerUpdates()
    }
    
    /*
    *  stopGyroUpdates
    *
    *  Discussion:
    *   Stops gyro updates.
    */
    func stopGyroUpdates(){
        self.manager.stopGyroUpdates()
    }
    
    /*
    *  stopDeviceMotionUpdates
    *
    *  Discussion:
    *   Stops device motion updates.
    */
    func stopDeviceMotionUpdates() {
        self.manager.stopDeviceMotionUpdates()
    }
    
    func stopAltimeterUpdates() {
        if (self.altimeter != nil) {
            self.altimeter!.stopRelativeAltitudeUpdates()
        }
    }
    
    /*
    *  stopMagnetometerUpdates
    *
    *  Discussion:
    *   Stops magnetometer updates.
    */
    @available(iOS, introduced=5.0)
    func stopMagnetometerUpdates() {
        self.manager.stopMagnetometerUpdates()
    }
    
}