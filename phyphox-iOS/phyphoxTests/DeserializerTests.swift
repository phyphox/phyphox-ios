//
//  DeserializerTests.swift
//  phyphoxTests
//
//  Created by Jonas Gessner on 15.06.18.
//  Copyright © 2018 Jonas Gessner. All rights reserved.
//

import Foundation
import Network
import XCTest
@testable import phyphox

/// Enum modeling deserialization results
private enum XMLParseResult {
    case failure
    case success
}

private enum DeserializerTestError: Error {
    case nilOptional
}

private extension Optional {
    func unwrap() throws -> Wrapped {
        switch self {
        case .some(let wrapped):
            return wrapped
        case .none:
            throw DeserializerTestError.nilOptional
        }
    }
}

/// Returns the test bundle
var testBundle: Bundle {
    return Bundle(for: DeserializerTests.self)
}

/// Tests for the experiment deserializer. These tests ensure that both `DocumentParser` and the phyphox-specific element handlers (`PhyphoxDocumentHandler` & co) work properly. This class tests whether correct experiment files are deserialized properly and whether incorrect files are properly detected as incorrect.
final class DeserializerTests: XCTestCase {
    private let experimentsBaseURL = testBundle.url(forResource: "phyphox-experiments", withExtension: nil)!

    /// Helper method that deserializes an experiment from an input stream using a `ResultElementHandler` and verifies that the result is the expected result (success or failure). In the case of success, the deserialized experiment is returned.
    @discardableResult private func expectParserResult<Handler: ResultElementHandler>(expectedResult: XMLParseResult, inputStream: InputStream, parser: DocumentParser<Handler>, file: String = "") throws -> Handler.Result? {
        switch expectedResult {
        case .failure:
            do {
               let result = try parser.parse(stream: inputStream)
                XCTFail("Expected parsing to fail for \(file)")
                return result
            }
            catch {
                return nil
            }
        case .success:
            do {
                return try parser.parse(stream: inputStream)
            }
            catch {
                XCTFail("Expected parsing to succeed for \(file), but it threw: \(error)")
                return nil
            }
        }
    }

    /// This test case deserializes all default experiment, ensuring that the deserializer successfully deserializes them without throwing an error. Also tests that reusing the same parser and using a fresh parser produces the same result.
    func testDefaultExperimentsAndReuse() throws {
        //The experiments folder also holds a license, a readme and image resources, so
        //only files with the phyphox extension are parsed, including those in subfolders.
        let enumerator = try FileManager.default.enumerator(at: experimentsBaseURL, includingPropertiesForKeys: nil).unwrap()
        let experiments = enumerator.compactMap({ $0 as? URL }).filter({ $0.pathExtension == "phyphox" })

        let reusableParser = DocumentParser(documentHandler: PhyphoxDocumentHandler())

        for url in experiments {
            let file = url.lastPathComponent

            let stream1 = try InputStream(url: url).unwrap()
            let stream2 = try InputStream(url: url).unwrap()

            let oneTimeUseParser = DocumentParser(documentHandler: PhyphoxDocumentHandler())

            let reuse = try expectParserResult(expectedResult: .success, inputStream: stream1, parser: reusableParser, file: file)
            let oneTime = try expectParserResult(expectedResult: .success, inputStream: stream2, parser: oneTimeUseParser, file: file)

            XCTAssertEqual(reuse, oneTime, "Parses of \(file) with a reused and a fresh parser differ")
        }
    }

    /// Tests whether an invalid input stream correctly triggers an error. Tests a fresh parser and a parser that has already been used to create a valid output.
    func testInvalidStream() throws {
        let experiments = try FileManager.default.contentsOfDirectory(atPath: experimentsBaseURL.path).filter({ $0.hasSuffix(".phyphox") })

        let usedParser = DocumentParser(documentHandler: PhyphoxDocumentHandler())

        guard let anyFile = experiments.first else { XCTFail(); return }

        let streamValid = try InputStream(url: experimentsBaseURL.appendingPathComponent(anyFile)).unwrap()

        try expectParserResult(expectedResult: .success, inputStream: streamValid, parser: usedParser)

        let invalidStream1 = try InputStream(fileAtPath: UUID().uuidString).unwrap()
        let invalidStream2 = try InputStream(fileAtPath: UUID().uuidString).unwrap()

        try expectParserResult(expectedResult: .failure, inputStream: invalidStream1, parser: usedParser)
        try expectParserResult(expectedResult: .failure, inputStream: invalidStream2, parser: DocumentParser(documentHandler: PhyphoxDocumentHandler()))
    }

    /// This test case deserializes an experiment file that exercises the full element/attribute
    /// surface of the format in one document. The original version compared the parsed result
    /// against a hard-coded experiment, but that comparison was not maintained as the model types
    /// evolved; successful parsing still pins the accepted surface, so any element or attribute
    /// that stops being accepted makes this test fail.
    func testFullSkeleton() throws {
        let skeleton = try testBundle.path(forResource: "full-skeleton", ofType: "phyphox").unwrap()

        let parser = DocumentParser(documentHandler: PhyphoxDocumentHandler())

        try expectParserResult(expectedResult: .success, inputStream: InputStream(fileAtPath: skeleton).unwrap(), parser: parser)
    }

    /// This test case attempts to deserialize experiment files that are incorrectly formatted. This test ensures that PhyphoxDocumentHandler and child handlers properly handle incorrect files and throw an error when attempting to deserialize these incorrect files. Also tests that reusing the same parser and using a fresh parser produces the same result.
    func testIncorrectFilesAndReuse() throws {
        let experimentsURL = try testBundle.url(forResource: "incorrect-files", withExtension: nil).unwrap()
        let experiments = try FileManager.default.contentsOfDirectory(atPath: experimentsURL.path)

        let reusableParser = DocumentParser(documentHandler: PhyphoxDocumentHandler())

        for file in experiments {
            let url = experimentsURL.appendingPathComponent(file)

            let stream1 = try InputStream(url: url).unwrap()
            let stream2 = try InputStream(url: url).unwrap()

            let oneTimeUseParser = DocumentParser(documentHandler: PhyphoxDocumentHandler())

            let reuse = try expectParserResult(expectedResult: .failure, inputStream: stream1, parser: reusableParser, file: file)
            let oneTime = try expectParserResult(expectedResult: .failure, inputStream: stream2, parser: oneTimeUseParser, file: file)

            XCTAssertEqual(reuse, oneTime)
        }
    }
}

//The decided translated-link semantics (specified in phyphox-docs): the label is
//a required key, a matching translated link replaces the base link in place, an unmatched label
//is appended, a label-only link removes the base link, the translation attribute holds the
//displayed text and highlight is inherited where not explicitly set. The invalid forms (missing
//label, duplicate labels, unmatched label without URL, translation attribute or empty URL at the
//root) are covered by the incorrect-files fixtures.
final class TranslatedLinkTests: XCTestCase {
    //The conformance fixture from phyphox-docs (corpus/generated/translated-links.phyphox)
    //exercises every form of a translated link in one document
    private func parseFixture() throws -> Experiment {
        let path = try testBundle.path(forResource: "translated-links", ofType: "phyphox").unwrap()
        return try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: InputStream(fileAtPath: path).unwrap())
    }

    func testFixtureParsesIntoTranslatedLinks() throws {
        let experiment = try parseFixture()
        let de = try (experiment.translation?.translations["de"]).unwrap()
        XCTAssertEqual(de.translatedLinks, [
            ExperimentTranslatedLink(label: "Wiki", translation: "Wiki (deutsch)", url: URL(string: "https://phyphox.org/de/wiki"), highlighted: true),
            ExperimentTranslatedLink(label: "Contact", translation: "Kontakt", url: nil, highlighted: nil),
            ExperimentTranslatedLink(label: "Survey", translation: nil, url: nil, highlighted: nil),
            ExperimentTranslatedLink(label: "Impressum", translation: nil, url: URL(string: "https://example.org/impressum"), highlighted: nil)
        ])
    }

    func testLinkLocalization() throws {
        //Applying the fixture's de block to its base links (done manually here because the block
        //selected at runtime depends on the test host's locale): full replacement in place,
        //text-only change with inherited URL and highlight, removal, appended addition
        let experiment = try parseFixture()
        let de = try (experiment.translation?.translations["de"]).unwrap()
        let base = [
            ExperimentLink(label: "Wiki", url: URL(string: "https://phyphox.org/wiki")!, highlighted: true),
            ExperimentLink(label: "Contact", url: URL(string: "https://example.org/contact")!, highlighted: false),
            ExperimentLink(label: "Survey", url: URL(string: "https://example.org/survey")!, highlighted: false)
        ]
        XCTAssertEqual(ExperimentLink.localizedLinks(base: base, translatedLinks: de.translatedLinks), [
            ExperimentLink(label: "Wiki (deutsch)", url: URL(string: "https://phyphox.org/de/wiki")!, highlighted: true),
            ExperimentLink(label: "Kontakt", url: URL(string: "https://example.org/contact")!, highlighted: false),
            ExperimentLink(label: "Impressum", url: URL(string: "https://example.org/impressum")!, highlighted: false)
        ])

        //Without a translation the base links pass through unchanged - in particular the label
        //is displayed as written, with no string-translation or [[...]] common-string expansion
        XCTAssertEqual(ExperimentLink.localizedLinks(base: base, translatedLinks: []), base)
    }

    func testHighlightExplicitValuesWinOverInheritance() {
        let base = [ExperimentLink(label: "Wiki", url: URL(string: "https://phyphox.org/wiki")!, highlighted: true)]
        //An explicit highlight="false" on a replacement overrides the base link's true...
        var localized = ExperimentLink.localizedLinks(base: base, translatedLinks: [
            ExperimentTranslatedLink(label: "Wiki", translation: nil, url: nil, highlighted: false)
        ])
        XCTAssertEqual(localized, [ExperimentLink(label: "Wiki", url: URL(string: "https://phyphox.org/wiki")!, highlighted: false)])

        //...and an added link may set it explicitly instead of the false default
        localized = ExperimentLink.localizedLinks(base: base, translatedLinks: [
            ExperimentTranslatedLink(label: "Hilfe", translation: nil, url: URL(string: "https://example.org/hilfe"), highlighted: true)
        ])
        XCTAssertEqual(localized.last, ExperimentLink(label: "Hilfe", url: URL(string: "https://example.org/hilfe")!, highlighted: true))
    }
}

//Regression test for the analysis deadlock that broke the tone generator: input view
//modules (sliders, edit fields) write their initial values with a user-input trigger while the
//view is being built, i.e. before the experiment assigned the analysis queue. The triggered run
//could then never execute and its busy flag blocked all analysis permanently.
final class AnalysisTriggerTests: XCTestCase {
    func testEarlyUserInputTriggerDoesNotDeadlockAnalysis() throws {
        let url = testBundle.url(forResource: "phyphox-experiments", withExtension: nil)!.appendingPathComponent("tone_generator.phyphox")
        let experiment = try ExperimentSerialization.readExperimentFromURL(url)
        let signal = try experiment.buffers["signal"].unwrap()

        //Simulate an input view module writing its initial value during view construction
        let sliderBuffer = try experiment.buffers["a1in"].unwrap()
        sliderBuffer.replaceValues([1.0])
        sliderBuffer.triggerUserInput()

        //The pre-run as done by willBecomeActive must still fill the preview graph buffers
        experiment.analysis.setNeedsUpdate(isPreRun: true)
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline && signal.count == 0 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertGreaterThan(signal.count, 0, "analysis deadlocked: pre-run produced no data")

        let a1_wf1A = try experiment.buffers["a1_wf1A"].unwrap()
        XCTAssertEqual(a1_wf1A.last, 0.5, "unexpected sine amplitude for default settings")
    }
}

//Verifies that every remote-access response carries the CORS header, matching the Android
//implementation and the canonical decision in phyphox-docs (cors-header): the header must be
//present without exception, including on error responses and the static web interface files.
final class WebServerCORSTests: XCTestCase {
    private class StubDelegate: ExperimentWebServerDelegate {
        var timerRunning: Bool { return false }
        var remainingTimerTime: Double { return 0.0 }
        func startExperiment() {}
        func stopExperiment() {}
        func clearData(clearGroups: [String]) {}
        func buttonPressed(viewDescriptor: ButtonViewDescriptor, buttonViewTriggerCallback: ButtonViewTriggerCallback?) {}
        func runExport(_ export: ExperimentExport, singleSet: Bool, format: ExportFileFormat, completion: @escaping (NSError?, URL?) -> Void) {}
    }

    func testCORSHeaderOnEveryResponse() throws {
        let url = testBundle.url(forResource: "phyphox-experiments", withExtension: nil)!.appendingPathComponent("accelerometer.phyphox")
        let experiment = try ExperimentSerialization.readExperimentFromURL(url)

        UserDefaults.standard.set("8967", forKey: "remoteAccessPort")
        defer { UserDefaults.standard.removeObject(forKey: "remoteAccessPort") }

        let delegate = StubDelegate()
        let webServer = ExperimentWebServer(experiment: experiment, delegate: delegate)
        XCTAssertTrue(webServer.start(), "web server did not start")
        defer { webServer.stop() }

        //Success paths (API, static file) and error paths (missing parameters, unknown path)
        for path in ["/", "/time", "/config", "/meta", "/get", "/res", "/doesnotexist"] {
            let requestURL = URL(string: "http://127.0.0.1:\(webServer.port)\(path)")!
            let expectation = self.expectation(description: path)
            var corsValue: String? = nil
            var status = 0
            URLSession.shared.dataTask(with: requestURL) { _, response, _ in
                if let http = response as? HTTPURLResponse {
                    status = http.statusCode
                    corsValue = http.allHeaderFields["Access-Control-Allow-Origin"] as? String
                }
                expectation.fulfill()
            }.resume()
            waitForExpectations(timeout: 5)
            XCTAssertEqual(corsValue, "*", "missing CORS header on \(path) (status \(status))")
        }
    }
}

//Pins the followX support of the remote interface: a graph with followX generates JS that
//anchors the window end at the newest x value while keeping the width from minX/maxX,
//mirroring the Android implementation (ExpView.dataCompleteHTML).
final class RemoteGraphFollowXTests: XCTestCase {
    func testFollowXGeneratesAnchoredRescale() throws {
        let skeleton = try testBundle.path(forResource: "full-skeleton", ofType: "phyphox").unwrap()
        let experiment = try ExperimentSerialization.readExperimentFromURL(URL(fileURLWithPath: skeleton))
        let graphs = (experiment.viewDescriptors ?? []).flatMap { $0.views }.compactMap { $0 as? GraphViewDescriptor }
        let followGraph = try graphs.first(where: { $0.followX }).unwrap()
        let js = followGraph.generateDataCompleteHTMLWithID(1)
        XCTAssertTrue(js.contains("ticks.min = maxX - 10.0;"), "followX rescale must anchor the window end at the newest x")
        XCTAssertTrue(js.contains("\"min\":0.0, \"max\":10.0"), "followX must keep the initial range from the attributes")
    }
}

//Foreign XML namespaces (i.e. editor metadata embedded in an experiment file) must be skipped
//with their entire subtree instead of failing the whole file, matching the Android parser.
final class ForeignNamespaceTests: XCTestCase {
    func testForeignNamespaceElementsAreSkipped() throws {
        let xml = """
        <phyphox version="1.6" xmlns:editor="http://example.org/editor-metadata">
            <editor:meta created="today"><editor:block id="4">nested content</editor:block></editor:meta>
            <title>nstest</title>
            <category>test</category>
            <description>foreign namespace test<editor:note>not part of the description</editor:note></description>
            <data-containers>
                <container>buffer</container>
                <editor:layout x="1" y="2"/>
            </data-containers>
            <views>
                <view label="v">
                    <editor:hint>irrelevant</editor:hint>
                    <value label="l"><input>buffer</input></value>
                </view>
            </views>
        </phyphox>
        """
        let stream = InputStream(data: xml.data(using: .utf8)!)
        let experiment = try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: stream)
        XCTAssertEqual(experiment.title, "nstest")
        XCTAssertEqual(experiment.localizedDescription, "foreign namespace test", "foreign element text must not leak into surrounding text content")
        XCTAssertNotNil(experiment.buffers["buffer"])
        XCTAssertEqual(experiment.buffers.count, 1)
    }
}

//Pins the bundled-asset fallback: an externally loaded experiment that references an image
//shipped with phyphox (hue.png) without delivering it alongside the file must resolve it from
//the app bundle, matching the Android implementation.
final class ResourceFallbackTests: XCTestCase {
    func testBundledImageFallback() throws {
        let xml = """
        <phyphox version="1.14">
            <title>restest</title>
            <category>test</category>
            <description>d</description>
            <views>
                <view label="v">
                    <image src="hue.png"/>
                </view>
            </views>
        </phyphox>
        """
        let stream = InputStream(data: xml.data(using: .utf8)!)
        let experiment = try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: stream)
        XCTAssertEqual(experiment.resources, ["hue.png"])
        //No source is set, so there is no res folder next to the file - the bundled image must be found
        let resolved = try experiment.resolveResource("hue.png").unwrap()
        XCTAssertTrue(resolved.path.hasSuffix("phyphox-experiments/res/hue.png"))
        XCTAssertNil(experiment.resolveResource("doesnotexist.png"))
    }

    func testPathTraversalIsRefused() throws {
        let xml = """
        <phyphox version="1.14">
            <title>restest</title>
            <category>test</category>
            <description>d</description>
            <views>
                <view label="v">
                    <image src="../../hue.png"/>
                </view>
            </views>
        </phyphox>
        """
        let stream = InputStream(data: xml.data(using: .utf8)!)
        let experiment = try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: stream)
        //Even though the file declares it as a resource, traversal must not resolve - the
        //target of the traversal (phyphox-experiments/hue.png relative to the bundled res
        //folder... anything at all) must stay unreachable
        XCTAssertNil(experiment.resolveResource("../../hue.png"))
        XCTAssertNil(experiment.resolveResource("res/../../hue.png"))
    }
}

//Validates the xlsx export (which replaced the JXLS xls export): the file must be a valid zip
//with the expected OOXML parts, all parts must be well-formed XML, and cell content must match
//the Android implementation, including string escaping, the NaN filler for short columns and
//sheet name sanitization.
import ZIPFoundation

final class XlsxExportTests: XCTestCase {
    private func entryString(_ archive: Archive, _ path: String) throws -> String {
        let entry = try XCTUnwrap(archive[path], "missing entry \(path)")
        var data = Data()
        _ = try archive.extract(entry) { data.append($0) }
        //Every part must be well-formed XML
        let parser = XMLParser(data: data)
        XCTAssertTrue(parser.parse(), "entry \(path) is not well-formed XML: \(String(describing: parser.parserError))")
        return try XCTUnwrap(String(data: data, encoding: .utf8))
    }

    func testXlsxExport() throws {
        let b1 = try DataBuffer(name: "x", size: 5, baseContents: [1.0, 2.5, Double.nan], static: false)
        let b2 = try DataBuffer(name: "y", size: 5, baseContents: [4.0], static: false)
        let set1 = ExperimentExportSet(name: "Data <&> [test]", data: [(name: "=danger", buffer: b1), (name: "y \"quoted\"", buffer: b2)])
        let set2 = ExperimentExportSet(name: "Data <&> [test]", data: [(name: "x", buffer: b1)]) //Same name: must be deduplicated
        let export = ExperimentExport(sets: [set1, set2])

        let expectation = self.expectation(description: "export")
        var exportURL: URL? = nil
        export.runExport(.excel, singleSet: false, filename: "xlsxtest", timeReference: nil) { errorMessage, fileURL in
            XCTAssertNil(errorMessage)
            exportURL = fileURL
            expectation.fulfill()
        }
        waitForExpectations(timeout: 10)

        let url = try XCTUnwrap(exportURL)
        XCTAssertEqual(url.pathExtension, "xlsx")
        let archive = try Archive(url: url, accessMode: .read)

        for path in ["_rels/.rels", "[Content_Types].xml", "xl/workbook.xml", "xl/_rels/workbook.xml.rels", "xl/styles.xml", "xl/worksheets/sheet1.xml", "xl/worksheets/sheet2.xml", "xl/worksheets/sheet3.xml"] {
            _ = try entryString(archive, path)
        }

        let workbook = try entryString(archive, "xl/workbook.xml")
        //Sheet name: forbidden characters replaced, xml escaping applied, duplicate deduplicated
        XCTAssertTrue(workbook.contains("name=\"Data &lt;&amp;&gt;  test\""), "unexpected sheet names: \(workbook)")
        XCTAssertTrue(workbook.contains("name=\"Data &lt;&amp;&gt;  test (2)\""), "duplicate sheet name not deduplicated: \(workbook)")
        XCTAssertTrue(workbook.contains("name=\"Metadata Device\""))

        let sheet1 = try entryString(archive, "xl/worksheets/sheet1.xml")
        //Formula injection guard and bold header
        XCTAssertTrue(sheet1.contains("<c t=\"inlineStr\" s=\"1\"><is><t xml:space=\"preserve\">'=danger</t></is></c>"))
        XCTAssertTrue(sheet1.contains("y &quot;quoted&quot;"))
        //Numbers as number cells, NaN (both as value and as missing cell of the short column) as text
        XCTAssertTrue(sheet1.contains("<c><v>1.0</v></c>"))
        XCTAssertTrue(sheet1.contains("<c><v>2.5</v></c>"))
        XCTAssertTrue(sheet1.contains("<c t=\"inlineStr\"><is><t xml:space=\"preserve\">NaN</t></is></c>"))
        //Three data rows: the row count follows the first column
        XCTAssertEqual(sheet1.components(separatedBy: "<row>").count - 1, 4)
    }
}

