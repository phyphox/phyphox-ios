//
//  DynamicTextSizeHelper.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 07.03.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

import Foundation

class DynamicTextSizeHelper {
    
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
    
    
    static func getGlGraphDynamicLineWidth() -> Double{
        switch getSystemTextSize() {
        case TextSize.XS:
            return 1.5
        case TextSize.S:
            return 1.75
        case TextSize.M:
            return 1.9
        case TextSize.L:
            return 2.0
        case TextSize.XL:
            return 3.0
        case TextSize.XXL:
            return 4.0
        case TextSize.XXXL:
            return 5.0
        default:
            return 2.0
        }
    }
    
    static func getGraphBorderWidth() -> Double {
        switch getSystemTextSize() {
        case TextSize.XS:
            return 1.0/UIScreen.main.scale
        case TextSize.S:
            return 1.0/UIScreen.main.scale
        case TextSize.M:
            return 1.5/UIScreen.main.scale
        case TextSize.L:
            return 2.0/UIScreen.main.scale
        case TextSize.XL:
            return 3.0/UIScreen.main.scale
        case TextSize.XXL:
            return 4.0/UIScreen.main.scale
        case TextSize.XXXL:
            return 5.0/UIScreen.main.scale
        default:
            return 2.0/UIScreen.main.scale
        }
     
    }
    
    static func getGraphSettingBorderWidth() -> Double {
        switch SettingBundleHelper.getGraphSize() {
            
        case 1:
            return 1.0/UIScreen.main.scale
            
        case 2:
            return 2.0/UIScreen.main.scale
            
        case 3:
            return 3.5/UIScreen.main.scale
            
        case 4:
            return 5.5/UIScreen.main.scale
            
        default:
            return 2.0/UIScreen.main.scale
        }
    }
    
    
    static func getGraphSettingCurveWidth() -> Double {
        switch SettingBundleHelper.getGraphSize() {
            
        case 1:
            return 1.75
            
        case 2:
            return 2.0
            
        case 3:
            return 3.5
            
        case 4:
            return 5.5
            
        default:
            return 2.0
        }
    }
    
    static func getGraphSettingXYLabelSize() -> Double {
        switch SettingBundleHelper.getGraphSize() {
            
        case 1:
            return 17.5
            
        case 2:
            return 20.0
            
        case 3:
            return 25.5
            
        case 4:
            return 30.5
            
        default:
            return 20.0
        }
    }
    
    static func getGraphSettingTitleLableSize() -> Double {
        switch SettingBundleHelper.getGraphSize() {
            
        case 1:
            return 15.0
            
        case 2:
            return 20.0
            
        case 3:
            return 25.0
            
        case 4:
            return 30.5
            
        default:
            return 20.0
        }
    }
    
    
    
    
}
