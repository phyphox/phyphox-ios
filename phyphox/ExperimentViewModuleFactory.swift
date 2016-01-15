//
//  ExperimentViewModuleFactory.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import UIKit

final class ExperimentViewModuleFactory {
    class func createViews(viewDescriptor: ExperimentViewCollectionDescriptor) -> [UIView] {
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
            else {
                print("Error! Invalid view descriptor: \(descriptor)")
            }
        }
//        
//        if viewDescriptor.infoViews != nil {
//            for descriptor in viewDescriptor.infoViews! {
//                m.append(ExperimentInfoView(descriptor: descriptor))
//            }
//        }
//        
//        if viewDescriptor.graphViews != nil {
//            for descriptor in viewDescriptor.graphViews! {
//                m.append(ExperimentGraphView(descriptor: descriptor))
//            }
//        }
//        
//        if viewDescriptor.editViews != nil {
//            for descriptor in viewDescriptor.editViews! {
//                m.append(ExperimentEditView(descriptor: descriptor))
//            }
//        }
//        
//        if viewDescriptor.valueViews != nil {
//            for descriptor in viewDescriptor.valueViews! {
//                m.append(ExperimentValueView(descriptor: descriptor))
//            }
//        }
        
        assert(m.count > 0, "No view descriptors")
        
        return m
    }
}
