//
//  ScanResultsTableViewController.swift
//  phyphox
//
//  Created by Dominik Dorsel on 14.01.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import UIKit
import CoreBluetooth

protocol ScanResultsDelegate {
    func reloadScanResults(updatedEntry: UUID)
    func autoConnect(device: CBPeripheral, advertisedUUIDs: [CBUUID]?)
}

protocol DeviceIsChosenDelegate {
    func useChosenBLEDevice(chosenDevice: CBPeripheral, advertisedUUIDs: [CBUUID]?)
}

protocol BluetoothScanDialogDismissedDelegate {
    func bluetoothScanDialogDismissed()
}

class BluetoothScanResultsTableViewController: UITableViewController, ScanResultsDelegate {
    
    var deviceIsChosenDelegate: DeviceIsChosenDelegate?
    var dialogDismissedDelegate: BluetoothScanDialogDismissedDelegate?
    var tableData: [String] = []
    public var ble: BluetoothScan
    private var sortedResults: [BluetoothScan.ScanResult] = []
    
    var signalImages: [UIImage]
    
    init(filterByName: String?, filterByUUID: CBUUID?, checkExperiments: Bool, autoConnect: Bool) {
        ble = BluetoothScan(scanDirectly: true, filterByName: filterByName, filterByUUID: filterByUUID, checkExperiments: checkExperiments, autoConnect: autoConnect)
        
        signalImages = []
        for i in 0..<5 {
            signalImages.append(UIImage(named: "bluetooth_signal_\(i)")!)
        }
        
        super.init(style: .plain)

        ble.scanResultsDelegate = self
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.backgroundColor = kBackgroundColor
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "my")
        view.addSubview(tableView)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        ble.stopScan()
    }
   
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func formatCell(_ cell: UITableViewCell, withEntry entry: BluetoothScan.ScanResult) {
        cell.backgroundColor = kBackgroundColor
        cell.textLabel?.text = entry.advertisedName ?? entry.peripheral.name ?? localize("unknown")
        cell.textLabel?.textColor = entry.experiment == .unavailable ? UIColor(white: 1.0, alpha: 0.6) : (entry.oneOfMany && entry.strongestSignal ? kHighlightColor : kTextColor)
        cell.detailTextLabel?.text = entry.experiment == .unavailable ? localize("bt_device_not_supported") : ""
        cell.detailTextLabel?.textColor = kHighlightColor
        let signal_i: Int
        if entry.rssi.decimalValue > -30 {
            signal_i = 4
        } else if entry.rssi.decimalValue > -50 {
            signal_i = 3
        } else if entry.rssi.decimalValue > -70 {
            signal_i = 2
        } else if entry.rssi.decimalValue > -90 {
            signal_i = 1
        } else {
            signal_i = 0
        }
        cell.accessoryView = UIImageView(image: signalImages[signal_i])
        cell.isUserInteractionEnabled = entry.experiment != .unavailable
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: UITableViewCell.CellStyle.subtitle, reuseIdentifier: "my")
        formatCell(cell, withEntry: sortedResults[indexPath.row])
        return cell
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sortedResults.count
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        self.dismiss(animated: true, completion: { () in
            self.deviceIsChosenDelegate?.useChosenBLEDevice(chosenDevice: self.sortedResults[indexPath.row].peripheral, advertisedUUIDs: self.sortedResults[indexPath.row].advertisedUUIDs)
            self.dialogDismissedDelegate?.bluetoothScanDialogDismissed()
        })
    }
    
    func autoConnect(device: CBPeripheral, advertisedUUIDs: [CBUUID]?) {
        self.dismiss(animated: true, completion: { () in
            self.deviceIsChosenDelegate?.useChosenBLEDevice(chosenDevice: device, advertisedUUIDs: advertisedUUIDs)
            self.dialogDismissedDelegate?.bluetoothScanDialogDismissed()
        })
    }
    
    func reloadScanResults(updatedEntry: UUID){
        if let i = sortedResults.firstIndex(where: { $0.peripheral.identifier == updatedEntry }), let newData = ble.discoveredDevices[updatedEntry], let cell = tableView.cellForRow(at: IndexPath.init(row: i, section: 0)) {
            sortedResults[i] = newData
            formatCell(cell, withEntry: newData)
        } else {
            sortedResults =  [BluetoothScan.ScanResult] (ble.discoveredDevices.values.sorted(by: {$0.firstSeen.compare($1.firstSeen) == .orderedAscending}))
            tableView.reloadData()
        }
    }
   
}
