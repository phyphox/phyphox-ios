//
//  ExperimentViewModuleFactory.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import UIKit

final class ExperimentViewModuleFactory {
    
    class func createViews(_ viewDescriptor: ExperimentViewCollectionDescriptor) -> [UIView] {
        var views: [UIView?] = []
        
        for descriptor in viewDescriptor.views {
            if let descriptor = descriptor as? InfoViewDescriptor {
                views.append(ExperimentInfoView(descriptor: descriptor))
            }
            else if let descriptor = descriptor as? ValueViewDescriptor {
                views.append(ExperimentValueView(descriptor: descriptor))
            }
            else if let descriptor = descriptor as? GraphViewDescriptor {
                if descriptor.history == 1 && descriptor.partialUpdate && descriptor.yInputBuffer.size == 0 && (descriptor.xInputBuffer?.size ?? 0) == 0 {
                    views.append(ExperimentUnboundedFunctionGraphView(descriptor: descriptor))
                }
                else {
                    views.append(ExperimentGraphView(descriptor: descriptor))
                }
            }
            else if let descriptor = descriptor as? EditViewDescriptor {
                views.append(ExperimentEditView(descriptor: descriptor))
            }
            else if let descriptor = descriptor as? ButtonViewDescriptor {
                views.append(ExperimentButtonView(descriptor: descriptor))
            }
            else if let descriptor = descriptor as? SeparatorViewDescriptor {
                views.append(ExperimentSeparatorView(descriptor: descriptor))
            }
            else {
                print("Error! Invalid view descriptor: \(descriptor)")
            }
        }

        return views.flatMap { $0 }
    }
}
