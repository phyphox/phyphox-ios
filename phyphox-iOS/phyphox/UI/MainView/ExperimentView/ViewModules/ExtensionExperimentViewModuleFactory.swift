//
//  ExtensionExperimentViewModuleFactory.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 18.03.24.
//  Copyright © 2024 RWTH Aachen. All rights reserved.
//

import Foundation

import SwiftUI

extension ExperimentViewModuleFactory {
    
    @available(iOS 13.0, *)
    class func createSwiftUiViews(_ viewDescriptor: ExperimentViewCollectionDescriptor) -> [UIView] {
        
        var views: [UIView] = []
        
        /**
        for descriptor in viewDescriptor.views {
            if let descriptor = descriptor as? CameraViewDescriptor {
                if #available(iOS 14.0, *) {
                    // TODO need to pass descriptor in view argument.
                    let hostingController = UIHostingController(rootView: PhyphoxCameraView())
                    views.append(hostingController.view)
                    //views.append(UIHostingController(rootView: PhyphoxCameraView()).view)
                } else {
                    // Fallback on earlier versions
                }

            } else {
                print("Error! Invalid view descriptor: \(descriptor)")
            }
        }
         */
        
        return views.compactMap { $0  }
        
    }
    
}
