//
//  CameraViewDescriptor.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 07.09.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

import Foundation

struct CameraViewDescriptor: ViewDescriptor, Equatable {
    let label: String
    let exposureAdjustmentLevel: CameraSettingLevel
    let grayscale: Bool
    let markOverexposure: UIColor?
    let markUnderexposure: UIColor?
    let showControls: CameraShowControlsState

    let translation: ExperimentTranslationCollection?

    init(label: String, exposureAdjustmentLevel: CameraSettingLevel, grayscale: Bool, markOverexposure: UIColor?, markUnderexposure: UIColor?, showControls: CameraShowControlsState, translation: ExperimentTranslationCollection?) {
        self.label = label
        self.exposureAdjustmentLevel = exposureAdjustmentLevel
        self.grayscale = grayscale
        self.markOverexposure = markOverexposure
        self.markUnderexposure = markUnderexposure
        self.showControls = showControls
        self.translation = translation
    }

    func generateViewHTMLWithID(_ id: Int) -> String {
        let warningText = localize("remoteCameraWarning").replacingOccurrences(of: "\"", with: "\\\"")
        return "<div style=\"font-size: 105%;\" class=\"graphElement\" id=\"element\(id)\"><span class=\"label\" onclick=\"toggleExclusive(\(id));\">\(localizedLabel)</span><div class=\"warningIcon\" onclick=\"alert('\(warningText)')\"></div></div>"
    }
}