//Pins the fix for sinh/cosh/tanh being mapped to the trigonometric modules: the classMap must
//resolve the hyperbolic module names to the hyperbolic implementations.
final class HyperbolicModuleTests: XCTestCase {
    func testHyperbolicNamesResolveToHyperbolicModules() {
        XCTAssertTrue(ExperimentAnalysisFactory.classMap["sinh"] == SinhAnalysis.self)
        XCTAssertTrue(ExperimentAnalysisFactory.classMap["cosh"] == CoshAnalysis.self)
        XCTAssertTrue(ExperimentAnalysisFactory.classMap["tanh"] == TanhAnalysis.self)
    }
}

//Pins the /export error handling: an out-of-range format index used to trap the app, a missing
//or non-numeric format silently became Excel. Both must answer the documented error object with
//the same messages as Android (export-invalid-format).
final class WebServerExportFormatTests: XCTestCase {
    private class StubDelegate: ExperimentWebServerDelegate {
        var timerRunning: Bool { return false }
        var remainingTimerTime: Double { return 0.0 }
        func startExperiment() {}
        func stopExperiment() {}
        func clearData(clearGroups: [String]) {}
        func buttonPressed(viewDescriptor: ButtonViewDescriptor, buttonViewTriggerCallback: ButtonViewTriggerCallback?) {}
        func runExport(_ export: ExperimentExport, singleSet: Bool, format: ExportFileFormat, completion: @escaping (NSError?, URL?) -> Void) {}
    }

    func testInvalidExportFormatAnswersError() throws {
        let url = testBundle.url(forResource: "phyphox-experiments", withExtension: nil)!.appendingPathComponent("accelerometer.phyphox")
        let experiment = try ExperimentSerialization.readExperimentFromURL(url)

        UserDefaults.standard.set("8968", forKey: "remoteAccessPort")
        defer { UserDefaults.standard.removeObject(forKey: "remoteAccessPort") }

        let delegate = StubDelegate()
        let webServer = ExperimentWebServer(experiment: experiment, delegate: delegate)
        XCTAssertTrue(webServer.start(), "web server did not start")
        defer { webServer.stop() }

        for (queryString, expectedError) in [("format=99", "Format out of range."), ("format=abc", "Invalid format."), ("", "Invalid format.")] {
            let requestURL = URL(string: "http://127.0.0.1:\(webServer.port)/export" + (queryString.isEmpty ? "" : "?" + queryString))!
            let expectation = self.expectation(description: queryString)
            var body: [String: Any]? = nil
            URLSession.shared.dataTask(with: requestURL) { data, _, _ in
                body = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
                expectation.fulfill()
            }.resume()
            waitForExpectations(timeout: 5)
            XCTAssertEqual(body?["error"] as? String, expectedError, "for query \(queryString)")
        }
    }

    //Pins the POST support (control-post): every endpoint accepts POST, the body may be JSON or
    //form-encoded, values are coerced to strings, body parameters win over query parameters and
    //a malformed JSON body answers 400. Uses the /export error surface to observe which
    //parameter reached the handler.
    func testPostBodies() throws {
        let url = testBundle.url(forResource: "phyphox-experiments", withExtension: nil)!.appendingPathComponent("accelerometer.phyphox")
        let experiment = try ExperimentSerialization.readExperimentFromURL(url)

        UserDefaults.standard.set("8969", forKey: "remoteAccessPort")
        defer { UserDefaults.standard.removeObject(forKey: "remoteAccessPort") }

        let delegate = StubDelegate()
        let webServer = ExperimentWebServer(experiment: experiment, delegate: delegate)
        XCTAssertTrue(webServer.start(), "web server did not start")
        defer { webServer.stop() }

        func post(_ path: String, body: String, contentType: String) -> (status: Int, json: [String: Any]?) {
            var request = URLRequest(url: URL(string: "http://127.0.0.1:\(webServer.port)\(path)")!)
            request.httpMethod = "POST"
            request.httpBody = body.data(using: .utf8)
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            let expectation = self.expectation(description: path + body)
            var status = 0
            var json: [String: Any]? = nil
            URLSession.shared.dataTask(with: request) { data, response, _ in
                status = (response as? HTTPURLResponse)?.statusCode ?? 0
                json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
                expectation.fulfill()
            }.resume()
            waitForExpectations(timeout: 5)
            return (status, json)
        }

        //JSON body reaches the handler, numeric scalar coerced to its string form
        var result = post("/export", body: "{\"format\": 99}", contentType: "application/json")
        XCTAssertEqual(result.json?["error"] as? String, "Format out of range.")

        //Form body reaches the handler
        result = post("/export", body: "format=abc", contentType: "application/x-www-form-urlencoded")
        XCTAssertEqual(result.json?["error"] as? String, "Invalid format.")

        //Body parameters win over query parameters of the same name
        result = post("/export?format=abc", body: "{\"format\": \"99\"}", contentType: "application/json")
        XCTAssertEqual(result.json?["error"] as? String, "Format out of range.")

        //A malformed JSON body answers 400 with a JSON error object (error-response-content-type)
        result = post("/export", body: "{format: 99", contentType: "application/json")
        XCTAssertEqual(result.status, 400)
        XCTAssertNotNil(result.json?["error"] as? String)

        //An endpoint without parameters ignores the body, even a malformed one
        result = post("/config", body: "{not json at all", contentType: "application/json")
        XCTAssertEqual(result.status, 200)
        XCTAssertNotNil(result.json?["title"])
    }
}

//Conformance of the /get, /control, /meta and /res endpoints with the canonical behaviour from
//phyphox-docs: get-no-parameters, get-invalid-threshold, get-negative-threshold,
//get-nonfinite-single-value, get-force-full-update, control-trigger-out-of-range,
//meta-missing-value-representation, res-content-type and res-fallback.
final class WebServerConformanceTests: XCTestCase {
    private class StubDelegate: ExperimentWebServerDelegate {
        var timerRunning: Bool { return false }
        var remainingTimerTime: Double { return 0.0 }
        func startExperiment() {}
        func stopExperiment() {}
        func clearData(clearGroups: [String]) {}
        func buttonPressed(viewDescriptor: ButtonViewDescriptor, buttonViewTriggerCallback: ButtonViewTriggerCallback?) {}
        func runExport(_ export: ExperimentExport, singleSet: Bool, format: ExportFileFormat, completion: @escaping (NSError?, URL?) -> Void) {}
    }

    private var webServer: ExperimentWebServer!
    private var experiment: Experiment!
    private var delegate: StubDelegate!

    override func setUpWithError() throws {
        let url = testBundle.url(forResource: "phyphox-experiments", withExtension: nil)!.appendingPathComponent("accelerometer.phyphox")
        experiment = try ExperimentSerialization.readExperimentFromURL(url)
        UserDefaults.standard.set("8970", forKey: "remoteAccessPort")
        delegate = StubDelegate()
        webServer = ExperimentWebServer(experiment: experiment, delegate: delegate)
        guard webServer.start() else { throw DeserializerTestError.nilOptional }
    }

    override func tearDown() {
        webServer.stop()
        UserDefaults.standard.removeObject(forKey: "remoteAccessPort")
    }

    private func get(_ path: String) -> (status: Int, contentType: String?, json: Any?) {
        let requestURL = URL(string: "http://127.0.0.1:\(webServer.port)\(path)")!
        let expectation = self.expectation(description: path)
        var status = 0
        var contentType: String? = nil
        var json: Any? = nil
        URLSession.shared.dataTask(with: requestURL) { data, response, _ in
            if let http = response as? HTTPURLResponse {
                status = http.statusCode
                contentType = http.allHeaderFields["Content-Type"] as? String
            }
            json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) }
            expectation.fulfill()
        }.resume()
        waitForExpectations(timeout: 5)
        return (status, contentType, json)
    }

    func testGetConformance() throws {
        //No parameters: 200 with an empty buffer object and a normal status object
        var result = get("/get")
        XCTAssertEqual(result.status, 200)
        var root = try XCTUnwrap(result.json as? [String: Any])
        XCTAssertEqual((root["buffer"] as? [String: Any])?.count, 0)
        XCTAssertNotNil((root["status"] as? [String: Any])?["session"])

        //Unparseable threshold: 400 with a JSON error object (error-response-content-type)
        result = get("/get?accX=abc")
        XCTAssertEqual(result.status, 400)
        XCTAssertEqual(result.contentType, "application/json")
        XCTAssertNotNil((result.json as? [String: Any])?["error"] as? String)

        //Negative threshold: an ordinary partial answer, not an empty one caused by a NaN nudge
        experiment.buffers["accX"]?.append(1.0)
        result = get("/get?accX=-5")
        root = try XCTUnwrap(result.json as? [String: Any])
        var buf = try XCTUnwrap((root["buffer"] as? [String: Any])?["accX"] as? [String: Any])
        XCTAssertEqual(buf["updateMode"] as? String, "partial")
        XCTAssertEqual(buf["buffer"] as? [Double], [1.0])

        //Non-finite single value: null
        experiment.buffers["accY"]?.append(Double.nan)
        result = get("/get?accY=")
        root = try XCTUnwrap(result.json as? [String: Any])
        buf = try XCTUnwrap((root["buffer"] as? [String: Any])?["accY"] as? [String: Any])
        XCTAssertEqual(buf["updateMode"] as? String, "single")
        XCTAssertTrue((buf["buffer"] as? [Any])?.first is NSNull)

        //After a clear, every requested buffer is upgraded to full, whatever it asked for
        webServer.forceFullUpdate = true
        result = get("/get?accX=12.5")
        root = try XCTUnwrap(result.json as? [String: Any])
        buf = try XCTUnwrap((root["buffer"] as? [String: Any])?["accX"] as? [String: Any])
        XCTAssertEqual(buf["updateMode"] as? String, "full")
    }

    func testControlTriggerOutOfRange() throws {
        var result = get("/control?cmd=trigger&element=999")
        XCTAssertEqual((result.json as? [String: Any])?["result"] as? Bool, false)
        result = get("/control?cmd=trigger&element=abc")
        XCTAssertEqual((result.json as? [String: Any])?["result"] as? Bool, false)
    }

    func testMetaOmitsUnavailableValues() throws {
        let result = get("/meta")
        XCTAssertEqual(result.status, 200)
        let root = try XCTUnwrap(result.json as? [String: Any])
        XCTAssertFalse(root.isEmpty)
        for (key, value) in root {
            XCTAssertFalse(value is NSNull, "null value for \(key) must be omitted instead")
        }
        XCTAssertNil(root["sensors"], "the sensors object is absent on iOS, not empty")
    }

    func testResErrorWordingAndContentType() throws {
        //A missing src answers the same error as an unknown one
        var result = get("/res")
        XCTAssertEqual((result.json as? [String: Any])?["error"] as? String, "Unknown file.")
        result = get("/res?src=doesnotexist.png")
        XCTAssertEqual((result.json as? [String: Any])?["error"] as? String, "Unknown file.")
    }
}

//The MQTT network services: the four service variants, their attributes and their validation,
//matching the Android parser (see network-mqtts-unofficial in phyphox-docs).
final class MqttNetworkServiceTests: XCTestCase {
    private func parse(connectionAttributes: String) throws -> Experiment {
        let xml = """
        <phyphox version="1.20">
            <title>mqtt test</title>
            <category>test</category>
            <description>d</description>
            <data-containers>
                <container>buffer</container>
            </data-containers>
            <views>
                <view label="v">
                    <value label="l"><input>buffer</input></value>
                </view>
            </views>
            <network>
                <connection address="broker.example.org" \(connectionAttributes) interval="1">
                    <receive id="rx">buffer</receive>
                </connection>
            </network>
        </phyphox>
        """
        let stream = InputStream(data: xml.data(using: .utf8)!)
        return try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: stream)
    }

    func testMqttCsvDefaults() throws {
        let experiment = try parse(connectionAttributes: "service=\"mqtt/csv\" conversion=\"csv\" receiveTopic=\"t\"")
        let service = try (experiment.networkConnections.first?.service as? MqttCsvService).unwrap()
        XCTAssertFalse(service is MqttTlsCsvService)
        XCTAssertFalse(service.tls)
        XCTAssertEqual(service.qos, 0)
        XCTAssertNil(service.username, "username stays nil when not given - the client must not send an empty string")
        XCTAssertNil(service.password)
        XCTAssertTrue(service.clientID.hasPrefix("phyphox_"))
        XCTAssertEqual(service.clientID.count, "phyphox_".count + 6)
        XCTAssertEqual(service.receiveTopic, "t")
        XCTAssertTrue(experiment.resources.isEmpty)
    }

    func testMqttJsonCredentialsAndPersistence() throws {
        let experiment = try parse(connectionAttributes: "service=\"mqtt/json\" conversion=\"json\" sendTopic=\"s\" username=\"u\" password=\"p\" persistence=\"true\"")
        let service = try (experiment.networkConnections.first?.service as? MqttJsonService).unwrap()
        XCTAssertFalse(service.tls)
        XCTAssertEqual(service.sendTopic, "s")
        XCTAssertEqual(service.username, "u", "username and password are optional but accepted on the plain mqtt services")
        XCTAssertEqual(service.password, "p")
        XCTAssertEqual(service.qos, 1, "persistence must select QoS 1 (at-least-once)")
        XCTAssertEqual(service.receiveTopic, "", "no receiveTopic means publish-only, not a nil crash")
    }

    func testMqttsUsesUsernameAsClientIdAndRegistersCertificate() throws {
        let experiment = try parse(connectionAttributes: "service=\"mqtts/csv\" conversion=\"csv\" username=\"u\" password=\"p\" certificate=\"ca.pem\"")
        let service = try (experiment.networkConnections.first?.service as? MqttTlsCsvService).unwrap()
        XCTAssertTrue(service.tls)
        XCTAssertEqual(service.clientID, "u")
        XCTAssertEqual(service.certificateFileName, "ca.pem")
        XCTAssertEqual(experiment.resources, ["ca.pem"], "the certificate is an experiment resource, so it is copied along when the experiment is saved")
    }

    func testMqttsJsonWithoutCertificateUsesSystemTrust() throws {
        let experiment = try parse(connectionAttributes: "service=\"mqtts/json\" conversion=\"json\" sendTopic=\"s\" username=\"u\" password=\"p\"")
        let service = try (experiment.networkConnections.first?.service as? MqttTlsJsonService).unwrap()
        XCTAssertTrue(service.tls)
        XCTAssertNil(service.certificateFileName)
        XCTAssertEqual(service.qos, 0)
        XCTAssertTrue(experiment.resources.isEmpty)
    }

    func testMqttValidation() {
        //sendTopic is mandatory for the json services
        XCTAssertThrowsError(try parse(connectionAttributes: "service=\"mqtt/json\" conversion=\"json\""))
        XCTAssertThrowsError(try parse(connectionAttributes: "service=\"mqtts/json\" conversion=\"json\" username=\"u\" password=\"p\""))
        //username and password are mandatory for the mqtts services
        XCTAssertThrowsError(try parse(connectionAttributes: "service=\"mqtts/csv\" conversion=\"csv\" password=\"p\""))
        XCTAssertThrowsError(try parse(connectionAttributes: "service=\"mqtts/csv\" conversion=\"csv\" username=\"u\""))
        XCTAssertThrowsError(try parse(connectionAttributes: "service=\"mqtts/json\" conversion=\"json\" sendTopic=\"s\" username=\"u\""))
        //a certificate name must not traverse out of the resource folder
        XCTAssertThrowsError(try parse(connectionAttributes: "service=\"mqtts/csv\" conversion=\"csv\" username=\"u\" password=\"p\" certificate=\"../../ca.pem\""))
        //unknown services are still rejected
        XCTAssertThrowsError(try parse(connectionAttributes: "service=\"mqtt/xml\" conversion=\"csv\""))
    }
}

//The wire format of the from-scratch MQTT 3.1.1 client.
final class MqttClientWireFormatTests: XCTestCase {
    func testRemainingLengthEncoding() {
        //Boundary examples from the MQTT 3.1.1 specification (section 2.2.3)
        XCTAssertEqual(Array(MqttClient.encodeRemainingLength(0)), [0x00])
        XCTAssertEqual(Array(MqttClient.encodeRemainingLength(127)), [0x7f])
        XCTAssertEqual(Array(MqttClient.encodeRemainingLength(128)), [0x80, 0x01])
        XCTAssertEqual(Array(MqttClient.encodeRemainingLength(16383)), [0xff, 0x7f])
        XCTAssertEqual(Array(MqttClient.encodeRemainingLength(16384)), [0x80, 0x80, 0x01])
        XCTAssertEqual(Array(MqttClient.encodeRemainingLength(268435455)), [0xff, 0xff, 0xff, 0x7f])
        for value in [0, 1, 127, 128, 16383, 16384, 2097151, 2097152, 268435455] {
            let encoded = MqttClient.encodeRemainingLength(value)
            let decoded = MqttClient.decodeRemainingLength(encoded)
            XCTAssertEqual(decoded?.value, value)
            XCTAssertEqual(decoded?.bytesUsed, encoded.count)
        }
        XCTAssertNil(MqttClient.decodeRemainingLength(Data([0x80])), "incomplete length must not decode")
        XCTAssertNil(MqttClient.decodeRemainingLength(Data([0x80, 0x80, 0x80, 0x80, 0x01])), "more than four length bytes are malformed")
    }

    func testConnectPacket() {
        let packet = Array(MqttClient.buildConnectPacket(clientId: "abc", username: "u", password: "p", cleanSession: true, keepAliveSeconds: 60))
        let expected: [UInt8] = [
            0x10, 21,                           //CONNECT, remaining length
            0x00, 0x04, 0x4d, 0x51, 0x54, 0x54, //protocol name "MQTT"
            0x04,                               //protocol level 4 = MQTT 3.1.1
            0xc2,                               //flags: username, password, clean session
            0x00, 0x3c,                         //keep alive 60 s
            0x00, 0x03, 0x61, 0x62, 0x63,       //client id "abc"
            0x00, 0x01, 0x75,                   //username "u"
            0x00, 0x01, 0x70                    //password "p"
        ]
        XCTAssertEqual(packet, expected)

        let anonymous = Array(MqttClient.buildConnectPacket(clientId: "abc", username: nil, password: nil, cleanSession: true, keepAliveSeconds: 60))
        XCTAssertEqual(anonymous[9], 0x02, "without credentials only the clean session flag is set")
        XCTAssertEqual(anonymous.count, 2 + 15, "without credentials the payload is just the client id")
    }

    func testPublishPacket() {
        let qos0 = Array(MqttClient.buildPublishPacket(topic: "t", payload: Data([0x68, 0x69]), qos: 0, packetId: 0))
        XCTAssertEqual(qos0, [0x30, 5, 0x00, 0x01, 0x74, 0x68, 0x69])
        let qos1 = Array(MqttClient.buildPublishPacket(topic: "t", payload: Data([0x68, 0x69]), qos: 1, packetId: 0x1234))
        XCTAssertEqual(qos1, [0x32, 7, 0x00, 0x01, 0x74, 0x12, 0x34, 0x68, 0x69])
    }

    func testSubscribePacket() {
        let packet = Array(MqttClient.buildSubscribePacket(topic: "t", qos: 0, packetId: 1))
        XCTAssertEqual(packet, [0x82, 6, 0x00, 0x01, 0x00, 0x01, 0x74, 0x00])
    }

