//
//  ExperimentExportSet.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

final class ExperimentExportSet {
    let name: String
    let data: [(name: String, buffer: DataBuffer)]
    
    init(name: String, data: [(name: String, buffer: DataBuffer)]) {
        self.name = name
        self.data = data
    }
}
