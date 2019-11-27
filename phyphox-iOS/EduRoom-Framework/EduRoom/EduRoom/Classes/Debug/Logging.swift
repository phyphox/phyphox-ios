//
//  Logging.swift
//  EduRoomSDK
//
//  Created by Nicky Weber on 12.06.19.
//

import Foundation

@objc public protocol Logging {
    func trace(_ message: String)
    func debug(_ message: String)
    func warning(_ message: String)
    func info(_ message: String)
    func warn(_ message: String)
    func error(_ message: String)
    func fatal(_ message: String)
}