    func testParsePublishBody() {
        let qos0 = MqttClient.parsePublishBody(Data([0x00, 0x01, 0x74, 0x68, 0x69]), qos: 0)
        XCTAssertEqual(qos0?.topic, "t")
        XCTAssertEqual(qos0?.payload, Data([0x68, 0x69]))
        let qos1 = MqttClient.parsePublishBody(Data([0x00, 0x01, 0x74, 0x12, 0x34, 0x68, 0x69]), qos: 1)
        XCTAssertEqual(qos1?.topic, "t")
        XCTAssertEqual(qos1?.packetId, 0x1234)
        XCTAssertEqual(qos1?.payload, Data([0x68, 0x69]))
        XCTAssertNil(MqttClient.parsePublishBody(Data([0x00, 0x05, 0x74]), qos: 0), "a topic length beyond the body must be rejected")
    }

    func testConnackMessages() {
        XCTAssertEqual(MqttClient.connackMessage(4), "connection refused: bad username or password")
        XCTAssertEqual(MqttClient.connackMessage(5), "connection refused: not authorized")
        XCTAssertEqual(MqttClient.connackMessage(42), "connection refused: code 42")
    }
}

//The custom CA certificate loader must accept both PEM and DER (Android's
//CertificateFactory.generateCertificate does the same).
final class MqttCertificateLoadingTests: XCTestCase {
    private let pem = """
    -----BEGIN CERTIFICATE-----
    MIIBizCCATGgAwIBAgIUWXXFLCB2LhsIhzOk4+y3Q2uFNXMwCgYIKoZIzj0EAwIw
    GjEYMBYGA1UEAwwPcGh5cGhveCB0ZXN0IENBMCAXDTI2MDgxMDA3NTQyNFoYDzIx
    MjYwNzE3MDc1NDI0WjAaMRgwFgYDVQQDDA9waHlwaG94IHRlc3QgQ0EwWTATBgcq
    hkjOPQIBBggqhkjOPQMBBwNCAARPyjajIOkcN8cymwVtKwAMSkT6wnzXBCfCbr0f
    1kT4i6GcY8Oo39OnccYsYhbnFMxblLGQVEByOCH+gKg9tg+to1MwUTAdBgNVHQ4E
    FgQUSrscLQR9Xjkv9KaNidXj2F9YXpMwHwYDVR0jBBgwFoAUSrscLQR9Xjkv9KaN
    idXj2F9YXpMwDwYDVR0TAQH/BAUwAwEB/zAKBggqhkjOPQQDAgNIADBFAiB1hkrv
    yC1vT4sTn3N8uda63G+3KSg2df3QLrB4S7FcCQIhAKt1qF7AHgMPlTEX29sxWcRB
    AZwi+JT2OKe3VZ3oU8wI
    -----END CERTIFICATE-----
    """

    private func write(_ data: Data, as name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    func testLoadsPem() throws {
        let url = try write(Data(pem.utf8), as: "phyphox-test-ca.pem")
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertNotNil(MqttService.loadCertificate(from: url))
    }

    func testLoadsDer() throws {
        let base64 = pem.components(separatedBy: .newlines).filter({ !$0.contains("CERTIFICATE") }).joined().trimmingCharacters(in: .whitespaces)
        let der = try (Data(base64Encoded: base64)).unwrap()
        let url = try write(der, as: "phyphox-test-ca.der")
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertNotNil(MqttService.loadCertificate(from: url))
    }

    func testRejectsGarbage() throws {
        let url = try write(Data("not a certificate".utf8), as: "phyphox-test-ca.txt")
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertNil(MqttService.loadCertificate(from: url))
        XCTAssertNil(MqttService.loadCertificate(from: URL(fileURLWithPath: "/nonexistent/ca.pem")))
    }
}

//Runs the from-scratch client against a minimal in-process broker on the loopback interface,
//covering a full session: CONNECT/CONNACK, SUBSCRIBE/SUBACK, an incoming QoS 1 PUBLISH (which
//the client must answer with PUBACK), and an outgoing QoS 1 publish.
final class MqttClientLoopbackTests: XCTestCase {
    private class Delegate: MqttClientDelegate {
        var onMessage: ((String, Data) -> Void)? = nil
        var onConnected: (() -> Void)? = nil
        func mqttMessage(topic: String, payload: Data) { onMessage?(topic, payload) }
        func mqttConnected() { onConnected?() }
        func mqttConnectionLost(reason: String) { }
    }

    private class FakeBroker {
        let listener: NWListener
        let queue = DispatchQueue(label: "phyphox test broker")
        private var connection: NWConnection? = nil
        private var buffer = Data()
        private var publishes: [(topic: String, payload: Data, qos: Int)] = []
        private var pubAcks: [Int] = []

        init() throws {
            listener = try NWListener(using: .tcp)
            listener.newConnectionHandler = { [weak self] connection in
                guard let self = self else { return }
                self.connection = connection
                connection.start(queue: self.queue)
                self.read(from: connection)
            }
        }

        func start(onReady: @escaping () -> Void) {
            listener.stateUpdateHandler = { state in
                if case .ready = state {
                    onReady()
                }
            }
            listener.start(queue: queue)
        }

        var port: UInt16 { listener.port?.rawValue ?? 0 }
        func receivedPublishes() -> [(topic: String, payload: Data, qos: Int)] { queue.sync { publishes } }
        func receivedPubAcks() -> [Int] { queue.sync { pubAcks } }

        func publish(topic: String, payload: Data, qos: Int, packetId: Int) {
            queue.async {
                self.send(MqttClient.buildPublishPacket(topic: topic, payload: payload, qos: qos, packetId: packetId))
            }
        }

        func stop() {
            connection?.cancel()
            listener.cancel()
        }

        private func read(from connection: NWConnection) {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
                guard let self = self, let data = data else { return }
                self.buffer.append(data)
                self.processBuffer()
                if error == nil && !isComplete {
                    self.read(from: connection)
                }
            }
        }

        private func processBuffer() {
            while buffer.count >= 2 {
                let header = buffer[buffer.startIndex]
                guard let (length, lengthBytes) = MqttClient.decodeRemainingLength(buffer.dropFirst()) else { return }
                let total = 1 + lengthBytes + length
                guard buffer.count >= total else { return }
                let body = Data(buffer.dropFirst(1 + lengthBytes).prefix(length))
                buffer = Data(buffer.dropFirst(total))
                handle(type: Int(header >> 4), flags: Int(header) & 0x0f, body: body)
            }
        }

        private func handle(type: Int, flags: Int, body: Data) {
            switch type {
            case MqttClient.CONNECT:
                send(Data([0x20, 0x02, 0x00, 0x00])) //CONNACK, accepted
            case MqttClient.SUBSCRIBE:
                send(MqttClient.buildPacket(type: MqttClient.SUBACK, flags: 0, body: body.prefix(2) + Data([0x00])))
            case MqttClient.PUBLISH:
                let qos = (flags >> 1) & 0x03
                if let publish = MqttClient.parsePublishBody(body, qos: qos) {
                    publishes.append((publish.topic, publish.payload, qos))
                    if qos == 1 {
                        send(MqttClient.buildPacket(type: MqttClient.PUBACK, flags: 0, body: Data([UInt8((publish.packetId >> 8) & 0xff), UInt8(publish.packetId & 0xff)])))
                    }
                }
            case MqttClient.PUBACK:
                pubAcks.append((Int(body[body.startIndex]) << 8) | Int(body[body.startIndex + 1]))
            case MqttClient.PINGREQ:
                send(Data([0xd0, 0x00])) //PINGRESP
            default:
                break
            }
        }

        private func send(_ data: Data) {
            connection?.send(content: data, completion: .contentProcessed({ _ in }))
        }
    }

    private func waitUntil(_ description: String, timeout: TimeInterval = 5, condition: @escaping () -> Bool) {
        let e = expectation(for: NSPredicate(block: { _, _ in condition() }), evaluatedWith: nil)
        wait(for: [e], timeout: timeout)
    }

    func testFullSession() throws {
        let broker = try FakeBroker()
        defer { broker.stop() }
        let brokerReady = expectation(description: "broker ready")
        broker.start(onReady: { brokerReady.fulfill() })
        wait(for: [brokerReady], timeout: 5)

        let delegate = Delegate()
        let connected = expectation(description: "connected")
        delegate.onConnected = { connected.fulfill() }

        let client = MqttClient(host: "127.0.0.1", port: broker.port, clientId: "test", username: "u", password: "p", cleanSession: true, keepAliveSeconds: 60, tls: nil, subscribeTopic: "rx", delegate: delegate)
        client.connect()
        defer { client.disconnect() }
        wait(for: [connected], timeout: 5)
        XCTAssertTrue(client.connected)

        waitUntil("subscribed after SUBACK") { client.subscribed }

        //Broker to client, QoS 1: the message must arrive and be acknowledged
        let messageReceived = expectation(description: "message received")
        delegate.onMessage = { topic, payload in
            XCTAssertEqual(topic, "rx")
            XCTAssertEqual(payload, Data("hello".utf8))
            messageReceived.fulfill()
        }
        broker.publish(topic: "rx", payload: Data("hello".utf8), qos: 1, packetId: 42)
        wait(for: [messageReceived], timeout: 5)
        waitUntil("incoming QoS 1 publish acknowledged") { broker.receivedPubAcks().contains(42) }

        //Client to broker, QoS 0 and QoS 1
        client.publish(topic: "tx", payload: Data("world".utf8), qos: 0)
        client.publish(topic: "tx1", payload: Data("world1".utf8), qos: 1)
        waitUntil("both publishes arrived") {
            let publishes = broker.receivedPublishes()
            return publishes.contains(where: { $0.topic == "tx" && $0.payload == Data("world".utf8) && $0.qos == 0 })
                && publishes.contains(where: { $0.topic == "tx1" && $0.payload == Data("world1".utf8) && $0.qos == 1 })
        }
    }

    func testConnackRejectionIsReported() throws {
        //A broker refusing the credentials must yield the descriptive CONNACK message
        let listener = try NWListener(using: .tcp)
        let queue = DispatchQueue(label: "phyphox test broker reject")
        var brokerConnection: NWConnection? = nil
        listener.newConnectionHandler = { connection in
            brokerConnection = connection
            connection.start(queue: queue)
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { _, _, _, _ in
                connection.send(content: Data([0x20, 0x02, 0x00, 0x04]), completion: .contentProcessed({ _ in })) //CONNACK, bad username or password
            }
        }
        let brokerReady = expectation(description: "broker ready")
        listener.stateUpdateHandler = { state in
            if case .ready = state { brokerReady.fulfill() }
        }
        listener.start(queue: queue)
        wait(for: [brokerReady], timeout: 5)
        defer {
            brokerConnection?.cancel()
            listener.cancel()
        }

        var reportedReason: String? = nil
        let rejected = expectation(description: "rejected")

        class RejectDelegate: MqttClientDelegate {
            let onLost: (String) -> Void
            init(onLost: @escaping (String) -> Void) { self.onLost = onLost }
            func mqttMessage(topic: String, payload: Data) { }
            func mqttConnected() { }
            func mqttConnectionLost(reason: String) { onLost(reason) }
        }
        var fulfilled = false
        let rejectDelegate = RejectDelegate(onLost: { reason in
            if !fulfilled {
                fulfilled = true
                reportedReason = reason
                rejected.fulfill()
            }
        })

        let client = MqttClient(host: "127.0.0.1", port: listener.port?.rawValue ?? 0, clientId: "test", username: "u", password: "wrong", cleanSession: true, keepAliveSeconds: 60, tls: nil, subscribeTopic: "", delegate: rejectDelegate)
        client.connect()
        defer { client.disconnect() }
        wait(for: [rejected], timeout: 5)
        XCTAssertEqual(reportedReason, "connection refused: bad username or password")
        XCTAssertFalse(client.connected)
    }
}

//On-device hardware test of the mqtts services against a real broker (mosquitto with a
//self-signed certificate and password authentication). These tests are skipped unless the
//broker is provided via TEST_RUNNER_ environment variables:
//  PHYPHOX_MQTT_TEST_BROKER - broker host/IP, listening on the default mqtts port 8883
//  PHYPHOX_MQTT_TEST_CA     - the broker certificate, PEM, base64-encoded
//The expected broker credentials are phyphox/testpass. Run against a device to exercise the
//real network stack; the same test on the simulator is a dry run on the host.
final class MqttHardwareTests: XCTestCase {
    private struct BrokerEnv {
        let host: String
        let ca: Data
    }

    //The service holds its experiment weakly (in the app the experiment owns the connection), so
    //the tests must keep the parsed experiments alive for certificate resolution to work
    private var retainedExperiments: [Experiment] = []

    override func tearDown() {
        retainedExperiments = []
        super.tearDown()
    }

    private func brokerEnv() throws -> BrokerEnv {
        guard let host = ProcessInfo.processInfo.environment["PHYPHOX_MQTT_TEST_BROKER"],
              let caBase64 = ProcessInfo.processInfo.environment["PHYPHOX_MQTT_TEST_CA"],
              let ca = Data(base64Encoded: caBase64) else {
            throw XCTSkip("No test broker configured (PHYPHOX_MQTT_TEST_BROKER / PHYPHOX_MQTT_TEST_CA).")
        }
        return BrokerEnv(host: host, ca: ca)
    }

    private func makeExperiment(password: String, certificate: String, ca: Data) throws -> (Experiment, MqttTlsJsonService) {
        let xml = """
        <phyphox version="1.20">
            <title>mqtts hardware test</title>
            <category>test</category>
            <description>d</description>
            <data-containers>
                <container>tx</container>
                <container>rx</container>
            </data-containers>
            <views>
                <view label="v"><value label="l"><input>rx</input></value></view>
            </views>
            <network>
                <connection address="placeholder" service="mqtts/json" conversion="json" sendTopic="phyphox/hwtest" receiveTopic="phyphox/hwtest" username="phyphox" password="\(password)" certificate="\(certificate)" persistence="true">
                    <send id="value" datatype="number">tx</send>
                    <receive id="value" append="true">rx</receive>
                </connection>
            </network>
        </phyphox>
        """
        let stream = InputStream(data: xml.data(using: .utf8)!)
        let experiment = try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: stream)

        //Deliver the certificate the way a zip container does: a res directory next to the
        //experiment file, which is where resolveResource looks
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mqtts-hw-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("res"), withIntermediateDirectories: true)
        try ca.write(to: dir.appendingPathComponent("res").appendingPathComponent("broker.pem"))
        experiment.source = dir.appendingPathComponent("test.phyphox")
        retainedExperiments.append(experiment)

        let service = try (experiment.networkConnections.first?.service as? MqttTlsJsonService).unwrap()
        return (experiment, service)
    }

    private func waitUntil(_ description: String, timeout: TimeInterval = 20, condition: @escaping () -> Bool) {
        let e = expectation(for: NSPredicate(block: { _, _ in condition() }), evaluatedWith: nil)
        wait(for: [e], timeout: timeout)
    }

    func testTlsRoundTripAgainstRealBroker() throws {
        let env = try brokerEnv()
        let (experiment, service) = try makeExperiment(password: "testpass", certificate: "broker.pem", ca: env.ca)
        service.connect(address: env.host) //no port: also exercises the 8883 default
        defer { service.disconnect() }
        waitUntil("connected and subscribed over TLS") { service.getState() == .success }

        //Write a value and execute: the JSON publish (QoS 1, persistence is set) goes to the
        //broker, which routes it straight back via our subscription on the same topic
        let connection = try (experiment.networkConnections.first).unwrap()
        if case .Buffer(let buffer, _) = try (connection.send["value"]?.source).unwrap() {
            buffer.append(42.25)
        } else {
            XCTFail("send entry must be a buffer")
        }

        class Callback: NetworkServiceRequestCallback {
            var results: [NetworkServiceResult] = []
            func requestFinished(result: NetworkServiceResult) { results.append(result) }
        }
        let callback = Callback()
        service.execute(send: connection.send, requestCallbacks: [callback])
        waitUntil("publish executed") { !callback.results.isEmpty }
        XCTAssertEqual(callback.results.first, .success)

        var received: [Data] = []
        waitUntil("message routed back by the broker") {
            received += service.getResults() ?? []
            return !received.isEmpty
        }
        let json = try (try JSONSerialization.jsonObject(with: received.first ?? Data()) as? [String: Any]).unwrap()
        XCTAssertEqual(json["value"] as? Double, 42.25)
    }

    func testWrongCredentialsReportDescriptiveError() throws {
        let env = try brokerEnv()
        let (_, service) = try makeExperiment(password: "wrongpass", certificate: "broker.pem", ca: env.ca)
        service.connect(address: env.host)
        defer { service.disconnect() }

        var reported: String? = nil
        waitUntil("CONNACK refusal surfaces in getState") {
            if case .genericError(let message) = service.getState(), message.contains("connection refused") {
                reported = message
                return true
            }
            return false
        }
        //mosquitto answers a wrong password with return code 5 (not authorized); accept 4 too,
        //which brokers may use instead
        XCTAssertTrue(reported?.contains("not authorized") == true || reported?.contains("bad username or password") == true, reported ?? "nil")
    }

    func testUnloadableCertificateRefusesConnection() throws {
        let env = try brokerEnv()
        let (_, service) = try makeExperiment(password: "testpass", certificate: "missing.pem", ca: env.ca)
        service.connect(address: env.host)
        guard case .genericError(let message) = service.getState() else {
            XCTFail("expected an error state, got \(service.getState())")
            return
        }
        XCTAssertTrue(message.contains("could not be loaded"), message)
        XCTAssertNil(service.client, "no connection may be attempted after a failed trust setup")
    }
}

//Enumerated values from an experiment file are matched case-insensitively across the whole
//format, and an invalid value is an error rather than silently selecting the default
//(enum-case-insensitive and enum-invalid-value in phyphox-docs, matching the Android parser).
final class EnumCaseFoldingTests: XCTestCase {
    private func parse(_ xml: String) throws -> Experiment {
        let stream = InputStream(data: xml.data(using: .utf8)!)
        return try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: stream)
    }

    ///The full skeleton exercises the accepted surface of the format in one document; upper-casing
    ///every enumerated attribute value in it must not change that.
    func testCaseMangledSkeletonParses() throws {
        let skeleton = try testBundle.path(forResource: "full-skeleton", ofType: "phyphox").unwrap()
        var xml = try String(contentsOfFile: skeleton, encoding: .utf8)
        //Only attributes with enumerated values - buffer names, labels and numbers must stay untouched
        for attribute in ["type", "component", "conversion", "waveform", "parameter", "axis", "as", "feature", "aeStrategy", "service", "discovery", "format", "style", "value"] {
            let regex = try NSRegularExpression(pattern: "\(attribute)=\"([^\"]*)\"")
            let matches = regex.matches(in: xml, range: NSRange(xml.startIndex..., in: xml)).reversed()
            for match in matches {
                let valueRange = Range(match.range(at: 1), in: xml)!
                xml.replaceSubrange(valueRange, with: xml[valueRange].uppercased())
            }
        }
        XCTAssertTrue(xml.contains("type=\"LINEAR_ACCELERATION\""), "the mangling itself must have worked")
        XCTAssertTrue(xml.contains("conversion=\"UINT16LITTLEENDIAN\""))
        _ = try parse(xml)
    }

    ///Folded values must map to the right case, not merely stop the parser from throwing
    func testFoldedValuesMapCorrectly() throws {
        let experiment = try parse("""
        <phyphox version="1.20">
            <title>t</title>
            <category>c</category>
            <description>d</description>
            <data-containers>
                <container>buffer</container>
            </data-containers>
            <input>
                <sensor type="ACCELEROMETER" rateStrategy="Limit" rate="10">
                    <output component="ABS">buffer</output>
                </sensor>
            </input>
            <views>
                <view label="v">
                    <graph label="g" style="DOTS" scaleMinX="FIXED">
                        <input axis="Y">buffer</input>
                    </graph>
                </view>
            </views>
        </phyphox>
        """)
        let sensor = try experiment.sensorInputs.first.unwrap()
        XCTAssertEqual(sensor.sensorType, .accelerometer)
        XCTAssertEqual(sensor.rateStrategy, .limit)
        XCTAssertNotNil(sensor.absBuffer, "component=\"ABS\" must map to the abs component")
        let graph = try ((experiment.viewDescriptors?.first?.views.first) as? GraphViewDescriptor).unwrap()
        XCTAssertEqual(graph.style.first, .dots)
        XCTAssertEqual(graph.scaleMinX, .fixed)
    }

    ///An invalid enumerated value must reject the file instead of silently selecting the default
    func testInvalidEnumValuesReject() {
        func sensorXML(_ sensorAttributes: String, camera: String? = nil, network: String? = nil) -> String {
            return """
            <phyphox version="1.20">
                <title>t</title>
                <category>c</category>
                <description>d</description>
                <data-containers>
                    <container>buffer</container>
                </data-containers>
                <input>
                    <sensor \(sensorAttributes) rate="10">
                        <output component="x">buffer</output>
                    </sensor>
                    \(camera ?? "")
                </input>
                \(network ?? "")
                <views>
                    <view label="v">
                        <value label="l"><input>buffer</input></value>
                    </view>
                </views>
            </phyphox>
            """
        }
        //The three offenders named by enum-invalid-value, which used to substitute their defaults:
        XCTAssertThrowsError(try parse(sensorXML("type=\"accelerometer\" rateStrategy=\"bogus\"")))
        XCTAssertThrowsError(try parse(sensorXML("type=\"accelerometer\"", camera: "<camera feature=\"bogus\"><output component=\"luminance\">buffer</output></camera>")))
        XCTAssertThrowsError(try parse(sensorXML("type=\"accelerometer\"", camera: "<camera aeStrategy=\"bogus\"><output component=\"luminance\">buffer</output></camera>")))
        //An unknown discovery method used to be silently ignored:
        XCTAssertThrowsError(try parse(sensorXML("type=\"accelerometer\"", network: "<network><connection address=\"a\" discovery=\"bogus\" discoveryAddress=\"b\" service=\"http/get\" conversion=\"none\"/></network>")))
        //Folding must not have broken rejection in the long-standing throwing paths:
        XCTAssertThrowsError(try parse(sensorXML("type=\"bogus\"")))

        //View and output elements whose invalid enumerated values used to be silently swallowed:
        func viewXML(_ viewBody: String, output: String = "") -> String {
            return """
            <phyphox version="1.20">
                <title>t</title>
                <category>c</category>
                <description>d</description>
                <data-containers>
                    <container>buffer</container>
                </data-containers>
                \(output)
                <views>
                    <view label="v">
                        \(viewBody)
                    </view>
                </views>
            </phyphox>
            """
        }
        //slider type used to silently produce a RANGE slider for anything but exactly "normal"
        XCTAssertThrowsError(try parse(viewXML("<slider label=\"s\" type=\"bogus\"><output>buffer</output></slider>")))
        //value format used to silently fall back to the plain number display
        XCTAssertThrowsError(try parse(viewXML("<value label=\"l\" format=\"bogus\"><input>buffer</input></value>")))
        //a per-set graph style used to be silently ignored (Android rejects it)
        XCTAssertThrowsError(try parse(viewXML("<graph label=\"g\"><input axis=\"y\" style=\"bogus\">buffer</input></graph>")))
        //the audio waveform used to silently fall back to sine
        XCTAssertThrowsError(try parse(viewXML("<value label=\"l\"><input>buffer</input></value>", output: "<output><audio><tone waveform=\"bogus\"><input parameter=\"frequency\" type=\"value\">440</input></tone></audio></output>")))
    }
}

