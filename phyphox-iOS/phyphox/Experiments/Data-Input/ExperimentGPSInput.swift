//
//  ExperimentGPSInput.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 31.05.17.
//  Copyright © 2017 RWTH Aachen. All rights reserved.
//

import Foundation
import CoreLocation

final class ExperimentGPSInput: NSObject, CLLocationManagerDelegate {
    var locationManager = CLLocationManager()
    private(set) var latBuffer: DataBuffer?
    private(set) var lonBuffer: DataBuffer?
    private(set) var zBuffer: DataBuffer?
    private(set) var zWgs84Buffer: DataBuffer?
    private(set) var vBuffer: DataBuffer?
    private(set) var dirBuffer: DataBuffer?
    private(set) var accuracyBuffer: DataBuffer?
    private(set) var zAccuracyBuffer: DataBuffer?
    private(set) var tBuffer: DataBuffer?
    
    private(set) var statusBuffer: DataBuffer?
    private(set) var satellitesBuffer: DataBuffer?
    
    private let timeReference: ExperimentTimeReference
    
    private var queue: DispatchQueue?
    
    init (latBuffer: DataBuffer?, lonBuffer: DataBuffer?, zBuffer: DataBuffer?, zWgs84Buffer: DataBuffer?, vBuffer: DataBuffer?, dirBuffer: DataBuffer?, accuracyBuffer: DataBuffer?, zAccuracyBuffer: DataBuffer?, tBuffer: DataBuffer?, statusBuffer: DataBuffer?, satellitesBuffer: DataBuffer?, timeReference: ExperimentTimeReference) {
        
        self.latBuffer = latBuffer
        self.lonBuffer = lonBuffer
        self.zBuffer = zBuffer
        self.zWgs84Buffer = zWgs84Buffer
        self.vBuffer = vBuffer
        self.dirBuffer = dirBuffer
        self.accuracyBuffer = accuracyBuffer
        self.zAccuracyBuffer = zAccuracyBuffer
        self.tBuffer = tBuffer
        
        self.statusBuffer = statusBuffer
        self.satellitesBuffer = satellitesBuffer
        
        self.timeReference = timeReference
        
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            guard let lastTimeReference = timeReference.timeMappings.last else {
                continue
            }
            if location.timestamp < lastTimeReference.systemTime {
                continue //Skip old data points, which have been acquired before the start of the measurement
            }
            let lat = location.coordinate.latitude
            let lon = location.coordinate.longitude
            let z = location.altitude
            let zWgs84 = z + GpsGeoid.shared.height(latitude: lat, longitude: lon)
            let v = location.speed
            let dir = location.course
            let accuracy = location.horizontalAccuracy
            let zAccuracy = location.horizontalAccuracy
            let t = location.timestamp
            let status = location.horizontalAccuracy > 0 ? 1.0 : 0.0
            let satellites = -1.0
            self.dataIn(lat, lon: lon, z: z, zWgs84: zWgs84, v: v, dir: dir, accuracy: accuracy, zAccuracy: zAccuracy, t: t, status: status, satellites: satellites)
        }
    }
    
    func clear() {
        
    }
    
    func start(queue: DispatchQueue) {
        self.queue = queue
                        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
        } else {
            let status = -1.0
            self.dataIn(nil, lon: nil, z:nil, zWgs84: nil, v: nil, dir: nil, accuracy: nil, zAccuracy: nil, t: nil, status: status, satellites: nil)
        }
    }
    
    func stop() {
        locationManager.stopUpdatingLocation()
    }
    
    private func writeToBuffers(_ lat: Double?, lon: Double?, z: Double?, zWgs84: Double?, v: Double?, dir: Double?, accuracy: Double?, zAccuracy: Double?, t: Date?, status: Double?, satellites: Double?) {

        func tryAppend(value: Double?, to buffer: DataBuffer?) {
            guard let value = value, let buffer = buffer else { return }

            buffer.append(value)
        }

        tryAppend(value: lat, to: latBuffer)
        tryAppend(value: lon, to: lonBuffer)
        tryAppend(value: z, to: zBuffer)
        tryAppend(value: zWgs84, to: zWgs84Buffer)
        tryAppend(value: v, to: vBuffer)
        tryAppend(value: dir, to: dirBuffer)
        tryAppend(value: accuracy, to: accuracyBuffer)
        tryAppend(value: zAccuracy, to: zAccuracyBuffer)

        if let t = t, let tBuffer = tBuffer {
            let relativeT = timeReference.getExperimentTimeFromSystem(systemTime: t)
            tBuffer.append(relativeT)
        }

        tryAppend(value: status, to: statusBuffer)
        tryAppend(value: satellites, to: satellitesBuffer)
    }
    
    private func dataIn(_ lat: Double?, lon: Double?, z: Double?, zWgs84: Double?, v: Double?, dir: Double?, accuracy: Double?, zAccuracy: Double?, t: Date?, status: Double?, satellites: Double?) {
        
        queue?.async {
            autoreleasepool(invoking: {
                self.writeToBuffers(lat, lon: lon, z: z, zWgs84: zWgs84, v: v, dir: dir, accuracy: accuracy, zAccuracy: zAccuracy, t: t, status: status, satellites: satellites)
            })
        }
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let rhs = object as? ExperimentGPSInput else { return false }

        let lhs = self

        return lhs.latBuffer == rhs.latBuffer &&
            lhs.lonBuffer == rhs.lonBuffer &&
            lhs.zBuffer == rhs.zBuffer &&
            lhs.vBuffer == rhs.vBuffer &&
            lhs.dirBuffer == rhs.dirBuffer &&
            lhs.accuracyBuffer == rhs.accuracyBuffer &&
            lhs.zAccuracyBuffer == rhs.zAccuracyBuffer &&
            lhs.tBuffer == rhs.tBuffer &&
            lhs.statusBuffer == rhs.statusBuffer &&
            lhs.satellitesBuffer == rhs.satellitesBuffer
    }
}
