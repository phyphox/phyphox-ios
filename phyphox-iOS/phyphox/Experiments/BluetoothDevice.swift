//
//  Bluetooth.swift
//  phyphox
//
//  Created by Sebastian Staacks on 24.05.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation
import CoreBluetooth

let baseUUID: UUID = UUID(uuidString: "00000000-0000-1000-8000-00805f9b34fb")!
let phyphoxServiceUUID: UUID = UUID(uuidString: "cddf0001-30f7-4671-8b43-5e40ba53514a")!
let phyphoxExperimentCharacteristicUUID: UUID = UUID(uuidString: "cddf0002-30f7-4671-8b43-5e40ba53514a")!
let phyphoxExperimentControlCharacteristicUUID: UUID = UUID(uuidString: "cddf0003-30f7-4671-8b43-5e40ba53514a")!
let phyphoxEventCharacteristicUUID: UUID = UUID(uuidString: "cddf0004-30f7-4671-8b43-5e40ba53514a")!
let batteryServiceUUID: String = "2A19"

public extension CBUUID {
    convenience init(uuidString: String) throws {
        let uuid: UUID
        if uuidString.count == 4 {
            let baseUUIDString = baseUUID.uuidString
            let startIndex = baseUUIDString.index(baseUUIDString.startIndex, offsetBy: 4)
            let stopIndex = baseUUIDString.index(baseUUIDString.startIndex, offsetBy: 8)
            let full = baseUUIDString.replacingCharacters(in: startIndex..<stopIndex, with: uuidString)
            if let newuuid = UUID(uuidString: full) {
                uuid = newuuid
            } else {
                throw ElementHandlerError.unexpectedAttributeValue("Invalid UUID: \(uuidString)")
            }
        } else if uuidString.count == 8 {
            let baseUUIDString = baseUUID.uuidString
            let startIndex = baseUUIDString.index(baseUUIDString.startIndex, offsetBy: 0)
            let stopIndex = baseUUIDString.index(baseUUIDString.startIndex, offsetBy: 8)
            let full = baseUUIDString.replacingCharacters(in: startIndex..<stopIndex, with: uuidString)
            if let newuuid = UUID(uuidString: full) {
                uuid = newuuid
            } else {
                throw ElementHandlerError.unexpectedAttributeValue("Invalid UUID: \(uuidString)")
            }
        } else if uuidString.count == 36 {
            if let newuuid = UUID(uuidString: uuidString) {
                uuid = newuuid
            } else {
                throw ElementHandlerError.unexpectedAttributeValue("Invalid UUID: \(uuidString)")
            }
        } else {
            throw ElementHandlerError.unexpectedAttributeValue("Invalid UUID: \(uuidString)")
        }
        self.init(nsuuid: uuid)
    }
    
    var uuid128String: String {
        get {
            let uuidString = self.uuidString
            if uuidString.count == 4 {
                let baseUUIDString = baseUUID.uuidString
                let startIndex = baseUUIDString.index(baseUUIDString.startIndex, offsetBy: 4)
                let stopIndex = baseUUIDString.index(baseUUIDString.startIndex, offsetBy: 8)
                return baseUUIDString.replacingCharacters(in: startIndex..<stopIndex, with: uuidString)
            } else if uuidString.count == 8 {
                let baseUUIDString = baseUUID.uuidString
                let startIndex = baseUUIDString.index(baseUUIDString.startIndex, offsetBy: 0)
                let stopIndex = baseUUIDString.index(baseUUIDString.startIndex, offsetBy: 8)
                return baseUUIDString.replacingCharacters(in: startIndex..<stopIndex, with: uuidString)
            } else {
                return uuidString
            }
        }
    }
}

protocol BluetoothDeviceDelegate {
    func deviceReady() throws
    func writeConfigData() throws
    func dataFromCharacteristic(uuid: CBUUID, data: Data)
}

protocol UpdateConnectedDeviceDelegate {
    func showUpdatedConnectedDevices(connectedDevice: [ConnectedDevicesDataModel])
}

