//
//  CameraService+Enums.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 13.11.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

import Foundation

@available(iOS 14.0, *)
extension CameraService{
    
    enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
}
