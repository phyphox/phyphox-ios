//
//  ExperimentManager.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import UIKit
import JGProgressHUD

let emptyBuffer: DataBuffer = {
    let buffer = try! DataBuffer(name: "empty", storage: .memory(size: 0), baseContents: [], static: true)
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
    static let shared = ExperimentManager()

    func deleteExperiment(_ experiment: Experiment) throws {
        guard let source = experiment.source else { return }
        try FileManager.default.removeItem(at: source)
        loadCustomExperiments()
    }

    private func registerExperiment(_ experiment: Experiment, custom: Bool) {
        experiment.delegate = self

        let category = experiment.localizedCategory

        if let collection = experimentCollections.first(where: { $0.title == category }) {
            let insertIndex = collection.experiments.index(where: { $0.experiment == experiment }) ?? collection.experiments.endIndex

            collection.experiments.insert((experiment, custom), at: insertIndex)
        }
        else {
            let collection = ExperimentCollection(title: category, experiments: [experiment], customExperiments: custom)

            let insertIndex = experimentCollections.index(where: { $0.title > category }) ?? experimentCollections.endIndex

            experimentCollections.insert(collection, at: insertIndex)
        }
    }

    private func showLoadingError(for name: String, error: Error) {
        let hud = JGProgressHUD(style: .dark)
        hud.indicatorView = JGProgressHUDErrorIndicatorView()
        hud.indicatorView?.tintColor = .white
        hud.textLabel.text = "Failed Loading Experiment \(name)"
        hud.detailTextLabel.text = error.localizedDescription

        (UIApplication.shared.keyWindow?.rootViewController?.view).map {
            hud.show(in: $0)
            hud.dismiss(afterDelay: 3.0)
        }
    }

    func loadSavedExperiments() {
        guard let experiments = try? FileManager.default.contentsOfDirectory(atPath: savedExperimentStatesURL.path) else { return }

        for file in experiments {
            let url = savedExperimentStatesURL.appendingPathComponent(file)

            guard url.pathExtension == experimentStateFileExtension else { continue }

            do {
                let experiment = try ExperimentSerialization.readExperimentFromURL(url)

                registerExperiment(experiment, custom: true)
            }
            catch {
                showLoadingError(for: file, error: error)
            }
        }

        NotificationCenter.default.post(name: Notification.Name(rawValue: ExperimentsReloadedNotification), object: nil)
    }

    func loadCustomExperiments() {
        guard let experiments = try? FileManager.default.contentsOfDirectory(atPath: customExperimentsURL.path) else { return }

        for file in experiments {
            let url = customExperimentsURL.appendingPathComponent(file)

            guard url.pathExtension == experimentFileExtension else { continue }

            do {
                let experiment = try ExperimentSerialization.readExperimentFromURL(url)

                registerExperiment(experiment, custom: true)
            }
            catch {
                showLoadingError(for: file, error: error)
            }
        }

        NotificationCenter.default.post(name: Notification.Name(rawValue: ExperimentsReloadedNotification), object: nil)
    }

    private func loadExperiments() {
        guard let experiments = try? FileManager.default.contentsOfDirectory(atPath: experimentsBaseURL.path) else { return }

        for file in experiments {
            let url = experimentsBaseURL.appendingPathComponent(file)

            guard url.pathExtension == experimentFileExtension else { continue }

            do {
                let experiment = try ExperimentSerialization.readExperimentFromURL(url)

                registerExperiment(experiment, custom: false)
            }
            catch {
                showLoadingError(for: file, error: error)
            }
        }
    }

    private func benchmark(repititions: Int, legacy: Bool, completion: @escaping (TimeInterval) -> Void) {
        let experiments = try! FileManager.default.contentsOfDirectory(atPath: experimentsBaseURL.path)

        let urls = experiments.map { experimentsBaseURL.appendingPathComponent($0) }

        var totalTime = 0.0

        var left = repititions

        func go() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                let start = CFAbsoluteTimeGetCurrent()

                for url in urls {
                    _ = try! ExperimentSerialization.readExperimentFromURL(url, legacy: legacy)
                }

                let duration = CFAbsoluteTimeGetCurrent() -  start

                totalTime += duration

                left -= 1
                if left > 0 {
                    go()
                }
                else {
                    let average = totalTime / Double(repititions)

                    completion(average)
                }
            }
        }

        go()
    }
    
    init() {
        let timestamp = CFAbsoluteTimeGetCurrent()

       loadExperiments()
       loadCustomExperiments()
       loadSavedExperiments()

        #if DEBUG
        let time = CFAbsoluteTimeGetCurrent() - timestamp
        print("Load took \(time * 1000) ms")
        #endif

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.benchmark(repititions: 20, legacy: true) { duration in
                 print("Legacy benchmark time: \(duration)")

                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    self.benchmark(repititions: 20, legacy: false) { duration in
                        print("New benchmark time: \(duration)")
                    }
                }
            }
        }
    }
}

extension ExperimentManager: ExperimentDelegate {
    func experimentWillBecomeActive(_ experiment: Experiment) {
        guard experiment.local, let url = experiment.source, url.pathExtension == experimentStateFileExtension else { return }

        experiment.buffers.forEach { name, buffer in
            let bufferURL = url.appendingPathComponent(name).appendingPathExtension(bufferContentsFileExtension)
            if FileManager.default.fileExists(atPath: bufferURL.path) {
                try? buffer.readState(from: bufferURL)
            }
        }
    }
}
