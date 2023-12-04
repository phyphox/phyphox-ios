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
    let aspectRatio: CGFloat

    let translation: ExperimentTranslationCollection?

    init(label: String, aspectRatio: CGFloat, translation: ExperimentTranslationCollection?) {
        self.label = label
        self.aspectRatio = aspectRatio
        self.translation = translation
    }

    func generateViewHTMLWithID(_ id: Int) -> String {
        let warningText = localize("remoteCameraWarning").replacingOccurrences(of: "\"", with: "\\\"")
        return "<div style=\"font-size: 105%;\" class=\"graphElement\" id=\"element\(id)\"><span class=\"label\" onclick=\"toggleExclusive(\(id));\">\(localizedLabel)</span><div class=\"warningIcon\" onclick=\"alert('\(warningText)')\"></div></div>"
    }
}