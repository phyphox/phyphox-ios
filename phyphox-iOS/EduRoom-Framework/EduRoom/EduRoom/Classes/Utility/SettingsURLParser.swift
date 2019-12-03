//
//  SettingsParser.swift
//  EduRoomSDK
//
//  Created by Nicky Weber on 05.06.19.
//

import Foundation

class SettingsURLParser {
    
    private let url: URL
    
    init(_ url: URL) {
        self.url = url
    }
    
    func parse() throws -> Settings {
        let urlStr = url.absoluteString
        
        guard let scheme = url.scheme,
            let range = urlStr.range(of: "\(scheme)://") else
        {
            let description = "URL's scheme not given, expected custom scheme of this app."
            throw EduRoomError.invalidURLError.asNSError(description)
        }
        
        let payloadBase64 = urlStr.replacingCharacters(in: range, with: "")
        guard let payload = payloadBase64.decodeBase64()?.data(using: .utf8) else {
            let description = "Payload not base64 encoded."
            let addInfo = [
                "payload" : payloadBase64
            ]
            
            throw EduRoomError.invalidURLError.asNSError(description, additionalInfo: addInfo)
        }
        
        return try JSONDecoder().decode(Settings.self, from: payload)
    }
}
