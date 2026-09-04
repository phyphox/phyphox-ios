//
//  HttpResultRaceTests.swift
//  phyphoxTests
//
//  Created by Sebastian Staacks on 04.09.26.
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
@testable import phyphox

//A callback does not receive the HTTP response: it reads it back through the service's
//getResults(), from a field every request of that service shares. Android found two responses
//finishing close together storing A, then B, and both callbacks reading B - one poll parked
//twice, one lost, seen as a duplicate poll counter in the t1 network fixtures (2026-09-04). The
//shared URLSession delivers its completion handlers on a serial queue, so that particular
//interleaving cannot happen here - but the analysis thread's next execute() clears the same
//field, and it can land between the store and the callback's read: the callback then parks an
//empty response, and the buffers it feeds are emptied on the next cycle.
//
//This pins the order: the first callback is held while the next request is issued, and it must
//still read its own body. The hold is the window the race needs; the service's lock is what
//keeps the next request out of it.
final class HttpResultRaceTests: XCTestCase {

    //A loopback stub on a plain socket: URLSession needs nothing more than a status line and a
    //Content-Length. The body is the request's own v, so a callback can tell whose response it read.
    private final class StubServer {
        private var listenFd: Int32 = -1
        let port: UInt16

        init() {
            let fd = socket(AF_INET, SOCK_STREAM, 0)
            var yes: Int32 = 1
            setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
            var addr = sockaddr_in()
            addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = 0
            addr.sin_addr.s_addr = inet_addr("127.0.0.1")
            let bindResult = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
            }
            precondition(bindResult == 0, "bind failed: \(errno)")
            precondition(listen(fd, 8) == 0, "listen failed: \(errno)")
            var local = sockaddr_in()
            var len = socklen_t(MemoryLayout<sockaddr_in>.size)
            withUnsafeMutablePointer(to: &local) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { _ = getsockname(fd, $0, &len) }
            }
            listenFd = fd
            port = UInt16(bigEndian: local.sin_port)
            Thread.detachNewThread { [weak self] in
                while true {
                    let client = accept(fd, nil, nil)
                    if client < 0 { return }    //closed by stop()
                    Thread.detachNewThread { self?.answer(client) }
                }
            }
        }

        private func answer(_ fd: Int32) {
            defer { close(fd) }
            var request = ""
            var buffer = [UInt8](repeating: 0, count: 4096)
            while !request.contains("\r\n\r\n") {
                let n = read(fd, &buffer, buffer.count)
                if n <= 0 { return }
                request += String(decoding: buffer[0..<n], as: UTF8.self)
            }
            let requestLine = request.components(separatedBy: "\r\n").first ?? ""
            let v = requestLine.components(separatedBy: "v=").last?.components(separatedBy: " ").first ?? "?"
            let body = Array(v.utf8)
            let head = Array("HTTP/1.1 200 OK\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8)
            let response = head + body
            response.withUnsafeBufferPointer { _ = write(fd, $0.baseAddress, $0.count) }
        }

        func stop() {
            close(listenFd)
            listenFd = -1
        }
    }

    private final class Callback: NetworkServiceRequestCallback {
        let body: (NetworkServiceResult) -> Void
        init(_ body: @escaping (NetworkServiceResult) -> Void) { self.body = body }
        func requestFinished(result: NetworkServiceResult) { body(result) }
    }

    func testEveryCallbackReadsItsOwnResponse() {
        let server = StubServer()
        defer { server.stop() }
        let base = "http://127.0.0.1:\(server.port)/?v="

        let service = HttpGetService()
        let firstInCallback = DispatchSemaphore(value: 0)
        let firstMayRead = DispatchSemaphore(value: 0)
        let firstDone = DispatchSemaphore(value: 0)
        let secondDone = DispatchSemaphore(value: 0)
        var first: String?
        var second: String?

        let cb1 = Callback { result in
            firstInCallback.signal()
            _ = firstMayRead.wait(timeout: .now() + 10)
            first = (service.getResults() ?? []).first.map { String(decoding: $0, as: UTF8.self) }
            firstDone.signal()
        }
        let cb2 = Callback { result in
            second = (service.getResults() ?? []).first.map { String(decoding: $0, as: UTF8.self) }
            secondDone.signal()
        }

        service.connect(address: base + "1")
        service.execute(send: [:], requestCallbacks: [cb1])

        XCTAssertEqual(firstInCallback.wait(timeout: .now() + 10), .success, "first response never arrived")
        //The first callback is now inside requestFinished. Issue the next request the way the
        //analysis thread does between cycles, and give it time to reach the point where it
        //would clear the stored response.
        DispatchQueue.global().async {
            service.connect(address: base + "2")
            service.execute(send: [:], requestCallbacks: [cb2])
        }
        Thread.sleep(forTimeInterval: 0.5)
        firstMayRead.signal()
        XCTAssertEqual(firstDone.wait(timeout: .now() + 10), .success, "first callback never finished")
        XCTAssertEqual(secondDone.wait(timeout: .now() + 10), .success, "second callback never ran")

        XCTAssertEqual(first, "1", "the first callback lost its response to the next request")
        XCTAssertEqual(second, "2")
    }
}
