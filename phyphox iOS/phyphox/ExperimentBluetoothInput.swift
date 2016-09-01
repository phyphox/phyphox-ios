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
    private(set) var rate: NSTimeInterval //in s
    
    var effectiveRate: NSTimeInterval {
        get {
            if self.averaging != nil {
                return 0.0
            }
            else {
                return rate
            }
        }
    }
    
    private(set) var startTimestamp: NSTimeInterval?
    
    private(set) var buffers: [DataBuffer]?
    
    private let queue = dispatch_queue_create("de.rwth-aachen.phyphox.bluetoothInputQueue", DISPATCH_QUEUE_SERIAL)
    
    private class Averaging {
        /**
         The duration of averaging intervals.
         */
        var averagingInterval: NSTimeInterval
        
        /**
         Start of current average mesurement.
         */
        var iterationStartTimestamp: NSTimeInterval?
        
        var v: [Double]?
        
        var numberOfUpdates: UInt = 0
        
        init(averagingInterval: NSTimeInterval) {
            self.averagingInterval = averagingInterval
        }
        
        func requiresFlushing(currentT: NSTimeInterval) -> Bool {
            return iterationStartTimestamp != nil && iterationStartTimestamp! + averagingInterval <= currentT
        }
    }
    
    /**
     Information on averaging. Set to `nil` to disable averaging.
     */
    private var averaging: Averaging?
    
    var recordingAverages: Bool {
        get {
            return self.averaging != nil
        }
    }
    
    init(rate: NSTimeInterval, average: Bool, buffers: [DataBuffer]?) {
        self.rate = rate
        
        self.buffers = buffers
        
        if average {
            self.averaging = Averaging(averagingInterval: rate)
        }
    }
    
    private func resetValuesForAveraging() {
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
    
    private func writeToBuffers(x: Double?, y: Double?, z: Double?, t: NSTimeInterval) {
        //TODO
    }
    
    private func dataIn(x: Double?, y: Double?, z: Double?, t: NSTimeInterval?, error: NSError?) {
        //TODO
        
        func dataInSync(x: Double?, y: Double?, z: Double?, t: NSTimeInterval?, error: NSError?) {
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
        
        dispatch_async(queue) {
            autoreleasepool({
                dataInSync(x, y: y, z: z, t: t, error: error)
            })
        }
    }
}
