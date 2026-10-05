//
//  BluetoothCommand.swift
//  phyphox
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import Foundation

//A command a device sends on the phyphox command characteristic (cddf0005): byte 0 of a notification, further bytes are
//reserved and ignored. The upper nibble groups the commands (0x0 measurement state, 0x1 clearing, 0xF queries) so each
//group can grow; a code the app does not know is ignored. Specified in phyphox-docs, bluetooth-low-energy.md, "Phyphox
//command characteristic (0005)".
enum BluetoothCommand: UInt8 {
    case pause = 0x00
    case start = 0x01
    case toggle = 0x02
    case clear = 0x10
    case clearAll = 0x11
    case status = 0xf0

    //The command in a notification, or nil for an empty notification or an unknown code
    static func decode(_ data: Data) -> BluetoothCommand? {
        guard let code = data.first else {
            return nil
        }
        return BluetoothCommand(rawValue: code)
    }
}

//Implemented by the experiment screen: carries out a command from a device as if the user had used the corresponding
//control of the app. Called on the main queue, where CoreBluetooth delivers the device's callbacks.
protocol BluetoothCommandDelegate: AnyObject {
    func onBluetoothCommand(_ command: BluetoothCommand, device: ExperimentBluetoothDevice)
}
