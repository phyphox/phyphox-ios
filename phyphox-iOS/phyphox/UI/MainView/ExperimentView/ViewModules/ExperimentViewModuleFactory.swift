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
                /*
                This should become an optimized version of the graphs, which deal more efficiently with data that is only appended by grouping data in max/min ranges if the number of data points per pixel exceeds 1. However, this is not yet ready and we deactivate it for now as all the new graph types would otherwise have to be implemented twice.
                 
                if descriptor.history == 1 && descriptor.partialUpdate && descriptor.yInputBuffer.size == 0 && (descriptor.xInputBuffer?.size ?? 0) == 0 {
                    views.append(ExperimentUnboundedFunctionGraphView(descriptor: descriptor))
                }
                else {
                    views.append(ExperimentGraphView(descriptor: descriptor))
                }
                */
                views.append(ExperimentGraphView(descriptor: descriptor))
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
            else if let descriptor = descriptor as? DepthGUIViewDescriptor {
                if #available(iOS 14.0, *) {
                    views.append(ExperimentDepthGUIView(descriptor: descriptor))
                } else {
                    print("DepthGUI not supported below iOS 14")
                    //Should not happen as the depth input is marked as unavailable below iOS 14
                }
            }
            else {
                print("Error! Invalid view descriptor: \(descriptor)")
            }
        }

        return views.compactMap { $0 }
    }
}
