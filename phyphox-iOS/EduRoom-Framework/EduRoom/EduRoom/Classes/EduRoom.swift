//
//  EduRoom.swift
//  EduRoom
//
//  Created by Nicky Weber on 14.05.18.
//

import Foundation
import UIKit

@available(iOS 9.0, *)
@objc final public class EduRoom: NSObject, PingManagerDelegate {

    @objc public class var shared: EduRoom {
        struct Singleton {
            static let instance = EduRoom()
        }
        return Singleton.instance
    }
    @objc public var logger: Logging?
    @objc public var pasteboard = UIPasteboard.general
    @objc public var application = UIApplication.shared
    @objc public var notificationCenter = NotificationCenter.default
    
    private var lastError: NSError?
    
    @objc public var isActive: Bool {
        return pingManager.isActive
    }
    
    @objc public var isTakingExam: Bool {
        return settings?.isTakingExam ?? false
    }

    @objc public var pingInterval: TimeInterval {
        return settings?.pingInterval ?? -1.0
    }

    @objc public var dismissInterval: TimeInterval {
        return settings?.dismissInterval ?? -1.0
    }
    
    private let pingManager: PingManager
    
    private var timer: Timer?
    
    private var settings: Settings?

    private var pinger: Pinger?
    private var pingedAfterStartUp = false
    
    @objc override public init()
    {
        pingManager = PingManager()

        super.init()
        
        pingManager.delegate = self

        addApplicationLifeCycleObservers()
    }
    
    deinit {
        notificationCenter.removeObserver(self)
        stopSession()
    }
    
    private func addApplicationLifeCycleObservers() {
        notificationCenter.addObserver(forName: UIApplication.willResignActiveNotification,
                                       object: nil,
                                       queue: nil)
        { notification in
            self.addTimeStampToPasteboard()
            self.pingManager.sendClosingPingAndPauseSession()
        }

        notificationCenter.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                       object: nil,
                                       queue: nil)
        { notification in
            if let lastError = self.lastError {
                self.stopSessionAndOpenEduRoom(lastError)
                return
            }
            
            self.pingManager.resumeSession(self.lastActiveTimeOnPasteboard())
        }
    }
    
    private func lastActiveTimeOnPasteboard() -> TimeInterval? {
        guard let pasteboardPayload = PasteboardPayload.fromPasteboard(pasteboard: pasteboard)
            else { return nil }
        
        return pasteboardPayload.timestamp
    }
    
    private func addTimeStampToPasteboard() {
        guard isActive else { return }
        
        let payload = PasteboardPayload(timestamp: Date.unixTimeStamp)
        payload.addToPasteboard(pasteboard)
    }
    
    public func openEduRoom(_ error: NSError?) {
        DispatchQueue.main.async {
            self.application.isIdleTimerDisabled = false
            guard let url = self.openEduRoomURL(error) else {
                return
            }
            
            if #available(iOS 10.0, *) {
                self.application.open(url, options: [:], completionHandler: nil)
            } else {
                // Fallback on earlier versions
                self.application.openURL(url)
            }
        }
    }
    
    private func openEduRoomURL(_ error: NSError?) -> URL? {
        let payload = EduRoomURLPayload(error: error)
        let factory = EduRoomURLFactory(payload)
        return factory.url()
    }
    
    @objc public func startSession(url: URL) {
        do {
            self.settings = try self.parseSettings(url)
        } catch let error as NSError {
            self.openEduRoom(error)
        }
        
        lastError = nil
        
        guard let settings = self.settings else {
            openEduRoom(EduRoomError.internalErrorMissingSettings.asNSError("Start Session missing settings!"))
            return
        }
        
        logger?.info("Ping interval \(settings.pingInterval) seconds")
        logger?.info("Dismiss interval \(settings.dismissInterval) seconds")

        application.isIdleTimerDisabled = true
        pingManager.logger = logger
        pingManager.startSession(settings)
    }
    
    @objc public func stopSession()
    {
        application.isIdleTimerDisabled = false
        
        pingManager.stopSession()
    }
       
    private func stopSessionAndOpenEduRoom(_ error: NSError)
    {
        self.logger?.error("ERROR, stopping session and going back to EduRoom. Details: \(error)")
        self.stopSession()
        
        openEduRoom(error)
    }
    
    private func parseSettings(_ url: URL) throws -> Settings
    {
        let parser = SettingsURLParser(url)
        return try parser.parse()
    }

    //MARK: PingManagerDelegate
    func failed(error: NSError) {
        lastError = error
        stopSessionAndOpenEduRoom(error)
    }
}
