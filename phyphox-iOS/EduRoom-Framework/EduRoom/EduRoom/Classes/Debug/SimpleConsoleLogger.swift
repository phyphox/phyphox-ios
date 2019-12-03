//
//  Logger.swift
//  EduRoomSDK
//
//  Created by Nicky Weber on 11.06.19.
//

import Foundation

@objc public enum LogLevel: Int {
    case
    all = 1,
    trace = 2,
    debug = 3,
    info = 4,
    warn = 5,
    error = 6,
    fatal = 7,
    off = 8
}

@objc public class SimpleConsoleLogger: NSObject, Logging {
    let prefix: String
    let logLevel: LogLevel
    let addStimeStamps: Bool
    
    private let dateFormatter = DateFormatter()
    
    @objc public init(minLogLevel: LogLevel ,prefix: String, addTimestamps: Bool) {
        self.logLevel = minLogLevel
        self.prefix = prefix
        self.addStimeStamps = addTimestamps
        
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT") //Set timezone that you want
        dateFormatter.locale = NSLocale.current
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm.SSS" //Specify your format that you want
    }
    
    public func trace(_ message: String) {
        log("[TRACE] \(message)", logLevel: LogLevel.trace)
    }
    
    public func debug(_ message: String) {
        log("[DEBUG] \(message)", logLevel: LogLevel.debug)
    }
    
    public func warning(_ message: String) {
        log("[WARNING] \(message)", logLevel: LogLevel.warn)
    }
    
    public func info(_ message: String) {
        log("[INFO] \(message)", logLevel: LogLevel.info)
    }
    
    public func warn(_ message: String) {
        log("[WARN] \(message)", logLevel: LogLevel.warn)
    }
    
    public func error(_ message: String) {
        log("[ERROR] \(message)", logLevel: LogLevel.error)
    }
    
    public func fatal(_ message: String) {
        log("[FATAL] \(message)", logLevel: LogLevel.fatal)
    }

    private func log(_ message: String, logLevel currentLogLevel: LogLevel) {
        guard self.logLevel.rawValue <= currentLogLevel.rawValue else { return }
        
        let timeStamp = self.addStimeStamps
            ? "[" + dateFormatter.string(from: Date()) + "] "
            : ""
        
        print("\(self.prefix)\(timeStamp)\(message)")
    }
}
