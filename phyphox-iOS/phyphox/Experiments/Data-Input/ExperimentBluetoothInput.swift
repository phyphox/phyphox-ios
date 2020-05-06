//
//  BluetoothInput.swift
//  phyphox
//
//  Created by Dominik Dorsel on 27.02.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation
import CoreBluetooth

class ExperimentBluetoothInput: BluetoothDeviceDelegate {
    
    let device: ExperimentBluetoothDevice
    
    let rate: Double
    let mode: BluetoothMode
    let subscribeOnStart: Bool
    
    private var startTimestamp: TimeInterval?
    var configList: [BluetoothConfigDescriptor] = []
    
    var running: Bool = false
    
    struct BluetoothOutput: Equatable {
        let char: CBUUID
        let conversion: InputConversion?
        let buffer: DataBuffer
        let extra: BluetoothOutputExtra
        
        static func ==(lhs: BluetoothOutput, rhs: BluetoothOutput) -> Bool {
            return lhs.char == rhs.char &&
                lhs.buffer == rhs.buffer &&
                lhs.extra == rhs.extra
        }
    }

    private var outputList: [BluetoothOutput] = []

    private var queue: DispatchQueue?
    
    var timer = Timer()
    
    init(device: ExperimentBluetoothDevice, mode: BluetoothMode, outputList: [BluetoothOutput], configList: [BluetoothConfigDescriptor], subscribeOnStart: Bool, rate: Double?) {
                
        self.outputList = outputList
        self.configList = configList
        
        self.mode = mode
        self.rate = rate ?? 0.0
        self.subscribeOnStart = subscribeOnStart
        
        self.device = device
        self.device.attachDelegate(self)
    }
    
    func start(queue: DispatchQueue){
        self.queue = queue
        running = true
        startTimestamp = nil
        switch mode {
        case .poll:
            timer = Timer.scheduledTimer(timeInterval: (1.0/rate), target: self, selector: #selector(pollData), userInfo: nil, repeats: true)
        case .notification:
            if subscribeOnStart {
                do {
                    for char in Set(outputList.map({$0.char})) {
                        try device.subscribeToCharacteristic(uuid: char)
                    }
                } catch BluetoothDeviceError.generic(let msg) {
                    device.disconnect()
                    device.showError(msg: msg)
                    return
                } catch {
                    device.showError(msg: "Unknown error.")
                    return
                }
            }
        default:
            print("default")
        }
        
    }
    
    @objc func pollData() {
        do {
            for char in Set(outputList.map({$0.char})) {
                try device.readCharacteristic(uuid: char)
            }
        } catch BluetoothDeviceError.generic(let msg) {
            device.disconnect()
            device.showError(msg: msg)
            return
        } catch {
            device.showError(msg: "Unknown error.")
            return
        }
    }
 
    func stop(){
        running = false
        switch mode {
        case .notification:
            if subscribeOnStart {
                do {
                    for char in Set(outputList.map({$0.char})) {
                        try device.unsubscribeFromCharacteristic(uuid: char)
                    }
                } catch BluetoothDeviceError.generic(let msg) {
                    device.disconnect()
                    device.showError(msg: msg)
                    return
                } catch {
                    device.showError(msg: "Unknown error.")
                    return
                }
            }
        case .poll:
            timer.invalidate()
        default:
            print("default stop message")
        }
    }
    
    func deviceReady() throws {
        if !subscribeOnStart {
            for char in Set(outputList.map({$0.char})) {
                try device.subscribeToCharacteristic(uuid: char)
            }
        }
    }
    
    func writeConfigData() throws {
        for config in configList{
            try device.writeCharacteristic(uuid: config.char, data: config.data)
        }
    }
    
    func dataFromCharacteristic(uuid: CBUUID, data: Data) {
        if !running {
            return
        }
        
        let t = CFAbsoluteTimeGetCurrent()
        for item in outputList{
            if item.char.uuid128String == uuid.uuid128String {
                
                if item.extra == .time {
                    if startTimestamp == nil {
                        startTimestamp = t - (item.buffer.last ?? 0.0)
                    }
                    
                    let relativeT = t-startTimestamp!
                    
                    self.dataIn(relativeT, t: t, dataBufferIn: item.buffer)
                } else {
                    if let newDataConverted = item.conversion?.convert(data: data), newDataConverted.isFinite {
                        self.dataIn(newDataConverted, t: t, dataBufferIn: item.buffer)
                    }
                }
            }
        }
    }
   
    private func writeToBuffers(_ value: Double?,t: TimeInterval, dataBufferIn: DataBuffer) {
        
        func tryAppend(myValue: Double?, to buffer: DataBuffer?) {
            guard let myValue = myValue, let buffer = buffer else { return }
            
            buffer.append(myValue)
        }
        
        tryAppend(myValue: value, to: dataBufferIn)
    }
   
    private func dataIn(_ value: Double?, t: TimeInterval, dataBufferIn: DataBuffer) {
        
        
        func dataInSync(_ value: Double?, t: TimeInterval?, dataBufferIn: DataBuffer) {
            writeToBuffers(value, t: t!, dataBufferIn: dataBufferIn )
        }
        
        
        queue?.async {
            autoreleasepool(invoking: {
                dataInSync(value, t: t, dataBufferIn: dataBufferIn)
            })
        }
    }
}

extension ExperimentBluetoothInput: Equatable {
    static func ==(lhs: ExperimentBluetoothInput, rhs: ExperimentBluetoothInput) -> Bool {
        return lhs.configList == rhs.configList &&
                lhs.device == rhs.device &&
                lhs.mode == lhs.mode &&
                lhs.outputList == rhs.outputList &&
                lhs.rate == rhs.rate &&
                lhs.subscribeOnStart == rhs.subscribeOnStart
    }
}

extension BluetoothConfigDescriptor: Equatable {
    static func ==(lhs: BluetoothConfigDescriptor, rhs: BluetoothConfigDescriptor) -> Bool {
        return lhs.char == rhs.char &&
               lhs.data == rhs.data
    }
}

extension BluetoothOutputDescriptor: Equatable {
    static func ==(lhs: BluetoothOutputDescriptor, rhs: BluetoothOutputDescriptor) -> Bool {
        return lhs.bufferName == rhs.bufferName &&
               lhs.char == rhs.char &&
               lhs.extra == rhs.extra
    }
}