enum BluetoothDeviceError: Error {
    case generic(String)
}

class ExperimentBluetoothDevice: BluetoothScan, DeviceIsChosenDelegate {
    let id: String?
    let deviceName: String?
    var deviceAddress: UUID? = nil
    let advertiseUUID: CBUUID?
    
    var stopExperimentDelegate: StopExperimentDelegate? = nil
    
    var peripheral: CBPeripheral? = nil
    
    private var delegates: [BluetoothDeviceDelegate] = []
    
    private var characteristics_map: [String: CBCharacteristic] = [:]
    private var servicesToBeDiscovered: [CBService] = []
    
    private var eventCharacteristic: CBCharacteristic? = nil
    
    let hud: JGProgressHUD
    var feedbackViewController: UIViewController?
    
    static var updateDelegate: UpdateConnectedDeviceDelegate?
    
    var batteryLevel = -1
    var connectedDeviceName: String = ""
    var signalLevel = 100
    var connectedDevices: [ConnectedDevicesDataModel] = [ConnectedDevicesDataModel]()
    
    init(delegate: UpdateConnectedDeviceDelegate) {
        ExperimentBluetoothDevice.updateDelegate = delegate
        
        self.id = ""
        self.deviceName = ""
        self.advertiseUUID = nil
        
        self.hud = JGProgressHUD(style: .dark)
        
        super.init(scanDirectly: false, filterByName: "", filterByUUID: nil, checkExperiments: false, autoConnect: false)
    }
    
    
    init(id: String?, name: String?, uuid: CBUUID?, autoConnect: Bool) {
        self.id = id
        self.deviceName = name
        self.advertiseUUID = uuid
        
        self.hud = JGProgressHUD(style: .dark)
        hud.interactionType = .blockTouchesOnHUDView
        hud.textLabel.text = localize("loadingTitle")
        hud.detailTextLabel.text = localize("loadingBluetoothConnectionText")
        
        super.init(scanDirectly: false, filterByName: name, filterByUUID: uuid, checkExperiments: false, autoConnect: autoConnect)
    }
    
    public func prepareForStart() -> Bool {
        if peripheral?.state == CBPeripheralState.connected {
            return true
        } else {
            disconnect()
            showError(msg: localize("bt_exception_no_connection"))
            return false
        }
    }
    
