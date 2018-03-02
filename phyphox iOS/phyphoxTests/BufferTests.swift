//
//  BufferTests.swift
//  phyphoxTests
//
//  Created by Jonas Gessner on 02.03.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import UIKit
import XCTest
@testable import phyphox

final class BufferTests: XCTestCase {
    var hasReceivedMemoryWarning = false

    func testFlushingWhenMemoryFull() throws {
        let observer = NotificationCenter.default.addObserver(forName: .UIApplicationDidReceiveMemoryWarning, object: nil, queue: nil) { _ in
            self.hasReceivedMemoryWarning = true
        }

        let buffer = DataBuffer(name: "test", size: 0)

        buffer.append(1.0)

        while buffer.count < 284354550 {
            buffer.appendFromArray(buffer.toArray())
        }

        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())

        sleep(5)

        try buffer.flush(to: tmp)

        NotificationCenter.default.removeObserver(observer)
    }
}
