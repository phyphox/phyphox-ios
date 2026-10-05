//
//  SavedStateTests.swift
//  phyphoxTests
//
//  Created by Sebastian Staacks on 05.10.26.
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
import ZIPFoundation
@testable import phyphox

// phyphox-test: saved-state-load
// phyphox-test: saved-state-write
//The saved-state container of phyphox-docs docs/saved-states.md: the fixture through the real intake route
//(extractContainer, then ExperimentSerialization), the writer, and the round trip between the two. What the fixture must
//restore is listed in fixtures/containers/README.md
final class SavedStateTests: XCTestCase {
    private var work: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        work = FileManager.default.temporaryDirectory.appendingPathComponent("saved-state-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: work)
        try super.tearDownWithError()
    }

    // MARK: - helpers

    private func docsFile(_ directory: String, _ name: String, notice: String) throws -> URL {
        let url = try DocsCorpus.docsDirectory(directory, notTestedNotice: notice).appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("the phyphox-docs checkout has no \(directory)/\(name)")
        }
        return url
    }

    private func fixtureState() throws -> URL {
        return try docsFile("fixtures/containers", "saved-state.zip", notice: "the saved-state container")
    }

    ///The intake route: the container unpacked into a fresh directory, which for a state is one .phystate folder
    private func unpack(_ archive: URL) throws -> URL {
        let destination = work.appendingPathComponent("extracted-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let files = try ExperimentsCollectionViewController.extractContainer(at: archive, to: destination)
        XCTAssertEqual(files.count, 1, "a state is dispatched as one experiment, never through the picker")
        let folder = try XCTUnwrap(files.first)
        XCTAssertEqual(folder.pathExtension, experimentStateFileExtension, "unpacked as a state folder")
        return folder
    }

    private func load(_ archive: URL) throws -> Experiment {
        return try ExperimentSerialization.readExperimentFromURL(try unpack(archive))
    }

    ///A copy of a container with its tree edited, zipped again
    private func modified(_ archive: URL, _ edit: (URL) throws -> Void) throws -> URL {
        let tree = work.appendingPathComponent("tree-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.unzipItem(at: archive, to: tree)
        try edit(tree)
        let zip = work.appendingPathComponent("modified-\(UUID().uuidString).zip")
        try FileManager.default.zipItem(at: tree, to: zip, shouldKeepParent: false)
        return zip
    }

    private func assertValues(_ actual: [Double], _ expected: [Double], _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.count, expected.count, "\(message): \(actual) vs \(expected)", file: file, line: line)
        for (a, e) in zip(actual, expected) {
            if e.isNaN {
                XCTAssertTrue(a.isNaN, "\(message): \(actual) vs \(expected)", file: file, line: line)
            } else {
                XCTAssertEqual(a, e, "\(message): \(actual) vs \(expected)", file: file, line: line)
            }
        }
    }

    private func values(_ experiment: Experiment, _ name: String, file: StaticString = #filePath, line: UInt = #line) throws -> [Double] {
        return try XCTUnwrap(experiment.buffers[name], "the experiment has a container \(name)", file: file, line: line).toArray()
    }

    ///Every file under the folder, by its path relative to it
    private func tree(of folder: URL) throws -> [String: Data] {
        var files: [String: Data] = [:]
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey]))
        for case let url as URL in enumerator where try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            let relative = String(url.standardizedFileURL.path.dropFirst(folder.standardizedFileURL.path.count + 1))
            files[relative] = try Data(contentsOf: url)
        }
        return files
    }

    private func text(_ folder: URL, _ entry: String) throws -> String {
        return try String(contentsOf: folder.appendingPathComponent(entry), encoding: .utf8)
    }

    // MARK: - loading

    // phyphox-test: saved-state-load
    func testTheFixtureStateRestoresTitleBuffersTimeReferenceAndResource() throws {
        let archive = try fixtureState()
        XCTAssertEqual(ExperimentsCollectionViewController.detectFileType(data: try Data(contentsOf: archive)), .zip,
                       "a state is a zip to the intake, told apart by its content")
        let experiment = try load(archive)

        XCTAssertEqual(experiment.stateTitle, "Fixture state", "the title comes from meta/state.csv")
        XCTAssertEqual(experiment.displayTitle, "Fixture state")
        XCTAssertEqual(experiment.localizedTitle, "Container fixture saved state", "the experiment's own title stays the subtitle")
        XCTAssertTrue(experiment.isSavedState)

        assertValues(try values(experiment, "t"), [0, 0.5, 1, 1.5], "t")
        assertValues(try values(experiment, "x"), [1, Double.nan, -2.5, Double.infinity], "NaN and Infinity survive the binary form")
        assertValues(try values(experiment, "calibration"), [9.81], "the static buffer")
        let calibration = try XCTUnwrap(experiment.buffers["calibration"])
        calibration.append(1)
        assertValues(calibration.toArray(), [9.81], "the static buffer is marked filled, so the analysis cannot fill it again")
        assertValues(try values(experiment, "empty"), [], "empty although its file exists")
        assertValues(try values(experiment, "max x (m/s²)"), [7], "init=\"1,2,3\" replaced, the file found through the index")

        let mappings = experiment.timeReference.timeMappings
        XCTAssertEqual(mappings.count, 2)
        XCTAssertEqual(mappings.first?.event, .START)
        XCTAssertEqual(mappings.first?.experimentTime, 0)
        XCTAssertEqual(mappings.first?.systemTime.timeIntervalSince1970 ?? 0, 1759650000.000, accuracy: 1e-4)
        XCTAssertEqual(mappings.last?.event, .PAUSE)
        XCTAssertEqual(mappings.last?.experimentTime, 1.5)
        XCTAssertEqual(mappings.last?.systemTime.timeIntervalSince1970 ?? 0, 1759650001.500, accuracy: 1e-4)

        let picture = try XCTUnwrap(experiment.resolveResource("pic.png"), "the image element gets res/pic.png")
        XCTAssertEqual(Array(try Data(contentsOf: picture).prefix(4)), [0x89, 0x50, 0x4e, 0x47])
        XCTAssertFalse(experiment.running, "loading a state does not start the experiment")
    }

    // phyphox-test: saved-state-load
    func testALegacyStateStillLoads() throws {
        let url = try docsFile("corpus/generated", "events-state.phyphox", notice: "the legacy state")
        let experiment = try ExperimentSerialization.readExperimentFromURL(url)

        XCTAssertEqual(experiment.stateTitle, "Corpus saved state 2026-08-13", "title from state-title")
        XCTAssertFalse(experiment.isSavedState)
        assertValues(try values(experiment, "values"), [1, 2, 3], "data from init")
        let mappings = experiment.timeReference.timeMappings
        XCTAssertEqual(mappings.map { $0.event }, [.START, .PAUSE, .START, .PAUSE], "events from the block")
        XCTAssertEqual(mappings.map { $0.experimentTime }, [0, 5.25, 5.25, 12.5])
        XCTAssertEqual(mappings[1].systemTime.timeIntervalSince1970, 1755080005.25, accuracy: 1e-4)
    }

    // phyphox-test: saved-state-load
    func testACountThatDoesNotMatchTheFileIsRefused() throws {
        let damaged = try modified(try fixtureState()) { tree in
            let index = tree.appendingPathComponent(SavedState.indexEntry)
            let csv = try String(contentsOf: index, encoding: .utf8).replacingOccurrences(of: "\"t\",\"t.bin\",4", with: "\"t\",\"t.bin\",5")
            try csv.write(to: index, atomically: true, encoding: .utf8)
        }
        XCTAssertThrowsError(try load(damaged), "a container whose count does not match its file is damaged") { error in
            XCTAssertTrue(error.localizedDescription.contains("Damaged saved state"), error.localizedDescription)
        }
    }

    // phyphox-test: saved-state-load
    func testAStateWithoutTimeOrIndexOrWithAnUnknownFormatIsRefused() throws {
        let noTime = try modified(try fixtureState()) { tree in
            try FileManager.default.removeItem(at: tree.appendingPathComponent(SavedState.timeEntry))
        }
        XCTAssertThrowsError(try load(noTime), "meta/time.csv is required")

        let noIndex = try modified(try fixtureState()) { tree in
            try FileManager.default.removeItem(at: tree.appendingPathComponent(SavedState.indexEntry))
        }
        XCTAssertThrowsError(try load(noIndex), "data/index.csv is required")

        let newFormat = try modified(try fixtureState()) { tree in
            let state = tree.appendingPathComponent(SavedState.stateEntry)
            let csv = try String(contentsOf: state, encoding: .utf8).replacingOccurrences(of: "\"format\",\"1\"", with: "\"format\",\"2\"")
            try csv.write(to: state, atomically: true, encoding: .utf8)
        }
        XCTAssertThrowsError(try load(newFormat), "a format this version does not know is refused")

        //Android's choice where the page is silent: a state holds exactly one experiment
        let twoExperiments = try modified(try fixtureState()) { tree in
            try FileManager.default.copyItem(at: tree.appendingPathComponent(SavedState.experimentEntry), to: tree.appendingPathComponent("other.phyphox"))
        }
        let destination = work.appendingPathComponent("two", isDirectory: true)
        XCTAssertThrowsError(try ExperimentsCollectionViewController.extractContainer(at: twoExperiments, to: destination),
                             "a state container with two experiments is refused, the picker is never shown for a state")
    }

    // phyphox-test: saved-state-load
    func testAnIndexRowReachingOutsideTheDataFolderIsRefused() throws {
        let traversal = try modified(try fixtureState()) { tree in
            let index = tree.appendingPathComponent(SavedState.indexEntry)
            let csv = try String(contentsOf: index, encoding: .utf8).replacingOccurrences(of: "\"t\",\"t.bin\",4", with: "\"t\",\"../res/pic.png\",4")
            try csv.write(to: index, atomically: true, encoding: .utf8)
        }
        XCTAssertThrowsError(try load(traversal), "a data file name is checked like a resource name")
    }

    // MARK: - writing

    ///The fixture's source experiment with its picture and one unreferenced file beside it, loaded as a plain file
    private func sourceExperiment() throws -> (experiment: Experiment, file: URL) {
        let source = try docsFile("fixtures/containers/src", "saved-state.phyphox", notice: "writing a state")
        let folder = work.appendingPathComponent("source", isDirectory: true)
        let res = folder.appendingPathComponent("res", isDirectory: true)
        try FileManager.default.createDirectory(at: res, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("saved-state.phyphox")
        try FileManager.default.copyItem(at: source, to: file)
        try Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).write(to: res.appendingPathComponent("pic.png"))
        try Data([0x00]).write(to: res.appendingPathComponent("unreferenced.png"))
        return (try ExperimentSerialization.readExperimentFromURL(file), file)
    }

    ///Fills the fixture experiment the way a measurement would: data, a filled static buffer, a start and a pause
    private func measure(_ experiment: Experiment) throws {
        try XCTUnwrap(experiment.buffers["t"]).appendFromArray([0, 0.5, 1, 1.5])
        try XCTUnwrap(experiment.buffers["x"]).appendFromArray([1, Double.nan, -2.5, Double.infinity])
        let calibration = try XCTUnwrap(experiment.buffers["calibration"])
        calibration.append(9.81)
        calibration.markSet()
        try XCTUnwrap(experiment.buffers["max x (m/s²)"]).append(7) //size 3, init 1,2,3
        experiment.timeReference.registerEvent(event: .START)
        usleep(20_000)
        experiment.timeReference.registerEvent(event: .PAUSE)
    }

    // phyphox-test: saved-state-write
    func testAWrittenStateHasTheDocumentedEntriesAndDialect() throws {
        let (experiment, file) = try sourceExperiment()
        try measure(experiment)
        let folder = work.appendingPathComponent("written.phystate", isDirectory: true)
        try SavedState.write(experiment: experiment, title: "Round trip", to: folder)

        let entries = try tree(of: folder)
        XCTAssertEqual(Set(entries.keys),
                       ["experiment.phyphox", "res/pic.png", "data/index.csv", "data/t.bin", "data/x.bin", "data/calibration.bin",
                        "data/empty.bin", "data/max_x__m_s__.bin", "meta/device.csv", "meta/time.csv", "meta/state.csv"],
                       "the entry set of the docs page: only the referenced resource, one data file per container")
        XCTAssertEqual(entries["experiment.phyphox"], try Data(contentsOf: file), "the experiment file byte for byte")

        XCTAssertEqual(try text(folder, SavedState.indexEntry),
                       "\"container\",\"file\",\"count\"\n\"t\",\"t.bin\",4\n\"x\",\"x.bin\",4\n\"calibration\",\"calibration.bin\",1\n\"empty\",\"empty.bin\",0\n\"max x (m/s²)\",\"max_x__m_s__.bin\",3\n",
                       "rows in data-containers order, the writer's entry-name rule, counts")
        XCTAssertEqual(entries["data/t.bin"]?.count, 32)
        XCTAssertEqual(entries["data/empty.bin"]?.count, 0, "an empty buffer is an empty file, still listed")
        assertValues(try DataBuffer.readValues(from: folder.appendingPathComponent("data/x.bin")), [1, Double.nan, -2.5, Double.infinity], "little-endian binary64")

        for entry in [SavedState.indexEntry, SavedState.deviceEntry, SavedState.timeEntry, SavedState.stateEntry] {
            let csv = try text(folder, entry)
            XCTAssertFalse(csv.contains("\r"), "\(entry): LF line ends")
            XCTAssertFalse(csv.contains(";"), "\(entry): comma separated regardless of the export settings")
            XCTAssertTrue(csv.hasSuffix("\n"))
        }

        let time = SavedState.parseCSV(try text(folder, SavedState.timeEntry))
        XCTAssertEqual(time.count, 3, "a header and the two events")
        XCTAssertEqual(time[0], ["event", "experiment time", "system time", "system time text"])
        XCTAssertEqual(time[1][0], "START")
        XCTAssertEqual(time[2][0], "PAUSE")
        XCTAssertEqual(SavedState.parseNumber(time[1][1]), 0)
        XCTAssertNotNil(time[2][1].range(of: "^[0-9.]+E[+-]?[0-9]+$", options: .regularExpression), "experiment time in scientific notation: \(time[2][1])")
        XCTAssertEqual(SavedState.parseNumber(time[2][1]), experiment.timeReference.timeMappings[1].experimentTime, "and exact to the last digit")
        XCTAssertNotNil(time[1][2].range(of: "^[0-9]+\\.[0-9]{3}$", options: .regularExpression), "system time in seconds with three decimals: \(time[1][2])")
        XCTAssertNotNil(time[1][3].range(of: "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{3} UTC[+-][0-9]{2}:[0-9]{2}$", options: .regularExpression),
                        "system time text: \(time[1][3])")
        XCTAssertEqual(try text(folder, SavedState.timeEntry).components(separatedBy: "\n")[0], "\"event\",\"experiment time\",\"system time\",\"system time text\"")

        let state = Dictionary(uniqueKeysWithValues: SavedState.parseCSV(try text(folder, SavedState.stateEntry)).dropFirst().map { ($0[0], $0[1]) })
        XCTAssertEqual(state["format"], "1")
        XCTAssertEqual(state["title"], "Round trip")
        XCTAssertNotNil(state["saved"].flatMap { $0.range(of: "^[0-9]+\\.[0-9]{3}$", options: .regularExpression) }, "saved in seconds with three decimals")
        XCTAssertEqual(SavedState.parseNumber(state["saved"] ?? "") ?? 0, Date().timeIntervalSince1970, accuracy: 60)
        XCTAssertTrue(state["app"]?.hasPrefix("phyphox ") == true && state["app"]?.hasSuffix("(iOS)") == true, "app: \(state["app"] ?? "nil")")
        XCTAssertEqual(try text(folder, SavedState.stateEntry).components(separatedBy: "\n")[0], "\"property\",\"value\"")

        let device = SavedState.parseCSV(try text(folder, SavedState.deviceEntry))
        XCTAssertEqual(device.first, ["property", "value"])
        XCTAssertTrue(device.contains { $0.first == "version" }, "the device rows of the CSV export")
        XCTAssertFalse(device.contains { $0.first == "uniqueId" }, "but not the per-experiment id")
    }

    // phyphox-test: saved-state-write
    func testAWrittenStateReadsBackEqual() throws {
        let (experiment, _) = try sourceExperiment()
        try measure(experiment)
        let folder = work.appendingPathComponent("round-trip.phystate", isDirectory: true)
        try SavedState.write(experiment: experiment, title: "Round trip", to: folder)

        let restored = try ExperimentSerialization.readExperimentFromURL(folder)
        XCTAssertEqual(restored.stateTitle, "Round trip")
        for name in experiment.bufferOrder {
            assertValues(try values(restored, name), try values(experiment, name), "container \(name)")
        }
        XCTAssertEqual(restored.bufferOrder, experiment.bufferOrder)
        let calibration = try XCTUnwrap(restored.buffers["calibration"])
        calibration.append(1)
        assertValues(calibration.toArray(), [9.81], "the static buffer is filled again")
        let maxX = try XCTUnwrap(restored.buffers["max x (m/s²)"])
        maxX.append(8)
        assertValues(maxX.toArray(), [3, 7, 8], "a plain buffer keeps taking values")

        let written = experiment.timeReference.timeMappings
        let read = restored.timeReference.timeMappings
        XCTAssertEqual(read.map { $0.event }, written.map { $0.event })
        XCTAssertEqual(read.map { $0.experimentTime }, written.map { $0.experimentTime })
        for (r, w) in zip(read, written) {
            XCTAssertEqual(r.systemTime.timeIntervalSince1970, w.systemTime.timeIntervalSince1970, accuracy: 0.0011, "system time to the millisecond")
        }
        XCTAssertNotNil(restored.resolveResource("pic.png"))
        XCTAssertEqual(restored.resolveResource("pic.png")?.standardizedFileURL.path, folder.appendingPathComponent("res/pic.png").standardizedFileURL.path,
                       "resolved from the state's res/")
        XCTAssertNil(restored.resolveResource("unreferenced.png"))
        XCTAssertEqual(restored.crc32, experiment.crc32, "the CRC32 is the experiment file's, as for the plain experiment")
    }

    // phyphox-test: saved-state-write
    func testTheSharedZipLoadsAsAState() throws {
        let (experiment, _) = try sourceExperiment()
        try measure(experiment)
        let folder = work.appendingPathComponent("to-share.phystate", isDirectory: true)
        try SavedState.write(experiment: experiment, title: "Shared", to: folder)
        let zip = work.appendingPathComponent("Shared.zip")
        try SavedState.zip(folder: folder, to: zip)

        let archive = try Archive(url: zip, accessMode: .read)
        XCTAssertEqual(Set(archive.filter { $0.type == .file }.map { $0.path }), Set(try tree(of: folder).keys), "the tree at the archive root")

        let restored = try load(zip)
        XCTAssertEqual(restored.stateTitle, "Shared")
        assertValues(try values(restored, "x"), [1, Double.nan, -2.5, Double.infinity], "x")
        XCTAssertEqual(restored.timeReference.timeMappings.count, 2)
    }

    // phyphox-test: saved-state-write
    func testALegacyStatesExperimentFileIsCopiedAsIs() throws {
        let url = try docsFile("corpus/generated", "events-state.phyphox", notice: "re-saving a legacy state")
        let experiment = try ExperimentSerialization.readExperimentFromURL(url)
        let folder = work.appendingPathComponent("legacy.phystate", isDirectory: true)
        try SavedState.write(experiment: experiment, title: "Re-saved", to: folder)

        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent(SavedState.experimentEntry)), try Data(contentsOf: url),
                       "state-title, events and init data included; nothing is stripped")
        XCTAssertFalse(try tree(of: folder).keys.contains { $0.hasPrefix("res/") }, "an experiment that references nothing has no res/")

        let restored = try ExperimentSerialization.readExperimentFromURL(folder)
        XCTAssertEqual(restored.stateTitle, "Re-saved", "the CSV wins over the file's state-title")
        XCTAssertEqual(restored.timeReference.timeMappings.map { $0.experimentTime }, [0, 5.25, 5.25, 12.5], "and over its events block, which here say the same")
        assertValues(try values(restored, "values"), [1, 2, 3], "the data the legacy init carried")
    }

    // phyphox-test: saved-state-write
    func testRenamingRewritesOnlyTheStateFile() throws {
        let (experiment, _) = try sourceExperiment()
        try measure(experiment)
        let folder = work.appendingPathComponent("renamed.phystate", isDirectory: true)
        try SavedState.write(experiment: experiment, title: "Before", to: folder)
        let before = try tree(of: folder)

        try SavedState.rename(folder: folder, title: "After, with \"quotes\"")
        let after = try tree(of: folder)

        XCTAssertEqual(Set(before.keys), Set(after.keys))
        for (entry, data) in before where entry != SavedState.stateEntry {
            XCTAssertEqual(after[entry], data, "\(entry) is untouched by a rename")
        }
        XCTAssertTrue(try text(folder, SavedState.stateEntry).contains("\"title\",\"After, with \"\"quotes\"\"\"\n"), "the quote doubled")
        XCTAssertEqual(try ExperimentSerialization.readExperimentFromURL(folder).stateTitle, "After, with \"quotes\"")
    }

    // phyphox-test: saved-state-write
    func testTheEntryNameRule() {
        var taken = Set<String>()
        XCTAssertEqual(SavedState.entryName(for: "max x (m/s²)", taken: &taken), "max_x__m_s__.bin")
        XCTAssertEqual(SavedState.entryName(for: "max_x__m_s__", taken: &taken), "max_x__m_s__-2.bin", "a collision gets -2")
        XCTAssertEqual(SavedState.entryName(for: "max x (m/s^)", taken: &taken), "max_x__m_s__-3.bin", "then -3")
        XCTAssertEqual(SavedState.entryName(for: String(repeating: "a", count: 70), taken: &taken), String(repeating: "a", count: 64) + ".bin", "64 characters at most")
        XCTAssertEqual(SavedState.entryName(for: "a😀b", taken: &taken), "a_b.bin", "a supplementary character is one code point, one underscore")
        XCTAssertEqual(SavedState.entryName(for: "acc-time_1", taken: &taken), "acc-time_1.bin", "letters, digits, _ and - stay")
    }

    func testTheCSVDialectParser() {
        XCTAssertEqual(SavedState.parseCSV("\"a\",\"b\"\n\"x,y\",\"say \"\"hi\"\"\"\n1.5E0,NaN\r\n"),
                       [["a", "b"], ["x,y", "say \"hi\""], ["1.5E0", "NaN"]])
        XCTAssertEqual(SavedState.parseNumber("1.5E0"), 1.5)
        XCTAssertEqual(SavedState.parseNumber("1.5e+00"), 1.5)
        XCTAssertEqual(SavedState.parseNumber("-Infinity"), -Double.infinity)
        XCTAssertEqual(SavedState.parseNumber("infinity"), Double.infinity)
        XCTAssertTrue(SavedState.parseNumber("nan")?.isNaN == true)
        XCTAssertNil(SavedState.parseNumber("1,5"))
    }
}
