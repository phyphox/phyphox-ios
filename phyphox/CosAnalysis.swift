//
//  CosAnalysis.swift
//  phyphox
//
//  Created by Jonas Gessner on 06.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation
import Surge

final class CosAnalysis: UpdateValueAnalysis {
    
    override func update() {
        updateAllWithMethod(Surge.cos)
    }
}

