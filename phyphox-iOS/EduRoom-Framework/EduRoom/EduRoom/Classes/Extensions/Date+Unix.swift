//
//  Date+Unix.swift
//  EduRoomSDK
//
//  Created by Nicky Weber on 20.06.19.
//

import Foundation

extension Date {
    static var unixTimeStamp: TimeInterval {
        return Date().timeIntervalSince1970
    }
}
