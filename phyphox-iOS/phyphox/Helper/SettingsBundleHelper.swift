//
//  SettingsBundleHelper.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 28.02.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

import Foundation

class SettingBundleHelper {
    
    private static let SMALL_WIDTH: Double  = 1.0
    private static let MEDIUM_WIDTH: Double = 2.0
    private static let BIG_WIDTH: Double  = 4.0
    private static let EXTRA_BIG_WIDTH: Double = 6.0
    
    private static let SMALL_LABEL: Double = 45.0/UIScreen.main.scale
    private static let MEDIUM_LABEL: Double = 50.0/UIScreen.main.scale
    private static let BIG_LABEL: Double = 55.0/UIScreen.main.scale
    private static let EXTRA_BIG_LABEL: Double  = 60.0/UIScreen.main.scale
    
    enum UserDefaultKeys: String {
        case APP_MODE = "appModeKey"
        case GRAPH_SIZE = "graphSizeKey"
    }
    
    static func registerDefaults(){
        var appDefaults = Dictionary<String, Any>()
        appDefaults[UserDefaultKeys.APP_MODE.rawValue] = "1"
        appDefaults[UserDefaultKeys.GRAPH_SIZE.rawValue] = 2
        UserDefaults.standard.register(defaults: appDefaults)
        UserDefaults.standard.synchronize()
        
    }
    
    static func getAppMode() -> String{
        return UserDefaults.standard.string(forKey: SettingBundleHelper.UserDefaultKeys.APP_MODE.rawValue)?.description ?? "1"
    }
    
    
    static func setAppMode(window: UIWindow?){
        if #available(iOS 13.0, *) {
            if(SettingBundleHelper.getAppMode() == Utility.LIGHT_MODE){
                window?.overrideUserInterfaceStyle = .light
            } else if(SettingBundleHelper.getAppMode() == Utility.DARK_MODE){
                window?.overrideUserInterfaceStyle = .dark
            } else {
                window?.overrideUserInterfaceStyle = .unspecified
            }
        } else {
            // Fallback on earlier versions
        }
    }
    
    static func setAppModeInView(view: UIView?){
        if #available(iOS 13.0, *) {
            if(SettingBundleHelper.getAppMode() == Utility.LIGHT_MODE){
                view?.overrideUserInterfaceStyle = .light
            } else if(SettingBundleHelper.getAppMode() == Utility.DARK_MODE){
                view?.overrideUserInterfaceStyle = .dark
            } else {
                view?.overrideUserInterfaceStyle = .unspecified
            }
        } else {
            // Fallback on earlier versions
        }
    }
    
    static func getGraphSize() -> Int{
        return UserDefaults.standard.integer(forKey: SettingBundleHelper.UserDefaultKeys.GRAPH_SIZE.rawValue)
    }
    
    
    static func getTextColorWhenDarkModeNotSupported() -> UIColor{
        let white = UIColor(white: 1.0, alpha: 1.0)
        let black = UIColor(white: 0.0, alpha: 1.0)
        if(getAppMode() == Utility.LIGHT_MODE){
            return black
        } else if(getAppMode() == Utility.DARK_MODE){
            return white
        } else {
            if #available(iOS 12.0, *) {
                if(UIScreen.main.traitCollection.userInterfaceStyle == .dark){
                    return white
                } else{
                    return black
                }
            } else {
                return white
            }
        }
    }
    
    static func getLightBackgroundColorWhenDarkModeNotSupported() -> UIColor{
        if(SettingBundleHelper.getAppMode() == Utility.LIGHT_MODE){
            return kLightBackgroundColorForLight
        } else if(SettingBundleHelper.getAppMode() == Utility.DARK_MODE){
           return kLightBackgroundColor
        } else {
            if #available(iOS 12.0, *) {
                if(UIScreen.main.traitCollection.userInterfaceStyle == .dark){
                    return kLightBackgroundColor
                } else{
                    return kLightBackgroundColorForLight
                }
            } else {
                return kLightBackgroundColor
            }
        }
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
