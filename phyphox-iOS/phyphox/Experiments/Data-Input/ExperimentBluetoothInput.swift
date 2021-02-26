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
    
    let timeReference: ExperimentTimeReference
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
    
    init(device: ExperimentBluetoothDevice, mode: BluetoothMode, outputList: [BluetoothOutput], configList: [BluetoothConfigDescriptor], subscribeOnStart: Bool, rate: Double?, timeReference: ExperimentTimeReference) {
                
        self.outputList = outputList
        self.configList = configList
        
        self.mode = mode
        self.rate = rate ?? 0.0
        self.subscribeOnStart = subscribeOnStart
        
        self.timeReference = timeReference
        
        self.device = device
        self.device.attachDelegate(self)
    }
    
    func start(queue: DispatchQueue){
        self.queue = queue
        running = true

        switch mode {
        case .poll:
            timer = Timer.scheduledTimer(timeInterval: (1.0/rate), target: self, selector: #selector(pollData), userInfo: nil, repeats: true)
        case .notification, .indication:
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
        case .notification, .indication:
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
        
        for item in outputList{
            if item.char.uuid128String == uuid.uuid128String {
                
                if item.extra == .time {
                    self.dataIn([timeReference.getExperimentTime()], dataBufferIn: item.buffer)
                } else {
                    if let newDataConverted = item.conversion?.convert(data: data) {
                        self.dataIn(newDataConverted, dataBufferIn: item.buffer)
                    }
                }
            }
        }
    }
   
    private func writeToBuffers(_ values: [Double],dataBufferIn: DataBuffer) {
        
        func tryAppend(myValues: [Double], to buffer: DataBuffer?) {
            guard let buffer = buffer else { return }
            
            buffer.appendFromArray(myValues)
        }
        
        tryAppend(myValues: values, to: dataBufferIn)
    }
   
    private func dataIn(_ values: [Double], dataBufferIn: DataBuffer) {
        
        
        func dataInSync(_ values: [Double], dataBufferIn: DataBuffer) {
            writeToBuffers(values, dataBufferIn: dataBufferIn )
        }
        
        
        queue?.async {
            autoreleasepool(invoking: {
                dataInSync(values, dataBufferIn: dataBufferIn)
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

