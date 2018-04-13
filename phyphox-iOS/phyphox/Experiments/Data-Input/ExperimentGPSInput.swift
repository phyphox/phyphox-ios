//
//  ExperimentGPSInput.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 31.05.17.
//  Copyright © 2017 RWTH Aachen. All rights reserved.
//

import Foundation
import CoreLocation

final class ExperimentGPSInput : NSObject, CLLocationManagerDelegate {
    var locationManager = CLLocationManager()
    private(set) var latBuffer: DataBuffer?
    private(set) var lonBuffer: DataBuffer?
    private(set) var zBuffer: DataBuffer?
    private(set) var vBuffer: DataBuffer?
    private(set) var dirBuffer: DataBuffer?
    private(set) var accuracyBuffer: DataBuffer?
    private(set) var zAccuracyBuffer: DataBuffer?
    private(set) var tBuffer: DataBuffer?
    
    private(set) var statusBuffer: DataBuffer?
    private(set) var satellitesBuffer: DataBuffer?
    
    private var startTime: TimeInterval = 0.0
    private var startTimestamp: TimeInterval?
    
    private let queue = DispatchQueue(label: "de.rwth-aachen.phyphox.gpsQueue", attributes: [])
    
    init (latBuffer: DataBuffer?, lonBuffer: DataBuffer?, zBuffer: DataBuffer?, vBuffer: DataBuffer?, dirBuffer: DataBuffer?, accuracyBuffer: DataBuffer?, zAccuracyBuffer: DataBuffer?, tBuffer: DataBuffer?, statusBuffer: DataBuffer?, satellitesBuffer: DataBuffer?) {
        self.latBuffer = latBuffer
        self.lonBuffer = lonBuffer
        self.zBuffer = zBuffer
        self.vBuffer = vBuffer
        self.dirBuffer = dirBuffer
        self.accuracyBuffer = accuracyBuffer
        self.zAccuracyBuffer = zAccuracyBuffer
        self.tBuffer = tBuffer
        
        self.statusBuffer = statusBuffer
        self.satellitesBuffer = satellitesBuffer
        
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            if location.timestamp.timeIntervalSinceReferenceDate < startTime {
                continue //Skip old data points, which have been acquired before the start of the measurement
            }
            let lat = location.coordinate.latitude
            let lon = location.coordinate.longitude
            let z = location.altitude
            let v = location.speed
            let dir = location.course
            let accuracy = location.horizontalAccuracy
            let zAccuracy = location.horizontalAccuracy
            let t = location.timestamp.timeIntervalSinceReferenceDate
            let status = location.horizontalAccuracy > 0 ? 1.0 : 0.0
            let satellites = 0.0
            self.dataIn(lat, lon: lon, z:z, v: v, dir: dir, accuracy: accuracy, zAccuracy: zAccuracy, t: t, status: status, satellites: satellites)
        }
    }
    
    func clear() {
        
    }
    
    func start() {
        startTime = Date.timeIntervalSinceReferenceDate //This is only used to filter cached data from the location manager
        
        startTimestamp = nil
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
        } else {
            let status = -1.0
            self.dataIn(nil, lon: nil, z:nil, v: nil, dir: nil, accuracy: nil, zAccuracy: nil, t: nil, status: status, satellites: nil)

        }
    }
    
    func stop() {
        locationManager.stopUpdatingLocation()
    }
    
    private func writeToBuffers(_ lat: Double?, lon: Double?, z: Double?, v: Double?, dir: Double?, accuracy: Double?, zAccuracy: Double?, t: TimeInterval?, status: Double?, satellites: Double?) {

        func tryAppend(value: Double?, to buffer: DataBuffer?) {
            guard let value = value, let buffer = buffer else { return }

            buffer.append(value)
        }

        tryAppend(value: lat, to: latBuffer)
        tryAppend(value: lon, to: lonBuffer)
        tryAppend(value: z, to: zBuffer)
        tryAppend(value: v, to: vBuffer)
        tryAppend(value: dir, to: dirBuffer)
        tryAppend(value: accuracy, to: accuracyBuffer)
        tryAppend(value: zAccuracy, to: zAccuracyBuffer)

        if let t = t, let tBuffer = tBuffer {
            if startTimestamp == nil {
                startTimestamp = t - (self.tBuffer?.last ?? 0.0)
            }
            
            let relativeT = t - self.startTimestamp!
            
            tBuffer.append(relativeT)
        }

        tryAppend(value: status, to: statusBuffer)
        tryAppend(value: satellites, to: satellitesBuffer)
    }
    
    private func dataIn(_ lat: Double?, lon: Double?, z: Double?, v: Double?, dir: Double?, accuracy: Double?, zAccuracy: Double?, t: TimeInterval?, status: Double?, satellites: Double?) {
        
        queue.async {
            autoreleasepool(invoking: {
                self.writeToBuffers(lat, lon: lon, z: z, v: v, dir: dir, accuracy: accuracy, zAccuracy: zAccuracy, t: t, status: status, satellites: satellites)
            })
        }
    }
}
