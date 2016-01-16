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

public class MotionSession {
    private let manager = CMMotionManager()
    private var altimeter: CMAltimeter?
    
    public func getAltimeterValues(interval: NSTimeInterval = 0.1, values: ((data: CMAltitudeData?, error: NSError?) -> Void)) {
        if CMAltimeter.isRelativeAltitudeAvailable() {
            if altimeter == nil {
                altimeter = CMAltimeter()
            }
            
            altimeter!.startRelativeAltitudeUpdatesToQueue(NSOperationQueue(), withHandler: values)
        }
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
    public func getAccelerometerValues (interval: NSTimeInterval = 0.1, values: ((x: Double?, y: Double?, z: Double?, error: NSError?) -> Void)){
        var valX: Double?
        var valY: Double?
        var valZ: Double?
        
        if manager.accelerometerAvailable {
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
            
        } else {
            NSLog("The Accelerometer is not available")
        }
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
    public func getGyroValues (interval: NSTimeInterval = 0.1, queue: dispatch_queue_t, values: ((x: Double?, y: Double?, z:Double?, error: NSError?) -> Void)) {
        var valX: Double?
        var valY: Double?
        var valZ: Double?
        
        if manager.gyroAvailable{
            manager.gyroUpdateInterval = interval
            manager.startGyroUpdatesToQueue(NSOperationQueue()) {
                (data: CMGyroData?, error: NSError?) in
                
                //                if let isError = error{
                //                    NSLog("Error: %@", isError)
                //                }
                
                if data != nil {
                    valX = data!.rotationRate.x
                    valY = data!.rotationRate.y
                    valZ = data!.rotationRate.z
                }
                
                dispatch_async(queue, { () -> Void in
                    values(x: valX, y: valY, z: valZ, error: error)
                })
                //                let absoluteVal = sqrt(valX * valX + valY * valY + valZ * valZ)
                //                self.delegate?.retrieveGyroscopeValues!(valX, y: valY, z: valZ, absoluteValue: absoluteVal)
            }
            
        } else {
            NSLog("The Gyroscope is not available")
        }
    }
    
    /*
    *  getMagnetometerValues:interval:values:
    *
    *  Discussion:
    *   Starts magnetometer updates, providing data to the given handler through the given queue.
    *   You can access the retrieved values either by a Trailing Closure or through a Delegate.
    */
    @available(iOS, introduced=5.0)
    public func getMagnetometerValues (interval: NSTimeInterval = 0.1, values: ((x: Double?, y:Double?, z:Double?, error: NSError?) -> Void)){
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
            
        } else {
            NSLog("Magnetometer is not available")
        }
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
    public func getDeviceMotionObject (interval: NSTimeInterval = 0.1, values: ((deviceMotion: CMDeviceMotion?, error: NSError?) -> Void)) {
        
        if manager.deviceMotionAvailable{
            manager.deviceMotionUpdateInterval = interval
            manager.startDeviceMotionUpdatesToQueue(NSOperationQueue(), withHandler: values)
        } else {
            NSLog("Device Motion is not available")
        }
    }
    
    
    /*
    *   getAccelerationFromDeviceMotion:interval:values:
    *   You can retrieve the processed user accelaration data from the device motion from this method.
    */
    public func getAccelerationFromDeviceMotion (interval: NSTimeInterval = 0.1, values: ((x:Double?, y:Double?, z:Double?, error: NSError?) -> Void)) {
        var valX: Double?
        var valY: Double?
        var valZ: Double?
        
        if manager.deviceMotionAvailable{
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
            
        } else {
            NSLog("Device Motion is unavailable")
        }
    }
    
    /*
    *   getGravityAccelerationFromDeviceMotion:interval:values:
    *   You can retrieve the processed gravitational accelaration data from the device motion from this
    *   method.
    */
    public func getGravityAccelerationFromDeviceMotion (interval: NSTimeInterval = 0.1, values: ((x:Double?, y:Double?, z:Double?, error: NSError?) -> Void)) {
        var valX: Double?
        var valY: Double?
        var valZ: Double?
        
        if manager.deviceMotionAvailable{
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
            
        } else {
            NSLog("Device Motion is not available")
        }
    }
    
    
    /*
    *   getAttitudeFromDeviceMotion:interval:values:
    *   You can retrieve the processed attitude data from the device motion from this
    *   method.
    */
    public func getAttitudeFromDeviceMotion (interval: NSTimeInterval = 0.1, values: ((attitude: CMAttitude?, error: NSError?) -> Void)) {
        
        if manager.deviceMotionAvailable{
            manager.deviceMotionUpdateInterval = interval
            manager.startDeviceMotionUpdatesToQueue(NSOperationQueue()){
                (data: CMDeviceMotion?, error: NSError?) in
                
                //                if let isError = error{
                //                    NSLog("Error: %@", isError)
                //                }
                values(attitude: data?.attitude, error: error)
                
                //                self.delegate?.getAttitudeFromDeviceMotion!(data?.attitude)
            }
            
        } else {
            NSLog("Device Motion is not available")
        }
    }
    
    /*
    *   getRotationRateFromDeviceMotion:interval:values:
    *   You can retrieve the processed rotation data from the device motion from this
    *   method.
    */
    public func getRotationRateFromDeviceMotion (interval: NSTimeInterval = 0.1, values: ((x:Double?, y:Double?, z:Double?, error: NSError?) -> Void)) {
        var valX: Double?
        var valY: Double?
        var valZ: Double?
        
        if manager.deviceMotionAvailable{
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
            
        } else {
            NSLog("Device Motion is not available")
        }
    }
    
    
    /*
    *   getMagneticFieldFromDeviceMotion:interval:values:
    *   You can retrieve the processed magnetic field data from the device motion from this
    *   method.
    */
    public func getMagneticFieldFromDeviceMotion (interval: NSTimeInterval = 0.1, values: ((x:Double?, y:Double?, z:Double?, accuracy: Int32?, error: NSError?) -> Void)) {
        var valX: Double?
        var valY: Double?
        var valZ: Double?
        
        var valAccuracy: Int32?
        
        if manager.deviceMotionAvailable{
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
            
        } else {
            NSLog("Device Motion is not available")
        }
    }
    
    /*  MARK :- DEVICE MOTION APPROACH ENDS HERE    */
    
    
    /*
    *   From the methods hereafter, the sensor values could be retrieved at
    *   a particular instant, whenever needed, through a trailing closure.
    */
    
    /*  MARK :- INSTANTANIOUS METHODS START HERE  */
    
    //    public func getAccelerationAtCurrentInstant (values: (x:Double, y:Double, z:Double) -> Void){
    //        self.getAccelerationFromDeviceMotion(interval: 0.5) { (x, y, z) -> Void in
    //            values(x: x,y: y,z: z)
    //            self.stopDeviceMotionUpdates()
    //        }
    //    }
    //
    //    public func getGravitationalAccelerationAtCurrentInstant (values: (x:Double, y:Double, z:Double) -> Void){
    //        self.getGravityAccelerationFromDeviceMotion(interval: 0.5) { (x, y, z) -> Void in
    //            values(x: x,y: y,z: z)
    //            self.stopDeviceMotionUpdates()
    //        }
    //    }
    //
    //    public func getAttitudeAtCurrentInstant (values: (attitude: CMAttitude) -> Void){
    //        self.getAttitudeFromDeviceMotion(interval: 0.5) { (attitude) -> Void in
    //            values(attitude: attitude)
    //            self.stopDeviceMotionUpdates()
    //        }
    //
    //    }
    //
    //    public func getMageticFieldAtCurrentInstant (values: (x:Double, y:Double, z:Double) -> Void){
    //        self.getMagneticFieldFromDeviceMotion(interval: 0.5) { (x, y, z, accuracy) -> Void in
    //            values(x: x,y: y,z: z)
    //            self.stopDeviceMotionUpdates()
    //        }
    //    }
    //
    //    public func getGyroValuesAtCurrentInstant (values: (x:Double, y:Double, z:Double) -> Void){
    //        self.getRotationRateFromDeviceMotion(interval: 0.5) { (x, y, z) -> Void in
    //            values(x: x,y: y,z: z)
    //            self.stopDeviceMotionUpdates()
    //        }
    //    }
    
    /*  MARK :- INSTANTANIOUS METHODS END HERE  */
    
    
    
    /*
    *  stopAccelerometerUpdates
    *
    *  Discussion:
    *   Stop accelerometer updates.
    */
    public func stopAccelerometerUpdates(){
        self.manager.stopAccelerometerUpdates()
    }
    
    /*
    *  stopGyroUpdates
    *
    *  Discussion:
    *   Stops gyro updates.
    */
    public func stopGyroUpdates(){
        self.manager.stopGyroUpdates()
    }
    
    /*
    *  stopDeviceMotionUpdates
    *
    *  Discussion:
    *   Stops device motion updates.
    */
    public func stopDeviceMotionUpdates() {
        self.manager.stopDeviceMotionUpdates()
    }
    
    public func stopAltimeterUpdates() {
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
    public func stopMagnetometerUpdates() {
        self.manager.stopMagnetometerUpdates()
    }
    
}