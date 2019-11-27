//
//  EduRoomError+NSError.swift
//  EduRoomSDK
//
//  Created by Nicky Weber on 16.11.18.
//

import Foundation

internal extension EduRoomError {
       
    func asNSError(_ description: String, additionalInfo:[String:String] = [:]) -> NSError
    {
        var userInfo = [NSDebugDescriptionErrorKey:description]
        additionalInfo.forEach { (k,v) in userInfo[k] = v }
        
        return NSError(domain: "EduRoomErrorDomain",
                       code: self.rawValue,
                       userInfo: userInfo)
    }
}

