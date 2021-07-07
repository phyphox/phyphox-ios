//
//  ExperimentManager.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import UIKit
import JGProgressHUD
import CoreBluetooth

let emptyBuffer: DataBuffer = {
    let buffer = try! DataBuffer(name: "empty", size: 0, baseContents: [], static: true)
    buffer.clear()
    return buffer
}()

let experimentsBaseURL = Bundle.main.url(forResource: "phyphox-experiments", withExtension: nil)!

let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

let savedExperimentStatesURL = documentsURL.appendingPathComponent("Saved-States")
let customExperimentsURL = documentsURL.appendingPathComponent("Experiments")

let ExperimentsReloadedNotification = "ExperimentsReloadedNotification"

enum FileError: Error {
    case genericError
}

final class ExperimentManager {
    var experimentCollections: [ExperimentCollection] = []
    var hiddenExperimentCollections: [ExperimentCollection] = []
    static let shared = ExperimentManager()

    func deleteExperiment(_ experiment: Experiment) throws {
        guard let source = experiment.source else { return }
        try FileManager.default.removeItem(at: source)
        reloadUserExperiments()
    }
    
    func renameExperiment(_ experiment: Experiment, newTitle: String) throws {
        guard let source = experiment.source else { return }
        try LegacyStateSerializer.renameStateFile(customTitle: newTitle, file: source)
        reloadUserExperiments()
    }

    let filteredServices: [String] = [CBUUID(string: "0x1812").uuid128String]
    
    public func getSupportedBLEServices() -> [CBUUID] {
        var supportedServices = Set<CBUUID>()
        for collection in hiddenExperimentCollections {
            for (experiment, _) in collection.experiments {
                for dev in experiment.bluetoothDevices {
                    if let uuid = dev.advertiseUUID {
                        if !filteredServices.contains(uuid.uuid128String) {
                            supportedServices.insert(uuid)
                        }
                    }
                }
            }
        }
        return Array(supportedServices)
    }
    
    public func getExperimentsForBluetoothDevice(deviceName: String?, deviceUUIDs: [CBUUID]?) -> [ExperimentCollection] {
        var resultCollections: [ExperimentCollection] = []
        for collection in hiddenExperimentCollections {
            for (experiment, custom) in collection.experiments {
                if experiment.bluetoothInputs.count != 1 {
                    continue
                }
                if let dev = experiment.bluetoothDevices.first {
                    if let name = dev.deviceName, name != "" {
                        if let deviceName = deviceName {
                            if !deviceName.contains(name) {
                                continue
                            }
                        } else {
                            continue
                        }
                    }
                    if let uuid = dev.advertiseUUID {
                        if filteredServices.contains(uuid.uuid128String) {
                            continue
                        }
                        if let deviceUUIDs = deviceUUIDs {
                            if !deviceUUIDs.contains(uuid) {
                                continue
                            }
                        } else {
                            continue
                        }
                    }
                    registerExperimentToCollections(experiment, custom: custom, collections: &resultCollections)
                }
            }
        }
        return resultCollections
    }
    
    private func registerExperimentToCollections(_ experiment: Experiment, custom: Bool, collections: inout [ExperimentCollection]) {
        let category = experiment.localizedCategory
        
        if let collection = collections.first(where: { $0.title == category }) {
            let insertIndex = collection.experiments.firstIndex(where: { $0.experiment.displayTitle.lowercased() > experiment.displayTitle.lowercased() }) ?? collection.experiments.endIndex
            
            collection.experiments.insert((experiment, custom), at: insertIndex)
        }
        else {
            let collection = ExperimentCollection(title: category, experiments: [(experiment, custom)])
            
            let insertIndex = collections.firstIndex(where: { ($0.type.rawValue == collection.type.rawValue && $0.title.lowercased() > category.lowercased()) || $0.type.rawValue > collection.type.rawValue }) ?? collections.endIndex
            
            collections.insert(collection, at: insertIndex)
        }
    }
    
    private func registerExperiment(_ experiment: Experiment, custom: Bool, hidden: Bool) {
        if hidden {
            registerExperimentToCollections(experiment, custom: custom, collections: &hiddenExperimentCollections)
        } else {
            registerExperimentToCollections(experiment, custom: custom, collections: &experimentCollections)
        }
    }

    private func showLoadingError(for name: String, error: Error, local: Bool, custom: Bool, src: URL) {
        let hud = JGProgressHUD(style: .dark)
        hud.indicatorView = JGProgressHUDErrorIndicatorView()
        hud.indicatorView?.tintColor = .white
        hud.textLabel.text = "Failed Loading Experiment \(name)"
        hud.detailTextLabel.text = error.localizedDescription

        (UIApplication.shared.keyWindow?.rootViewController?.view).map {
            hud.show(in: $0)
            hud.dismiss(afterDelay: 3.0)
        }
        
        let experiment = Experiment(file: name, error: error.localizedDescription)
        experiment.local = local
        experiment.source = src
        registerExperiment(experiment, custom: custom, hidden: false)
    }