//Metadata identifiers of network send elements and the camera locked setting names fold case
//as well (maintainer decision 2026-08-10, extending enum-case-insensitive; Android still
//matches both case-sensitively - see ANDROID-TODO).
final class MetadataAndLockedFoldingTests: XCTestCase {
    private func parse(_ xml: String) throws -> Experiment {
        let stream = InputStream(data: xml.data(using: .utf8)!)
        return try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: stream)
    }

    private func xml(meta: String, locked: String) -> String {
        return """
        <phyphox version="1.20">
            <title>t</title>
            <category>c</category>
            <description>d</description>
            <data-containers>
                <container>buffer</container>
            </data-containers>
            <input>
                <camera locked="\(locked)">
                    <output component="luminance">buffer</output>
                </camera>
            </input>
            <network>
                <connection address="a" service="http/post" conversion="none" interval="1">
                    \(meta)
                </connection>
            </network>
            <views>
                <view label="v">
                    <value label="l"><input>buffer</input></value>
                </view>
            </views>
        </phyphox>
        """
    }

    func testMetadataNamesAndLockedSettingsFold() throws {
        let experiment = try parse(xml(meta: """
            <send id="m1" type="meta">UNIQUEID</send>
            <send id="m2" type="meta">ACCELEROMETERNAME</send>
            <send id="m3" type="meta">FileFormat</send>
        """, locked: "Shutter_Speed=1/50, ISO=100"))

        //locked setting names are normalized to lowercase at parse time
        let locked = try (experiment.cameraInput?.locked).unwrap()
        XCTAssertEqual(Set(locked.keys), ["shutter_speed", "iso"])
        XCTAssertEqual(locked["iso"] ?? nil, 100)
        XCTAssertEqual(locked["shutter_speed"] ?? nil, 1.0/50.0, "the shutter speed fraction syntax must survive the folded name")

        //metadata identifiers resolve regardless of case
        let connection = try experiment.networkConnections.first.unwrap()
        guard case .Metadata(.uniqueId) = try (connection.send["m1"]?.source).unwrap() else {
            return XCTFail("UNIQUEID must fold to the unique id metadata")
        }
        guard case .Metadata(.sensor(.accelerometer, .name)) = try (connection.send["m2"]?.source).unwrap() else {
            return XCTFail("ACCELEROMETERNAME must fold to the accelerometer name metadata")
        }
        guard case .Metadata(.fileFormat) = try (connection.send["m3"]?.source).unwrap() else {
            return XCTFail("FileFormat must fold to the file format metadata")
        }
    }

    func testUnknownMetadataNameStillRejects() {
        XCTAssertThrowsError(try parse(xml(meta: "<send id=\"m\" type=\"meta\">bogusMeta</send>", locked: "iso=100")))
    }
}

//Format-wide case folding beyond the enumerated attribute values (maintainer decisions
//2026-08-10): the datatype attribute, boolean attribute values and element names all fold,
//and invalid values are rejected rather than silently defaulted.
final class FormatWideCaseFoldingTests: XCTestCase {
    private func parse(_ xml: String) throws -> Experiment {
        let stream = InputStream(data: xml.data(using: .utf8)!)
        return try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: stream)
    }

    func testElementNamesFold() throws {
        //Element names fold without exception, including the root
        let experiment = try parse("""
        <PHYPHOX version="1.20">
            <title>t</title>
            <category>c</category>
            <description>d</description>
            <Data-Containers>
                <CONTAINER>buffer</CONTAINER>
            </Data-Containers>
            <Input>
                <SENSOR type="accelerometer" rate="10">
                    <Output component="x">buffer</Output>
                </SENSOR>
            </Input>
            <Analysis>
                <Append>
                    <Input>buffer</Input>
                    <OUTPUT>buffer</OUTPUT>
                </Append>
            </Analysis>
            <VIEWS>
                <View label="v">
                    <Value label="l"><Input>buffer</Input></Value>
                </View>
            </VIEWS>
        </PHYPHOX>
        """)
        //Successful parsing is the assertion that matters: <Append> only parses if the folded
        //module name reached the classMap, and <SENSOR>/<CONTAINER> only via the folded lookup
        XCTAssertEqual(experiment.sensorInputs.count, 1)
        XCTAssertNotNil(experiment.buffers["buffer"])
    }

    private func boolXML(sensor: String, graph: String) -> String {
        return """
        <phyphox version="1.20">
            <title>t</title>
            <category>c</category>
            <description>d</description>
            <data-containers>
                <container>buffer</container>
            </data-containers>
            <input>
                <sensor type="accelerometer" rate="10" \(sensor)>
                    <output component="x">buffer</output>
                </sensor>
            </input>
            <views>
                <view label="v">
                    <graph label="g" \(graph)>
                        <input axis="y">buffer</input>
                    </graph>
                </view>
            </views>
        </phyphox>
        """
    }

    func testBooleansFoldAndReject() throws {
        let experiment = try parse(boolXML(sensor: "average=\"True\"", graph: "partialUpdate=\"TRUE\" followX=\"False\""))
        let graph = try ((experiment.viewDescriptors?.first?.views.first) as? GraphViewDescriptor).unwrap()
        XCTAssertTrue(graph.partialUpdate)
        XCTAssertFalse(graph.followX)
        //Anything that is not true or false is an error - Android's silent false and the XSD-style
        //"1"/"0" are not part of the format
        XCTAssertThrowsError(try parse(boolXML(sensor: "average=\"yes\"", graph: "")))
        XCTAssertThrowsError(try parse(boolXML(sensor: "", graph: "partialUpdate=\"1\"")))
    }

    private func datatypeXML(_ datatype: String) -> String {
        return """
        <phyphox version="1.20">
            <title>t</title>
            <category>c</category>
            <description>d</description>
            <data-containers>
                <container>buffer</container>
            </data-containers>
            <network>
                <connection address="a" service="http/post" conversion="none" interval="1">
                    <send id="x" datatype="\(datatype)">buffer</send>
                </connection>
            </network>
            <views>
                <view label="v">
                    <value label="l"><input>buffer</input></value>
                </view>
            </views>
        </phyphox>
        """
    }

    func testDatatypeFoldsAndRejects() throws {
        //The folded value is normalized to lowercase, which the send-time comparisons rely on
        let experiment = try parse(datatypeXML("NUMBER"))
        let send = try (experiment.networkConnections.first?.send["x"]).unwrap()
        XCTAssertEqual(send.additionalAttributes["datatype"], "number")
        _ = try parse(datatypeXML("Array"))
        XCTAssertThrowsError(try parse(datatypeXML("bogus")))
    }
}

//The input/output mapping mechanism is validated against slot tables, mirroring Android's
//ioBlockParser: components of input elements, and the as attribute of analysis inputs and
//outputs, must name an allowed slot with its count and type restrictions respected.
final class SlotMappingValidationTests: XCTestCase {
    private func parse(_ xml: String) throws -> Experiment {
        let stream = InputStream(data: xml.data(using: .utf8)!)
        return try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: stream)
    }

    private func xml(input: String = "", analysis: String = "") -> String {
        return """
        <phyphox version="1.20">
            <title>t</title>
            <category>c</category>
            <description>d</description>
            <data-containers>
                <container>buffer</container>
                <container>buffer2</container>
            </data-containers>
            <input>\(input)</input>
            <analysis>\(analysis)</analysis>
            <views>
                <view label="v">
                    <value label="l"><input>buffer</input></value>
                </view>
            </views>
        </phyphox>
        """
    }

    private func assertRejects(_ document: String, message expected: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try parse(document), file: file, line: line) { error in
            //The debug description escapes the quotes inside the message
            let rendered = "\(error)".replacingOccurrences(of: "\\\"", with: "\"")
            XCTAssertTrue(rendered.contains(expected), "expected \"\(expected)\" in \(error)", file: file, line: line)
        }
    }

    func testInputComponentValidation() throws {
        //Unknown, duplicate and unnamed components of a sensor are errors, with Android's wording
        assertRejects(xml(input: "<sensor type=\"accelerometer\" rate=\"10\"><output component=\"acc\">buffer</output></sensor>"),
                      message: "Could not find mapping for output \"acc\".")
        assertRejects(xml(input: "<sensor type=\"accelerometer\" rate=\"10\"><output component=\"x\">buffer</output><output component=\"x\">buffer2</output></sensor>"),
                      message: "The output \"x\" has already been defined.")
        assertRejects(xml(input: "<sensor type=\"accelerometer\" rate=\"10\"><output>buffer</output></sensor>"),
                      message: "The non-mapped output could not be matched.")
        //The audio recording output is required...
        assertRejects(xml(input: "<audio><output component=\"rate\">buffer</output></audio>"),
                      message: "A minimum of 1 outputs was expected for out but 0 were found.")
        //...and an unnamed output fills it
        let experiment = try parse(xml(input: "<audio><output>buffer</output></audio>"))
        XCTAssertEqual(experiment.audioInputs.count, 1)
    }

    func testAnalysisSlotValidation() throws {
        //A subtraction without a subtrahend is an error (matches Android's mapping table)
        assertRejects(xml(analysis: "<subtract><input>buffer</input><output>buffer2</output></subtract>"),
                      message: "A minimum of 1 inputs was expected for subtrahend but 0 were found.")
        //An as name the module does not know is an error instead of positional assignment
        assertRejects(xml(analysis: "<add><input as=\"bogus\">buffer</input><output>buffer2</output></add>"),
                      message: "Could not find mapping for input \"bogus\".")
        //A slot that takes a single tag refuses a second one
        assertRejects(xml(analysis: "<butterworth><input as=\"y\">buffer</input><input as=\"y\">buffer2</input><input as=\"n\" type=\"value\">4</input><input as=\"cutoff\" type=\"value\">10</input><output as=\"filtered\">buffer2</output></butterworth>"),
                      message: "The input \"y\" has already been defined.")
        //A slot that requires a data container refuses a literal value
        assertRejects(xml(analysis: "<average><input type=\"value\">5</input><output>buffer2</output></average>"),
                      message: "Value-type not allowed for input \"buffer\".")
        //The stddev output slot requires its as attribute, so a second unnamed output cannot match
        assertRejects(xml(analysis: "<average><input>buffer</input><output>buffer2</output><output>buffer2</output></average>"),
                      message: "The non-mapped output could not be matched.")
        //Valid repeat groups still parse: three summands, two of them named
        _ = try parse(xml(analysis: "<add><input>buffer</input><input as=\"summand\">buffer2</input><input as=\"summand\" type=\"value\">5</input><output>buffer2</output></add>"))
    }

    func testAverageMapsOutputsByName() throws {
        //Writing stddev before average must not swap the two values: outputs map by the
        //documented names, not by document order
        let avgBuffer = try DataBuffer(name: "avg", size: 10, baseContents: [], static: false)
        let stddevBuffer = try DataBuffer(name: "stddev", size: 10, baseContents: [], static: false)
        let inputData = MutableDoubleArray(data: [1.0, 2.0, 3.0, 4.0])
        let inputBuffer = try DataBuffer(name: "in", size: 10, baseContents: [], static: false)

        let module = try AverageAnalysis(
            inputs: [.buffer(buffer: inputBuffer, data: inputData, usedAs: "buffer", keep: true)],
            outputs: [
                .buffer(buffer: stddevBuffer, data: MutableDoubleArray(data: []), usedAs: "stddev", append: false),
                .buffer(buffer: avgBuffer, data: MutableDoubleArray(data: []), usedAs: "average", append: false)
            ],
            additionalAttributes: .empty)
        module.update()

        XCTAssertEqual(avgBuffer.last, 2.5, "the mean must land in the output named average")
        XCTAssertEqual(stddevBuffer.last ?? .nan, 1.2909944487358056, accuracy: 1e-12, "the standard deviation must land in the output named stddev")
    }
}

//average delivers single values, so its error states are intermediate NaN values: an empty or
//all-non-finite input writes exactly one NaN to each connected output instead of nothing. A
//single finite value yields its own value as the average and exactly one NaN as the stddev.
final class AverageDegenerateInputTests: XCTestCase {
    private func runAverage(input: [Double]) throws -> (average: [Double], stddev: [Double]) {
        let avgBuffer = try DataBuffer(name: "avg", size: 10, baseContents: [], static: false)
        let stddevBuffer = try DataBuffer(name: "stddev", size: 10, baseContents: [], static: false)
        let inputBuffer = try DataBuffer(name: "in", size: 10, baseContents: [], static: false)

        let module = try AverageAnalysis(
            inputs: [.buffer(buffer: inputBuffer, data: MutableDoubleArray(data: input), usedAs: "buffer", keep: true)],
            outputs: [
                .buffer(buffer: avgBuffer, data: MutableDoubleArray(data: []), usedAs: "average", append: false),
                .buffer(buffer: stddevBuffer, data: MutableDoubleArray(data: []), usedAs: "stddev", append: false)
            ],
            additionalAttributes: .empty)
        module.update()

        return (avgBuffer.toArray(), stddevBuffer.toArray())
    }

    func testEmptyInputWritesNaNToEachOutput() throws {
        let result = try runAverage(input: [])
        XCTAssertEqual(result.average.count, 1, "an empty input must write exactly one NaN, not nothing")
        XCTAssertTrue(result.average[0].isNaN)
        XCTAssertEqual(result.stddev.count, 1)
        XCTAssertTrue(result.stddev[0].isNaN)
    }

    func testAllNonFiniteInputWritesNaNToEachOutput() throws {
        let result = try runAverage(input: [.nan, .infinity, -.infinity])
        XCTAssertEqual(result.average.count, 1, "an all-non-finite input must write exactly one NaN, not nothing")
        XCTAssertTrue(result.average[0].isNaN)
        XCTAssertEqual(result.stddev.count, 1)
        XCTAssertTrue(result.stddev[0].isNaN)
    }

    func testSingleValueYieldsValueAndSingleNaNStddev() throws {
        let result = try runAverage(input: [3.5])
        XCTAssertEqual(result.average, [3.5])
        XCTAssertEqual(result.stddev.count, 1, "a single input value must yield exactly one stddev value")
        XCTAssertTrue(result.stddev[0].isNaN)
    }
}

//threshold error states: when no crossing is found the output is NaN (not the last sample's x
//or -1), and a NaN threshold value participates like any number - no comparison with it is ever
//true, so no crossing is found. Only an absent threshold input or an empty threshold buffer
//selects the documented default of 0. The sticky-side triggering (any value not on the trigger
//side arms, NaN included; the next value on the trigger side fires) is the canonical behaviour.
final class ThresholdNaNHandlingTests: XCTestCase {
    private func runThreshold(x: [Double]? = nil, y: [Double], threshold: ExperimentAnalysisDataInput? = nil) throws -> [Double] {
        var inputs: [ExperimentAnalysisDataInput] = []
        if let x = x {
            let xBuffer = try DataBuffer(name: "x", size: 0, baseContents: [], static: false)
            inputs.append(.buffer(buffer: xBuffer, data: MutableDoubleArray(data: x), usedAs: "x", keep: true))
        }
        let yBuffer = try DataBuffer(name: "y", size: 0, baseContents: [], static: false)
        inputs.append(.buffer(buffer: yBuffer, data: MutableDoubleArray(data: y), usedAs: "y", keep: true))
        if let threshold = threshold {
            inputs.append(threshold)
        }
        let out = try DataBuffer(name: "position", size: 0, baseContents: [], static: false)

        let module = try ThresholdAnalysis(
            inputs: inputs,
            outputs: [.buffer(buffer: out, data: MutableDoubleArray(data: []), usedAs: "position", append: false)],
            additionalAttributes: .empty)
        module.update()
        return out.toArray()
    }

    func testNoCrossingOutputsNaN() throws {
        let result = try runThreshold(y: [1, 2, 1], threshold: .value(value: 5.0, usedAs: "threshold"))
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].isNaN, "no crossing found must output NaN, not the last sample's x")
    }

    func testEmptyInputOutputsNaN() throws {
        let result = try runThreshold(y: [])
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].isNaN, "an empty input must output NaN, not -1")
    }

    func testNaNThresholdParticipatesAndYieldsNaN() throws {
        let result = try runThreshold(y: [-1, 1, -1, 1], threshold: .value(value: .nan, usedAs: "threshold"))
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].isNaN, "a NaN threshold makes every comparison false, so no crossing is found")
    }

    func testEmptyThresholdBufferSelectsDefaultZero() throws {
        let thresholdBuffer = try DataBuffer(name: "threshold", size: 0, baseContents: [], static: false)
        let result = try runThreshold(
            y: [-1, 1],
            threshold: .buffer(buffer: thresholdBuffer, data: MutableDoubleArray(data: []), usedAs: "threshold", keep: true))
        XCTAssertEqual(result, [1], "an empty threshold buffer selects the default 0; the crossing fires at index 1")
    }

    func testStickySideSkipsNaNValues() throws {
        //[2, NaN, 5] rising with threshold 3: 2 arms (below), NaN also counts as armed, 5 fires
        let result = try runThreshold(x: [10, 20, 30], y: [2, .nan, 5], threshold: .value(value: 3.0, usedAs: "threshold"))
        XCTAssertEqual(result, [30])
    }

    func testNormalCrossingStillFires() throws {
        //5 is already on the trigger side but not armed; 1 arms; 6 fires
        let result = try runThreshold(x: [10, 20, 30], y: [5, 1, 6], threshold: .value(value: 3.0, usedAs: "threshold"))
        XCTAssertEqual(result, [30])
    }
}

