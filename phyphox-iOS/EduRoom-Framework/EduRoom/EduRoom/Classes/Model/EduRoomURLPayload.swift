//
//  EduRoomURLPayload.swift
//  EduRoomSDK
//
//  Created by Nicky Weber on 05.06.19.
//

import Foundation

extension NSError: Encodable {
    enum CodingKeys: String, CodingKey {
        case code
        case debugDescription
        case domain
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .code)
        try container.encode(domain, forKey: .domain)
        if let str = userInfo[NSDebugDescriptionErrorKey] as? String {
            try container.encode(str, forKey: .debugDescription)
        }
    }
}

struct EduRoomURLPayload: Encodable {
    let error: NSError?
    
    enum CodingKeys: String, CodingKey {
        case error
    }
}
