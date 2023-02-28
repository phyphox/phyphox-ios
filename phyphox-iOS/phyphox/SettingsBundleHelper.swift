//
//  SettingsBundleHelper.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 28.02.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

import Foundation

class SettingBundleHelper {
    
    enum UserDefaultKeys: String {
        case APP_MODE = "appModeKey"
    }
    
    static func registerDefaults(){
        var appDefaults = Dictionary<String, Any>()
        appDefaults[UserDefaultKeys.APP_MODE.rawValue] = "1"
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
    

}