//first pairs input i with output i, like Android: each output receives exactly the first value
//of its own input; an empty input skips only its own pair, and outputs beyond the input count
//stay empty. The first values must never be collected and broadcast to every output.
final class FirstPairingTests: XCTestCase {
    private func makeInput(_ data: [Double]) throws -> ExperimentAnalysisDataInput {
        let buffer = try DataBuffer(name: "in", size: 0, baseContents: [], static: false)
        return .buffer(buffer: buffer, data: MutableDoubleArray(data: data), usedAs: "value", keep: true)
    }

    private func runFirst(inputs inputData: [[Double]], outputCount: Int) throws -> [[Double]] {
        let outBuffers = try (0..<outputCount).map { try DataBuffer(name: "out\($0)", size: 0, baseContents: [], static: false) }

        let module = try FirstAnalysis(
            inputs: inputData.map { try makeInput($0) },
            outputs: outBuffers.map { .buffer(buffer: $0, data: MutableDoubleArray(data: []), usedAs: "first", append: false) },
            additionalAttributes: .empty)
        module.update()

        return outBuffers.map { $0.toArray() }
    }

    func testPairsInputWithOutput() throws {
        let result = try runFirst(inputs: [[1, 2, 3], [4, 5, 6]], outputCount: 2)
        XCTAssertEqual(result[0], [1], "output 0 must receive only the first value of input 0")
        XCTAssertEqual(result[1], [4], "output 1 must receive only the first value of input 1")
    }

    func testEmptyInputSkipsOnlyItsOwnPair() throws {
        let result = try runFirst(inputs: [[], [4, 5]], outputCount: 2)
        XCTAssertEqual(result[0], [], "an empty input must leave its own output untouched")
        XCTAssertEqual(result[1], [4])
    }

    func testExtraOutputsStayEmpty() throws {
        let result = try runFirst(inputs: [[7]], outputCount: 2)
        XCTAssertEqual(result[0], [7])
        XCTAssertEqual(result[1], [], "an output without a paired input must stay empty")
    }
}

//match with more outputs than inputs must leave the extra outputs empty (matching Android)
//instead of trapping on an index out of range.
final class MatchExtraOutputsTests: XCTestCase {
    private func runMatch(inputs inputData: [[Double]], outputCount: Int) throws -> [[Double]] {
        let inputs: [ExperimentAnalysisDataInput] = try inputData.map {
            let buffer = try DataBuffer(name: "in", size: 0, baseContents: [], static: false)
            return .buffer(buffer: buffer, data: MutableDoubleArray(data: $0), usedAs: "in", keep: true)
        }
        let outBuffers = try (0..<outputCount).map { try DataBuffer(name: "out\($0)", size: 0, baseContents: [], static: false) }

        let module = try MatchAnalysis(
            inputs: inputs,
            outputs: outBuffers.map { .buffer(buffer: $0, data: MutableDoubleArray(data: []), usedAs: "out", append: false) },
            additionalAttributes: .empty)
        module.update()

        return outBuffers.map { $0.toArray() }
    }

    func testExtraOutputsAreLeftEmpty() throws {
        let result = try runMatch(inputs: [[1, .nan, 3]], outputCount: 2)
        XCTAssertEqual(result[0], [1, 3], "rows with a non-finite value are dropped")
        XCTAssertEqual(result[1], [], "an output beyond the input count must stay empty, not trap")
    }

    func testNormalMatchingUnchanged() throws {
        let result = try runMatch(inputs: [[1, 2, 3], [4, .nan, 6]], outputCount: 2)
        XCTAssertEqual(result[0], [1, 3], "a non-finite value in any input drops the whole row")
        XCTAssertEqual(result[1], [4, 6])
    }
}

//gcd/lcm operate on non-negative integers: fractional values are rounded half away from zero
//(C rounding, not truncation), negative and non-finite inputs yield NaN, values or results
//beyond UInt yield NaN instead of trapping, and lcm(0,x) = 0 including lcm(0,0).
final class GCDLCMDomainTests: XCTestCase {
    private func runGCD(_ a: Double, _ b: Double) throws -> [Double] {
        let out = try DataBuffer(name: "out", size: 0, baseContents: [], static: false)
        let module = try GCDAnalysis(
            inputs: [.value(value: a, usedAs: "value"), .value(value: b, usedAs: "value")],
            outputs: [.buffer(buffer: out, data: MutableDoubleArray(data: []), usedAs: "gcd", append: false)],
            additionalAttributes: .empty)
        module.update()
        return out.toArray()
    }

    private func runLCM(_ a: Double, _ b: Double) throws -> [Double] {
        let out = try DataBuffer(name: "out", size: 0, baseContents: [], static: false)
        let module = try LCMAnalysis(
            inputs: [.value(value: a, usedAs: "value"), .value(value: b, usedAs: "value")],
            outputs: [.buffer(buffer: out, data: MutableDoubleArray(data: []), usedAs: "lcm", append: false)],
            additionalAttributes: .empty)
        module.update()
        return out.toArray()
    }

    func testGCDDomain() throws {
        XCTAssertEqual(try runGCD(12, 18), [6])
        XCTAssertEqual(try runGCD(4.5, 10), [5], "4.5 rounds half away from zero to 5 (truncation to 4 would give gcd 2)")
        XCTAssertTrue(try runGCD(-4, 6)[0].isNaN, "a negative input yields NaN, not a trap")
        XCTAssertTrue(try runGCD(.nan, 6)[0].isNaN)
        XCTAssertTrue(try runGCD(1e20, 6)[0].isNaN, "a value beyond UInt.max yields NaN, not a conversion trap")
        XCTAssertEqual(try runGCD(0, 0), [0])
    }

    func testLCMDomain() throws {
        XCTAssertEqual(try runLCM(4, 6), [12])
        XCTAssertEqual(try runLCM(2.5, 5), [15], "2.5 rounds half away from zero to 3 (lcm 15), not to even (lcm 10)")
        XCTAssertEqual(try runLCM(0, 5), [0], "lcm(0,x) = 0 by convention")
        XCTAssertEqual(try runLCM(0, 0), [0], "lcm(0,0) = 0, formerly a division-by-zero trap")
        XCTAssertTrue(try runLCM(-2, 4)[0].isNaN, "a negative input yields NaN, not a trap")
        XCTAssertTrue(try runLCM(.infinity, 4)[0].isNaN)
        XCTAssertTrue(try runLCM(1e10, 1e10 + 1)[0].isNaN, "an lcm overflowing UInt yields NaN, not a trap")
    }

}

//rangefilter: strictly row-wise filtering like Android - a row is dropped for all outputs when
//any input's value falls outside its range, keeping outputs aligned; non-finite values are
//compared like any number (infinities can be filtered, NaN never triggers); extra outputs are
//ignored; a min/max before the first in binds to the first group.
final class RangefilterRowAlignmentTests: XCTestCase {
    private func makeIn(_ data: [Double]) throws -> ExperimentAnalysisDataInput {
        let buffer = try DataBuffer(name: "in", size: 0, baseContents: [], static: false)
        return .buffer(buffer: buffer, data: MutableDoubleArray(data: data), usedAs: "in", keep: true)
    }

    private func run(inputs: [ExperimentAnalysisDataInput], outputCount: Int) throws -> [[Double]] {
        let outBuffers = try (0..<outputCount).map { try DataBuffer(name: "out\($0)", size: 0, baseContents: [], static: false) }
        let module = try RangefilterAnalysis(
            inputs: inputs,
            outputs: outBuffers.map { .buffer(buffer: $0, data: MutableDoubleArray(data: []), usedAs: "out", append: false) },
            additionalAttributes: .empty)
        module.update()
        return outBuffers.map { $0.toArray() }
    }

    func testRowAlignmentWithMultipleFilteredInputs() throws {
        //row 0 is filtered by input 2, row 1 by input 1, row 2 passes - the old global
        //deleteCount misaligned exactly this pattern
        let result = try run(inputs: [
            try makeIn([1, 100, 3]), .value(value: 0, usedAs: "min"), .value(value: 10, usedAs: "max"),
            try makeIn([100, 2, 3]), .value(value: 0, usedAs: "min"), .value(value: 10, usedAs: "max")
        ], outputCount: 2)
        XCTAssertEqual(result[0], [3], "outputs must stay row-aligned")
        XCTAssertEqual(result[1], [3])
    }

    func testInfinitiesAreFiltered() throws {
        let result = try run(inputs: [
            try makeIn([1, .infinity, -.infinity, 2]), .value(value: 0, usedAs: "min"), .value(value: 10, usedAs: "max")
        ], outputCount: 1)
        XCTAssertEqual(result[0], [1, 2], "infinities are compared like any number and filtered")
    }

    func testNaNNeverTriggersTheFilter() throws {
        let result = try run(inputs: [
            try makeIn([1, .nan, 2]), .value(value: 0, usedAs: "min"), .value(value: 10, usedAs: "max")
        ], outputCount: 1)
        XCTAssertEqual(result[0].count, 3)
        XCTAssertTrue(result[0][1].isNaN)
    }

    func testShorterInputContributesNaN() throws {
        let result = try run(inputs: [
            try makeIn([1, 2, 3]),
            try makeIn([5]), .value(value: 0, usedAs: "min"), .value(value: 10, usedAs: "max")
        ], outputCount: 2)
        XCTAssertEqual(result[0], [1, 2, 3])
        XCTAssertEqual(result[1].count, 3)
        XCTAssertEqual(result[1][0], 5)
        XCTAssertTrue(result[1][1].isNaN, "an exhausted input contributes NaN and does not trigger the filter")
        XCTAssertTrue(result[1][2].isNaN)
    }

    func testExtraOutputsAreIgnored() throws {
        let result = try run(inputs: [try makeIn([1, 2])], outputCount: 2)
        XCTAssertEqual(result[0], [1, 2], "an extra output must be ignored, not trap")
        XCTAssertEqual(result[1], [])
    }

    func testLeadingMinBindsToFirstGroup() throws {
        let result = try run(inputs: [
            .value(value: 2, usedAs: "min"), try makeIn([1, 2, 3])
        ], outputCount: 1)
        XCTAssertEqual(result[0], [2, 3], "a min before the first in must bind to the first group, not be discarded")
    }
}

//map: x/y/z accept value-type inputs as one-element buffers; a degenerate range (minX equal to
//maxX) clamps the bin index instead of trapping (NaN ratio -> bin 0, infinite ratios fall
//outside the bounds check); a missing z input with zMode sum/average rejects the file at load.
final class MapAnalysisTests: XCTestCase {
    private func runMap(x: ExperimentAnalysisDataInput, y: ExperimentAnalysisDataInput, z: ExperimentAnalysisDataInput,
                        minX: Double = 0, maxX: Double = 1, minY: Double = 0, maxY: Double = 1) throws -> (x: [Double], y: [Double], z: [Double]) {
        let xOut = try DataBuffer(name: "xOut", size: 0, baseContents: [], static: false)
        let yOut = try DataBuffer(name: "yOut", size: 0, baseContents: [], static: false)
        let zOut = try DataBuffer(name: "zOut", size: 0, baseContents: [], static: false)

        let module = try MapAnalysis(
            inputs: [
                .value(value: 2, usedAs: "mapWidth"), .value(value: minX, usedAs: "minX"), .value(value: maxX, usedAs: "maxX"),
                .value(value: 2, usedAs: "mapHeight"), .value(value: minY, usedAs: "minY"), .value(value: maxY, usedAs: "maxY"),
                x, y, z
            ],
            outputs: [
                .buffer(buffer: xOut, data: MutableDoubleArray(data: []), usedAs: "x", append: false),
                .buffer(buffer: yOut, data: MutableDoubleArray(data: []), usedAs: "y", append: false),
                .buffer(buffer: zOut, data: MutableDoubleArray(data: []), usedAs: "z", append: false)
            ],
            additionalAttributes: .empty)
        module.update()
        return (xOut.toArray(), yOut.toArray(), zOut.toArray())
    }

    func testValueTypeInputsAccepted() throws {
        //a single point at (0,0) with z=5 on a 2x2 grid, all given as value-type inputs
        let result = try runMap(x: .value(value: 0, usedAs: "x"), y: .value(value: 0, usedAs: "y"), z: .value(value: 5, usedAs: "z"))
        XCTAssertEqual(result.x, [0, 1, 0, 1])
        XCTAssertEqual(result.y, [0, 0, 1, 1])
        XCTAssertEqual(result.z.count, 4)
        XCTAssertEqual(result.z[0], 5, "the point must land in bin (0,0) with its average value")
        XCTAssertTrue(result.z[1].isNaN, "empty bins average to NaN")
    }

    func testDegenerateRangeDoesNotTrap() throws {
        //minX == maxX: the point at exactly that value gets bin 0 (NaN ratio), others fall out
        let xBuffer = try DataBuffer(name: "x", size: 0, baseContents: [], static: false)
        let yBuffer = try DataBuffer(name: "y", size: 0, baseContents: [], static: false)
        let zBuffer = try DataBuffer(name: "z", size: 0, baseContents: [], static: false)
        let result = try runMap(
            x: .buffer(buffer: xBuffer, data: MutableDoubleArray(data: [0, 1]), usedAs: "x", keep: true),
            y: .buffer(buffer: yBuffer, data: MutableDoubleArray(data: [0, 0]), usedAs: "y", keep: true),
            z: .buffer(buffer: zBuffer, data: MutableDoubleArray(data: [5, 7]), usedAs: "z", keep: true),
            minX: 0, maxX: 0)
        XCTAssertEqual(result.z.count, 4, "a degenerate range must be clamped, not trap")
        XCTAssertEqual(result.z[0], 5, "the point at the degenerate value lands in bin 0; the other point falls outside")
    }
}

//The z input of map is required at load when zMode is sum or average (the default) - running
//without it would silently produce a zero grid. Only zMode="count" works without z.
final class MapMissingZTests: XCTestCase {
    private func parse(_ xml: String) throws -> Experiment {
        let stream = InputStream(data: xml.data(using: .utf8)!)
        return try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: stream)
    }

    private func xml(zMode: String, zInput: String) -> String {
        return """
        <phyphox version="1.20">
            <title>t</title>
            <category>c</category>
            <description>d</description>
            <data-containers>
                <container>bx</container>
                <container>by</container>
                <container>bz</container>
                <container>ox</container>
                <container>oy</container>
                <container>oz</container>
            </data-containers>
            <analysis>
                <map\(zMode)>
                    <input as="mapWidth" type="value">2</input>
                    <input as="minX" type="value">0</input>
                    <input as="maxX" type="value">1</input>
                    <input as="mapHeight" type="value">2</input>
                    <input as="minY" type="value">0</input>
                    <input as="maxY" type="value">1</input>
                    <input as="x">bx</input>
                    <input as="y">by</input>
                    \(zInput)
                    <output as="x">ox</output>
                    <output as="y">oy</output>
                    <output as="z">oz</output>
                </map>
            </analysis>
            <views>
                <view label="v">
                    <value label="l"><input>oz</input></value>
                </view>
            </views>
        </phyphox>
        """
    }

    func testMissingZRejectedForDefaultAndSum() throws {
        XCTAssertThrowsError(try parse(xml(zMode: "", zInput: "")), "the default zMode is average, which requires z")
        XCTAssertThrowsError(try parse(xml(zMode: " zMode=\"sum\"", zInput: "")))
        XCTAssertThrowsError(try parse(xml(zMode: " zMode=\"average\"", zInput: "")))
    }

    func testCountModeLoadsWithoutZ() throws {
        _ = try parse(xml(zMode: " zMode=\"count\"", zInput: ""))
    }

    func testZPresentLoads() throws {
        _ = try parse(xml(zMode: "", zInput: "<input as=\"z\">bz</input>"))
    }
}

//interpolate/loess: xi accepts a value-type input as a one-element buffer (matching Android);
//a non-positive or non-finite loess d yields empty outputs instead of NaN fills; the out slots
//no longer accept repeats (max 1).
final class InterpolateLoessTests: XCTestCase {
    private func makeBuffer(_ name: String, _ data: [Double]) throws -> ExperimentAnalysisDataInput {
        let buffer = try DataBuffer(name: name, size: 0, baseContents: [], static: false)
        return .buffer(buffer: buffer, data: MutableDoubleArray(data: data), usedAs: name, keep: true)
    }

    private func runInterpolate(x: [Double], y: [Double], xi: ExperimentAnalysisDataInput) throws -> [Double] {
        let out = try DataBuffer(name: "out", size: 0, baseContents: [], static: false)
        let module = try InterpolateAnalysis(
            inputs: [try makeBuffer("x", x), try makeBuffer("y", y), xi],
            outputs: [.buffer(buffer: out, data: MutableDoubleArray(data: []), usedAs: "out", append: false)],
            additionalAttributes: .empty)
        module.update()
        return out.toArray()
    }

    private func runLoess(x: [Double], y: [Double], d: ExperimentAnalysisDataInput, xi: ExperimentAnalysisDataInput) throws -> [Double] {
        let out = try DataBuffer(name: "yi0", size: 0, baseContents: [], static: false)
        let module = try LoessAnalysis(
            inputs: [try makeBuffer("x", x), try makeBuffer("y", y), d, xi],
            outputs: [.buffer(buffer: out, data: MutableDoubleArray(data: []), usedAs: "yi0", append: false)],
            additionalAttributes: .empty)
        module.update()
        return out.toArray()
    }

    func testInterpolateAcceptsValueTypeXi() throws {
        let result = try runInterpolate(x: [0, 10], y: [0, 100], xi: .value(value: 5, usedAs: "xi"))
        XCTAssertEqual(result, [50], "a value-type xi must act as a one-element buffer, not be rejected")
    }

    func testInterpolateBufferXiUnchanged() throws {
        let result = try runInterpolate(x: [0, 10], y: [0, 100], xi: try makeBuffer("xi", [2.5, 7.5]))
        XCTAssertEqual(result, [25, 75])
    }

    func testLoessAcceptsValueTypeXi() throws {
        let result = try runLoess(x: [0, 1, 2, 3, 4], y: [0, 1, 2, 3, 4], d: .value(value: 2, usedAs: "d"), xi: .value(value: 2, usedAs: "xi"))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], 2, accuracy: 1e-9, "loess of linear data returns the linear value")
    }

    func testLoessInvalidDYieldsEmptyOutputs() throws {
        for d in [0.0, -1.0, Double.nan, .infinity] {
            let result = try runLoess(x: [0, 1, 2], y: [0, 1, 2], d: .value(value: d, usedAs: "d"), xi: try makeBuffer("xi", [1]))
            XCTAssertEqual(result, [], "d=\(d) must yield empty outputs, not NaN fills")
        }
    }

    func testRepeatedOutputsAreRejected() throws {
        let out1 = try DataBuffer(name: "o1", size: 0, baseContents: [], static: false)
        let out2 = try DataBuffer(name: "o2", size: 0, baseContents: [], static: false)
        XCTAssertThrowsError(try InterpolateAnalysis(
            inputs: [try makeBuffer("x", [0, 1]), try makeBuffer("y", [0, 1]), try makeBuffer("xi", [0.5])],
            outputs: [
                .buffer(buffer: out1, data: MutableDoubleArray(data: []), usedAs: "out", append: false),
                .buffer(buffer: out2, data: MutableDoubleArray(data: []), usedAs: "out", append: false)
            ],
            additionalAttributes: .empty), "a second out output must be rejected")
    }
}

//crosscorrelation: raw correlation sums without normalization (matching numpy/scipy/MATLAB
//defaults), and an empty input yields an empty output instead of zeros. The reference test
//compares the vDSP result against plain sums computed independently.
final class CrosscorrelationTests: XCTestCase {
    private func runCrosscorrelation(_ a: [Double], _ b: [Double]) throws -> [Double] {
        let bufferA = try DataBuffer(name: "a", size: 0, baseContents: [], static: false)
        let bufferB = try DataBuffer(name: "b", size: 0, baseContents: [], static: false)
        let out = try DataBuffer(name: "out", size: 0, baseContents: [], static: false)

        let module = try CrosscorrelationAnalysis(
            inputs: [
                .buffer(buffer: bufferA, data: MutableDoubleArray(data: a), usedAs: "in", keep: true),
                .buffer(buffer: bufferB, data: MutableDoubleArray(data: b), usedAs: "in", keep: true)
            ],
            outputs: [.buffer(buffer: out, data: MutableDoubleArray(data: []), usedAs: "out", append: false)],
            additionalAttributes: .empty)
        module.update()
        return out.toArray()
    }

    func testRawSumsWithoutNormalization() throws {
        //m=4, n=2 -> 2 raw sums; the old normalization would have divided them by 2
        let result = try runCrosscorrelation([1, 2, 3, 4], [1, 1])
        XCTAssertEqual(result, [3, 5])
    }

