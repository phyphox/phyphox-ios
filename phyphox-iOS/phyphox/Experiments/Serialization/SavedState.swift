//
//  SavedState.swift
//  phyphox
//
//  Created by Sebastian Staacks on 05.10.26.
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import Foundation
import ZIPFoundation

//The saved-state container of phyphox-docs docs/saved-states.md (phyphox 1.3.0): experiment.phyphox byte for byte as loaded,
//res/ with the referenced resources, data/index.csv plus one little-endian binary64 file per container, and meta/device.csv,
//meta/time.csv, meta/state.csv in a fixed CSV dialect. In the collection a state is kept as this tree, a
//Saved-States/<name>.phystate folder (see ExperimentSerialization); shared, it is the folder zipped. Legacy .phyphox states
//(data in init, state-title, events) are read by the ordinary parser and renamed by LegacyStateSerializer.
enum SavedState {
    static let experimentEntry = "experiment.phyphox"
    static let resourceFolder = "res"
    static let dataFolder = "data"
    static let indexEntry = "data/index.csv"
    static let deviceEntry = "meta/device.csv"
    static let timeEntry = "meta/time.csv"
    static let stateEntry = "meta/state.csv"
    static let format = 1

    private static func damaged(_ message: String) -> SerializationError {
        return SerializationError.genericError(message: "Damaged saved state: \(message)")
    }

    // MARK: - The CSV dialect (comma, dot, quoted strings, LF)

