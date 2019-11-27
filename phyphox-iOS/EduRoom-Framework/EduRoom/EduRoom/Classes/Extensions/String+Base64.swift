//
//  String+Base64.swift
//  Student App
//
//  Created by Nicky Weber on 16.11.18.
//  Copyright © 2018 nickweaver. All rights reserved.
//

import Foundation

internal extension String {
    
    func decodeBase64() -> String? {
        guard let data = Data(base64Encoded: self) else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    func encodeBase64() -> String {
        return Data(self.utf8).base64EncodedString()
    }
}