    func testEmptyInputYieldsEmptyOutput() throws {
        XCTAssertEqual(try runCrosscorrelation([1, 2, 3], []), [], "an empty input must yield an empty output, not zeros")
        XCTAssertEqual(try runCrosscorrelation([], [1, 2, 3]), [])
        //equal lengths yield abs(m-n) = 0 values
        XCTAssertEqual(try runCrosscorrelation([1, 2], [3, 4]), [])
    }

    func testAgainstPlainSumReference() throws {
        //the offline plain-sum reference: the vDSP result must match sums computed naively
        let a = (0..<200).map { sin(Double($0) * 0.37) + 0.5 * cos(Double($0) * 0.11) }
        let b = (0..<50).map { sin(Double($0) * 0.29) - 0.3 * cos(Double($0) * 0.53) }

        let result = try runCrosscorrelation(a, b)
        XCTAssertEqual(result.count, 150)

        for n in 0..<150 {
            var reference = 0.0
            for p in 0..<50 {
                reference += a[n + p] * b[p]
            }
            XCTAssertEqual(result[n], reference, accuracy: 1e-9, "raw sum mismatch at offset \(n)")
        }
    }
}

//periodicity: an invalid dx (non-positive, non-finite, empty buffer) yields empty outputs
//instead of running at dx=1; min is floored and max is ceiled (a fractional max includes the
//boundary period); NaN bounds yield empty outputs; x shorter than y processes the common
//length instead of trapping.
final class PeriodicityEdgeCaseTests: XCTestCase {
    private func runPeriodicity(x: [Double], y: [Double], dx: ExperimentAnalysisDataInput, extra: [ExperimentAnalysisDataInput] = []) throws -> (time: [Double], period: [Double]) {
        let xBuffer = try DataBuffer(name: "x", size: 0, baseContents: [], static: false)
        let yBuffer = try DataBuffer(name: "y", size: 0, baseContents: [], static: false)
        let timeOut = try DataBuffer(name: "time", size: 0, baseContents: [], static: false)
        let periodOut = try DataBuffer(name: "period", size: 0, baseContents: [], static: false)

        let module = try PeriodicityAnalysis(
            inputs: [
                .buffer(buffer: xBuffer, data: MutableDoubleArray(data: x), usedAs: "x", keep: true),
                .buffer(buffer: yBuffer, data: MutableDoubleArray(data: y), usedAs: "y", keep: true),
                dx
            ] + extra,
            outputs: [
                .buffer(buffer: timeOut, data: MutableDoubleArray(data: []), usedAs: "time", append: false),
                .buffer(buffer: periodOut, data: MutableDoubleArray(data: []), usedAs: "period", append: false)
            ],
            additionalAttributes: .empty)
        module.update()
        return (timeOut.toArray(), periodOut.toArray())
    }

    private var cosineSignal: [Double] {
        return (0..<64).map { cos(2.0 * Double.pi * Double($0) / 8.0) }
    }

    func testInvalidDxYieldsEmptyOutputs() throws {
        let x = (0..<64).map(Double.init)
        for dx in [ExperimentAnalysisDataInput.value(value: 0, usedAs: "dx"),
                   .value(value: -2, usedAs: "dx"),
                   .value(value: .nan, usedAs: "dx")] {
            let result = try runPeriodicity(x: x, y: cosineSignal, dx: dx)
            XCTAssertEqual(result.time, [], "an invalid dx must yield empty outputs, not run at dx = 1")
            XCTAssertEqual(result.period, [])
        }
        let emptyDx = try DataBuffer(name: "dx", size: 0, baseContents: [], static: false)
        let result = try runPeriodicity(x: x, y: cosineSignal, dx: .buffer(buffer: emptyDx, data: MutableDoubleArray(data: []), usedAs: "dx", keep: true))
        XCTAssertEqual(result.time, [], "an empty dx buffer must yield empty outputs")
    }

    func testFractionalMaxIsCeiled() throws {
        //Period-8 cosine, search range min=6, max=9.5: the peak at 8 needs its right neighbour
        //at 9 evaluated for the parabolic fit, so a ceiled max (10) finds the period while a
        //truncated max (9) would report NaN.
        let x = (0..<64).map(Double.init)
        let result = try runPeriodicity(x: x, y: cosineSignal, dx: .value(value: 64, usedAs: "dx"), extra: [
            .value(value: 6, usedAs: "min"),
            .value(value: 9.5, usedAs: "max")
        ])
        XCTAssertEqual(result.period.count, 1)
        XCTAssertEqual(result.period[0], 8, accuracy: 0.5, "a fractional max must be ceiled so the boundary period is found")
    }

    func testNaNBoundsYieldEmptyOutputs() throws {
        let x = (0..<64).map(Double.init)
        for bound in [ExperimentAnalysisDataInput.value(value: .nan, usedAs: "min"),
                      .value(value: .nan, usedAs: "max")] {
            let result = try runPeriodicity(x: x, y: cosineSignal, dx: .value(value: 64, usedAs: "dx"), extra: [bound])
            XCTAssertEqual(result.time, [])
        }
    }

    func testXShorterThanYProcessesCommonLength() throws {
        let x = (0..<16).map(Double.init)
        let result = try runPeriodicity(x: x, y: cosineSignal, dx: .value(value: 16, usedAs: "dx"))
        XCTAssertEqual(result.time, [0], "x shorter than y truncates to the common length instead of trapping")
        XCTAssertEqual(result.period.count, 1)
    }
}

//sort: all buffers are truncated to the shortest input before sorting (matching Android, no
//NaN substitution for shorter co-buffers), and NaN sorts deterministically as the largest
//value like Java's Double.compareTo.
final class SortUnequalLengthTests: XCTestCase {
    private func runSort(_ inputData: [[Double]], descending: Bool = false) throws -> [[Double]] {
        let inputs: [ExperimentAnalysisDataInput] = try inputData.map {
            let buffer = try DataBuffer(name: "in", size: 0, baseContents: [], static: false)
            return .buffer(buffer: buffer, data: MutableDoubleArray(data: $0), usedAs: "in", keep: true)
        }
        let outBuffers = try (0..<inputData.count).map { try DataBuffer(name: "out\($0)", size: 0, baseContents: [], static: false) }

        let module = try SortAnalysis(
            inputs: inputs,
            outputs: outBuffers.map { .buffer(buffer: $0, data: MutableDoubleArray(data: []), usedAs: "out", append: false) },
            additionalAttributes: .empty)
        module.descending = descending
        module.update()
        return outBuffers.map { $0.toArray() }
    }

    func testCoBufferSorting() throws {
        let result = try runSort([[3, 1, 2], [30, 10, 20]])
        XCTAssertEqual(result[0], [1, 2, 3])
        XCTAssertEqual(result[1], [10, 20, 30], "the co-buffer is reordered along with the sorted buffer")
    }

    func testShorterCoBufferTruncatesAll() throws {
        let result = try runSort([[3, 1, 2], [30, 10]])
        XCTAssertEqual(result[0], [1, 3], "all buffers truncate to the shortest input; no NaN substitution")
        XCTAssertEqual(result[1], [10, 30])
    }

    func testNaNSortsAsLargest() throws {
        let ascending = try runSort([[2, .nan, 1]])
        XCTAssertEqual(ascending[0][0], 1)
        XCTAssertEqual(ascending[0][1], 2)
        XCTAssertTrue(ascending[0][2].isNaN, "NaN must sort as the largest value")

        let descending = try runSort([[2, .nan, 1]], descending: true)
        XCTAssertTrue(descending[0][0].isNaN)
        XCTAssertEqual(descending[0][1], 2)
        XCTAssertEqual(descending[0][2], 1)
    }

    func testMultipleNaNsAreDeterministic() throws {
        let result = try runSort([[.nan, 1, .nan, 0]])
        XCTAssertEqual(result[0][0], 0)
        XCTAssertEqual(result[0][1], 1)
        XCTAssertTrue(result[0][2].isNaN)
        XCTAssertTrue(result[0][3].isNaN)
    }
}

//reduce: processing truncates to the shortest present buffer (only an absent y keeps
//processing all of x with 0 contributions); the incomplete final chunk is averaged over the
//values actually summed, not the nominal factor; a non-finite factor yields empty outputs.
final class ReduceEdgeCaseTests: XCTestCase {
    private func runReduce(factor: Double, x: [Double], y: [Double]? = nil, averageX: Bool = false, averageY: Bool = false, sumY: Bool = false) throws -> (x: [Double], y: [Double]) {
        var inputs: [ExperimentAnalysisDataInput] = [.value(value: factor, usedAs: "factor")]
        let xBuffer = try DataBuffer(name: "x", size: 0, baseContents: [], static: false)
        inputs.append(.buffer(buffer: xBuffer, data: MutableDoubleArray(data: x), usedAs: "x", keep: true))
        if let y = y {
            let yBuffer = try DataBuffer(name: "y", size: 0, baseContents: [], static: false)
            inputs.append(.buffer(buffer: yBuffer, data: MutableDoubleArray(data: y), usedAs: "y", keep: true))
        }
        let xOut = try DataBuffer(name: "xOut", size: 0, baseContents: [], static: false)
        let yOut = try DataBuffer(name: "yOut", size: 0, baseContents: [], static: false)

        let module = try ReduceAnalysis(
            inputs: inputs,
            outputs: [
                .buffer(buffer: xOut, data: MutableDoubleArray(data: []), usedAs: "x", append: false),
                .buffer(buffer: yOut, data: MutableDoubleArray(data: []), usedAs: "y", append: false)
            ],
            additionalAttributes: .empty)
        module.averageX = averageX
        module.averageY = averageY
        module.sumY = sumY
        module.update()
        return (xOut.toArray(), yOut.toArray())
    }

    func testBasicDownsampleAndUpsample() throws {
        let down = try runReduce(factor: 2, x: [1, 2, 3, 4], y: [10, 20, 30, 40])
        XCTAssertEqual(down.x, [1, 3], "without averaging, each chunk keeps its first value")
        XCTAssertEqual(down.y, [10, 30])

        let up = try runReduce(factor: 0.5, x: [1, 2], y: [10, 20])
        XCTAssertEqual(up.x, [1, 1, 2, 2])
        XCTAssertEqual(up.y, [10, 10, 20, 20])
    }

    func testYShorterThanXTruncates() throws {
        let down = try runReduce(factor: 2, x: [1, 2, 3, 4], y: [10, 20, 30])
        XCTAssertEqual(down.x, [1, 3], "processing truncates to the shortest present buffer instead of trapping")
        XCTAssertEqual(down.y, [10, 30])

        let up = try runReduce(factor: 0.5, x: [1, 2], y: [10])
        XCTAssertEqual(up.x, [1, 1], "the upsample branch truncates too, instead of substituting 0")
        XCTAssertEqual(up.y, [10, 10])
    }

    func testIncompleteFinalChunkAveragesOverActualCount() throws {
        let result = try runReduce(factor: 2, x: [0, 2, 5], y: [10, 20, 40], averageX: true, averageY: true)
        XCTAssertEqual(result.x, [1, 5], "the final single-value chunk must be divided by 1, not by the factor")
        XCTAssertEqual(result.y, [15, 40])
    }

    func testNonFiniteFactorYieldsEmptyOutputs() throws {
        for factor in [Double.nan, .infinity, 1e-300] {
            let result = try runReduce(factor: factor, x: [1, 2], y: [10, 20])
            XCTAssertEqual(result.x, [], "factor=\(factor) must yield empty outputs, not a trap")
            XCTAssertEqual(result.y, [])
        }
    }
}

//const/ramp: an explicit length of 0, an empty length buffer and a non-finite or negative
//length yield empty output; only an absent length input falls back to the output buffer's
//size. Empty value/start/stop buffers and non-finite ramp start/stop yield empty output. A
//present NaN const value is a permitted deliberate NaN fill. A single-point ramp outputs its
//start value.
final class ConstRampEdgeCaseTests: XCTestCase {
    private func runConst(value: ExperimentAnalysisDataInput? = nil, length: ExperimentAnalysisDataInput? = nil, bufferSize: Int = 0) throws -> [Double] {
        var inputs: [ExperimentAnalysisDataInput] = []
        if let value = value { inputs.append(value) }
        if let length = length { inputs.append(length) }
        let out = try DataBuffer(name: "out", size: bufferSize, baseContents: [], static: false)

        let module = try ConstGeneratorAnalysis(
            inputs: inputs,
            outputs: [.buffer(buffer: out, data: MutableDoubleArray(data: []), usedAs: "out", append: false)],
            additionalAttributes: .empty)
        module.update()
        return out.toArray()
    }

    private func runRamp(start: ExperimentAnalysisDataInput, stop: ExperimentAnalysisDataInput, length: ExperimentAnalysisDataInput? = nil, bufferSize: Int = 0) throws -> [Double] {
        var inputs: [ExperimentAnalysisDataInput] = [start, stop]
        if let length = length { inputs.append(length) }
        let out = try DataBuffer(name: "out", size: bufferSize, baseContents: [], static: false)

        let module = try RampGeneratorAnalysis(
            inputs: inputs,
            outputs: [.buffer(buffer: out, data: MutableDoubleArray(data: []), usedAs: "out", append: false)],
            additionalAttributes: .empty)
        module.update()
        return out.toArray()
    }

    private func emptyBuffer(_ usedAs: String) throws -> ExperimentAnalysisDataInput {
        let buffer = try DataBuffer(name: usedAs, size: 0, baseContents: [], static: false)
        return .buffer(buffer: buffer, data: MutableDoubleArray(data: []), usedAs: usedAs, keep: true)
    }

    func testConstBasicsAndDefaults() throws {
        XCTAssertEqual(try runConst(value: .value(value: 5, usedAs: "value"), length: .value(value: 3, usedAs: "length")), [5, 5, 5])
        XCTAssertEqual(try runConst(value: .value(value: 7, usedAs: "value"), bufferSize: 4), [7, 7, 7, 7], "an absent length falls back to the output buffer's size")
        XCTAssertEqual(try runConst(length: .value(value: 2, usedAs: "length")), [0, 0], "an absent value keeps the default 0")
    }

    func testConstLengthErrorStates() throws {
        XCTAssertEqual(try runConst(value: .value(value: 5, usedAs: "value"), length: .value(value: 0, usedAs: "length"), bufferSize: 4), [], "an explicit length of 0 yields empty output, not the buffer size")
        XCTAssertEqual(try runConst(value: .value(value: 5, usedAs: "value"), length: try emptyBuffer("length"), bufferSize: 4), [], "an empty length buffer yields empty output")
        for l in [Double.nan, .infinity, -2] {
            XCTAssertEqual(try runConst(value: .value(value: 5, usedAs: "value"), length: .value(value: l, usedAs: "length"), bufferSize: 4), [], "length=\(l) must yield empty output, not a trap")
        }
    }

    func testConstNaNValueIsPermittedFill() throws {
        let result = try runConst(value: .value(value: .nan, usedAs: "value"), length: .value(value: 2, usedAs: "length"))
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.isNaN }, "a present NaN value is a deliberate NaN initialization")
    }

    func testConstEmptyValueBufferYieldsEmptyOutput() throws {
        XCTAssertEqual(try runConst(value: try emptyBuffer("value"), length: .value(value: 2, usedAs: "length")), [])
    }

    func testRampBasics() throws {
        XCTAssertEqual(try runRamp(start: .value(value: 0, usedAs: "start"), stop: .value(value: 10, usedAs: "stop"), length: .value(value: 3, usedAs: "length")), [0, 5, 10])
        XCTAssertEqual(try runRamp(start: .value(value: 0, usedAs: "start"), stop: .value(value: 2, usedAs: "stop"), bufferSize: 3), [0, 1, 2], "an absent length falls back to the output buffer's size")
    }

    func testRampLengthOneOutputsStart() throws {
        XCTAssertEqual(try runRamp(start: .value(value: 5, usedAs: "start"), stop: .value(value: 10, usedAs: "stop"), length: .value(value: 1, usedAs: "length")), [5], "a single-point ramp outputs its start, not NaN")
    }

    func testRampErrorStates() throws {
        //length 0, empty length buffer, non-finite and negative lengths
        XCTAssertEqual(try runRamp(start: .value(value: 0, usedAs: "start"), stop: .value(value: 1, usedAs: "stop"), length: .value(value: 0, usedAs: "length"), bufferSize: 4), [])
        XCTAssertEqual(try runRamp(start: .value(value: 0, usedAs: "start"), stop: .value(value: 1, usedAs: "stop"), length: try emptyBuffer("length"), bufferSize: 4), [])
        for l in [Double.nan, -3] {
            XCTAssertEqual(try runRamp(start: .value(value: 0, usedAs: "start"), stop: .value(value: 1, usedAs: "stop"), length: .value(value: l, usedAs: "length")), [])
        }
        //empty and non-finite start/stop
        XCTAssertEqual(try runRamp(start: try emptyBuffer("start"), stop: .value(value: 1, usedAs: "stop"), length: .value(value: 3, usedAs: "length")), [])
        XCTAssertEqual(try runRamp(start: .value(value: .nan, usedAs: "start"), stop: .value(value: 1, usedAs: "stop"), length: .value(value: 3, usedAs: "length")), [])
        XCTAssertEqual(try runRamp(start: .value(value: 0, usedAs: "start"), stop: .value(value: .infinity, usedAs: "stop"), length: .value(value: 3, usedAs: "length")), [])
    }
}

//split: a present but non-finite index/overlap yields empty outputs; finite indices are
//clamped into range (negative index: out1 empty, out2 receives everything; huge index: no
//trap). Absent inputs keep the defaults (index = input length, overlap = 0).
final class SplitEdgeCaseTests: XCTestCase {
    private func runSplit(data: [Double], index: Double? = nil, overlap: Double? = nil) throws -> (out1: [Double], out2: [Double]) {
        let inBuffer = try DataBuffer(name: "data", size: 0, baseContents: [], static: false)
        var inputs: [ExperimentAnalysisDataInput] = [.buffer(buffer: inBuffer, data: MutableDoubleArray(data: data), usedAs: "data", keep: true)]
        if let index = index {
            inputs.append(.value(value: index, usedAs: "index"))
        }
        if let overlap = overlap {
            inputs.append(.value(value: overlap, usedAs: "overlap"))
        }
        let out1 = try DataBuffer(name: "out1", size: 0, baseContents: [], static: false)
        let out2 = try DataBuffer(name: "out2", size: 0, baseContents: [], static: false)

        let module = try SplitAnalysis(
            inputs: inputs,
            outputs: [
                .buffer(buffer: out1, data: MutableDoubleArray(data: []), usedAs: "out1", append: false),
                .buffer(buffer: out2, data: MutableDoubleArray(data: []), usedAs: "out2", append: false)
            ],
            additionalAttributes: .empty)
        module.update()
        return (out1.toArray(), out2.toArray())
    }

    func testBasicSplitAndDefaults() throws {
        let split = try runSplit(data: [1, 2, 3], index: 2)
        XCTAssertEqual(split.out1, [1, 2])
        XCTAssertEqual(split.out2, [3])

        let defaulted = try runSplit(data: [1, 2, 3])
        XCTAssertEqual(defaulted.out1, [1, 2, 3], "the index defaults to the input length")
        XCTAssertEqual(defaulted.out2, [])

        let overlapping = try runSplit(data: [1, 2, 3], index: 2, overlap: 1)
        XCTAssertEqual(overlapping.out1, [1, 2])
        XCTAssertEqual(overlapping.out2, [2, 3])
    }

    func testOutOfRangeIndicesAreClamped() throws {
        let negative = try runSplit(data: [1, 2, 3], index: -5)
        XCTAssertEqual(negative.out1, [])
        XCTAssertEqual(negative.out2, [1, 2, 3])

        let huge = try runSplit(data: [1, 2, 3], index: 1e300)
        XCTAssertEqual(huge.out1, [1, 2, 3], "an out-of-range index is clamped, not a trap")
        XCTAssertEqual(huge.out2, [])
    }

    func testNonFiniteParametersYieldEmptyOutputs() throws {
        for parameters in [(index: Double.nan, overlap: 0.0), (index: 2.0, overlap: .infinity), (index: -.infinity, overlap: 0.0)] {
            let result = try runSplit(data: [1, 2, 3], index: parameters.index, overlap: parameters.overlap)
            XCTAssertEqual(result.out1, [], "index=\(parameters.index) overlap=\(parameters.overlap) must yield empty outputs")
            XCTAssertEqual(result.out2, [])
        }
    }
}

