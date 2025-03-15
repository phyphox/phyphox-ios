//
//  CameraButtons.swift
//  phyphox
//
//  Created by Sebastian Staacks on 15.03.25.
//  Copyright © 2025 RWTH Aachen. All rights reserved.
//

extension UIButton {
    func setLocked(_ locked: Bool) {
        isEnabled = !locked
        alpha = locked ? 0.5 : 1.0
    }
}

extension UILabel {
    func setLocked(_ locked: Bool) {
        isEnabled = !locked
        alpha = locked ? 0.5 : 1.0
    }
}
