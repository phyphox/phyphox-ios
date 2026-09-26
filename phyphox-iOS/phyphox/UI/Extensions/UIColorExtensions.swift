//
//  UIColorExtensions.swift
//  phyphox
//
//  Created by Sebastian Staacks on 02.06.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

import Foundation

extension UIColor {
    ///The colour for the remote interface without the "#": RRGGBB, or RRGGBBAA when it is not opaque (file format 1.21,
    ///phyphox-webinterface readme.md "The graph configuration")
    var webHexString: String {
        var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 1.0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return hexStringValue ?? "000000"
        }
        func byte(_ v: CGFloat) -> Int { return Int((Swift.min(Swift.max(v, 0), 1) * 255).rounded()) }
        let rgb = String(format: "%02X%02X%02X", byte(r), byte(g), byte(b))
        return a < 1 ? rgb + String(format: "%02X", byte(a)) : rgb
    }

    func autoLightColor() -> UIColor {
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
