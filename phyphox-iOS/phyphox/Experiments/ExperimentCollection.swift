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
        case rawSensors, savedStates, other, phyphoxOrg
        init (title: String) {
            switch title {
                case localize("categoryRawSensor"):
                    self = .rawSensors
                case localize("save_state_category"):
                    self = .savedStates
                case "phyphox.org":
                    self = .phyphoxOrg
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