    public func showError(msg: String, retry: Bool = true) {
        stopExperimentDelegate?.stopExperiment()
        hud.dismiss()
        
        let alert = UIAlertController(title: localize("warning"), message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: localize("cancel"), style: .default, handler: { _ in
            
        }))
        if retry {
            alert.addAction(UIAlertAction(title: localize("tryagain"), style: .default, handler: { _ in
                self.scanToConnect()
            }))
        }
        feedbackViewController?.present(alert, animated: true, completion: nil)
    }
    
    public func attachDelegate(_ delegate: BluetoothDeviceDelegate) {
        delegates.append(delegate)
    }
    
    public func showScanDialog(dismissDelegate: BluetoothScanDialogDismissedDelegate?) {
        let message: String
        let deviceIDInfo: String
        if let deviceID = id, deviceID != "" {
            deviceIDInfo =  " (" + deviceID + ")"
        } else {
            deviceIDInfo = ""
        }
        if let filterName = deviceName, filterName != "" {
            message = localize("bt_scanning_specific1") + " \"" + filterName + "\" " + localize("bt_scanning_specific2") + deviceIDInfo
        } else {
            message = localize("bt_scanning_generic") + deviceIDInfo
        }
        
        let alertController = UIAlertController(title: autoConnect ?  nil : localize("bt_pick_device"),
                                                message: message,
                                                preferredStyle: UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad ? .alert : .actionSheet)
        
        let cancelAction = UIAlertAction(title: localize("cancel"), style: .cancel)
        { (action) in
            //we allow cancelling the scanning dialog but bring up the issue again if the user wants to start the experiment without connecting devices
        }
        alertController.addAction(cancelAction)
        
        let scanController = BluetoothScanResultsTableViewController(filterByName: deviceName, filterByUUID: advertiseUUID, checkExperiments: false, autoConnect: autoConnect)
        scanController.tableView = FixedTableView()
        alertController.setValue(scanController, forKey: "contentViewController")
        
        scanController.deviceIsChosenDelegate = self
        scanController.dialogDismissedDelegate = dismissDelegate
        
        if let popover = scanController.popoverPresentationController, let feedbackViewController = feedbackViewController {
            popover.sourceView = feedbackViewController.view
            popover.sourceRect = CGRect(x: feedbackViewController.view.bounds.midX, y: feedbackViewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
            
        }
        
        feedbackViewController?.present(alertController, animated: true)
    }
    
    func scanToConnect() {
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
        if let deviceAddress = deviceAddress {
            if centralManager?.retrievePeripherals(withIdentifiers: [deviceAddress]).count ?? 0 > 0 {
                scanImmediately = false
                tryDirectConnection()
                return
            }
        } else {
            showScanDialog(dismissDelegate: nil)
            scanImmediately = true
            centralManager?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey : NSNumber(value: true)])
        }
    }
    
    func useChosenBLEDevice(chosenDevice: CBPeripheral, advertisedUUIDs: [CBUUID]?) {
        deviceAddress = chosenDevice.identifier
        scanToConnect()
    }
    
    func tryDirectConnection() {
        if let deviceAddress = deviceAddress, peripheral == nil {
            if let device = centralManager?.retrievePeripherals(withIdentifiers: [deviceAddress]).first {
                if centralManager?.state == .poweredOn {
                    connect(peripheral: device)
                } else {
                    let state = centralManager?.state
                    if state == .unsupported || state == .unauthorized {
                        showError(msg: "Bluetooth Low Energy is not supported or not authorized on this device.", retry: false)
                    } else if state == .poweredOff {
                        showError(msg: localize("bt_exception_disabled"))
                    }
                }
            }
        }
    }
    
    override func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            let state = central.state
            if state == .unsupported || state == .unauthorized {
                showError(msg: "Bluetooth Low Energy is not supported or not authorized on this device.", retry: false)
            } else if state == .poweredOff {
                showError(msg: localize("bt_exception_disabled"))
            }
            return
        }
        
        if(scanImmediately){
            scan(central)
        }
        
        tryDirectConnection()
        
        
    }
    
    func connect(peripheral: CBPeripheral) {
        if let feedbackView = feedbackViewController?.view {
            hud.show(in: feedbackView)
        }
        
        self.peripheral = peripheral
        peripheral.delegate = self
        centralManager?.connect(peripheral, options: nil)
        after(5) {
            if peripheral.state != .connected {
                self.centralManager?.cancelPeripheralConnection(peripheral)
                self.hud.dismiss()
                self.disconnect()
                self.showError(msg: localize("bt_exception_notfound"))
            }
        }
    }
    
    func disconnect() {
        stopExperimentDelegate?.stopExperiment()
        if let peripheral = self.peripheral {
            for item in characteristics_map.keys{
                if let char = characteristics_map[item] {
                    peripheral.setNotifyValue(false, for: char)
                }
            }
            self.peripheral = nil
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        characteristics_map = [:]
        servicesToBeDiscovered = []
        connectedDevices = []
        centralManager?.stopScan()
        
    }
    
    override func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if(deviceAddress == peripheral.identifier ){
            connect(peripheral: peripheral)
            centralManager?.stopScan()
        }
        
    }
    
    override func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected: \(peripheral.name ?? "No Name")")
        peripheral.readRSSI()
        peripheral.discoverServices(nil)
        after(10) {
            if self.characteristics_map.count == 0 {
                self.hud.dismiss()
                self.disconnect()
                self.showError(msg: localize("bt_exception_services"))
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,didReadRSSI RSSI: NSNumber, error: Error?){
        signalLevel = Int(RSSI)
        connectedDeviceName = peripheral.name ?? ""
        let  connectedDevice = ConnectedDevicesDataModel(deviceIdentifier: peripheral.identifier,
                                                         signalStrength: signalLevel,
                                                         batteryLabel: batteryLevel,
                                                         deviceName: connectedDeviceName)
        
        // append or update the list as per the current state
        if(connectedDevices.isEmpty){
            connectedDevices.append(connectedDevice)
            
        } else {
            if(connectedDevices.filter { $0.getDeviceIdentifier() == peripheral.identifier}.isEmpty){
                // if the current device name is not in list than add it to the list
                connectedDevices.append(connectedDevice)
            } else{
                // Get row index of the current device info to update its elements
                if let row = connectedDevices.firstIndex(where: {$0.getDeviceIdentifier() == peripheral.identifier}){
                    connectedDevices[row] = connectedDevice
                }
            }
        }
        
        ExperimentBluetoothDevice
            .updateDelegate?
            .showUpdatedConnectedDevices(connectedDevice: connectedDevices)
        
    }
    
    override func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        self.disconnect()
        self.showError(msg: localize("bt_exception_connection"))
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        stopExperimentDelegate?.stopExperiment()
        if (self.peripheral != nil) {
            scan(central)
        }
    }
    
    public func subscribeToCharacteristic(uuid: CBUUID) throws {
        if let char = characteristics_map[uuid.uuid128String] {
            peripheral?.setNotifyValue(true, for: char)
        } else {
            throw BluetoothDeviceError.generic(localize("bt_exception_notification") + " \(uuid) " + localize("bt_exception_notification_enable"))
        }
    }
    
    public func unsubscribeFromCharacteristic(uuid: CBUUID) throws {
        if let char = characteristics_map[uuid.uuid128String] {
            peripheral?.setNotifyValue(false, for: char)
        } else {
            throw BluetoothDeviceError.generic(localize("bt_exception_notification") + " \(uuid) " + localize("bt_exception_notification_disable"))
        }
    }
    
    public func readCharacteristic(uuid: CBUUID) throws {
        if let char = characteristics_map[uuid.uuid128String] {
            peripheral?.readValue(for: char)
        } else {
            throw BluetoothDeviceError.generic(localize("bt_error_reading") + " \(uuid)")
        }
    }
    
    public func writeCharacteristic(uuid: CBUUID, data: Data) throws {
        if let char = characteristics_map[uuid.uuid128String] {
            peripheral?.writeValue(data, for: char, type: char.properties.contains(.writeWithoutResponse) ? CBCharacteristicWriteType.withoutResponse : CBCharacteristicWriteType.withResponse)
        } else {
            throw BluetoothDeviceError.generic(localize("bt_error_writing") + " \(uuid)")
        }
    }
    
    override func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services, services.count > 0 else {
            self.showError(msg: localize("bt_exception_services") + " (response empty)")
            return
        }
        
        for service in services {
            servicesToBeDiscovered.append(service)
        }
        
        peripheral.discoverCharacteristics(nil, for: servicesToBeDiscovered.first!)
        
        after(10) {
            if self.servicesToBeDiscovered.count > 0 {
                self.hud.dismiss()
                self.showError(msg: localize("bt_exception_services") + " (response incomplete)")
                self.disconnect()
            }
        }
    }
    
    override func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        peripheral.readRSSI()
        if let newData = characteristic.value {
            for delegate in delegates {
                if(characteristic.uuid.uuidString == batteryServiceUUID){
                    guard let newBatteryLevel = characteristic.value?.first else {
                        return
                    }
                    if(batteryLevel != newBatteryLevel) {
                        batteryLevel = Int(newBatteryLevel)
                        peripheral.readValue(for: characteristic)
                    }
                    
                }
                delegate.dataFromCharacteristic(uuid: characteristic.uuid, data: newData)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        /* We ignore errors because it seems possible that devices do not set up a proper config descriptor while still working as expected.
         if let error = error {
         self.disconnect()
         self.showError(msg: localize("bt_exception_notification_fail_enable") + " \(characteristic.uuid) " + localize("bt_exception_notification_fail") + " (\(error.localizedDescription))")
         }
         */
    }
    
    override func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let index = servicesToBeDiscovered.firstIndex(of: service) {
            servicesToBeDiscovered.remove(at: index)
        } else {
            return
        }
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        for characteristic in characteristics {
            
            if characteristic.uuid.uuid128String == phyphoxEventCharacteristicUUID.uuidString {
                eventCharacteristic = characteristic
            }
            
            if(characteristic.uuid.uuidString == batteryServiceUUID){
                //Battery Label
                peripheral.readValue(for: characteristic)
                
            }
            
            
            characteristics_map[characteristic.uuid.uuid128String] = characteristic
        }
        
        if let service = servicesToBeDiscovered.first {
            peripheral.discoverCharacteristics(nil, for: service)
            return
        }
        
        print("Service discovery completed. Writing config data to device.")
        
        do {
            writeEventCharacteristic(timeMapping: nil)
            
            for delegate in delegates {
                try delegate.writeConfigData()
            }
            for delegate in delegates {
                try delegate.deviceReady()
            }
        } catch BluetoothDeviceError.generic(let msg) {
            hud.dismiss()
            disconnect()
            showError(msg: msg)
            return
        } catch {
            hud.dismiss()
            showError(msg: "Unknown error.")
            return
        }
        
        hud.dismiss()
        
    }
    
    func writeEventCharacteristic(timeMapping: ExperimentTimeReference.TimeMapping?) {
        if let char = eventCharacteristic {
            var out: Data = Data(capacity: 17)
            var experimentTime: Int64
            var systemTime: Int64
            
            if let timeMapping = timeMapping {
                switch timeMapping.event {
                case .PAUSE:
                    out.append(0x00)
                case .START:
                    out.append(0x01)
                case .CLEAR:
                    out.append(0x02)
                }
                experimentTime = Int64(timeMapping.experimentTime * 1000)
                systemTime = Int64(timeMapping.systemTime.timeIntervalSince1970 * 1000)
            } else {
                out.append(0xff)
                experimentTime = -1
                systemTime = Int64(Date().timeIntervalSince1970 * 1000)
            }
            
            let leExpTimeData = Data(bytes: &experimentTime, count: MemoryLayout.size(ofValue: experimentTime))
            for byte in leExpTimeData.subdata(in: (0..<MemoryLayout.size(ofValue: experimentTime))).reversed() {
                out.append(byte)
            }
            
            let leSysTimeData = Data(bytes: &systemTime, count: MemoryLayout.size(ofValue: systemTime))
            for byte in leSysTimeData.subdata(in: (0..<MemoryLayout.size(ofValue: systemTime))).reversed() {
                out.append(byte)
            }
            
            do {
                try writeCharacteristic(uuid: char.uuid, data: out)
            } catch BluetoothDeviceError.generic(let msg) {
                showError(msg: "Could not write event. \(msg)")
            } catch {
                showError(msg: "Could not write event. Unknown error.")
            }
        }
    }
    
}

class ConnectedDevicesDataModel {
    private  var deviceIdentifier: UUID?
    private  var signalStrength: Int?
    private  var batteryLabel: Int?
    private  var deviceName: String?
    
    init(deviceIdentifier: UUID, signalStrength: Int, batteryLabel: Int,  deviceName: String) {
        self.deviceIdentifier = deviceIdentifier
        self.signalStrength = signalStrength
        self.batteryLabel = batteryLabel
        self.deviceName = deviceName
    }
    
    init(signalStrength: Int) {
        self.signalStrength = signalStrength
    }
    
    func getDeviceIdentifier() -> UUID {
        return deviceIdentifier ?? UUID()
    }
    
    func getSignalStrength() -> Int{
        return signalStrength ?? 100
    }
    
    func getBatteryLabel() -> Int{
        return batteryLabel ?? 100
    }
    
    func getDeviceName() -> String{
        return deviceName ?? ""
    }
    
}



