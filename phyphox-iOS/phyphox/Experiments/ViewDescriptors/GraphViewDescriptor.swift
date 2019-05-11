//
//  GraphViewDescriptor.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import Foundation

struct GraphViewDescriptor: ViewDescriptor, Equatable {
    private let xLabel: String
    private let yLabel: String
    private let zLabel: String?
    private let xUnit: String?
    private let yUnit: String?
    private let zUnit: String?
    
    private var legacyXLabel: String? = nil
    private var legacyXUnit: String? = nil
    private var legacyYLabel: String? = nil
    private var legacyYUnit: String? = nil
    
    var localizedXLabelWithUnit: String {
        if legacyXLabel != nil && legacyXUnit != nil {
            return legacyXLabel!  + " (" + legacyXUnit! + ")"
        }
        return localizedXLabel + " (" + localizedXUnit + ")"
    }
    
    var localizedYLabelWithUnit: String {
        if legacyYLabel != nil && legacyYUnit != nil {
            return legacyYLabel!  + " (" + legacyYUnit! + ")"
        }
        return localizedYLabel + " (" + localizedYUnit + ")"
    }
    
    var localizedZLabelWithUnit: String {
        return localizedZLabel + " (" + localizedZUnit + ")"
    }
    
    var localizedXLabel: String {
        if legacyXLabel != nil {
            return legacyXLabel!
        }
        return translation?.localize(xLabel) ?? xLabel
    }
    
    var localizedYLabel: String {
        if legacyYLabel != nil {
            return legacyYLabel!
        }
        return translation?.localize(yLabel) ?? yLabel
    }
    
    var localizedZLabel: String {
        return translation?.localize(zLabel ?? "") ?? zLabel ?? ""
    }
    
    var localizedXUnit: String {
        if legacyXUnit != nil {
            return legacyXUnit!
        }
        return translation?.localize(xUnit ?? "") ?? xUnit ?? ""
    }
    
    var localizedYUnit: String {
        if legacyYUnit != nil {
            return legacyYUnit!
        }
        return translation?.localize(yUnit ?? "") ?? yUnit ?? ""
    }
    
    var localizedZUnit: String {
        return translation?.localize(zUnit ?? "") ?? zUnit ?? ""
    }
    
    let logX: Bool
    let logY: Bool
    let logZ: Bool
    
    let xPrecision: UInt
    let yPrecision: UInt
    let zPrecision: UInt
    
    enum ScaleMode: String, LosslessStringConvertible {
        case auto, extend, fixed
    }
    
    enum GraphStyle: String, LosslessStringConvertible {
        case lines
        case dots
        case hbars
        case vbars
        case map
    }
    
    let minX: CGFloat
    let maxX: CGFloat
    let minY: CGFloat
    let maxY: CGFloat
    let minZ: CGFloat
    let maxZ: CGFloat
    
    let scaleMinX: ScaleMode
    let scaleMaxX: ScaleMode
    let scaleMinY: ScaleMode
    let scaleMaxY: ScaleMode
    let scaleMinZ: ScaleMode
    let scaleMaxZ: ScaleMode
    
    var xInputBuffers: [DataBuffer?]
    var yInputBuffers: [DataBuffer]
    var zInputBuffers: [DataBuffer?]
    
    let aspectRatio: CGFloat
    let partialUpdate: Bool
    let history: UInt
    
    let style: [GraphStyle]
    let lineWidth: [CGFloat]
    let color: [UIColor]

    let mapWidth: UInt
    let colorMap: [UIColor]
    
    let label: String
    let translation: ExperimentTranslationCollection?

    init(label: String, translation: ExperimentTranslationCollection?, xLabel: String, yLabel: String, zLabel: String?, xUnit: String?, yUnit: String?, zUnit: String?, xInputBuffers: [DataBuffer?], yInputBuffers: [DataBuffer], zInputBuffers: [DataBuffer?], logX: Bool, logY: Bool, logZ: Bool, xPrecision: UInt, yPrecision: UInt, zPrecision: UInt, scaleMinX: ScaleMode, scaleMaxX: ScaleMode, scaleMinY: ScaleMode, scaleMaxY: ScaleMode, scaleMinZ: ScaleMode, scaleMaxZ: ScaleMode, minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat, minZ: CGFloat, maxZ: CGFloat, aspectRatio: CGFloat, partialUpdate: Bool, history: UInt, style: [GraphViewDescriptor.GraphStyle], lineWidth: [CGFloat], color: [UIColor], mapWidth: UInt, colorMap: [UIColor]) {
        self.xLabel = xLabel
        self.yLabel = yLabel
        self.zLabel = zLabel
        self.xUnit = xUnit
        self.yUnit = yUnit
        self.zUnit = zUnit
        
        //Parse units from old experiments, where the unit is part of the label
        if xUnit == nil {
            let pattern = "^(.+)\\ \\((.+)\\)$"
            let regex = try? NSRegularExpression(pattern: pattern)
            let source = translation?.localize(xLabel) ?? xLabel
            if let match = regex?.firstMatch(in: source, range: NSRange(location: 0, length: source.count)) {
                if let labelRange = Range(match.range(at: 1), in: source), let unitRange = Range(match.range(at: 2), in: source) {
                    let newLabel = source[labelRange]
                    legacyXUnit = String(source[unitRange])
                    legacyXLabel = String(newLabel)
                }
            }
        }
        
        if yUnit == nil {
            let pattern = "^(.+)\\ \\((.+)\\)$"
            let regex = try? NSRegularExpression(pattern: pattern)
            let source = translation?.localize(yLabel) ?? yLabel
            if let match = regex?.firstMatch(in: source, range: NSRange(location: 0, length: source.count)) {
                if let labelRange = Range(match.range(at: 1), in: source), let unitRange = Range(match.range(at: 2), in: source) {
                    let newLabel = source[labelRange]
                    legacyYUnit = String(source[unitRange])
                    legacyYLabel = String(newLabel)
                }
            }
        }
        
        self.logX = logX
        self.logY = logY
        self.logZ = logZ
        
        self.xPrecision = xPrecision
        self.yPrecision = yPrecision
        self.zPrecision = zPrecision
        
        self.minX = minX
        self.maxX = maxX
        self.minY = minY
        self.maxY = maxY
        self.minZ = minZ
        self.maxZ = maxZ
        
        self.scaleMinX = scaleMinX
        self.scaleMaxX = scaleMaxX
        self.scaleMinY = scaleMinY
        self.scaleMaxY = scaleMaxY
        self.scaleMinZ = scaleMinZ
        self.scaleMaxZ = scaleMaxZ
        
        self.xInputBuffers = xInputBuffers
        self.yInputBuffers = yInputBuffers
        self.zInputBuffers = zInputBuffers
        
        self.aspectRatio = aspectRatio
        self.partialUpdate = partialUpdate
        self.history = history
        
        self.style = style
        self.lineWidth = lineWidth
        self.color = color

        self.mapWidth = mapWidth
        if colorMap.count > 1 {
            self.colorMap = colorMap
        } else {
            self.colorMap = [UIColor.black, kHighlightColor, UIColor.white]
        }
        
        self.label = label
        self.translation = translation
    }
    
