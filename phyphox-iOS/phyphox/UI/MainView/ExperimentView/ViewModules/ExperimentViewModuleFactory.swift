//
//  ExperimentViewModuleFactory.swift
//  phyphox
//
//  Created by Jonas Gessner on 14.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import UIKit

final class ExperimentViewModuleFactory {
    
    class func createViews(_ viewDescriptor: ExperimentViewCollectionDescriptor, resourceFolder: URL?) -> [ExperimentModule] {
        let views = viewDescriptor.views.map { createView(for: $0, resourceFolder: resourceFolder, inStack: false) }

        return views.compactMap { ExperimentModule(view: $0, isVisible: true)}
    }

    ///One module per descriptor; the view groups of file format 1.21 get their children the same way, recursively.
    ///Inside a stack a graph is static: no tap-to-maximize, no zoom, no pick (the stack takes no touches at all).
    class func createView(for descriptor: ViewDescriptor, resourceFolder: URL?, inStack: Bool) -> UIView? {
        if let descriptor = descriptor as? InfoViewDescriptor {
            return ExperimentInfoView(descriptor: descriptor, resourceFolder: resourceFolder)
        }
        else if let descriptor = descriptor as? ValueViewDescriptor {
            return ExperimentValueView(descriptor: descriptor, resourceFolder: resourceFolder)
        }
        else if let descriptor = descriptor as? GraphViewDescriptor {
            /*
            This should become an optimized version of the graphs, which deal more efficiently with data that is only appended by grouping data in max/min ranges if the number of data points per pixel exceeds 1. However, this is not yet ready and we deactivate it for now as all the new graph types would otherwise have to be implemented twice.
             
            if descriptor.history == 1 && descriptor.partialUpdate && descriptor.yInputBuffer.size == 0 && (descriptor.xInputBuffer?.size ?? 0) == 0 {
                views.append(ExperimentUnboundedFunctionGraphView(descriptor: descriptor, resourceFolder: resourceFolder))
            }
            else {
                views.append(ExperimentGraphView(descriptor: descriptor, resourceFolder: resourceFolder))
            }
            */
            let graph = ExperimentGraphView(descriptor: descriptor, resourceFolder: resourceFolder)
            graph?.isStatic = inStack
            return graph
        }
        else if let descriptor = descriptor as? EditViewDescriptor {
            return ExperimentEditView(descriptor: descriptor, resourceFolder: resourceFolder)
        }
        else if let descriptor = descriptor as? ButtonViewDescriptor {
            return ExperimentButtonView(descriptor: descriptor, resourceFolder: resourceFolder)
        }
        else if let descriptor = descriptor as? SeparatorViewDescriptor {
            return ExperimentSeparatorView(descriptor: descriptor, resourceFolder: resourceFolder)
        }
        else if let descriptor = descriptor as? DepthGUIViewDescriptor {
            return ExperimentDepthGUIView(descriptor: descriptor, resourceFolder: resourceFolder)
        } else  if let descriptor = descriptor as? CameraViewDescriptor {
            return ExperimentCameraUIView(descriptor: descriptor)
        }
        else if let descriptor = descriptor as? ImageViewDescriptor {
            return ExperimentImageView(descriptor: descriptor, resourceFolder: resourceFolder)
        }
        else if let descriptor = descriptor as? SwitchViewDescriptor {
            return ExperimentSwitchView(descriptor: descriptor, resourceFolder: resourceFolder)
        }
        else if let descriptor = descriptor as? DropdownViewDescriptor {
            return ExperimentDropdownView(descriptor: descriptor, resourceFolder: resourceFolder)
        } else if let descriptor = descriptor as? SliderViewDescriptor {
            return ExperimentSliderView(descriptor: descriptor, resourceFolder: resourceFolder)
        }
        else if let descriptor = descriptor as? VerticalViewDescriptor {
            return ExperimentGroupView(kind: .vertical, children: children(of: descriptor, resourceFolder: resourceFolder, inStack: inStack), visibilityBuffer: descriptor.visibilityBuffer)
        }
        else if let descriptor = descriptor as? HorizontalViewDescriptor {
            return ExperimentGroupView(kind: .horizontal(weights: descriptor.weights), children: children(of: descriptor, resourceFolder: resourceFolder, inStack: inStack), visibilityBuffer: descriptor.visibilityBuffer)
        }
        else if let descriptor = descriptor as? GridViewDescriptor {
            return ExperimentGroupView(kind: .grid(maxWidth: descriptor.maxWidth, screenUnit: descriptor.maxWidthUnit == .screen, fillLastRow: descriptor.fillLastRow), children: children(of: descriptor, resourceFolder: resourceFolder, inStack: inStack), visibilityBuffer: descriptor.visibilityBuffer)
        }
        else if let descriptor = descriptor as? StackViewDescriptor {
            return ExperimentGroupView(kind: .stack, children: children(of: descriptor, resourceFolder: resourceFolder, inStack: true), visibilityBuffer: descriptor.visibilityBuffer)
        }
        else if let descriptor = descriptor as? TransformViewDescriptor {
            guard let child = createView(for: descriptor.child, resourceFolder: resourceFolder, inStack: true) else { return nil }
            return ExperimentTransformView(descriptor: descriptor, child: child)
        }
        else {
            print("Error! Invalid view descriptor: \(descriptor)")
            return nil
        }
    }

    ///A child whose module cannot be built is left out, as at the top level
    private class func children(of group: GroupViewDescriptor, resourceFolder: URL?, inStack: Bool) -> [UIView] {
        return group.children.compactMap { createView(for: $0, resourceFolder: resourceFolder, inStack: inStack) }
    }
}
