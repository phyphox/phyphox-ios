//
//  ExperimentViewModuleFactory.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import UIKit

final class ExperimentViewModuleFactory {
    
    class func createViews(_ viewDescriptor: ExperimentViewCollectionDescriptor) -> [UIView] {
        var m: [UIView] = []
        
        for descriptor in viewDescriptor.views {
            if let d = descriptor as? InfoViewDescriptor {
                m.append(ExperimentInfoView(descriptor: d))
            }
            else if let d = descriptor as? ValueViewDescriptor {
                m.append(ExperimentValueView(descriptor: d))
            }
            else if let d = descriptor as? GraphViewDescriptor {
                m.append(ExperimentGraphView(descriptor: d))
            }
            else if let d = descriptor as? EditViewDescriptor {
                m.append(ExperimentEditView(descriptor: d))
            }
            else if let d = descriptor as? ButtonViewDescriptor {
                m.append(ExperimentButtonView(descriptor: d))
            }
            else if let d = descriptor as? SeparatorViewDescriptor {
                m.append(ExperimentSeparatorView(descriptor: d))
            }
            else {
                print("Error! Invalid view descriptor: \(descriptor)")
            }
        }
        
        assert(m.count > 0, "No view descriptors")
        
        return m
    }
}
