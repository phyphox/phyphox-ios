//
//  PasteboardPayload.swift
//  EduRoomSDK
//
//  Created by Nicky Weber on 14.06.19.
//

import Foundation
import UIKit

let EDUROOM_PASTEBOARD_TYPE = "de.edumode.eduroom"

struct PasteboardPayload: Codable {
    var timestamp: TimeInterval
}

extension PasteboardPayload {
    static func fromPasteboard(pasteboard: UIPasteboard) -> PasteboardPayload? {
        let value = pasteboard.values(forPasteboardType: EDUROOM_PASTEBOARD_TYPE, inItemSet: nil)?.last
        guard let data = value as? Data,
            let base64String = String(data: data, encoding: .utf8),
            let string = base64String.decodeBase64(),
            let unpackedData = string.data(using: .utf8)
            else { return nil }
        
        return try? JSONDecoder().decode(PasteboardPayload.self, from: unpackedData)
    }
    
    private func removeOldEntriesFromPasteboard(_ pasteboard: UIPasteboard) {
        pasteboard.items = pasteboard.items.filter{ $0.keys.first != EDUROOM_PASTEBOARD_TYPE }
    }
    
    func addToPasteboard(_ pasteboard: UIPasteboard) {
        
        removeOldEntriesFromPasteboard(pasteboard)
        
        do {
            let payloadData = try JSONEncoder().encode(self)
            let jsonString = String(data: payloadData, encoding: .utf8)!
            let base64Str = jsonString.encodeBase64()
            pasteboard.addItems([[EDUROOM_PASTEBOARD_TYPE : base64Str]])
            
        } catch {
            // Nothing to do
        }
    }
}
