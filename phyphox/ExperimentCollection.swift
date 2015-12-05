//
//  ExperimentCollection.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

final class ExperimentCollection: NSObject {
    private(set) var title: String
    private(set) var experiments: [Experiment]
    
    init(title: String, experiments: [Experiment]) {
        self.title = title
        self.experiments = experiments
        
        super.init()
    }

}
