//
//  UIColorExtensions.swift
//  phyphox
//
//  Created by Sebastian Staacks on 02.06.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

import Foundation

extension UIColor {
    func autoLightColor() -> UIColor {
        guard #available(iOS 13.0, *) else {
            return ColorConverterHelper().adjustColorForLightTheme(colorName: self)
        }
        if SettingBundleHelper.getAppMode() == Utility.LIGHT_MODE {
            return ColorConverterHelper().adjustColorForLightTheme(colorName: self)
        } else if SettingBundleHelper.getAppMode() == Utility.DARK_MODE {
            return self
        } else {
            if UIScreen.main.traitCollection.userInterfaceStyle == .dark {
                return self
            }
            return ColorConverterHelper().adjustColorForLightTheme(colorName: self)
        }
    }
    func overlayTextColor() -> UIColor {
        if self.luminance > 0.7 {
            return UIColor(white: 0.0, alpha: 1.0)
        } else {
            return UIColor(white: 1.0, alpha: 1.0)
        }
    }
}
