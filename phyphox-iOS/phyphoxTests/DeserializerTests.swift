//
//  DeserializerTests.swift
//  phyphoxTests
//
//  Created by Jonas Gessner on 15.06.18.
//  Copyright © 2018 Jonas Gessner. All rights reserved.
//

import Foundation
import XCTest
@testable import phyphox


private enum XMLParseResult {
    case failure
    case success
}

var testBundle: Bundle {
    return Bundle(for: DeserializerTests.self)
}

final class DeserializerTests: XCTestCase {
    private let experimentsBaseURL = testBundle.url(forResource: "phyphox-experiments", withExtension: nil)!
    
    @discardableResult private func expectParserResult<Handler: ResultElementHandler>(expectedResult: XMLParseResult, handler: Handler, inputStream: InputStream) throws -> Handler.Result? {
        let parser = DocumentParser(documentHandler: handler)

        switch expectedResult {
        case .failure:
            do {
               let result = try parser.parse(stream: inputStream)
                XCTFail()
                return result
            }
            catch {
                return nil
            }
        case .success:
            return try parser.parse(stream: inputStream)
        }
    }

    func testDefaultExperiments() throws {
        let experiments = try FileManager.default.contentsOfDirectory(atPath: experimentsBaseURL.path)

        let handler = PhyphoxDocumentHandler()

        for file in experiments {
            let url = experimentsBaseURL.appendingPathComponent(file)

            let stream = try InputStream(url: url).unwrap()

            try expectParserResult(expectedResult: .success, handler: handler, inputStream: stream)
        }
    }

    func testValueAccuracy() throws {
        let skeleton = try testBundle.path(forResource: "full-skeleton", ofType: "phyphox").unwrap()

        let handler = PhyphoxDocumentHandler()

        let fileExperiment = try expectParserResult(expectedResult: .success, handler: handler, inputStream: InputStream(fileAtPath: skeleton).unwrap())
    }

}
