//
//  UIExperimentTabControl.swift
//  phyphox
//
//  Created by Sebastian Staacks on 24.07.20.
//  Copyright © 2020 RWTH Aachen. All rights reserved.
//

import Foundation

class UIExperimentTabControl: UISegmentedControl {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer.isKind(of: UIPanGestureRecognizer.self) {
            return true
        } else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
    }
}