    func generateViewHTMLWithID(_ id: Int) -> String {
        return "<div style=\"font-size: 105%;\" class=\"graphElement\" id=\"element\(id)\"><span class=\"label\">\(localizedLabel)</span><div class=\"graphBox\"><div class=\"graphRatio\" style=\"padding-top: \(100.0/aspectRatio)%\"></div><div class=\"graph\"></div></div></div>"
    }
    
    func generateDataCompleteHTMLWithID(_ id: Int) -> String {
        let transformX: String
        let transformY: String
        
        if logX {
            transformX = "ticks: [0.1,1,10,100,1000,10000], transform: function (v) { if (v >= 0.001) return Math.log(v); else return Math.log(0.001) }, inverseTransform: function (v) { return Math.exp(v); }, "
        }
        else {
            transformX = "\"ticks\": 3, "
        }
        
        if logY {
            transformY = "ticks: [0.01,0.1,1,10], transform: function (v) { if (v >= 0.001) return Math.log(v); else return Math.log(0.001) }, inverseTransform: function (v) { return Math.exp(v); }, "
        }
        else {
            transformY = "\"ticks\": 3, "
        }
        
        var scaleX: String = ""
        if scaleMinX == GraphViewDescriptor.ScaleMode.fixed && minX.isFinite {
            scaleX += "\"min\": " + String(describing: minX) + ", "
        }
        if scaleMaxX == GraphViewDescriptor.ScaleMode.fixed && maxX.isFinite {
            scaleX += "\"max\": " + String(describing: maxX) + ", "
        }
        var scaleY: String = ""
        if scaleMinY == GraphViewDescriptor.ScaleMode.fixed && minY.isFinite {
            scaleY += "\"min\": " + String(describing: minY) + ", "
        }
        if scaleMaxY == GraphViewDescriptor.ScaleMode.fixed && maxY.isFinite {
            scaleY += "\"max\": " + String(describing: maxY) + ", "
        }
        
        return "function () {" +
            "var d = [];" +
            "if (!elementData[\(id)].hasOwnProperty(\"y\"))return;" +
            "if (!elementData[\(id)].hasOwnProperty(\"x\") || elementData[\(id)][\"x\"].length == 0) {" +
            "elementData[\(id)][\"x\"] = [];" +
            "for (i = 0; i < elementData[\(id)][\"y\"].length; i++)" +
            "elementData[\(id)][\"x\"][i] = i" +
            "}" +
            "for (i = 0; i < elementData[\(id)][\"y\"].length && i < elementData[\(id)][\"x\"].length; i++)" +
            "d[i] = [elementData[\(id)][\"x\"][i], elementData[\(id)][\"y\"][i]];" +
            //TODO For now we have just inserted the index 0 for multiple lines. This has to be converted to the new plotting library anyway.
            "$.plot(\"#element\(id) .graph\", [{ \"color\": \"#\(color[0].hexStringValue!)\" , \"data\": d }], {\"lines\": {\"show\":\(style[0] == .dots ? "false" : "true"), \"lineWidth\":\(2.0*lineWidth[0])}, \"points\": {\"show\":\(style[0] == .dots ? "true" : "false")}, \"xaxis\": {\(scaleX) \(transformX)\"axisLabel\": \"\(localizedXLabelWithUnit)\", \"tickColor\": \"#\(UIColor(white: 0.6, alpha: 1.0).hexStringValue!)\"}, \"yaxis\": {\(scaleY) \(transformY)\"axisLabel\": \"\(localizedYLabelWithUnit)\", \"tickColor\": \"#\(UIColor(white: 0.6, alpha: 1.0).hexStringValue!)\"}, \"grid\": {\"borderColor\": \"#\(kTextColor.hexStringValue!)\", \"backgroundColor\": \"#\(kBackgroundColor.hexStringValue!)\"}});}"
    }
    
    func setDataXHTMLWithID(_ id: Int) -> String {
        return "function (x) { elementData[\(id)][\"x\"] = x }"
    }
    
    func setDataYHTMLWithID(_ id: Int) -> String {
        return "function (y) { elementData[\(id)][\"y\"] = y }"
    }
}
