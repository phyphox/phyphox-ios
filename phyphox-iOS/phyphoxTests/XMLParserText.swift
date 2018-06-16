//
//  XMLParserText.swift
//  phyphoxTests
//
//  Created by Jonas Gessner on 15.06.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation
import XCTest
@testable import phyphox

final class XMLParserTest: XCTestCase {
    private enum XMLParseResult<Result: Equatable> {
        case failure
        case result(Result)
    }

    private func expectParserResult<Handler: ResultElementHandler>(expectedResult: XMLParseResult<Handler.Result>, handler: Handler, input: String) throws {
        guard let data = input.data(using: .utf8) else {
            XCTFail()
            return
        }

        switch expectedResult {
        case .failure:
            do {
               _ = try XMLElementParser(rootHandler: handler).parse(stream: InputStream(data:data))
                XCTFail()
            }
            catch {}
        case .result(let expectedResultValue):
            let result = try XMLElementParser(rootHandler: handler).parse(stream: InputStream(data:data))
            XCTAssertEqual(expectedResultValue, result)
        }
    }
}
