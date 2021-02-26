//
//  NetworkConnection.swift
//  phyphox
//
//  Created by Sebastian Staacks on 27.11.19.
//  Copyright © 2019 RWTH Aachen. All rights reserved.
//

import Foundation

protocol NetworkScanDialogDismissedDelegate {
    func networkScanDialogDismissed()
}

protocol NetworkConnectionDataPolicyInfoDelegate {
    func dataPolicyInfoDismissed()
}

struct NetworkSendableData {
    enum Source {
    case Buffer(DataBuffer)
    case Metadata(Metadata)
    case Time(ExperimentTimeReference)
    }
    let source: Source
    
    var additionalAttributes: [String:String]
}

struct NetworkReceivableData {
    let buffer: DataBuffer
    let clear: Bool
}

class NetworkConnection: NetworkServiceRequestCallback, NetworkDiscoveryCallback {
    let id: String?
    let privacyURL: String?
    
    let address: String
    var specificAddress: String?
    let discovery: NetworkDiscovery?
    let autoConnect: Bool
    let service: NetworkService
    let conversion: NetworkConversion
    
    let send: [String: NetworkSendableData]
    let receive: [String: NetworkReceivableData]
    let interval: Double
    
    var executeRequested = false
    var dataReady = false
    var requestCallbacks: [NetworkServiceRequestCallback] = []
    var timer: Timer? = nil
    
    let hud: JGProgressHUD
    var feedbackViewController: UIViewController?
    
    init(id: String?, privacyURL: String?, address: String, discovery: NetworkDiscovery?, autoConnect: Bool, service: NetworkService, conversion: NetworkConversion, send: [String: NetworkSendableData], receive: [String: NetworkReceivableData], interval: Double) {
        self.id = id
        self.privacyURL = privacyURL
        self.address = address
        self.discovery = discovery
        self.autoConnect = autoConnect
        self.service = service
        self.conversion = conversion
        self.send = send
        self.receive = receive
        self.interval = interval
        
        self.hud = JGProgressHUD(style: .dark)
        hud.interactionType = .blockNoTouches
        hud.indicatorView = JGProgressHUDErrorIndicatorView()
        hud.textLabel.text = localize("error")
        hud.detailTextLabel.text = localize("loadingBluetoothConnectionText")
    }
    
    public func showError(msg: String) {
        DispatchQueue.main.async {
            self.hud.dismiss()
            if let feedbackView = self.feedbackViewController?.view {
                self.hud.detailTextLabel.text = msg
                self.hud.show(in: feedbackView)
            }
            after(3) {
                self.hud.dismiss()
            }
        }
    }
    
