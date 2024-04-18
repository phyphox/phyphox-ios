//
//  CameraService+Enums.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 18.04.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
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