//eventstream: a NaN threshold participates in the comparisons (nothing triggers); index/skip/
//last keep their documented start defaults (0/0/NaN) when absent or empty; a non-finite value
//reaching the distance/index/skip conversions yields empty outputs instead of trapping, which
//resets the state loop on the next run.
final class EventStreamEdgeCaseTests: XCTestCase {
    private func runEventStream(data: [Double], parameters: [ExperimentAnalysisDataInput] = []) throws -> (events: [Double], index: [Double], skip: [Double], last: [Double]) {
        let inBuffer = try DataBuffer(name: "data", size: 0, baseContents: [], static: false)
        let events = try DataBuffer(name: "events", size: 0, baseContents: [], static: false)
        let indexOut = try DataBuffer(name: "indexOut", size: 0, baseContents: [], static: false)
        let skipOut = try DataBuffer(name: "skipOut", size: 0, baseContents: [], static: false)
        let lastOut = try DataBuffer(name: "lastOut", size: 0, baseContents: [], static: false)

        let module = try EventStreamAnalysis(
            inputs: [.buffer(buffer: inBuffer, data: MutableDoubleArray(data: data), usedAs: "data", keep: true)] + parameters,
            outputs: [
                .buffer(buffer: events, data: MutableDoubleArray(data: []), usedAs: "events", append: false),
                .buffer(buffer: indexOut, data: MutableDoubleArray(data: []), usedAs: "index", append: false),
                .buffer(buffer: skipOut, data: MutableDoubleArray(data: []), usedAs: "skip", append: false),
                .buffer(buffer: lastOut, data: MutableDoubleArray(data: []), usedAs: "last", append: false)
            ],
            additionalAttributes: .empty)
        module.update()
        return (events.toArray(), indexOut.toArray(), skipOut.toArray(), lastOut.toArray())
    }

    func testBasicTriggering() throws {
        let result = try runEventStream(data: [0, 5, 0, 6], parameters: [.value(value: 3, usedAs: "threshold")])
        XCTAssertEqual(result.events, [1, 3])
        XCTAssertEqual(result.index, [4])
        XCTAssertEqual(result.skip, [0])
        XCTAssertEqual(result.last, [6])
    }

    func testDistanceSkipsSamples() throws {
        let result = try runEventStream(data: [0, 5, 5, 5], parameters: [
            .value(value: 3, usedAs: "threshold"),
            .value(value: 2, usedAs: "distance")
        ])
        XCTAssertEqual(result.events, [1], "the two samples after the trigger are skipped")
        XCTAssertEqual(result.index, [4])
        XCTAssertEqual(result.skip, [0])
        XCTAssertEqual(result.last, [5])
    }

    func testNaNThresholdParticipates() throws {
        let result = try runEventStream(data: [1, 2], parameters: [.value(value: .nan, usedAs: "threshold")])
        XCTAssertEqual(result.events, [], "no comparison with a NaN threshold is true")
        XCTAssertEqual(result.index, [2])
        XCTAssertEqual(result.last, [2])
    }

    func testNonFiniteStateYieldsEmptyOutputs() throws {
        for parameter in [ExperimentAnalysisDataInput.value(value: .nan, usedAs: "index"),
                          .value(value: .infinity, usedAs: "skip"),
                          .value(value: .nan, usedAs: "distance")] {
            let result = try runEventStream(data: [0, 5], parameters: [.value(value: 3, usedAs: "threshold"), parameter])
            XCTAssertEqual(result.events, [])
            XCTAssertEqual(result.index, [], "a non-finite state value must yield empty outputs, not a trap")
            XCTAssertEqual(result.skip, [])
            XCTAssertEqual(result.last, [])
        }
    }

    func testEmptyStateBuffersSelectStartDefaults() throws {
        let indexBuffer = try DataBuffer(name: "index", size: 0, baseContents: [], static: false)
        let result = try runEventStream(data: [0, 5], parameters: [
            .value(value: 3, usedAs: "threshold"),
            .buffer(buffer: indexBuffer, data: MutableDoubleArray(data: []), usedAs: "index", keep: true)
        ])
        XCTAssertEqual(result.events, [1], "an empty index buffer selects the start default 0")
        XCTAssertEqual(result.index, [2])
    }
}

//movingaverage: non-finite values inside the window are skipped (aligning with average and
//binning; a window without any finite value yields NaN). A present but invalid width
//(non-finite or negative) yields empty output; an absent width input or an empty width buffer
//selects the documented default of 10.
final class MovingAverageEdgeCaseTests: XCTestCase {
    private func runMovingAverage(data: [Double], width: ExperimentAnalysisDataInput? = nil) throws -> [Double] {
        let inBuffer = try DataBuffer(name: "data", size: 0, baseContents: [], static: false)
        var inputs: [ExperimentAnalysisDataInput] = [.buffer(buffer: inBuffer, data: MutableDoubleArray(data: data), usedAs: "data", keep: true)]
        if let width = width {
            inputs.append(width)
        }
        let out = try DataBuffer(name: "out", size: 0, baseContents: [], static: false)

        let module = try MovingAverageAnalysis(
            inputs: inputs,
            outputs: [.buffer(buffer: out, data: MutableDoubleArray(data: []), usedAs: "data", append: false)],
            additionalAttributes: .empty)
        module.update()
        return out.toArray()
    }

    func testBasicMovingAverage() throws {
        let result = try runMovingAverage(data: [1, 2, 3, 4], width: .value(value: 1, usedAs: "width"))
        XCTAssertEqual(result, [1, 1.5, 2.5, 3.5])
    }

    func testNonFiniteValuesInWindowAreSkipped() throws {
        let result = try runMovingAverage(data: [1, .nan, 3], width: .value(value: 2, usedAs: "width"))
        XCTAssertEqual(result, [1, 1, 2], "NaN in the window must be skipped, not propagate into every average")
    }

    func testAllNonFiniteWindowYieldsNaN() throws {
        let result = try runMovingAverage(data: [.nan], width: .value(value: 0, usedAs: "width"))
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].isNaN)
    }

    func testInvalidWidthYieldsEmptyOutput() throws {
        for width in [Double.nan, .infinity, -.infinity, -1] {
            let result = try runMovingAverage(data: [1, 2, 3], width: .value(value: width, usedAs: "width"))
            XCTAssertEqual(result, [], "width=\(width) must yield an empty output, not a trap or substitute width")
        }
    }

    func testEmptyWidthBufferSelectsDefault() throws {
        let widthBuffer = try DataBuffer(name: "width", size: 0, baseContents: [], static: false)
        let result = try runMovingAverage(data: [1, 2], width: .buffer(buffer: widthBuffer, data: MutableDoubleArray(data: []), usedAs: "width", keep: true))
        XCTAssertEqual(result, [1, 1.5], "an empty width buffer selects the default of 10")
    }
}

//binning: invalid dx (zero, negative, non-finite) and non-finite x0 yield empty outputs (no
//silent dx=1 substitution); absent inputs or empty parameter buffers keep the defaults x0=0,
//dx=1. Bins are lower-edge inclusive with floor semantics - truncation toward zero would give
//bin 0 double width.
final class BinningEdgeCaseTests: XCTestCase {
    private func runBinning(data: [Double], x0: Double? = nil, dx: Double? = nil, dxBuffer: [Double]? = nil) throws -> (starts: [Double], counts: [Double]) {
        let inBuffer = try DataBuffer(name: "in", size: 0, baseContents: [], static: false)
        var inputs: [ExperimentAnalysisDataInput] = [.buffer(buffer: inBuffer, data: MutableDoubleArray(data: data), usedAs: "in", keep: true)]
        if let x0 = x0 {
            inputs.append(.value(value: x0, usedAs: "x0"))
        }
        if let dx = dx {
            inputs.append(.value(value: dx, usedAs: "dx"))
        }
        if let dxBuffer = dxBuffer {
            let buffer = try DataBuffer(name: "dx", size: 0, baseContents: [], static: false)
            inputs.append(.buffer(buffer: buffer, data: MutableDoubleArray(data: dxBuffer), usedAs: "dx", keep: true))
        }
        let startsOut = try DataBuffer(name: "binStarts", size: 0, baseContents: [], static: false)
        let countsOut = try DataBuffer(name: "binCounts", size: 0, baseContents: [], static: false)

        let module = try BinningAnalysis(
            inputs: inputs,
            outputs: [
                .buffer(buffer: startsOut, data: MutableDoubleArray(data: []), usedAs: "binStarts", append: false),
                .buffer(buffer: countsOut, data: MutableDoubleArray(data: []), usedAs: "binCounts", append: false)
            ],
            additionalAttributes: .empty)
        module.update()
        return (startsOut.toArray(), countsOut.toArray())
    }

    func testInvalidDxAndX0YieldEmptyOutputs() throws {
        for (x0, dx) in [(0.0, 0.0), (0.0, -1.0), (0.0, Double.nan), (0.0, .infinity), (Double.nan, 1.0), (.infinity, 1.0)] {
            let result = try runBinning(data: [1, 2, 3], x0: x0, dx: dx)
            XCTAssertEqual(result.starts, [], "x0=\(x0) dx=\(dx) must yield empty outputs")
            XCTAssertEqual(result.counts, [])
        }
    }

    func testEmptyDxBufferKeepsDefault() throws {
        let result = try runBinning(data: [0.5, 1.5], dxBuffer: [])
        XCTAssertEqual(result.starts, [0, 1], "an empty dx buffer keeps the default dx = 1")
        XCTAssertEqual(result.counts, [1, 1])
    }

    func testBinZeroIsNotDoubleWidth() throws {
        //floor semantics: -0.5 belongs to bin -1, 0.5 to bin 0. Truncation put both in bin 0.
        let result = try runBinning(data: [-0.5, 0.5], x0: 0, dx: 1)
        XCTAssertEqual(result.starts, [-1, 0])
        XCTAssertEqual(result.counts, [1, 1])
    }

    func testLowerEdgeInclusive() throws {
        let result = try runBinning(data: [1.0], x0: 0, dx: 1)
        XCTAssertEqual(result.starts, [1], "a value exactly on a bin edge belongs to the bin starting there")
        XCTAssertEqual(result.counts, [1])
    }

    func testBasicBinningAndNonFiniteValuesSkipped() throws {
        let result = try runBinning(data: [0.1, .nan, 0.2, 1.5, .infinity], x0: 0, dx: 1)
        XCTAssertEqual(result.starts, [0, 1])
        XCTAssertEqual(result.counts, [2, 1])
    }

    func testHugeRatioDoesNotTrap() throws {
        //finite parameters, but the bin index of 1e300 exceeds Int - that value is skipped, no trap
        let result = try runBinning(data: [1e300, 0.5], x0: 0, dx: 1)
        XCTAssertEqual(result.starts, [0])
        XCTAssertEqual(result.counts, [1])
    }
}

//max/min: one comparison loop like Android - NaN values never win a comparison, an x buffer
//shorter than y truncates to the common length, the final open set in multiple mode is flushed,
//and an empty/all-invalid input yields NaN per connected output (single mode) or empty outputs
//(multiple mode).
final class MaxMinAnalysisTests: XCTestCase {
    private func run(_ isMax: Bool, x: [Double]? = nil, y: [Double], threshold: Double? = nil, multiple: Bool = false) throws -> (values: [Double], positions: [Double]) {
        var inputs: [ExperimentAnalysisDataInput] = []
        if let x = x {
            let xBuffer = try DataBuffer(name: "x", size: 0, baseContents: [], static: false)
            inputs.append(.buffer(buffer: xBuffer, data: MutableDoubleArray(data: x), usedAs: "x", keep: true))
        }
        let yBuffer = try DataBuffer(name: "y", size: 0, baseContents: [], static: false)
        inputs.append(.buffer(buffer: yBuffer, data: MutableDoubleArray(data: y), usedAs: "y", keep: true))
        if let threshold = threshold {
            inputs.append(.value(value: threshold, usedAs: "threshold"))
        }

        let valueOut = try DataBuffer(name: "value", size: 0, baseContents: [], static: false)
        let positionOut = try DataBuffer(name: "position", size: 0, baseContents: [], static: false)
        let outputs: [ExperimentAnalysisDataOutput] = [
            .buffer(buffer: valueOut, data: MutableDoubleArray(data: []), usedAs: isMax ? "max" : "min", append: false),
            .buffer(buffer: positionOut, data: MutableDoubleArray(data: []), usedAs: "position", append: false)
        ]

        if isMax {
            let module = try MaxAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: .empty)
            module.multiple = multiple
            module.update()
        } else {
            let module = try MinAnalysis(inputs: inputs, outputs: outputs, additionalAttributes: .empty)
            module.multiple = multiple
            module.update()
        }
        return (valueOut.toArray(), positionOut.toArray())
    }

    func testSingleModeBasics() throws {
        let maxResult = try run(true, x: [10, 20, 30], y: [1, 5, 3])
        XCTAssertEqual(maxResult.values, [5])
        XCTAssertEqual(maxResult.positions, [20])

        let minResult = try run(false, y: [3, 1, 2])
        XCTAssertEqual(minResult.values, [1])
        XCTAssertEqual(minResult.positions, [1], "an omitted x input auto-generates indices")
    }

    func testNaNValuesAreSkipped() throws {
        //the audio_scope fallback shape: min over [2400, NaN] must be 2400
        let minResult = try run(false, y: [2400, .nan])
        XCTAssertEqual(minResult.values, [2400], "NaN must not leak into the result like vDSP_minvD would")

        let maxResult = try run(true, y: [.nan, 5, .nan])
        XCTAssertEqual(maxResult.values, [5])
        XCTAssertEqual(maxResult.positions, [1])
    }

    func testEmptyAndAllInvalidInputYieldNaNInSingleMode() throws {
        for y in [[Double](), [Double.nan, Double.nan]] {
            let result = try run(true, y: y)
            XCTAssertEqual(result.values.count, 1)
            XCTAssertTrue(result.values[0].isNaN, "empty/all-invalid input must yield NaN, not a vDSP artifact")
            XCTAssertEqual(result.positions.count, 1)
            XCTAssertTrue(result.positions[0].isNaN)
        }
    }

    func testXShorterThanYTruncates() throws {
        let result = try run(true, x: [10], y: [1, 5])
        XCTAssertEqual(result.values, [1], "processing truncates to the common length instead of trapping")
        XCTAssertEqual(result.positions, [10])
    }

    func testMultipleModeFlushesTrailingSet() throws {
        let maxResult = try run(true, y: [1, 2, -1, 3, 4], threshold: 0, multiple: true)
        XCTAssertEqual(maxResult.values, [2, 4], "the set still open at the end of the data must be emitted")
        XCTAssertEqual(maxResult.positions, [1, 4])

        let minResult = try run(false, y: [-1, -2, 1, -3], threshold: 0, multiple: true)
        XCTAssertEqual(minResult.values, [-2, -3])
        XCTAssertEqual(minResult.positions, [1, 3])
    }

    func testMultipleModeEmptyInputYieldsEmptyOutputs() throws {
        let result = try run(true, y: [], threshold: 0, multiple: true)
        XCTAssertEqual(result.values, [])
        XCTAssertEqual(result.positions, [])
    }

    func testMultipleModeNaNThresholdFormsOneSet() throws {
        let result = try run(true, y: [1, -2, 3], threshold: .nan, multiple: true)
        XCTAssertEqual(result.values, [3], "no comparison with a NaN threshold is true, so the whole input is one set")
        XCTAssertEqual(result.positions, [2])
    }
}

//round in default mode: ties round half away from zero (C rounding, like the formula
//language's round) and non-finite values pass through unchanged. vvnint was replaced because
//it rounds ties to even.
final class RoundTiesTests: XCTestCase {
    func testTiesRoundHalfAwayFromZeroAndNonFinitePassesThrough() throws {
        let inputBuffer = try DataBuffer(name: "in", size: 0, baseContents: [], static: false)
        let inputData = MutableDoubleArray(data: [0.5, 1.5, 2.5, -0.5, -1.5, -2.5, 2.4, -2.4, .nan, .infinity, -.infinity])
        let out = try DataBuffer(name: "out", size: 0, baseContents: [], static: false)

        let module = try RoundAnalysis(
            inputs: [.buffer(buffer: inputBuffer, data: inputData, usedAs: "value", keep: true)],
            outputs: [.buffer(buffer: out, data: MutableDoubleArray(data: []), usedAs: "round", append: false)],
            additionalAttributes: .empty)
        module.update()

        let result = out.toArray()
        XCTAssertEqual(Array(result[0..<8]), [1, 2, 3, -1, -2, -3, 2, -2], "ties must round half away from zero, not to even")
        XCTAssertTrue(result[8].isNaN, "NaN passes through unchanged")
        XCTAssertEqual(result[9], .infinity)
        XCTAssertEqual(result[10], -.infinity)
    }
}

//An empty sigma attribute on gausssmooth is treated like an absent one and selects the default
//of 3, consistent with the format-wide empty-equals-omitted convention (matching Android). A
//present non-positive or unparseable sigma still rejects the file.
final class GaussSmoothEmptySigmaTests: XCTestCase {
    private func parse(_ xml: String) throws -> Experiment {
        let stream = InputStream(data: xml.data(using: .utf8)!)
        return try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: stream)
    }

    private func xml(sigma: String) -> String {
        return """
        <phyphox version="1.20">
            <title>t</title>
            <category>c</category>
            <description>d</description>
            <data-containers>
                <container>buffer</container>
                <container>buffer2</container>
            </data-containers>
            <analysis>
                <gausssmooth\(sigma)><input>buffer</input><output>buffer2</output></gausssmooth>
            </analysis>
            <views>
                <view label="v">
                    <value label="l"><input>buffer2</input></value>
                </view>
            </views>
        </phyphox>
        """
    }

    func testEmptySigmaLoadsWithDefault() throws {
        _ = try parse(xml(sigma: " sigma=\"\""))
    }

    func testAbsentSigmaLoads() throws {
        _ = try parse(xml(sigma: ""))
    }

    func testExplicitSigmaLoads() throws {
        _ = try parse(xml(sigma: " sigma=\"2.5\""))
    }

    func testNonPositiveSigmaStillRejected() throws {
        XCTAssertThrowsError(try parse(xml(sigma: " sigma=\"0\"")))
        XCTAssertThrowsError(try parse(xml(sigma: " sigma=\"-1\"")))
    }

    func testUnparseableSigmaStillRejected() throws {
        XCTAssertThrowsError(try parse(xml(sigma: " sigma=\"abc\"")))
    }
}

//subrange error states: a present but non-finite from/to/length yields empty outputs (matching
//Android); only an absent input or an empty parameter buffer keeps the defaults (from 0, to the
//full input range).
final class SubrangeNonfiniteParameterTests: XCTestCase {
    private func runSubrange(data: [Double], parameters: [ExperimentAnalysisDataInput]) throws -> [Double] {
        let inBuffer = try DataBuffer(name: "in", size: 0, baseContents: [], static: false)
        let out = try DataBuffer(name: "out", size: 0, baseContents: [], static: false)

        let module = try SubrangeAnalysis(
            inputs: parameters + [.buffer(buffer: inBuffer, data: MutableDoubleArray(data: data), usedAs: "in", keep: true)],
            outputs: [.buffer(buffer: out, data: MutableDoubleArray(data: []), usedAs: "out", append: false)],
            additionalAttributes: .empty)
        module.update()
        return out.toArray()
    }

    func testNaNToYieldsEmptyOutput() throws {
        let result = try runSubrange(data: [10, 20, 30, 40], parameters: [.value(value: .nan, usedAs: "to")])
        XCTAssertEqual(result, [], "a NaN to must yield an empty output, not the full range")
    }

    func testInfiniteLengthYieldsEmptyOutput() throws {
        let result = try runSubrange(data: [10, 20, 30, 40], parameters: [.value(value: .infinity, usedAs: "length")])
        XCTAssertEqual(result, [])
    }

    func testNaNFromYieldsEmptyOutput() throws {
        let result = try runSubrange(data: [10, 20, 30, 40], parameters: [.value(value: .nan, usedAs: "from")])
        XCTAssertEqual(result, [])
    }

    func testFiniteParametersUnchanged() throws {
        let result = try runSubrange(data: [10, 20, 30, 40], parameters: [
            .value(value: 1, usedAs: "from"),
            .value(value: 3, usedAs: "to")
        ])
        XCTAssertEqual(result, [20, 30])
    }

    func testEmptyParameterBufferKeepsDefault() throws {
        let toBuffer = try DataBuffer(name: "to", size: 0, baseContents: [], static: false)
        let result = try runSubrange(data: [10, 20, 30], parameters: [
            .buffer(buffer: toBuffer, data: MutableDoubleArray(data: []), usedAs: "to", keep: true)
        ])
        XCTAssertEqual(result, [10, 20, 30], "an empty to buffer keeps the full-range default, unlike a non-finite value")
    }
}