    func showDataAndPolicy(infoMicrophone: Bool, infoLocation: Bool, infoSensorData: Bool, infoSensorDataList: [String], callback: NetworkConnectionDataPolicyInfoDelegate) {
        var msg = localize("networkPrivacyInfo")
        msg += "\n\n"
        
        var infoUniqueID = false
        var infoDeviceInfo = false
        var infoSensorInfo = false
        var infoSensorInfoList: Set<String> = []
        
        for dataset in send {
            switch dataset.value.source {
            case .Metadata(let metadata):
                switch metadata {
                case .uniqueId:
                    infoUniqueID = true
                case .build, .deviceBaseOS, .deviceBoard, .deviceBrand, .deviceCodename, .deviceManufacturer, .deviceModel, .deviceRelease, .fileFormat, .version:
                    infoDeviceInfo = true
                case .sensor(let type, _):
                    infoSensorInfo = true
                    infoSensorInfoList.insert(type.getLocalizedName())
                }
            default:
                break
            }
        }
        
        if infoUniqueID {
            msg += "- " + localize("networkPrivacyUniqueID") + "\n"
        }
        if infoMicrophone {
            msg += "- " + localize("networkPrivacySensorMicrophone") + "\n"
        }
        if infoLocation {
            msg += "- " + localize("networkPrivacySensorLocation") + "\n"
        }
        if infoSensorData {
            msg += "- " + localize("networkPrivacySensorData") + " " + infoSensorDataList.sorted().joined(separator: ", ") + "\n"
        }
        if infoDeviceInfo {
            msg += "- " + localize("networkPrivacyDeviceInfo") + "\n"
        }
        if infoSensorInfo {
            msg += "- " + localize("networkPrivacySensorInfo") + " " + infoSensorInfoList.sorted().joined(separator: ", ") + "\n"
        }
        
        let alert = UIAlertController(title: localize("networkPrivacyWarning"), message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: localize("ok"), style: .default, handler: { _ in
            callback.dataPolicyInfoDismissed()
        }))
        alert.addAction(UIAlertAction(title: localize("networkVisitPrivacyURL"), style: .default, handler: { _ in
            if let url = URL(string: self.privacyURL ?? "") {
                UIApplication.shared.openURL(url)
            }
        }))
        feedbackViewController?.present(alert, animated: true, completion: nil)
    }
    
    func start() {
        if interval > 0 {
            timedExecute()
            timer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(timedExecute), userInfo: nil, repeats: true)
        }
    }
    
    func stop() {
        timer?.invalidate()
    }
    
    var dismissDelegate: NetworkScanDialogDismissedDelegate?
    func connect(dismissDelegate: NetworkScanDialogDismissedDelegate?) {
        if let specificAddress = specificAddress {
            connect(address: specificAddress)
            dismissDelegate?.networkScanDialogDismissed()
        } else {
            if let discovery = discovery {
                discovery.startDiscovery(onNewResult: self)
                self.dismissDelegate = dismissDelegate
                //TODO Scan and dialog for multiple results or conenct to first result if autoConnect is set
                //Call delegate if connected
            } else {
                specificAddress = address
                connect(address: specificAddress ?? "")
                dismissDelegate?.networkScanDialogDismissed()
            }
        }
    }
    
    func newItem(name: String?, address: String) {
        dismissDelegate?.networkScanDialogDismissed()
        discovery?.stopDiscovery()
        specificAddress = address
        connect(address: specificAddress ?? "")
        //TODO. move to scan dialog
    }
        
    func connect(address: String) {
        dataReady = false
        service.connect(address: address)
    }
    
    func disconnect() {
        dataReady = false
    }
    
    @objc func timedExecute() {
        execute(requestCallbacks: [])
    }
    
    func execute(requestCallbacks: [NetworkServiceRequestCallback]) {
        executeRequested = true
        self.requestCallbacks.append(contentsOf: requestCallbacks)
    }
    
    func doExecute() {
        if executeRequested {
            self.requestCallbacks.append(self)
            service.execute(send: send, requestCallbacks: requestCallbacks)
            self.requestCallbacks = []
            executeRequested = false
        }
    }
    
    func requestFinished(result: NetworkServiceResult) {
        switch result {
        case .conversionError(let msg):
            showError(msg: "Network error: Conversion failed. \(msg)")
        case .genericError(let msg):
            showError(msg: "Network error: Generic error. \(msg)")
        case .noConnection:
            showError(msg: "Network error: No connection to network service.")
        case .timeout:
            showError(msg: "Network error: The connection timed out.")
        case .success:
            if let data = service.getResults() {
                do {
                    try conversion.prepare(data: data)
                    dataReady = true
                } catch (let error as NetworkConversionError) {
                    switch error {
                    case .emptyInput: showError(msg: "Network error: Failed to prepare the data conversion. Empty input.")
                    case .notImplemented: showError(msg: "Network error: Failed to prepare the data conversion. Not implemented.")
                    case .genericError(let msg): showError(msg: "Network error: Failed to prepare the data conversion. Generic error. \(msg)")
                    case .invalidInput(let msg): showError(msg: "Network error: Failed to prepare the data conversion. Invalid input. \(msg)")
                    }
                } catch {
                    showError(msg: "Network error: Failed to prepare the data conversion.")
                }
            }
        }
    }
    
    func pushDataToBuffers() {
        if !dataReady {
            return
        }
        for item in receive {
            if let data = try? conversion.get(item.key) {
                if item.value.clear {
                    item.value.buffer.replaceValues(data)
                } else {
                    item.value.buffer.appendFromArray(data)
                }
            }
        }
        dataReady = false
    }
    
}

extension NetworkConnection: Equatable {
    static func ==(lhs: NetworkConnection, rhs: NetworkConnection) -> Bool {
        return lhs.id == rhs.id &&
                lhs.privacyURL == rhs.privacyURL &&
                lhs.autoConnect == rhs.autoConnect &&
                lhs.address == rhs.address &&
                lhs.interval == rhs.interval
    }
}
