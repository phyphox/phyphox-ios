//
//  CameraViewElementHandler.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 07.09.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

import Foundation

struct CameraViewElementDescriptor {
    let label: String
    let exposureAdjustmentLevel: CameraSettingLevel
    let grayscale: Bool
    let markOverexposure: UIColor?
    let markUnderexposure: UIColor?
    let showControls: CameraShowControlsState
}

final class CameraViewElementHandler: ResultElementHandler, ChildlessElementHandler, ViewComponentElementHandler {
    var results = [ViewElementDescriptor]()
    
    func startElement(attributes: AttributeContainer) throws {}
    
    private enum Attribute: String, AttributeKey {
        case label
        case exposure_adjustment_level
        case grayscale
        case markOverexposure
        case markUnderexposure
        case show_controls
    }
    
    func endElement(text: String, attributes: AttributeContainer) throws {
        let attributes = attributes.attributes(keyedBy: Attribute.self)
        
        let label = attributes.optionalString(for: .label) ?? ""
        
        let exposureAdjustmentLevelVal: Int = try attributes.optionalValue(for: .exposure_adjustment_level) ?? 0
        let exposureAdjustmentLevel = switch exposureAdjustmentLevelVal {
        case 1: CameraSettingLevel.BASIC
        case 2: CameraSettingLevel.INTERMEDIATE
        case 3: CameraSettingLevel.ADVANCE
        default: CameraSettingLevel.BASIC
        }
                
        let grayScale = try attributes.optionalValue(for: .grayscale) ?? false
        
        let markOverexposure = mapColorString(attributes.optionalString(for: .markOverexposure))
        
        let markUnderexposure = mapColorString(attributes.optionalString(for: .markUnderexposure))
        
        let showControlsStr = attributes.optionalString(for: .show_controls)
        let showControls: CameraShowControlsState = switch showControlsStr?.lowercased() {
        case nil: .FULL_VIEW_ONLY
        case "always": .ALWAYS
        case "full_view_only": .FULL_VIEW_ONLY
        case "never": .NEVER
        default: throw ElementHandlerError.unexpectedAttributeValue(showControlsStr ?? "")
        }
        
        results.append(.camera(CameraViewElementDescriptor(label: label, exposureAdjustmentLevel: exposureAdjustmentLevel, grayscale: grayScale, markOverexposure: markOverexposure, markUnderexposure: markUnderexposure, showControls: showControls)))
    }
    
    func nextResult() throws -> ViewElementDescriptor {
        guard !results.isEmpty else { throw ElementHandlerError.missingElement("") }
        return results.removeFirst()
    }
}