    static func quote(_ string: String) -> String {
        return "\"" + string.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    ///Rows of fields; quoted fields may contain commas, doubled quotes and (tolerated) line breaks. CRLF is accepted
    static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var wasQuoted = false
        var iterator = text.makeIterator()
        var pending: Character? = nil

        func endField() {
            row.append(field)
            field = ""
            wasQuoted = false
        }
        func endRow() {
            endField()
            //A blank line is no row (the trailing LF of the last line ends it, it does not start an empty one)
            if !(row.count == 1 && row[0].isEmpty) {
                rows.append(row)
            }
            row = []
        }

        while let character = pending ?? iterator.next() {
            pending = nil
            if quoted {
                if character == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" {
                            field.append("\"")
                        } else {
                            quoted = false
                            pending = next
                        }
                    } else {
                        quoted = false
                    }
                } else {
                    field.append(character)
                }
                continue
            }
            switch character {
            case "\"" where field.isEmpty && !wasQuoted:
                quoted = true
                wasQuoted = true
            case ",":
                endField()
            case "\n", "\r\n":
                endRow()
            case "\r":
                endRow()
            default:
                field.append(character)
            }
        }
        if !field.isEmpty || !row.isEmpty || wasQuoted {
            endRow()
        }
        return rows
    }

    ///Plain and scientific notation, NaN and the infinities in any case
    static func parseNumber(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        switch trimmed.lowercased() {
        case "nan": return Double.nan
        case "infinity", "inf", "+infinity", "+inf": return Double.infinity
        case "-infinity", "-inf": return -Double.infinity
        default: return Double(trimmed)
        }
    }

    ///Seconds with millisecond resolution, the export's system time column
    static func formatSeconds(_ seconds: Double) -> String {
        return String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), seconds)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS 'UTC'XXX"
        return formatter
    }()

    ///Scientific notation like the export's column, with the 17 significant digits that round-trip a double exactly
    static func formatExperimentTime(_ seconds: Double) -> String {
        return String(format: "%.16E", locale: Locale(identifier: "en_US_POSIX"), seconds)
    }

    // MARK: - Entry names

    ///The writer's rule for a data file name: ASCII letters, digits, _ and - kept, every other code point one _, 64 code
    ///points at most, .bin appended; a collision gets -2, -3, ... before the extension. Readers never derive this, they use the index
    static func entryName(for bufferName: String, taken: inout Set<String>) -> String {
        var base = ""
        for scalar in bufferName.unicodeScalars.prefix(64) {
            let keep = (scalar >= "a" && scalar <= "z") || (scalar >= "A" && scalar <= "Z") || (scalar >= "0" && scalar <= "9") || scalar == "_" || scalar == "-"
            base.unicodeScalars.append(keep ? scalar : "_")
        }
        var name = base + ".bin"
        var suffix = 2
        while taken.contains(name) {
            name = base + "-\(suffix).bin"
            suffix += 1
        }
        taken.insert(name)
        return name
    }

    ///A data file name from an index written elsewhere: it has to stay under data/ (checked like a resource name)
    private static func dataFileURL(_ name: String, in folder: URL) -> URL? {
        guard !name.isEmpty, !name.hasPrefix("/"), name.isSafeResourceName else { return nil }
        let data = folder.appendingPathComponent(dataFolder, isDirectory: true)
        return ExperimentsCollectionViewController.containerEntryDestination(name, in: data)
    }

    // MARK: - Writing

    ///Writes the state of `experiment` as the container tree at `folder` (which must not exist yet). Staged in a temporary
    ///folder and moved into place, so a failure leaves nothing half written. Stop the experiment first, as both apps do
    static func write(experiment: Experiment, title: String, to folder: URL) throws {
        guard let sourceFile = experiment.sourceExperimentFile else {
            throw SerializationError.genericError(message: "Source of experiment unknown.")
        }
        let experimentData: Data
        do {
            experimentData = try Data(contentsOf: sourceFile)
        } catch {
            throw SerializationError.genericError(message: "Cannot load experiment source.")
        }

        let fileManager = FileManager.default
        let staging = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }

        //The experiment file, verbatim: a legacy state keeps its state-title, events and init data (docs/saved-states.md)
        try experimentData.write(to: staging.appendingPathComponent(experimentEntry))

        //Only the referenced resources; the bundled ones (hue.png) go along too, so the container is self-contained elsewhere
        let resources = experiment.resources.filter { $0.isSafeResourceName }
        if !resources.isEmpty {
            let res = staging.appendingPathComponent(resourceFolder, isDirectory: true)
            for resource in resources {
                guard let source = experiment.resolveResource(resource) else {
                    print("Resource \(resource) not found, not written into the state.")
                    continue
                }
                let target = res.appendingPathComponent(resource)
                try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fileManager.copyItem(at: source, to: target)
            }
        }

        //All containers in ONE go under the data lock, so the state cannot catch an analysis cycle half applied
        //(ExperimentExport.snapshot, Android 2b8d7acf); the files are written outside the lock
        let order = experiment.bufferOrder.isEmpty ? experiment.buffers.keys.sorted() : experiment.bufferOrder
        let contents: [String: [Double]] = experiment.dataLock.read {
            var contents: [String: [Double]] = [:]
            for (name, buffer) in experiment.buffers {
                contents[name] = buffer.toArray()
            }
            return contents
        }
        let data = staging.appendingPathComponent(dataFolder, isDirectory: true)
        try fileManager.createDirectory(at: data, withIntermediateDirectories: true)
        var index = "\(quote("container")),\(quote("file")),\(quote("count"))\n"
        var taken = Set<String>()
        for name in order {
            guard let values = contents[name] else { continue }
            let file = entryName(for: name, taken: &taken)
            try DataBuffer.writeValues(values, to: data.appendingPathComponent(file))
            index += "\(quote(name)),\(quote(file)),\(values.count)\n"
        }
        try index.write(to: staging.appendingPathComponent(indexEntry), atomically: false, encoding: .utf8)

        let meta = staging.appendingPathComponent("meta", isDirectory: true)
        try fileManager.createDirectory(at: meta, withIntermediateDirectories: true)

        var device = "\(quote("property")),\(quote("value"))\n"
        for row in Metadata.deviceRows {
            device += "\(quote(row.property)),\(quote(row.value))\n"
        }
        try device.write(to: staging.appendingPathComponent(deviceEntry), atomically: false, encoding: .utf8)

        var time = "\(quote("event")),\(quote("experiment time")),\(quote("system time")),\(quote("system time text"))\n"
        for mapping in experiment.timeReference.timeMappings {
            time += "\(quote(mapping.event.rawValue)),\(formatExperimentTime(mapping.experimentTime)),\(formatSeconds(mapping.systemTime.timeIntervalSince1970)),\(quote(dateFormatter.string(from: mapping.systemTime)))\n"
        }
        try time.write(to: staging.appendingPathComponent(timeEntry), atomically: false, encoding: .utf8)

        let now = Date()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let state = stateCSV(properties: [
            ("format", String(format)),
            ("title", title),
            ("saved", formatSeconds(now.timeIntervalSince1970)),
            ("saved text", dateFormatter.string(from: now)),
            ("app", "phyphox \(version) (iOS)")
        ])
        try state.write(to: staging.appendingPathComponent(stateEntry), atomically: false, encoding: .utf8)

        try fileManager.createDirectory(at: folder.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.moveItem(at: staging, to: folder)
    }

    private static func stateCSV(properties: [(String, String)]) -> String {
        var csv = "\(quote("property")),\(quote("value"))\n"
        for (property, value) in properties {
            csv += "\(quote(property)),\(quote(value))\n"
        }
        return csv
    }

    ///Renaming a state in the collection rewrites the title in meta/state.csv and nothing else
    static func rename(folder: URL, title: String) throws {
        let stateFile = folder.appendingPathComponent(stateEntry)
        var rows = parseCSV(try String(contentsOf: stateFile, encoding: .utf8)).filter { $0.count >= 2 }.map { ($0[0], $0[1]) }
        rows.removeFirst() //The header
        if let i = rows.firstIndex(where: { $0.0 == "title" }) {
            rows[i].1 = title
        } else {
            rows.append(("title", title))
        }
        try stateCSV(properties: rows).write(to: stateFile, atomically: true, encoding: .utf8)
    }

    ///A new, unique Saved-States/<name>.phystate folder for a state (not created yet)
    static func newCollectionFolder(name: String) throws -> URL {
        if !FileManager.default.fileExists(atPath: savedExperimentStatesURL.path) {
            try FileManager.default.createDirectory(at: savedExperimentStatesURL, withIntermediateDirectories: true)
        }
        let base = FileNameFormat.sanitize(name)
        var folder = savedExperimentStatesURL.appendingPathComponent(base).appendingPathExtension(experimentStateFileExtension)
        var i = 1
        while FileManager.default.fileExists(atPath: folder.path) {
            folder = savedExperimentStatesURL.appendingPathComponent(base + "-\(i)").appendingPathExtension(experimentStateFileExtension)
            i += 1
        }
        return folder
    }

    ///The shareable form: the tree zipped, with the entries at the archive root
    static func zip(folder: URL, to zipURL: URL) throws {
        try? FileManager.default.removeItem(at: zipURL)
        try FileManager.default.zipItem(at: folder, to: zipURL, shouldKeepParent: false, compressionMethod: .deflate)
    }

    // MARK: - Reading

    static func isStateFolder(_ folder: URL) -> Bool {
        return FileManager.default.fileExists(atPath: folder.appendingPathComponent(stateEntry).path)
    }

    private static func properties(of file: URL) throws -> [String: String] {
        guard let text = try? String(contentsOf: file, encoding: .utf8) else {
            throw damaged("\(file.lastPathComponent) is missing or unreadable.")
        }
        var properties: [String: String] = [:]
        for row in parseCSV(text).dropFirst() where row.count >= 2 {
            properties[row[0]] = row[1]
        }
        return properties
    }

    ///Restores the state at `folder` into the freshly parsed `experiment` (docs/saved-states.md, "Loading semantics"):
    ///every indexed container's contents are replaced, a static one with data is marked filled, the time reference is
    ///rebuilt from meta/time.csv and the title taken from meta/state.csv. A damaged or unknown container is refused
    static func restore(into experiment: Experiment, from folder: URL) throws {
        let state = try properties(of: folder.appendingPathComponent(stateEntry))
        guard let formatText = state["format"], let format = Int(formatText.trimmingCharacters(in: .whitespaces)) else {
            throw damaged("meta/state.csv does not name a format.")
        }
        guard format == SavedState.format else {
            throw SerializationError.genericError(message: "This saved state uses format \(format), which this version of phyphox does not know.")
        }
        guard let title = state["title"] else {
            throw damaged("meta/state.csv has no title.")
        }

        //Both files are required; without them the container is not a saved state
        guard let timeText = try? String(contentsOf: folder.appendingPathComponent(timeEntry), encoding: .utf8) else {
            throw damaged("meta/time.csv is missing.")
        }
        guard let indexText = try? String(contentsOf: folder.appendingPathComponent(indexEntry), encoding: .utf8) else {
            throw damaged("data/index.csv is missing.")
        }

        //Validate every row before touching a buffer, so a refused state leaves nothing half restored
        var restored: [(DataBuffer, [Double])] = []
        for row in parseCSV(indexText).dropFirst() {
            guard row.count >= 3 else {
                throw damaged("a row of data/index.csv is incomplete.")
            }
            let name = row[0]
            guard let count = Int(row[2].trimmingCharacters(in: .whitespaces)), count >= 0 else {
                throw damaged("the count of \(name) is not a number.")
            }
            guard let file = dataFileURL(row[1], in: folder) else {
                throw damaged("the data file \(row[1]) of \(name) is not a file under data/.")
            }
            guard let size = (try? FileManager.default.attributesOfItem(atPath: file.path))?[.size] as? NSNumber,
                  size.intValue == count * MemoryLayout<Double>.size else {
                throw damaged("the data file of \(name) does not hold \(count) values.")
            }
            //A row naming a container the experiment does not have is ignored
            guard let buffer = experiment.buffers[name] else { continue }
            restored.append((buffer, try DataBuffer.readValues(from: file)))
        }

        var mappings: [ExperimentTimeReference.TimeMapping] = []
        for row in parseCSV(timeText).dropFirst() {
            guard row.count >= 3 else {
                throw damaged("a row of meta/time.csv is incomplete.")
            }
            //An unknown event name is skipped, so a later event type does not make this version refuse the file
            guard let event = ExperimentTimeReference.TimeMappingEvent(rawValue: row[0].uppercased()), event != .CLEAR else { continue }
            guard let experimentTime = parseNumber(row[1]), let systemSeconds = parseNumber(row[2]) else {
                throw damaged("a time of meta/time.csv is not a number.")
            }
            let systemTime = Date(timeIntervalSince1970: (systemSeconds * 1000).rounded() / 1000)
            mappings.append(ExperimentTimeReference.TimeMapping(event: event, experimentTime: experimentTime, eventTime: 0.0, systemTime: systemTime))
        }

        for (buffer, values) in restored {
            buffer.restoreState(values)
        }
        //The events block and state-title of the experiment file are ignored in favour of the CSVs
        experiment.timeReference.reset()
        for mapping in mappings {
            experiment.timeReference.appendMapping(mapping)
        }
        experiment.stateTitle = title
    }
}
