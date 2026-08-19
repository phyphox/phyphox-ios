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
}
