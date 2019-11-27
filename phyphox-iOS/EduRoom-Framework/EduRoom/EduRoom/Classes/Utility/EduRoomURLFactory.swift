//
//  SDKURL.swift
//  EduRoom
//
//  Created by Nicky Weber on 16.05.19.
//  Copyright © 2019 nickweaver. All rights reserved.
//

import Foundation

private struct Payload: Codable {
    let pingURL: String
    let pingInterval: TimeInterval
    let isTakingExam: Bool
}

struct EduRoomURLFactory
{
    private let scheme = "de.edumode.eduroom"
    private let payload: EduRoomURLPayload
    
    init(_ payload: EduRoomURLPayload)
    {
        self.payload = payload
    }
    
    func url() -> URL?
    {
        do {
            let payload = try payloadAsBase64()
            let urlStr = "\(scheme)://\(payload)"
            
            return URL(string: urlStr)
        } catch {
            return nil
        }
    }
    
    private func payloadAsBase64() throws -> String
    {
        let payloadData = try JSONEncoder().encode(payload)
        let jsonString = String(data: payloadData, encoding: .utf8)!
        return jsonString.encodeBase64()
    }
}