    func loadSavedExperiments() {
        let timestamp = CFAbsoluteTimeGetCurrent()

        guard let experiments = try? FileManager.default.contentsOfDirectory(atPath: savedExperimentStatesURL.path) else { return }
        
        let loadHud = JGProgressHUD()
        loadHud.indicatorView = JGProgressHUDPieIndicatorView()
        loadHud.interactionType = .blockAllTouches
        loadHud.textLabel.text = localize("loadingTitle")
        loadHud.setProgress(0.0, animated: true)
        (UIApplication.shared.keyWindow?.rootViewController?.view).map {
            loadHud.show(in: $0)
        }

        DispatchQueue.global(qos: .userInitiated).async {

            
            for (i, file) in experiments.enumerated() {
                let url = savedExperimentStatesURL.appendingPathComponent(file)

                guard url.pathExtension == experimentStateFileExtension
                    || url.pathExtension == experimentFileExtension
                    else { continue }

                do {
                    let experiment = try ExperimentSerialization.readExperimentFromURL(url)
                    experiment.local = true

                    self.registerExperiment(experiment, custom: true, hidden: false)
                }
                catch {
                    DispatchQueue.main.async {
                        self.showLoadingError(for: file, error: error, local: true, custom: true, src: url)
                    }
                }
                DispatchQueue.main.async {
                    loadHud.setProgress(Float(i) / Float(experiments.count), animated: true)
                }
            }
            DispatchQueue.main.async {
                loadHud.dismiss()
                NotificationCenter.default.post(name: Notification.Name(rawValue: ExperimentsReloadedNotification), object: nil)
            }
            #if DEBUG
            let time = CFAbsoluteTimeGetCurrent() - timestamp
            print("Load saved experiments took \(time * 1000) ms")
            #endif
        }
    }

    func loadCustomExperiments() {
        let timestamp = CFAbsoluteTimeGetCurrent()

        guard let experiments = try? FileManager.default.contentsOfDirectory(atPath: customExperimentsURL.path) else { return }

        for file in experiments {
            let url = customExperimentsURL.appendingPathComponent(file)

            guard url.pathExtension == experimentFileExtension else { continue }

            do {
                let experiment = try ExperimentSerialization.readExperimentFromURL(url)
                experiment.local = true

                registerExperiment(experiment, custom: true, hidden: false)
            }
            catch {
                showLoadingError(for: file, error: error, local: true, custom: true, src: url)
            }
        }

        NotificationCenter.default.post(name: Notification.Name(rawValue: ExperimentsReloadedNotification), object: nil)
        
        #if DEBUG
        let time = CFAbsoluteTimeGetCurrent() - timestamp
        print("Load custom experiments took \(time * 1000) ms")
        #endif
    }

    private func loadExperiments() {
        guard let experiments = try? FileManager.default.contentsOfDirectory(atPath: experimentsBaseURL.path) else { return }

        for file in experiments {
            let url = experimentsBaseURL.appendingPathComponent(file)

            guard url.pathExtension == experimentFileExtension else { continue }

            do {
                let experiment = try ExperimentSerialization.readExperimentFromURL(url)
                experiment.local = true

                registerExperiment(experiment, custom: false, hidden: false)
            }
            catch {
                showLoadingError(for: file, error: error, local: true, custom: false, src: url)
            }
        }
    }
    
    private func loadHiddenBluetoothExperiments() {
        let bluetoothBaseURL = experimentsBaseURL.appendingPathComponent("bluetooth")
        guard let experiments = try? FileManager.default.contentsOfDirectory(atPath: bluetoothBaseURL.path) else { return }
        
        for file in experiments {
            let url = bluetoothBaseURL.appendingPathComponent(file)
            
            guard url.pathExtension == experimentFileExtension else { continue }
            
            do {
                let experiment = try ExperimentSerialization.readExperimentFromURL(url)
                
                registerExperiment(experiment, custom: false, hidden: true)
            }
            catch {
                showLoadingError(for: file, error: error, local: true, custom: false, src: url)
            }
        }
    }
    
    private func loadExperimentsByURL(_ files: [URL]) {
        for file in files {
            do {
                let experiment = try ExperimentSerialization.readExperimentFromURL(file)
                experiment.local = false
                
                registerExperiment(experiment, custom: true, hidden: false)
            }
            catch {
                showLoadingError(for: file.absoluteString, error: error, local: false, custom: true, src: file)
            }
        }
    }
    
    func reloadUserExperiments() {
        for collection in experimentCollections {
            collection.experiments.removeAll(where: {$0.custom})
        }
        loadCustomExperiments()
        loadSavedExperiments()
        
        
    }
    
    func experimentInCollection(crc32: UInt?) -> Bool {
        guard let crc32 = crc32 else {
            return false
        }
        for collection in experimentCollections {
            for experiment in collection.experiments {
                if experiment.experiment.crc32 == crc32 {
                    return true
                }
            }
        }
        return false
    }
    
    init() {
        let timestamp = CFAbsoluteTimeGetCurrent()

        loadExperiments()
        loadHiddenBluetoothExperiments()

        #if DEBUG
        let time = CFAbsoluteTimeGetCurrent() - timestamp
        print("Load took \(time * 1000) ms")
        #endif
    }
    
    init(files: [URL]) {
        loadExperimentsByURL(files)
    }
}

