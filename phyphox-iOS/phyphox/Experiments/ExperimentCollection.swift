//
//  ExperimentCollection.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation

final class ExperimentCollection {
    private(set) var title: String
    
    enum ContentType: Int {
        case rawSensors, savedStates, other
        init (title: String) {
            switch title {
                case NSLocalizedString("categoryRawSensor", comment: ""):
                    self = .rawSensors
                case NSLocalizedString("save_state_category", comment: ""):
                    self = .savedStates
                default:
                    self = .other
            }
        }
    }
    
    private(set) var type: ContentType
    
    var experiments: [(experiment: Experiment, custom: Bool)]
    
    init(title: String, experiments: [(Experiment, Bool)]) {
        self.title = title
        self.type = ContentType.init(title: title)
        self.experiments = experiments
    }
}
