//
//  BluetoothScan.swift
//  phyphox
//
//  Created by Dominik Dorsel on 28.02.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation
import CoreBluetooth
import zlib

class BluetoothScan: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    struct ScanResult {
        let peripheral: CBPeripheral
        let rssi: NSNumber
        let experiment: ExperimentForDevice
        let advertisedUUIDs: [CBUUID]?
        let advertisedName: String?
        var oneOfMany: Bool
        var strongestSignal: Bool
        var firstSeen: Date
    }
    
    public var centralManager: CBCentralManager?
    
    public var discoveredDevices: [UUID:ScanResult] = [:]
    var scanResultsDelegate: ScanResultsDelegate?
    
    let filterByName: String?
    let filterByUUID: CBUUID?
    let checkExperiments: Bool
   
    var scanImmediately: Bool
    let autoConnect: Bool
    
    enum ExperimentForDevice {
        case local
        case onDevice
        case localAndOnDevice
        case unavailable
        case unknown
    }
    
    init(scanDirectly: Bool, filterByName: String?, filterByUUID: CBUUID?, checkExperiments: Bool, autoConnect: Bool) {
        self.scanImmediately = scanDirectly
        self.filterByName = filterByName
        self.filterByUUID = filterByUUID
        self.checkExperiments = checkExperiments
        self.autoConnect = autoConnect

        super.init()
        if scanDirectly {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
    
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            return
        }
        
        if peripheralToBeConnected != nil {
            loadExperimentFromPeripheralConnect()
        }
        
        if(scanImmediately){
            scan(central)
        }
    }

    func scan(_ central: CBCentralManager) {
        discoveredDevices = [:]
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : NSNumber(value: true)])
        let services: [CBUUID]
        if let filterByUUID = filterByUUID {
            services = [filterByUUID]
        } else {
            services = ExperimentManager.shared.getSupportedBLEServices()
        }
        for service in services {
            for device in central.retrieveConnectedPeripherals(withServices: [service]) {
                addDevice(peripheral: device, advertisedUUIDs: [service], advertisedName: nil, rssi: -100)
            }
        }
    }
    
    func stopScan() {
        centralManager?.stopScan()
    }
    
    func addDevice(peripheral: CBPeripheral, advertisedUUIDs: [CBUUID]?, advertisedName: String?, rssi: NSNumber) {
        let advertisedName = advertisedName ?? discoveredDevices[peripheral.identifier]?.advertisedName
        let firstSeen = discoveredDevices[peripheral.identifier]?.firstSeen ?? Date()
        var oneOfMany = false
        var strongestSignal = true
        
        if let foundName = advertisedName ?? peripheral.name {
            
            if let filterByUUID = filterByUUID {
                if let advertisedUUIDs = advertisedUUIDs {
                    var correctServiceAdvertised = false
                    for advertisedUUID in advertisedUUIDs {
                        if advertisedUUID.uuid128String == filterByUUID.uuid128String {
                            correctServiceAdvertised = true
                        }
                    }
                    if !correctServiceAdvertised {
                        return
                    }
                } else {
                    return
                }
            }
            
            if let filterByName = filterByName, filterByName != "" {
                if !foundName.contains(filterByName) {
                    return
                }
            }
            
            if autoConnect {
                //Passed along: this returns before discoveredDevices is written, and peripheral.name may be stale
                scanResultsDelegate?.autoConnect(device: peripheral, advertisedUUIDs: advertisedUUIDs,
                                                 advertisedName: advertisedName)
                return
            }
            
            for device in discoveredDevices {
                if device.key != peripheral.identifier {
                    if let otherName = device.value.advertisedName ?? device.value.peripheral.name {
                        if otherName == foundName {
                            discoveredDevices[device.key]?.oneOfMany = true
                            oneOfMany = true
                            if device.value.rssi.decimalValue > rssi.decimalValue {
                                strongestSignal = false
                            } else {
                                discoveredDevices[device.key]?.strongestSignal = false
                            }
                        }
                    }
                }
            }
            
            var experiment: ExperimentForDevice
            if checkExperiments {
                let experimentCollections = ExperimentManager.shared.getExperimentsForBluetoothDevice(deviceName: foundName, deviceUUIDs: advertisedUUIDs)
                experiment = experimentCollections.count > 0 ? .local : .unavailable
                if let advertisedUUIDs = advertisedUUIDs, advertisedUUIDs.map({(uuid) -> String in uuid.uuid128String}).contains(phyphoxServiceUUID.uuidString) {
                    if experiment == .local {
                        experiment = .localAndOnDevice
                    } else {
                        experiment = .onDevice
                    }
                }
            } else {
                experiment = .unknown
            }
            
            
            discoveredDevices[peripheral.identifier] = ScanResult(peripheral: peripheral, rssi: rssi, experiment: experiment, advertisedUUIDs: advertisedUUIDs, advertisedName: advertisedName, oneOfMany: oneOfMany, strongestSignal: strongestSignal, firstSeen: firstSeen)
            scanResultsDelegate?.reloadScanResults(updatedEntry: peripheral.identifier)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        let advertisedUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        addDevice(peripheral: peripheral, advertisedUUIDs: advertisedUUIDs, advertisedName: advertisedName, rssi: RSSI)
        
    }
    
    //-- Load experiment from device --
    
    enum LoadExperimentStages {
        case ready
        case connecting
        case discoveringServices
        case discoveringCharacteristics
        case subscribing
        case transmitting
        case done
        case failed
    }
    
    var loadFromBluetoothDeviceStage: LoadExperimentStages  = .ready {
        didSet {
            if oldValue != loadFromBluetoothDeviceStage {
                print("Load experiment from bluetooth device: \(loadFromBluetoothDeviceStage)")
            }
        }
    }
    var loadHud: JGProgressHUD? = nil
    var peripheralConnecting: CBPeripheral? = nil
    var peripheralToBeConnected: CBPeripheral? = nil
    
    var currentBluetoothData: Data? = nil
    var currentBluetoothDataSize: UInt32? = nil
    var currentBluetoothDataCRC32: UInt32? = nil
    
    //Per packet, not a deadline for the whole transfer (Android: BluetoothExperimentLoader.DATA_TIMEOUT_MS)
    private static let transferInactivityTimeout = 10.0
    private var transferWatchdog = 0
    private var transferStarted: Date? = nil
    private var lastProgressShown: Date? = nil
    private var receivedPackets = 0
    
    //Signs of a second interleaved stream (extra header, short packet before the end), bounded, for the stall report
    private var streamOddities: [String] = []
    
    ///One line per finished connection/transfer for the lab (phyphox-docs `tools/lab/ble.py`, `parse_retry_lines`);
    ///`attempts` counts the successful one too. NSLog, not print: the driver reads the device's syslog.
    static func reportBLERetries(_ fields: String) {
        NSLog("phyphox-ble-retries %@", fields)
    }
    
    ///Whether any attempt reached a connection; otherwise the failure is reported as `connect` only, not twice
    private var transferReachedDevice = false
    
    var viewController: UIViewController? = nil
    var experimentLauncher: ExperimentController? = nil
    
    //A transfer that lost packets is retried whole (no sequence numbers): the Arduino library's ESP32 send loop drops
    //notifications when Bluedroid's buffers are full, more often on iOS with its slower connection interval
    private static let transferAttempts = 3
    private static let transferRetryDelay = 1.0
    private var transferAttempt = 0
    
    public func loadExperimentFromPeripheral(_ peripheral: CBPeripheral, viewController: UIViewController, experimentLauncher: ExperimentController?) {
        self.viewController = viewController
        self.experimentLauncher = experimentLauncher
        transferAttempt = 0
        transferReachedDevice = false
        
        startTransfer(from: peripheral)
    }
    
    private func startTransfer(from peripheral: CBPeripheral) {
        //Kept across attempts, so a retry does not flicker the dialog away and back
        if loadHud == nil {
            loadHud = JGProgressHUD()
            loadHud?.indicatorView = JGProgressHUDPieIndicatorView()
            loadHud?.interactionType = .blockTouchesOnHUDView
            loadHud?.textLabel.text = localize("loadingTitle")
            loadHud?.detailTextLabel.text = localize("loadingText")
            if let view = viewController?.view {
                loadHud?.show(in: view)
            }
        }
        loadHud?.setProgress(0.0, animated: false)
        
        loadFromBluetoothDeviceStage = .connecting
        resetTransferState()
        connectAttempt = 0
        
        attemptConnect(peripheral: peripheral)
    }
    
    //Retried before it becomes an error, as on Android (BluetoothExperimentLoader.connect, Bluetooth.CONNECT_ATTEMPTS);
    //the pause lets a device finish releasing a previous connection
    private static let connectAttempts = 3
    private static let connectRetryDelay = 0.5
    private static let connectTimeout = 10.0
    private var connectAttempt = 0
    
    private func attemptConnect(peripheral: CBPeripheral) {
        connectAttempt += 1
        let attempt = connectAttempt
        
        self.peripheralToBeConnected = peripheral
        
        if centralManager?.state == .poweredOn {
            loadExperimentFromPeripheralConnect()
        }
        
        after(BluetoothScan.connectTimeout) {
            guard attempt == self.connectAttempt,
                  self.loadFromBluetoothDeviceStage == .connecting else { return }
            self.retryOrFailConnect(peripheral: peripheral, marker: " (1)", reason: "timeout")
        }
    }
    
    private func retryOrFailConnect(peripheral: CBPeripheral, marker: String, reason: String) {
        guard loadFromBluetoothDeviceStage == .connecting else { return }
        //A pending connection request would otherwise come up later, behind the retry
        centralManager?.cancelPeripheralConnection(peripheral)
        peripheralToBeConnected = nil
        peripheralConnecting = nil
        guard connectAttempt < BluetoothScan.connectAttempts else {
            BluetoothScan.reportBLERetries("event=connect attempts=\(connectAttempt) "
                                           + "result=failed reason=\(reason)")
            loadExperimentFromPeripheralError(peripheral: peripheral, characteristic: nil, message: localize("bt_exception_connection") + marker, reason: reason)
            return
        }
        print("Bluetooth experiment transfer: connect attempt \(connectAttempt) of \(BluetoothScan.connectAttempts) failed, retrying")
        after(BluetoothScan.connectRetryDelay) {
            guard self.loadFromBluetoothDeviceStage == .connecting else { return }
            self.attemptConnect(peripheral: peripheral)
        }
    }
    
    //Everything a transfer accumulates, cleared together (a stale size makes the next header look like payload)
    private func resetTransferState() {
        currentBluetoothData = nil
        currentBluetoothDataSize = nil
        currentBluetoothDataCRC32 = nil
        transferStarted = nil
        lastProgressShown = nil
        receivedPackets = 0
        streamOddities = []
        transferWatchdog += 1
    }
    
    ///Fails the transfer if nothing arrives within the inactivity timeout; re-armed by every packet, reports how far it got
    private func armTransferWatchdog(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        transferWatchdog += 1
        let generation = transferWatchdog
        after(BluetoothScan.transferInactivityTimeout) {
            guard generation == self.transferWatchdog,
                  self.loadFromBluetoothDeviceStage != .done,
                  self.loadFromBluetoothDeviceStage != .failed else { return }
            let received = self.currentBluetoothData?.count ?? 0
            if let announced = self.currentBluetoothDataSize {
                print("Bluetooth experiment transfer stalled after \(received) of \(announced) "
                      + "bytes in \(self.receivedPackets) packet(s); "
                      + (self.streamOddities.isEmpty ? "every payload packet was a full 20 bytes"
                                                     : "not one plain stream: " + self.streamOddities.joined(separator: ", ")))
            } else {
                print("Bluetooth experiment transfer: nothing arrived at all")
            }
            self.loadExperimentFromPeripheralError(peripheral: peripheral, characteristic: characteristic, message: localize("bt_fail_reading") + " (timeout)", reason: "timeout", retryable: true)
        }
    }
    
    func setControlCharacteristicIfPresent(value: UInt8, peripheral: CBPeripheral) {
        //If the characteristic phyphoxExperimentControlCharacteristicUUID is present, the peripheral expects us to write a 1 to start the experiment transfer and a 0 when we are done. Otherwise, the peripheral just looks for subscriptions to the phyphoxExperimentCharacteristicUUID characteristic
        guard let service = peripheral.services?.first(where: {$0.uuid.uuid128String == phyphoxServiceUUID.uuidString}) else {
            return
        }
        guard let controlCharacteristic = service.characteristics?.first(where: {$0.uuid.uuid128String == phyphoxExperimentControlCharacteristicUUID.uuidString}) else {
            return
        }
        peripheral.writeValue(Data([value]), for: controlCharacteristic, type: controlCharacteristic.properties.contains(.writeWithoutResponse) ? CBCharacteristicWriteType.withoutResponse : CBCharacteristicWriteType.withResponse)
    }
    
    func loadExperimentFromPeripheralConnect() {
        if let peripheralToBeConnected = peripheralToBeConnected {
            self.peripheralConnecting = peripheralToBeConnected
            self.peripheralConnecting!.delegate = self
            centralManager?.connect(self.peripheralConnecting!, options: nil)
            self.peripheralToBeConnected = nil
        }
    }
    
    ///`retryable`: a transfer that went wrong on the way (lost packets, bad checksum), not a device lacking what we need
    func loadExperimentFromPeripheralError(peripheral: CBPeripheral, characteristic: CBCharacteristic?, message: String, reason: String, retryable: Bool = false) {
        if let char = characteristic, char.properties.contains(.notify) {
            peripheral.setNotifyValue(false, for: char)
        }
        setControlCharacteristicIfPresent(value: 0x00, peripheral: peripheral)
        centralManager?.cancelPeripheralConnection(peripheral)
        loadFromBluetoothDeviceStage = .failed
        resetTransferState()
        
        if retryable && transferAttempt + 1 < BluetoothScan.transferAttempts {
            transferAttempt += 1
            print("Bluetooth experiment transfer: \(message) - attempt "
                  + "\(transferAttempt + 1) of \(BluetoothScan.transferAttempts)")
            //From a fresh connection: the pause lets the device finish releasing the one just dropped
            after(BluetoothScan.transferRetryDelay) {
                self.startTransfer(from: peripheral)
            }
            return
        }
        
        //Reported even after the last failed attempt; a device never reached is already reported as the connection
        if transferReachedDevice {
            BluetoothScan.reportBLERetries("event=transfer attempts=\(transferAttempt + 1) "
                                           + "result=failed reason=\(reason)")
        }
        
        loadHud?.dismiss()
        loadHud = nil
        
        let alert = UIAlertController(title: localize("newExperimentBTReadErrorTitle"), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: localize("cancel"), style: .default, handler: { _ in
            
        }))
        alert.addAction(UIAlertAction(title: localize("tryagain"), style: .default, handler: { _ in
            self.loadExperimentFromPeripheral(peripheral, viewController: self.viewController!, experimentLauncher: self.experimentLauncher)
        }))
        viewController?.present(alert, animated: true, completion: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Bluetooth experiment transfer: connection refused: \(error?.localizedDescription ?? "no reason given")")
        //The CBError code is the nearest equivalent of the GATT status Android reports
        retryOrFailConnect(peripheral: peripheral, marker: " (2)",
                           reason: "refused" + ((error as NSError?).map { "_\($0.code)" } ?? ""))
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        BluetoothScan.reportBLERetries("event=connect attempts=\(connectAttempt) result=ok")
        transferReachedDevice = true
        loadFromBluetoothDeviceStage = .discoveringServices
        peripheral.discoverServices([CBUUID(nsuuid: phyphoxServiceUUID)])
        after(5) {
            if self.loadFromBluetoothDeviceStage == .discoveringServices {
                self.loadExperimentFromPeripheralError(peripheral: peripheral, characteristic: nil, message: localize("bt_exception_services"), reason: "discovery")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: {$0.uuid.uuid128String == phyphoxServiceUUID.uuidString}) else {
            self.loadExperimentFromPeripheralError(peripheral: peripheral, characteristic: nil, message: localize("bt_exception_uuid") + " " + phyphoxServiceUUID.uuidString + " " + localize("bt_exception_uuid2") + " (no phyphox service)", reason: "no_service")
            return
        }
        loadFromBluetoothDeviceStage = .discoveringCharacteristics
        peripheral.discoverCharacteristics([CBUUID(nsuuid: phyphoxExperimentCharacteristicUUID),CBUUID(nsuuid: phyphoxExperimentControlCharacteristicUUID)], for: service)
        after(5) {
            if self.loadFromBluetoothDeviceStage == .discoveringCharacteristics {
                self.loadExperimentFromPeripheralError(peripheral: peripheral, characteristic: nil, message: localize("bt_exception_uuid") + " " + phyphoxServiceUUID.uuidString + " " + localize("bt_exception_uuid2") + " (characteristic discovery timed out)", reason: "discovery")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        guard let characteristic = service.characteristics?.first(where: {$0.uuid.uuid128String == phyphoxExperimentCharacteristicUUID.uuidString}) else {
            self.loadExperimentFromPeripheralError(peripheral: peripheral, characteristic: nil, message: localize("bt_exception_uuid") + " " + phyphoxServiceUUID.uuidString + " " + localize("bt_exception_uuid2") + " (no phyphox experiment characteristic)", reason: "no_characteristic")
            return
        }
        if characteristic.properties.contains(.notify) {
            loadFromBluetoothDeviceStage = .subscribing
            peripheral.setNotifyValue(true, for: characteristic)
        }
        setControlCharacteristicIfPresent(value: 0x01, peripheral: peripheral)
        if !characteristic.properties.contains(.notify) {
            print("Polling experiment data.")
            loadFromBluetoothDeviceStage = .transmitting
            peripheral.readValue(for: characteristic)
        }
        armTransferWatchdog(peripheral: peripheral, characteristic: characteristic)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if loadFromBluetoothDeviceStage == .done || loadFromBluetoothDeviceStage == .failed {
            return
        }
        loadFromBluetoothDeviceStage = .transmitting
        armTransferWatchdog(peripheral: peripheral, characteristic: characteristic)
        if let newData = characteristic.value {
            receivedPackets += 1
            if let currentBluetoothDataSize = currentBluetoothDataSize, let currentBluetoothDataCRC32 = currentBluetoothDataCRC32 {
                guard currentBluetoothData != nil else {
                    self.loadExperimentFromPeripheralError(peripheral: peripheral, characteristic: characteristic, message: localize("newExperimentBTReadErrorCorrupted") + " (unexpected nil)", reason: "internal", retryable: true)
                    return
                }
                if streamOddities.count < 12 {
                    let atByte = currentBluetoothData!.count
                    if newData.count == 20 && newData.starts(with: "phyphox".data(using: .utf8)!) {
                        streamOddities.append("a second header at byte \(atByte)")
                    } else if newData.count != 20 {
                        streamOddities.append("a \(newData.count)-byte packet at byte \(atByte)")
                    }
                }
                currentBluetoothData!.append(newData)

                if currentBluetoothData!.count >= currentBluetoothDataSize {
                    loadFromBluetoothDeviceStage = .done
                    let seconds = -(transferStarted?.timeIntervalSinceNow ?? 0)
                    BluetoothScan.reportBLERetries("event=transfer attempts=\(transferAttempt + 1) "
                                                   + "result=ok bytes=\(currentBluetoothDataSize) "
                                                   + "ms=\(Int(seconds * 1000))")
                    print(String(format: "Bluetooth experiment transfer: %d bytes in %d packets, %.1f s (%.0f packets/s)",
                                 Int(currentBluetoothDataSize), receivedPackets, seconds,
                                 seconds > 0 ? Double(receivedPackets)/seconds : 0)
                          + (streamOddities.isEmpty ? "" : "; not one plain stream: " + streamOddities.joined(separator: ", ")))
                    if characteristic.properties.contains(.notify) {
                        peripheral.setNotifyValue(false, for: characteristic)
                    }
                    setControlCharacteristicIfPresent(value: 0x00, peripheral: peripheral)
                    centralManager?.cancelPeripheralConnection(peripheral)
                    loadHud?.dismiss()
                    
                    let transmittedExperimentData = currentBluetoothData!.subdata(in: (0..<Int(currentBluetoothDataSize)))
                    
                    var receivedCRC32: uLong = 0
                    transmittedExperimentData.withUnsafeBytes{(ptr: UnsafeRawBufferPointer) in
                        receivedCRC32 = crc32(uLong(0), ptr.baseAddress?.assumingMemoryBound(to: UInt8.self), UInt32(transmittedExperimentData.count))
                    }
                    //print("\(transmittedExperimentData.count), \(currentBluetoothData?.count), \(currentBluetoothDataSize)")
                    //print("\(String(format: "%02x", receivedCRC32)) == \(String(format: "%02x", currentBluetoothDataCRC32)) -> \(receivedCRC32 == currentBluetoothDataCRC32)")
                    //print("\(currentBluetoothData!.map{String(format: "%02hhx", $0)}.joined(separator: " "))")
                    //print("\(transmittedExperimentData.map{String(format: "%02hhx", $0)}.joined(separator: " "))")
                    guard receivedCRC32 == currentBluetoothDataCRC32 else {
                        print("CRC32 mismatch")
                        self.loadExperimentFromPeripheralError(peripheral: peripheral, characteristic: characteristic, message: localize("newExperimentBTReadErrorCorrupted") + " (CRC mismatch)", reason: "crc", retryable: true)
                        return
                    }
                    
                    let tmp = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("temp.phyphox")
                    
                    do {
                        try transmittedExperimentData.write(to: tmp, options: .atomic)
                    } catch {
                        self.loadExperimentFromPeripheralError(peripheral: peripheral, characteristic: characteristic, message: localize("newExperimentBTReadErrorTitle") + " (write failed)", reason: "file_write")
                        return
                    }
                    
                    //A Bluetooth transfer is the other route that may carry the partial zip form
                    _ = self.experimentLauncher?.launchExperimentByURL(tmp, chosenPeripheral: peripheral, acceptPartialZip: true)
                    //A stale size would make the next transfer's header look like payload
                    resetTransferState()
                    
                } else {
                    //Throttled, not animated: packets arrive on the main queue, per-packet animation backs up the transfer
                    if lastProgressShown == nil || -lastProgressShown!.timeIntervalSinceNow > 0.1 {
                        lastProgressShown = Date()
                        loadHud?.setProgress(Float(currentBluetoothData!.count)/Float(currentBluetoothDataSize), animated: false)
                    }
                    if !characteristic.properties.contains(.notify) {
                        peripheral.readValue(for: characteristic)
                    }
                }
            } else {
                if !newData.starts(with: "phyphox".data(using: .utf8)!) {
                    print("Bad header: \(newData.map{ String(format: "%02d", $0)}.joined()) from \(characteristic.uuid)")
                    self.loadExperimentFromPeripheralError(peripheral: peripheral, characteristic: characteristic, message: localize("newExperimentBTReadErrorCorrupted") + " (bad header)", reason: "header", retryable: true)
                } else {
                    let sizeData = newData.subdata(in: (7..<7+4))
                    currentBluetoothDataSize = UInt32(bigEndian: sizeData.withUnsafeBytes{$0.load(as: UInt32.self)})
                    let crcData = newData.subdata(in: (11..<11+4))
                    currentBluetoothDataCRC32 = UInt32(bigEndian: crcData.withUnsafeBytes{$0.load(as: UInt32.self)})
                    currentBluetoothData = Data()
                    transferStarted = Date()
                    print("Bluetooth experiment transfer: header announces \(currentBluetoothDataSize ?? 0) bytes")
                    if !characteristic.properties.contains(.notify) {
                        peripheral.readValue(for: characteristic)
                    }
                }
            }
        } else {
            print("No data.")
            self.loadExperimentFromPeripheralError(peripheral: peripheral, characteristic: characteristic, message: localize("newExperimentBTReadErrorCorrupted") + " (no data)", reason: "no_data", retryable: true)
        }
    }
}
