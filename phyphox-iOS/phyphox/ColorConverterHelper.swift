//
//  ColorConverterHelper.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 23.02.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

import Foundation

class ColorConverterHelper {
    
    struct RGB {
        var red: Double
        var green: Double
        var blue: Double
    }
    
    struct HSV {
        var heu: Double
        var saturation: Double
        var value: Double
    }
    
    public func adjustableColor(colorName: UIColor) -> UIColor {
        print("3")
        let r = colorName.cgColor.components?[0]
         let g = colorName.cgColor.components?[1]
         let b = colorName.cgColor.components?[2]
        
        if r == 0x40 && g == 0x40 && b == 0x40 {
            return UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        }
        
        print("4")
        
        var hsv = rbgToHsv(rgb: RGB(red: r!, green: g!, blue: b!))
        
        var l = (2.0 - hsv.saturation) * hsv.value / 2.0
        var s = l > 0 && l < 1 ? hsv.saturation * hsv.value / (l < 0.5 ? l * 2.0 : 2.0 - l * 2.0) : 0.0
        l = 1.0 - l
        let t = s * (l < 0.5 ? l : 1.0 - l)
        hsv.value = l + t
        hsv.saturation = l > 0 ? 2 * t / hsv.value : 0.0
        
        let newRgb =  hsvToRgb(hsv: HSV(heu: hsv.heu, saturation: hsv.saturation, value: hsv.value))
        
        
        return UIColor.init(red: CGFloat(newRgb.red), green: CGFloat(newRgb.green), blue: CGFloat(newRgb.blue), alpha: 0.0)
    }
    
    func stringToRgb(colorString: String) -> RGB {
        
        var rgb = RGB.init(red: 0, green: 0, blue: 0)
        if colorString.hasPrefix("#") {
            if let i = Int(colorString.dropFirst(), radix: 16) {
                rgb.red = Double((i >> 16) & 255)
                rgb.green = Double((i >> 8) & 255)
                rgb.blue = Double(i & 255)
            }
        } else {
            let rgbsep = colorString.replacingOccurrences(of: "[^\\d,]", with: "", options: .regularExpression).split(separator: ",").map { String($0) }
            if rgbsep.count == 3 {
                rgb.red = Double(rgbsep[0]) ?? 0.0
                rgb.red = Double(rgbsep[1]) ?? 0.0
                rgb.red = Double(rgbsep[2]) ?? 0.0
            }
        }
        return rgb
        
    }
    
    func rbgToHsv(rgb: RGB) -> HSV {
        
        let HUE_MAX = 360.0
        var hsv = HSV(heu: 0.0, saturation: 0.0, value: 0.0)
        let r = Double(rgb.red)
        let g = Double(rgb.green)
        let b = Double(rgb.blue)
        
        let maxVal = max(r, max(g, b))
        let minVal = min(r, min(g, b))
        let delta = maxVal - minVal
        
        hsv.value = maxVal / 255.0
        let s = (maxVal == 0) ? 0 : delta / maxVal
        
        var h: Double
        if maxVal == minVal {
            h = 0
        } else if maxVal == r {
            h = (g - b + delta * 6) / (6 * delta)
        } else if maxVal == g {
            h = (b - r + delta * 2) / (6 * delta)
        } else {
            h = (r - g + delta * 4) / (6 * delta)
        }
        
        hsv.heu = h * HUE_MAX
        hsv.saturation = s
        return hsv
        
    }
    
    func hsvToRgb(hsv: HSV) -> RGB {
        
        var r, g, b, i: Int
        var f, p, q, t: Double
        i = Int(floor(hsv.heu * 6))
        f = hsv.heu * 6 - Double(i)
        p = hsv.value * (1 - hsv.saturation)
        q = hsv.value * (1 - f * hsv.saturation)
        t = hsv.value * (1 - (1 - f) * hsv.saturation)
        
        switch (i % 6) {
        case 0:
            r = Int(hsv.value * 255)
            g = Int(t * 255)
            b = Int(p * 255)
        case 1:
            r = Int(q * 255)
            g = Int(hsv.value * 255)
            b = Int(p * 255)
        case 2:
            r = Int(p * 255)
            g = Int(hsv.value * 255)
            b = Int(t * 255)
        case 3:
            r = Int(p * 255)
            g = Int(q * 255)
            b = Int(hsv.value * 255)
        case 4:
            r = Int(t * 255)
            g = Int(p * 255)
            b = Int(hsv.value * 255)
        case 5:
            r = Int(hsv.value * 255)
            g = Int(p * 255)
            b = Int(q * 255)
        default:
            return RGB(red: 0, green: 0, blue: 0)
        }
        
        let colorString = String(format: "#%06X", (0xFFFFFF & ((r << 16) | (g << 8) | b)))
        return stringToRgb(colorString: colorString)
        
        
    }
    
    
}
