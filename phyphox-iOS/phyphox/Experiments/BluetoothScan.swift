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
                scanResultsDelegate?.autoConnect(device: peripheral, advertisedUUIDs: advertisedUUIDs)
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
    
    var viewController: UIViewController? = nil
    var experimentLauncher: ExperimentController? = nil
    
    public func loadExperimentFromPeripheral(_ peripheral: CBPeripheral, viewController: UIViewController, experimentLauncher: ExperimentController?) {
        self.viewController = viewController
        self.experimentLauncher = experimentLauncher
        
        loadHud = JGProgressHUD()
        loadHud?.indicatorView = JGProgressHUDPieIndicatorView()
        loadHud?.interactionType = .blockTouchesOnHUDView
        loadHud?.textLabel.text = localize("loadingTitle")
        loadHud?.detailTextLabel.text = localize("loadingText")
        loadHud?.setProgress(0.0, animated: true)
        loadHud?.show(in: viewController.view)
        
        loadFromBluetoothDeviceStage = .connecting
        currentBluetoothData = nil
        
        self.peripheralToBeConnected = peripheral
        
        if centralManager?.state == .poweredOn {
            loadExperimentFromPeripheralConnect()
        }
        
        after(5) {
            if self.loadFromBluetoothDeviceStage == .connecting {
                self.loadExperimentFromPeripheralError(peripheral: peripheral, characteristic: nil)
            }
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
    
    func loadExperimentFromPeripheralError(peripheral: CBPeripheral, characteristic: CBCharacteristic?) {
        if let char = characteristic {
            peripheral.setNotifyValue(false, for: char)
        }
        setControlCharacteristicIfPresent(value: 0x00, peripheral: peripheral)
        centralManager?.cancelPeripheralConnection(peripheral)
        loadFromBluetoothDeviceStage = .failed
        currentBluetoothData = nil
        currentBluetoothDataSize = nil
        currentBluetoothDataCRC32 = nil
        
        loadHud?.dismiss()
        loadHud = nil
        
        let alert = UIAlertController(title: localize("warning"), message: localize("newExperimentBTReadErrorTitle"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: localize("cancel"), style: .default, handler: { _ in
            
        }))
        alert.addAction(UIAlertAction(title: localize("tryagain"), style: .default, handler: { _ in
            self.loadExperimentFromPeripheral(peripheral, viewController: self.viewController!, experimentLauncher: self.experimentLauncher)
        }))
        viewController?.present(alert, animated: true, completion: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        self.loadExperimentFromPeripheralError(peripheral: peripheral, characteristic: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        loadFromBluetoothDeviceStage = .discoveringServices
        peripheral.discoverServices([CBUUID(nsuuid: phyphoxServiceUUID)])
        after(5) {
            if self.loadFromBluetoothDeviceStage == .discoveringServices {
                self.loadExperimentFromPeripheralError(peripheral: peripheral, characteristic: nil)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: {$0.uuid.uuid128String == phyphoxServiceUUID.uuidString}) else {
            self.loadExperimentFromPeripheralError(peripheral: peripheral, characteristic: nil)
            return
        }
        loadFromBluetoothDeviceStage = .discoveringCharacteristics
        peripheral.discoverCharacteristics([CBUUID(nsuuid: phyphoxExperimentCharacteristicUUID),CBUUID(nsuuid: phyphoxExperimentControlCharacteristicUUID)], for: service)
        after(5) {
            if self.loadFromBluetoothDeviceStage == .discoveringCharacteristics {
                self.loadExperimentFromPeripheralError(peripheral: peripheral, characteristic: nil)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        guard let characteristic = service.characteristics?.first(where: {$0.uuid.uuid128String == phyphoxExperimentCharacteristicUUID.uuidString}) else {
            self.loadExperimentFromPeripheralError(peripheral: peripheral, characteristic: nil)
            return
        }
        loadFromBluetoothDeviceStage = .subscribing
        peripheral.setNotifyValue(true, for: characteristic)
        setControlCharacteristicIfPresent(value: 0x01, peripheral: peripheral)
        after(30) {
            if self.loadFromBluetoothDeviceStage != .done && self.loadFromBluetoothDeviceStage != .failed {
                self.loadExperimentFromPeripheralError(peripheral: peripheral, characteristic: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if loadFromBluetoothDeviceStage == .done || loadFromBluetoothDeviceStage == .failed {
            return
        }
        loadFromBluetoothDeviceStage = .transmitting
        if let newData = characteristic.value {
            if let currentBluetoothDataSize = currentBluetoothDataSize, let currentBluetoothDataCRC32 = currentBluetoothDataCRC32 {
                guard currentBluetoothData != nil else {
                    self.loadExperimentFromPeripheralError(peripheral: peripheral, characteristic: characteristic)
                    return
                }
                currentBluetoothData!.append(newData)

                if currentBluetoothData!.count >= currentBluetoothDataSize {
                    loadFromBluetoothDeviceStage = .done
                    peripheral.setNotifyValue(false, for: characteristic)
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
                        self.loadExperimentFromPeripheralError(peripheral: peripheral, characteristic: characteristic)
                        return
                    }
                    
                    let tmp = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("temp.phyphox")
                    
                    do {
                        try transmittedExperimentData.write(to: tmp, options: .atomic)
                    } catch {
                        self.loadExperimentFromPeripheralError(peripheral: peripheral, characteristic: characteristic)
                        return
                    }
                    
                    _ = self.experimentLauncher?.launchExperimentByURL(tmp, chosenPeripheral: peripheral)
                    
                } else {
                    loadHud?.setProgress(Float(currentBluetoothData!.count)/Float(currentBluetoothDataSize), animated: true)
                }
            } else {
                if !newData.starts(with: "phyphox".data(using: .utf8)!) {
                    self.loadExperimentFromPeripheralError(peripheral: peripheral, characteristic: characteristic)
                } else {
                    let sizeData = newData.subdata(in: (7..<7+4))
                    currentBluetoothDataSize = UInt32(bigEndian: sizeData.withUnsafeBytes{$0.load(as: UInt32.self)})
                    let crcData = newData.subdata(in: (11..<11+4))
                    currentBluetoothDataCRC32 = UInt32(bigEndian: crcData.withUnsafeBytes{$0.load(as: UInt32.self)})
                    currentBluetoothData = Data()
                }
            }
        }
    }
}
