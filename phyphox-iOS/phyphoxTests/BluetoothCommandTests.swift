//
//  BluetoothCommandTests.swift
//  phyphoxTests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
import CoreBluetooth
@testable import phyphox

// phyphox-test: ble-command-dispatch
//The command characteristic contract (phyphox-docs, bluetooth-low-energy.md, "Phyphox command characteristic (0005)"):
//byte 0 selects the command, further bytes are ignored, unknown codes are dropped, and a known one reaches the
//experiment screen as the corresponding command. Mirrors Android's BluetoothCommandTest.
final class BluetoothCommandTests: XCTestCase {

    func testEveryDocumentedCodeDecodesToItsCommand() {
        XCTAssertEqual(BluetoothCommand.decode(Data([0x00])), .pause)
        XCTAssertEqual(BluetoothCommand.decode(Data([0x01])), .start)
        XCTAssertEqual(BluetoothCommand.decode(Data([0x02])), .toggle)
        XCTAssertEqual(BluetoothCommand.decode(Data([0x10])), .clear)
        XCTAssertEqual(BluetoothCommand.decode(Data([0x11])), .clearAll)
        XCTAssertEqual(BluetoothCommand.decode(Data([0xf0])), .status)
    }

    func testReservedBytesAfterTheCommandAreIgnored() {
        XCTAssertEqual(BluetoothCommand.decode(Data([0x01, 0x7f, 0xff, 0x00])), .start)
    }

    func testUnknownAndEmptyNotificationsDecodeToNothing() {
        //unused codes inside the groups, an unknown group, the event characteristic's SYNC code
        for code: UInt8 in [0x03, 0x0f, 0x12, 0x20, 0xf1, 0xff] {
            XCTAssertNil(BluetoothCommand.decode(Data([code])), String(format: "0x%02x", code))
        }
        XCTAssertNil(BluetoothCommand.decode(Data()))
    }

    private final class CapturingDelegate: BluetoothCommandDelegate {
        var received: [BluetoothCommand] = []
        func onBluetoothCommand(_ command: BluetoothCommand, device: ExperimentBluetoothDevice) {
            received.append(command)
        }
    }

    func testANotificationReachesTheDelegateAsACommandAndUnknownOnesDoNot() {
        let delegate = CapturingDelegate()
        let device = ExperimentBluetoothDevice(id: nil, name: "sim", uuid: nil, autoConnect: false)
        device.commandDelegate = delegate
        device.handleCommand(Data([0x01]))
        device.handleCommand(Data([0x03]))
        device.handleCommand(Data())
        device.handleCommand(Data([0x11, 0x55]))
        device.handleCommand(Data([0xf0]))
        XCTAssertEqual(delegate.received, [.start, .clearAll, .status])
    }
}
