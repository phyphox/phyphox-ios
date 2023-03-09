//
//  DynamicTextSizeHelper.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 07.03.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

import Foundation

class DynamicTextSizeHelper {
    
    
    private static let SMALL_WIDTH: Double  = 1.0
    private static let MEDIUM_WIDTH: Double = 2.0
    private static let BIG_WIDTH: Double  = 4.0
    private static let EXTRA_BIG_WIDTH: Double = 6.0
    
    private static let SMALL_LABEL: Double = 45.0/UIScreen.main.scale
    private static let MEDIUM_LABEL: Double = 50.0/UIScreen.main.scale
    private static let BIG_LABEL: Double = 55.0/UIScreen.main.scale
    private static let EXTRA_BIG_LABEL: Double  = 60.0/UIScreen.main.scale
    
    
    static func getSystemTextSize() -> TextSize{
        let key = UIScreen.main.traitCollection.preferredContentSizeCategory.rawValue.description
        let textSizeDictionary: Dictionary = [
            "UICTContentSizeCategoryXS": TextSize.XS,
            "UICTContentSizeCategoryS": TextSize.S,
            "UICTContentSizeCategoryM": TextSize.M,
            "UICTContentSizeCategoryL": TextSize.L,
            "UICTContentSizeCategoryXL": TextSize.XL,
            "UICTContentSizeCategoryXXL": TextSize.XXL,
            "UICTContentSizeCategoryXXXL": TextSize.XXXL]
        
        return textSizeDictionary[key] ?? TextSize.Empty
        
    }
    
    enum TextSize {
        case XS
        case S
        case M
        case L
        case XL
        case XXL
        case XXXL
        case Empty
    }
    
    
    static func getGraphSettingWidth() -> Double {
        switch SettingBundleHelper.getGraphSize() {
            
        case 1:
            return SMALL_WIDTH
            
        case 2:
            return MEDIUM_WIDTH
            
        case 3:
            return BIG_WIDTH
            
        case 4:
            return EXTRA_BIG_WIDTH
            
        default:
            return MEDIUM_WIDTH
        }
    }
    
    static func getGraphSettingLabelSize() -> Double {
        switch SettingBundleHelper.getGraphSize() {
            
        case 1:
            return SMALL_LABEL
            
        case 2:
            return MEDIUM_LABEL
            
        case 3:
            return BIG_LABEL
            
        case 4:
            return EXTRA_BIG_LABEL
            
        default:
            return MEDIUM_LABEL
        }
    }
    
    
    
    
}
