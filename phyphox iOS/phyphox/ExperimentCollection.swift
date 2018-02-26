//
//  ExperimentCollection.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation

final class ExperimentCollection {
    fileprivate(set) var title: String
    var experiments: [(experiment: Experiment, custom: Bool)]?
    
    init(title: String, experiments: [Experiment]?, customExperiments: Bool) {
        self.title = title
        self.experiments = []
        if (experiments == nil) {
            return
        }
        for experiment in experiments! {
            self.experiments?.append((experiment: experiment, custom: customExperiments))
        }
    }

}
