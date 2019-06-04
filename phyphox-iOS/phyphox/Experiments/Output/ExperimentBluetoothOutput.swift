//
//  ExperimentBluetoothOutput.swift
//  phyphox
//
//  Created by Sebastian Staacks on 24.05.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation
import CoreBluetooth

class ExperimentBluetoothOutput: BluetoothDeviceDelegate {
    
    let device: ExperimentBluetoothDevice
    
    var configList: [BluetoothConfigDescriptor] = []
    
    struct BluetoothInput: Equatable {
        let char: CBUUID
        let conversion: OutputConversion?
        let buffer: DataBuffer
        
        static func ==(lhs: BluetoothInput, rhs: BluetoothInput) -> Bool {
            return lhs.char == rhs.char &&
                lhs.buffer == rhs.buffer
        }
    }
    
    private var inputList: [BluetoothInput] = []
    
    init(device: ExperimentBluetoothDevice, inputList: [BluetoothInput], configList: [BluetoothConfigDescriptor]) {
        
        self.inputList = inputList
        self.configList = configList
        
        self.device = device
        self.device.attachDelegate(self)
    }
    
    func deviceReady() {
    }
    
    func writeConfigData() {
        do {
            for config in configList{
                try device.writeCharacteristic(uuid: config.char, data: config.data)
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
    
    func dataFromCharacteristic(uuid: CBUUID, data: Data) {
        //Bluetooth Outputs do not read data
    }
    
    func send() {
        do {
            for input in inputList {
                if let dataConverted = input.conversion?.convert(data: input.buffer) {
                    if dataConverted.count > 0 {
                        try device.writeCharacteristic(uuid: input.char, data: dataConverted)
                    }
                }
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

extension ExperimentBluetoothOutput: Equatable {
    static func ==(lhs: ExperimentBluetoothOutput, rhs: ExperimentBluetoothOutput) -> Bool {
        return lhs.configList == rhs.configList &&
            lhs.device == rhs.device &&
            lhs.inputList == rhs.inputList
    }
}

extension BluetoothInputDescriptor: Equatable {
    static func ==(lhs: BluetoothInputDescriptor, rhs: BluetoothInputDescriptor) -> Bool {
        return lhs.bufferName == rhs.bufferName &&
            lhs.char == rhs.char
    }
}
