//
//  ExperimentBluetoothInput.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 01.09.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//


// This is a first step for the implementation of Bluetooth...

import Foundation

final class ExperimentBluetoothInput {
    /**
     The update frequency of the sensor.
     */
    fileprivate(set) var rate: TimeInterval //in s
    
    var effectiveRate: TimeInterval {
        get {
            if self.averaging != nil {
                return 0.0
            }
            else {
                return rate
            }
        }
    }
    
    fileprivate(set) var startTimestamp: TimeInterval?
    
    fileprivate(set) var buffers: [DataBuffer]?
    
    fileprivate let queue = DispatchQueue(label: "de.rwth-aachen.phyphox.bluetoothInputQueue", attributes: [])
    
    fileprivate class Averaging {
        /**
         The duration of averaging intervals.
         */
        var averagingInterval: TimeInterval
        
        /**
         Start of current average mesurement.
         */
        var iterationStartTimestamp: TimeInterval?
        
        var v: [Double]?
        
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
    fileprivate var averaging: Averaging?
    
    var recordingAverages: Bool {
        get {
            return self.averaging != nil
        }
    }
    
    init(rate: TimeInterval, average: Bool, buffers: [DataBuffer]?) {
        self.rate = rate
        
        self.buffers = buffers
        
        if average {
            self.averaging = Averaging(averagingInterval: rate)
        }
    }
    
    fileprivate func resetValuesForAveraging() {
        guard let averaging = self.averaging else {
            return
        }
        
        averaging.iterationStartTimestamp = nil
        
        averaging.v = []
        
        averaging.numberOfUpdates = 0
    }
    
    func start() {
        resetValuesForAveraging()
        
        //TODO
    }
    
    func stop() {
        //TODO
    }
    
    func clear() {
        self.startTimestamp = nil
    }
    
    fileprivate func writeToBuffers(_ x: Double?, y: Double?, z: Double?, t: TimeInterval) {
        //TODO
    }
    
    fileprivate func dataIn(_ x: Double?, y: Double?, z: Double?, t: TimeInterval?, error: NSError?) {
        //TODO
        
        func dataInSync(_ x: Double?, y: Double?, z: Double?, t: TimeInterval?, error: NSError?) {
            guard error == nil else {
                print("Sensor error: \(error!.localizedDescription)")
                return
            }
            
            if let av = self.averaging {
                if av.iterationStartTimestamp == nil {
                    av.iterationStartTimestamp = t
                }
                
                //TODO
                
                av.numberOfUpdates += 1
            }
            else {
                writeToBuffers(x, y: y, z: z, t: t!)
            }
            
            if let av = self.averaging {
                if av.requiresFlushing(t!) {
                    let u = Double(av.numberOfUpdates)
  
                    //TODO
//                    writeToBuffers((av.x != nil ? av.x!/u : nil), y: (av.y != nil ? av.y!/u : nil), z: (av.z != nil ? av.z!/u : nil), t: t!)
                    
                    self.resetValuesForAveraging()
                    av.iterationStartTimestamp = t
                }
            }
        }
        
        queue.async {
            autoreleasepool(invoking: {
                dataInSync(x, y: y, z: z, t: t, error: error)
            })
        }
    }
}
