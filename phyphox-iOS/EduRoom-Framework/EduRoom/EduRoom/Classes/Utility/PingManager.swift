//
//  PingManager.swift
//  EduRoomSDK
//
//  Created by Nicky Weber on 11.06.19.
//

import Foundation
import UIKit

protocol PingManagerDelegate: class {
    func failed(error: NSError)
}

@available(iOS 9.0, *)
class PingManager {

    public var application = UIApplication.shared

    public weak var delegate: PingManagerDelegate?
    public var logger: Logging?
    
    public private(set) var isActive: Bool = false
    public private(set) var isPaused: Bool = false
    
    private var taskId: UIBackgroundTaskIdentifier?
    private var pinger: Pinger?
    private var settings: Settings?
    private var timer: Timer?

    public var lastActiveTime: TimeInterval = 0.0
    public var lastActiveTimeOther: TimeInterval = 0.0
    
    public func startSession(_ settings: Settings) {
        self.settings = settings
        pinger = Pinger(settings: settings)
                
        isActive = true
        isPaused = false
        
        pingAndStartTimer()
        
        logger?.info("Session Started.")
    }
    
    public func stopSession() {
        isActive = false
        isPaused = false
        
        timer?.invalidate()
        timer = nil
        
        pinger?.stopAllRequests()
        pinger = nil
        
        logger?.info("Session Stopped.")
        logger?.debug("Cancelled all ping requests.")
    }
    
    public func pauseSession() {
        logger?.info("Pausing Session")
        isPaused = true
        timer?.invalidate()
        timer = nil
        lastActiveTime = Date.unixTimeStamp
    }
    
    public func resumeSession(_ lastActiveTime: TimeInterval?) {
        if let lastActiveTime = lastActiveTime {
            lastActiveTimeOther = lastActiveTime
        }
       
        guard isActive
            && isPaused
            && expireSessionIfAbsenceTooLong() else { return }
        
        isPaused = false
        logger?.info("Resuming Session")
        pingAndStartTimer()
    }
    
    private func expireSessionIfAbsenceTooLong() -> Bool {
        guard let settings = self.settings else {
            stopSessionAndTellDelegate(EduRoomError.internalErrorMissingSettings.asNSError("Missing Settings"))
            return false
        }
        
        let absenceActivity = Date.unixTimeStamp - self.lastActiveTime
        let absenceActivityOther = Date.unixTimeStamp - self.lastActiveTimeOther
        logger?.debug("Absence since self activity: \(absenceActivity)")
        logger?.debug("Absence since other(pasteboard): \(absenceActivityOther)")
        let absence = min(absenceActivity, absenceActivityOther)
        if absence > settings.dismissInterval {
            logger?.info("Session expired due to absence: %\(absence).2f seconds.")
            stopSessionAndTellDelegate(EduRoomError.pingStudentSessionEndedError.asNSError("Session expired"))
            return false
        }
        return true
    }
    
    public func sendClosingPingAndPauseSession() {
        logger?.debug("Pinging last time...")
        taskId = application.beginBackgroundTask {
            self.logger?.debug("Ping last time - Background Task expiring!")
            self.pauseSession()
        }
        
        pinger?.pingSessionClosing() { [weak self] in
            self?.logger?.debug("Ping last time OK!")
            self?.pauseSession()
            
            if let taskId = self?.taskId {
                self?.application.endBackgroundTask(taskId)
            }
        }
    }
    
    private func pingAndStartTimer() {
        resetTimer()
        pingTimerAction()
    }
    
    private func isConnectivityError(_ error: NSError) -> Bool {
        return error.code >= NSURLErrorDNSLookupFailed
            && error.code <= NSURLErrorTimedOut
    }
    
    @objc private func pingTimerAction()
    {
        self.logger?.debug("Ping...")
        pinger?.ping { [weak self] error in
            self?.handlePingCompletion(error)
        }
    }
    
    private func handlePingCompletion(_ error: NSError?) {
        guard let error = error else {
            logger?.debug("Ping...OK!")
            return
        }

        if isConnectivityError(error) {
            logger?.debug("Ping...Failed but that's OK, connectivity error: \(error.code) \(error.localizedDescription)")
            return
        }
        logger?.error("Ping Failed: \(error)")
        stopSessionAndTellDelegate(error)
    }
    
    private func stopSessionAndTellDelegate(_ error: NSError) {
        stopSession()
        delegate?.failed(error: error)
    }
    
    private func resetTimer() {
        guard let pingInterval = settings?.pingInterval else {
            stopSessionAndTellDelegate(EduRoomError.internalErrorMissingSettings.asNSError("Missing Settings"))
            return
        }
        
        timer?.invalidate()
        timer = Timer(timeInterval: pingInterval,
                      target: self,
                      selector: #selector(pingTimerAction),
                      userInfo: nil,
                      repeats: true)
        
        timer?.tolerance = 1.0
        
        if let timer = self.timer
        {
            self.logger?.debug("Ping interval: \(pingInterval) seconds")
            RunLoop.main.add(timer, forMode: RunLoop.Mode.common)
        }
    }
}
