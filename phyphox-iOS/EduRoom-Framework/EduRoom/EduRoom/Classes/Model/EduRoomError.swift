//
//  EduRoomError.swift
//  EduRoomSDK
//
//  Created by Nicky Weber on 16.11.18.
//

import Foundation

@objc public enum EduRoomError: Int {
    case
    invalidPingIntervalError = 100,
    invalidURLError = 101,
    invalidSourceError = 102,
    pingAPIError = 200,
    pingAPIMissingJsonBodyError = 201,
    pingProtocolError = 202,
    pingStudentSessionEndedError = 203,
    internalErrorMissingSettings = 998,
    internalError = 999
}