final class GCDVectorTests: XCTestCase {
    func testGCDVectorInputs() throws {
        let bufferA = try DataBuffer(name: "a", size: 0, baseContents: [], static: false)
        let bufferB = try DataBuffer(name: "b", size: 0, baseContents: [], static: false)
        let out = try DataBuffer(name: "out", size: 0, baseContents: [], static: false)
        let module = try GCDAnalysis(
            inputs: [
                .buffer(buffer: bufferA, data: MutableDoubleArray(data: [12, 4.5, -4]), usedAs: "value", keep: true),
                .buffer(buffer: bufferB, data: MutableDoubleArray(data: [18, 10, 6]), usedAs: "value", keep: true)
            ],
            outputs: [.buffer(buffer: out, data: MutableDoubleArray(data: []), usedAs: "gcd", append: false)],
            additionalAttributes: .empty)
        module.update()

        let result = out.toArray()
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0], 6)
        XCTAssertEqual(result[1], 5)
        XCTAssertTrue(result[2].isNaN)
    }
}

//Every analysis module must declare the slot table its inputs and outputs are validated
//against (ExperimentAnalysisModule.ioMapping) - without this, a module would silently skip
//validation. Also guards the folding rule: no table may hold two slot names differing only
//in case, or the case-insensitive match would silently pick the first.
final class AnalysisIOMappingCoverageTests: XCTestCase {
    func testEveryModuleDeclaresItsIOMapping() {
        for (key, moduleClass) in ExperimentAnalysisFactory.classMap {
            guard let mapping = moduleClass.ioMapping else {
                XCTFail("\(key) does not declare its io mapping")
                continue
            }
            for slots in [mapping.inputs, mapping.outputs] {
                let folded = slots.map { $0.name.lowercased() }
                XCTAssertEqual(folded.count, Set(folded).count, "\(key) has slot names that collide after case folding")
            }
        }
    }
}

//The four small strictness fixes: unbounded map colour scales, rejection of the Android-only
//bluetooth address attribute, container type validation and gausssmooth's sigma check
//(views-map-color-limit, ble-address-ios-must-reject, container-type-unvalidated and
//gausssmooth-nonpositive-sigma in phyphox-docs).
final class StrictnessFixesTests: XCTestCase {
    private func parse(_ xml: String) throws -> Experiment {
        let stream = InputStream(data: xml.data(using: .utf8)!)
        return try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: stream)
    }

    private func xml(containers: String = "<container>buffer</container>", input: String = "", analysis: String = "", view: String = "<value label=\"l\"><input>buffer</input></value>") -> String {
        return """
        <phyphox version="1.20">
            <title>t</title>
            <category>c</category>
            <description>d</description>
            <data-containers>\(containers)</data-containers>
            <input>\(input)</input>
            <analysis>\(analysis)</analysis>
            <views>
                <view label="v">\(view)</view>
            </views>
        </phyphox>
        """
    }

    private func assertRejects(_ document: String, message expected: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try parse(document), file: file, line: line) { error in
            //The debug description escapes the quotes inside the message
            let rendered = "\(error)".replacingOccurrences(of: "\\\"", with: "\"")
            XCTAssertTrue(rendered.contains(expected), "expected \"\(expected)\" in \(error)", file: file, line: line)
        }
    }

    func testColorAttributesAreStrict() throws {
        //A colour is a named phyphox colour (case-insensitive) or exactly six hex digits with
        //an optional "#"; anything else rejects the file instead of silently falling back to
        //the element's default (color-invalid-value in phyphox-docs)
        func value(color: String) -> String {
            return xml(view: "<value label=\"l\" color=\"\(color)\"><input>buffer</input></value>")
        }
        _ = try parse(value(color: "orange"))
        _ = try parse(value(color: "WeakGreen"))
        _ = try parse(value(color: "fF00Aa"))
        _ = try parse(value(color: "#ff00aa"))

        //"abc" and "12zz34" would pass the old NSScanner hex path (any digit count, trailing
        //garbage ignored); Android accepts exactly six digits, nothing else
        for bad in ["bogus", "abc", "#abc", "12zz34", "ff00aab", "#ff00aabb"] {
            assertRejects(value(color: bad), message: "Could not parse color \"\(bad)\" of attribute \"color\".")
        }
    }

    func testMapColorStopsAreStrict() throws {
        //A present but unparseable stop is an error, not the end of the scale
        assertRejects(xml(view: """
            <graph label="g" style="map" mapWidth="10" mapColor1="red" mapColor2="bogus" mapColor3="blue">
                <input axis="x">buffer</input>
                <input axis="y">buffer</input>
                <input axis="z">buffer</input>
            </graph>
        """), message: "Could not parse color \"bogus\" of attribute \"mapColor2\".")
    }

    func testPerSetGraphColorIsStrict() throws {
        //The per-set colour on a graph input tag carries Android's distinct message
        assertRejects(xml(view: """
            <graph label="g">
                <input axis="x">buffer</input>
                <input axis="y" color="bogus">buffer</input>
            </graph>
        """), message: "Could not parse color of input tag.")
        //A valid per-set colour still parses
        _ = try parse(xml(view: """
            <graph label="g">
                <input axis="x">buffer</input>
                <input axis="y" color="#ff00aa">buffer</input>
            </graph>
        """))
    }

    func testMapColorScaleIsUnbounded() throws {
        let colors = ["red", "green", "blue", "yellow", "orange", "magenta", "white", "weakred", "weakgreen", "weakblue", "weakyellow", "weakorange"]
        let mapColors = colors.enumerated().map { "mapColor\($0.offset + 1)=\"\($0.element)\"" }.joined(separator: " ")
        let experiment = try parse(xml(view: """
            <graph label="g" style="map" mapWidth="10" \(mapColors)>
                <input axis="x">buffer</input>
                <input axis="y">buffer</input>
                <input axis="z">buffer</input>
            </graph>
        """))
        let graph = try ((experiment.viewDescriptors?.first?.views.first) as? GraphViewDescriptor).unwrap()
        XCTAssertEqual(graph.colorMap.count, 12, "a tenth stop and beyond must no longer be dropped")
    }

    func testBluetoothAddressIsRejected() {
        //An experiment pinned to a hardware address cannot be honoured on iOS and must not
        //silently connect to whatever matches the remaining criteria
        XCTAssertThrowsError(try parse(xml(input: """
            <bluetooth name="d" mode="notification" address="00:11:22:33:44:55">
                <output char="cddf1002-30f7-4671-8b43-5e40ba53514a" conversion="float32LittleEndian">buffer</output>
            </bluetooth>
        """)))
        //Without the attribute the same block parses
        XCTAssertNoThrow(try parse(xml(input: """
            <bluetooth name="d" mode="notification">
                <output char="cddf1002-30f7-4671-8b43-5e40ba53514a" conversion="float32LittleEndian">buffer</output>
            </bluetooth>
        """)))
    }

    func testContainerTypeIsValidated() throws {
        _ = try parse(xml(containers: "<container type=\"buffer\">buffer</container>"))
        _ = try parse(xml(containers: "<container type=\"BUFFER\">buffer</container>")) //folds
        XCTAssertThrowsError(try parse(xml(containers: "<container type=\"bogus\">buffer</container>")))
    }

    func testGaussSmoothSigmaIsValidated() throws {
        func gauss(_ attributes: String) -> String {
            return xml(analysis: "<gausssmooth \(attributes)><input>buffer</input><output>buffer</output></gausssmooth>")
        }
        _ = try parse(gauss(""))                //absent keeps the default of 3
        _ = try parse(gauss("sigma=\"2.5\""))
        XCTAssertThrowsError(try parse(gauss("sigma=\"0\"")), "sigma 0 would divide the kernel normalisation by zero")
        XCTAssertThrowsError(try parse(gauss("sigma=\"-1\"")))
    }
}

//Guard rail for the case folding of enumerated attribute values: no allowed set may contain two
//values differing only in case, or the folding scan would silently pick the first
//(enum-case-insensitive in phyphox-docs). Walks every CaseInsensitiveAttributeDecodable enum
//reachable from tests; the two file-private ones (icon Format, GraphAxis) hold trivially distinct
//values. The analysis slot tables get the same check in AnalysisIOMappingCoverageTests.
final class CaseFoldingGuardRailTests: XCTestCase {
    func testNoEnumHasCaseFoldedRawValueCollisions() {
        func check<T: CaseIterable & RawRepresentable>(_ type: T.Type) where T.RawValue == String {
            let folded = type.allCases.map { $0.rawValue.lowercased() }
            XCTAssertEqual(folded.count, Set(folded).count, "\(type) has raw values that collide after case folding")
        }
        check(SensorType.self)
        check(SensorMetadata.self)
        check(ExperimentSensorInput.RateStrategy.self)
        check(ExperimentDepthInput.DepthExtractionMode.self)
        check(ExperimentDepthInput.CameraOrientation.self)
        check(ExperimentCameraInput.AutoExposureStrategy.self)
        check(CameraFeature.self)
        check(SimpleInputConversion.ConversionFunction.self)
        check(SimpleOutputConversion.ConversionFunction.self)
        check(SimpleConfigConversion.ConversionFunction.self)
        check(BluetoothMode.self)
        check(BluetoothOutputExtra.self)
        check(AudioWaveform.self)
        check(DataInputTypeAttribute.self)
        check(NetworkConnectionSendDescriptor.SendableType.self)
        check(EventStreamAnalysis.TriggerMode.self)
        check(InterpolateAnalysis.InterpolationMethod.self)
        check(GraphPickAxis.self)
        check(GraphViewDescriptor.ScaleMode.self)
        check(GraphViewDescriptor.GraphStyle.self)
        check(ImageViewElementDescriptor.Filter.self)
        check(InfoViewElementDescriptor.TextAlignment.self)
    }
}

//Regression test for GitHub issue 22: a remote /get read must see a consistent length across
//buffers that are written together, even while a measurement keeps writing. The shared BufferLock
//makes a multi-buffer write group atomic with respect to a read snapshot.
final class BufferSnapshotConsistencyTests: XCTestCase {
    func testGroupedWritesAreAtomicAgainstReads() throws {
        let lock = BufferLock()
        let a = try DataBuffer(name: "a", size: 0, baseContents: [], static: false)
        let b = try DataBuffer(name: "b", size: 0, baseContents: [], static: false)
        a.dataLock = lock
        b.dataLock = lock

        let sampleCount = 5000
        let writerDone = expectation(description: "writer finished")

        //Writer: append to both buffers as one atomic group, like an input's writeToBuffers
        DispatchQueue.global(qos: .userInitiated).async {
            for i in 0..<sampleCount {
                synchronizedBufferWrite([a, b]) {
                    a.append(Double(i))
                    b.append(Double(i))
                }
            }
            writerDone.fulfill()
        }

        //Reader: snapshot both buffers under the same lock, as /get does. Their lengths must always
        //match; without the lock the writer could land between the two reads and they would differ.
        var reads = 0
        while reads < 20000 {
            lock.read {
                XCTAssertEqual(a.toArray().count, b.toArray().count, "grouped buffers must always have equal length under a snapshot read")
            }
            reads += 1
        }

        wait(for: [writerDone], timeout: 10)
        lock.read {
            XCTAssertEqual(a.toArray().count, sampleCount)
            XCTAssertEqual(b.toArray().count, sampleCount)
        }
    }
}

//The file format version attribute is strictly major.minor. A newer version is refused, and a
//string that is not major.minor is rejected rather than silently reinterpreted - in particular a
//three-part app version like "1.2.0" used by mistake, which used to load (matching Android, which
//requires a plain integer after the dot).
final class FileVersionValidationTests: XCTestCase {
    private func parse(version: String) throws -> Experiment {
        let xml = """
        <phyphox version="\(version)">
            <title>t</title>
            <category>c</category>
            <description>d</description>
            <data-containers><container>buffer</container></data-containers>
            <views><view label="v"><value label="l"><input>buffer</input></value></view></views>
        </phyphox>
        """
        return try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: InputStream(data: xml.data(using: .utf8)!))
    }

    func testSupportedVersionsLoad() throws {
        _ = try parse(version: "1.20")     //the latest supported version
        _ = try parse(version: "1.7")      //an older version
        _ = try parse(version: "1.0")
    }

    func testNewerVersionIsRejected() {
        XCTAssertThrowsError(try parse(version: "1.21"))
        XCTAssertThrowsError(try parse(version: "2.0"))
        XCTAssertThrowsError(try parse(version: "1.100"), "the minor version must compare numerically, not lexically")
    }

    func testMalformedVersionFormatIsRejected() {
        //A three-part app version mistakenly put in the file version attribute - the reported case
        XCTAssertThrowsError(try parse(version: "1.2.0"))
        //Other shapes that are not major.minor
        XCTAssertThrowsError(try parse(version: "1.20.0"))
        XCTAssertThrowsError(try parse(version: "1"))
        XCTAssertThrowsError(try parse(version: "1.20-beta"))
        XCTAssertThrowsError(try parse(version: "v1.20"))
        XCTAssertThrowsError(try parse(version: "1."))
        XCTAssertThrowsError(try parse(version: ""))
    }
}

//Confirms iOS is not affected by two dropdown bugs fixed on Android: a <map> before the <output>
//being dropped, and the default attribute not taking effect. iOS collects maps and the output in
//independent child handlers (order-independent) and applies the default by seeding the output
//buffer, so both work.
final class DropdownViewTests: XCTestCase {
    private func parse(_ dropdown: String) throws -> Experiment {
        let xml = """
        <phyphox version="1.20">
            <title>t</title><category>c</category><description>d</description>
            <data-containers><container>buffer</container></data-containers>
            <views><view label="v">\(dropdown)</view></views>
        </phyphox>
        """
        return try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: InputStream(data: xml.data(using: .utf8)!))
    }

    private func dropdownDescriptor(_ experiment: Experiment) throws -> DropdownViewDescriptor {
        return try (experiment.viewDescriptors?.first?.views.compactMap { $0 as? DropdownViewDescriptor }.first).unwrap()
    }

    func testMapBeforeOutputIsNotDropped() throws {
        //The first <map> comes before <output>; it must still be collected (Android dropped it)
        let experiment = try parse("""
        <dropdown label="d">
            <map value="1">One</map>
            <output>buffer</output>
            <map value="2">Two</map>
        </dropdown>
        """)
        let descriptor = try dropdownDescriptor(experiment)
        XCTAssertEqual(descriptor.mappings.count, 2, "a map before the output must not be dropped")
        XCTAssertEqual(Set(descriptor.mappings.map { $0.value }), [1, 2])
    }

    func testDefaultValueIsApplied() throws {
        let experiment = try parse("""
        <dropdown label="d" default="2">
            <output>buffer</output>
            <map value="1">One</map>
            <map value="2">Two</map>
        </dropdown>
        """)
        let descriptor = try dropdownDescriptor(experiment)
        XCTAssertEqual(descriptor.defaultValue, 2)
        XCTAssertEqual(descriptor.buffer.last, 2, "the default is written to the empty output buffer so the matching option is selected")
        XCTAssertEqual(descriptor.value, 2)
    }
}

//An FFT with a real input only (no imaginary input) treats the imaginary part as zero and returns
//the full complex spectrum, not the unique first half - matching Android.
final class FFTRealInputTests: XCTestCase {
    func testRealOnlyFFTReturnsFullLength() throws {
        let inputBuffer = try DataBuffer(name: "in", size: 0, baseContents: [], static: false)
        let inputData = MutableDoubleArray(data: [1, 2, 3, 4, 5, 6, 7, 8])
        let reOut = try DataBuffer(name: "re", size: 0, baseContents: [], static: false)
        let imOut = try DataBuffer(name: "im", size: 0, baseContents: [], static: false)

        let module = try FFTAnalysis(
            inputs: [.buffer(buffer: inputBuffer, data: inputData, usedAs: "re", keep: true)],
            outputs: [
                .buffer(buffer: reOut, data: MutableDoubleArray(data: []), usedAs: "re", append: false),
                .buffer(buffer: imOut, data: MutableDoubleArray(data: []), usedAs: "im", append: false)
            ],
            additionalAttributes: .empty)
        module.update()

        let expected = nextFFTSize(8) //8 is already a power of two, so the FFT length is 8
        XCTAssertEqual(reOut.toArray().count, expected, "a real-only FFT must return the full complex spectrum, not half")
        XCTAssertEqual(imOut.toArray().count, expected)
        //The DC bin equals the sum of the input (1..8 = 36); a sanity check that it is a real FFT
        XCTAssertEqual(reOut.toArray().first ?? 0, 36, accuracy: 1e-6)
    }

    func testTinyInputDoesNotCrash() throws {
        //vDSP_DFT documents a minimum length of 8 but handles N = 1, 2 and 4; this pins that
        //inputs below 8 samples produce a correct transform (and never a crash)
        let inputBuffer = try DataBuffer(name: "in", size: 0, baseContents: [], static: false)
        let inputData = MutableDoubleArray(data: [1, 2])
        let reOut = try DataBuffer(name: "re", size: 0, baseContents: [], static: false)
        let imOut = try DataBuffer(name: "im", size: 0, baseContents: [], static: false)

        let module = try FFTAnalysis(
            inputs: [.buffer(buffer: inputBuffer, data: inputData, usedAs: "re", keep: true)],
            outputs: [
                .buffer(buffer: reOut, data: MutableDoubleArray(data: []), usedAs: "re", append: false),
                .buffer(buffer: imOut, data: MutableDoubleArray(data: []), usedAs: "im", append: false)
            ],
            additionalAttributes: .empty)
        module.update()

        //DFT of [1, 2]: X0 = 3, X1 = -1, imaginary parts zero
        let re = reOut.toArray()
        let im = imOut.toArray()
        XCTAssertEqual(re.count, 2)
        XCTAssertEqual(re[0], 3, accuracy: 1e-9)
        XCTAssertEqual(re[1], -1, accuracy: 1e-9)
        XCTAssertEqual(im[0], 0, accuracy: 1e-9)
        XCTAssertEqual(im[1], 0, accuracy: 1e-9)
    }
}

//The x output of autocorrelation is optional and omitting it must simply skip it, like on
//Android - it used to trap on a forced unwrap as soon as data arrived. min/max filtering has
//to keep working without an x output, applied to the implicit 0,1,2,... displacement ramp.
final class AutocorrelationOmittedXOutputTests: XCTestCase {
    //Autocorrelation of [1,2,3,4]: displacement i yields sum(y[j]*y[j+i])/(count-i)
    private let expectedY = [7.5, 20.0/3.0, 5.5, 4.0]

    func testOmittedXOutput() throws {
        let inputBuffer = try DataBuffer(name: "in", size: 0, baseContents: [], static: false)
        let inputData = MutableDoubleArray(data: [1, 2, 3, 4])
        let yOut = try DataBuffer(name: "y", size: 0, baseContents: [], static: false)

        let module = try AutocorrelationAnalysis(
            inputs: [.buffer(buffer: inputBuffer, data: inputData, usedAs: "y", keep: true)],
            outputs: [.buffer(buffer: yOut, data: MutableDoubleArray(data: []), usedAs: "y", append: false)],
            additionalAttributes: .empty)
        module.update()

        let result = yOut.toArray()
        XCTAssertEqual(result.count, expectedY.count)
        for (value, expected) in zip(result, expectedY) {
            XCTAssertEqual(value, expected, accuracy: 1e-12)
        }
    }

    func testOmittedXOutputWithFiltering() throws {
        let inputBuffer = try DataBuffer(name: "in", size: 0, baseContents: [], static: false)
        let inputData = MutableDoubleArray(data: [1, 2, 3, 4])
        let yOut = try DataBuffer(name: "y", size: 0, baseContents: [], static: false)

        let module = try AutocorrelationAnalysis(
            inputs: [
                .buffer(buffer: inputBuffer, data: inputData, usedAs: "y", keep: true),
                .value(value: 1.0, usedAs: "minX"),
                .value(value: 2.0, usedAs: "maxX")
            ],
            outputs: [.buffer(buffer: yOut, data: MutableDoubleArray(data: []), usedAs: "y", append: false)],
            additionalAttributes: .empty)
        module.update()

        let result = yOut.toArray()
        XCTAssertEqual(result.count, 2, "only the displacements 1 and 2 pass the minX/maxX filter")
        for (value, expected) in zip(result, [expectedY[1], expectedY[2]]) {
            XCTAssertEqual(value, expected, accuracy: 1e-12)
        }
    }
}
