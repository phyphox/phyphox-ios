//
//  ExperimentDownloadErrorTests.swift
//  phyphoxTests
//
//  Created by Sebastian Staacks on 18.11.26.
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
@testable import phyphox

//A failed experiment download names its cause (offline, unreachable host, HTTP status) instead of NSCocoaErrorDomain 256,
//and phyphox:// skips the http fallback where http cannot help. Strings and rules as on Android (DownloadErrorMessageTest)
final class ExperimentDownloadErrorTests: XCTestCase {

    //Answers every request with what `respond` returns: a status and body, or an error
    private final class StubProtocol: URLProtocol {
        static var respond: ((URLRequest) -> Result<(Int, Data), URLError>)?

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            switch StubProtocol.respond!(request) {
            case .success(let (status, body)):
                let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: body)
                client?.urlProtocolDidFinishLoading(self)
            case .failure(let error):
                client?.urlProtocol(self, didFailWithError: error)
            }
        }

        override func stopLoading() {}
    }

    private var session: URLSession!
    private let url = URL(string: "https://example.org/s/abc/download")!

    override func setUp() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        session = URLSession(configuration: configuration)
    }

    override func tearDown() {
        StubProtocol.respond = nil
        session.invalidateAndCancel()
    }

    private func download(_ response: Result<(Int, Data), URLError>) -> Result<Data, Error> {
        StubProtocol.respond = { _ in response }
        return ExperimentsCollectionViewController.downloadExperimentData(from: url, session: session)
    }

    func testSuccessReturnsBody() throws {
        let body = Data("<phyphox version=\"1.21\"></phyphox>".utf8)
        XCTAssertEqual(try download(.success((200, body))).get(), body)
    }

    func testHttpErrorStatusFailsWithStatus() {
        guard case .failure(let error) = download(.success((404, Data("<html>Not found</html>".utf8)))) else {
            return XCTFail("A 404 must not count as a downloaded experiment")
        }
        guard case ExperimentsCollectionViewController.ExperimentDownloadError.httpStatus(let status) = error else {
            return XCTFail("Expected an HTTP status error, got \(error)")
        }
        XCTAssertEqual(status, 404)
        let message = ExperimentsCollectionViewController.downloadErrorMessage(for: error, host: "example.org")
        XCTAssertEqual(message, localize("downloadErrorGeneral") + "\n\nHTTP 404")
    }

    func testURLErrorReachesTheMessage() {
        guard case .failure(let error) = download(.failure(URLError(.notConnectedToInternet))) else {
            return XCTFail("An offline download must fail")
        }
        XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
        XCTAssertEqual(ExperimentsCollectionViewController.downloadErrorMessage(for: error, host: "example.org"), localize("downloadErrorOffline"))
    }

    func testMessages() {
        let message = { (code: URLError.Code) in
            ExperimentsCollectionViewController.downloadErrorMessage(for: URLError(code), host: "example.org")
        }
        for code in [URLError.Code.notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff] {
            XCTAssertEqual(message(code), localize("downloadErrorOffline"), "\(code)")
        }
        for code in [URLError.Code.cannotFindHost, .dnsLookupFailed, .timedOut, .cannotConnectToHost] {
            XCTAssertEqual(message(code), localize("downloadErrorUnreachable") + " example.org", "\(code)")
        }
        let other = message(.secureConnectionFailed)
        XCTAssertEqual(other, localize("downloadErrorGeneral") + "\n\n" + URLError(.secureConnectionFailed).localizedDescription, "The technical detail goes on a separate line")

        //Errors that did not come from a download keep the old message
        XCTAssertNil(ExperimentsCollectionViewController.downloadErrorMessage(for: SerializationError.invalidFilePath, host: "example.org"))
    }

    func testHttpFallbackSkippedOnlyWhereHttpCannotHelp() {
        for code in [URLError.Code.notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff, .cannotFindHost, .dnsLookupFailed] {
            XCTAssertFalse(ExperimentsCollectionViewController.httpFallbackCanHelp(after: URLError(code)), "\(code)")
        }
        for code in [URLError.Code.timedOut, .cannotConnectToHost, .secureConnectionFailed, .serverCertificateUntrusted] {
            XCTAssertTrue(ExperimentsCollectionViewController.httpFallbackCanHelp(after: URLError(code)), "\(code)")
        }
        //The server answered over https, http would not get a better answer
        XCTAssertFalse(ExperimentsCollectionViewController.httpFallbackCanHelp(after: ExperimentsCollectionViewController.ExperimentDownloadError.httpStatus(404)))
    }
}
