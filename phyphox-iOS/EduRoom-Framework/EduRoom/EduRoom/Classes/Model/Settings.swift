//
//  Settings.swift
//  EduRoomSDK
//
//  Created by Nicky Weber on 16.11.18.
//

import Foundation

internal struct Settings: Decodable {
    let pingURL: URL
    let dismissInterval: TimeInterval
    let pingInterval: TimeInterval
    let isTakingExam: Bool

    private enum CodingKeys : String, CodingKey
    {
        case isTakingExam
        case pingURL
        case pingInterval
        case dismissInterval
    }
    
    init(from decoder: Decoder) throws {
        do {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            
            isTakingExam = try values.decode(Bool.self, forKey: .isTakingExam)
            pingInterval = try values.decode(TimeInterval.self, forKey: .pingInterval)
            dismissInterval = try values.decode(TimeInterval.self, forKey: .dismissInterval)
            
            guard let pingUrl = try URL(string: values.decode(String.self, forKey: .pingURL)),
                pingUrl.scheme == "https"
            else {
                throw EduRoomError.invalidURLError.asNSError("Ping or startup ping URL is not of https scheme.")
            }
            self.pingURL = pingUrl
        }
        catch {
            throw EduRoomError.invalidURLError.asNSError("JSON payload could not be decoded: \(error)")
        }
    }
}
