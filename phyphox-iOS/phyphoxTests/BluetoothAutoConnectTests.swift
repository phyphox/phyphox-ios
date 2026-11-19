//
//  BluetoothAutoConnectTests.swift
//  phyphoxTests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
@testable import phyphox

// phyphox-test: ble-shipped-sensors
//-phyphoxBleAutoConnect (AutomationLaunchOptions) lets the ble-sensors lab suite connect without the pick list:
//every <bluetooth> block, input and output, auto-connects to the first device passing its filters, any unit will do.
final class BluetoothAutoConnectTests: XCTestCase {

    private static let experiment = """
        <phyphox version="1.21">
            <title>Bluetooth auto connect</title>
            <category>Test</category>
            <data-containers>
                <container size="0">value</container>
                <container size="1">setting</container>
                <container size="0">other</container>
            </data-containers>
            <input>
                <bluetooth id="in" name="phyphox:m" mode="notification">
                    <output char="cddf1002-30f7-4671-8b43-5e40ba53514a" conversion="float32LittleEndian">value</output>
                </bluetooth>
                <bluetooth id="declared" name="phyphox" autoConnect="true" mode="notification">
                    <output char="cddf1002-30f7-4671-8b43-5e40ba53514a" conversion="float32LittleEndian">other</output>
                </bluetooth>
            </input>
            <output>
                <bluetooth id="out" name="phyphox">
                    <input char="cddf1003-30f7-4671-8b43-5e40ba53514a" conversion="float32LittleEndian">setting</input>
                </bluetooth>
            </output>
            <views>
                <view label="Data">
                    <value label="Value"><input>value</input></value>
                </view>
            </views>
        </phyphox>
        """

    private var previous = false

    override func setUp() {
        super.setUp()
        previous = AutomationLaunchOptions.bleAutoConnect
    }

    override func tearDown() {
        AutomationLaunchOptions.bleAutoConnect = previous
        super.tearDown()
    }

    //Device autoConnect per block id
    private func load() throws -> [String: Bool] {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ble-auto-connect-\(UUID().uuidString).phyphox")
        try Self.experiment.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        let experiment = try ExperimentSerialization.readExperimentFromURL(url)
        XCTAssertEqual(experiment.bluetoothInputs.count, 2)
        XCTAssertEqual(experiment.bluetoothOutputs.count, 1)
        let devices = experiment.bluetoothInputs.map { $0.device } + experiment.bluetoothOutputs.map { $0.device }
        return Dictionary(uniqueKeysWithValues: devices.map { ($0.id ?? "", $0.autoConnect) })
    }

    func testWithoutTheOptionOnlyTheDeclaredBlockAutoConnects() throws {
        AutomationLaunchOptions.bleAutoConnect = false
        XCTAssertEqual(try load(), ["in": false, "declared": true, "out": false])
    }

    func testWithTheOptionEveryBlockAutoConnects() throws {
        AutomationLaunchOptions.bleAutoConnect = true
        XCTAssertEqual(try load(), ["in": true, "declared": true, "out": true])
    }
}
