//
//  GraphViewDescriptor.swift
//  phyphox
//
//  Created by Jonas Gessner on 12.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation

final class GraphViewDescriptor: ViewDescriptor {
    fileprivate let xLabel: String
    fileprivate let yLabel: String
    
    var localizedXLabel: String {
        return translation?.localize(xLabel) ?? xLabel
    }
    
    var localizedYLabel: String {
        return translation?.localize(yLabel) ?? yLabel
    }
    
    let logX: Bool
    let logY: Bool
    
    let xPrecision: UInt
    let yPrecision: UInt
    
    enum scaleMode {
        case auto, extend, fixed
    }
    
    let minX: CGFloat
    let maxX: CGFloat
    let minY: CGFloat
    let maxY: CGFloat
    
    let scaleMinX: scaleMode
    let scaleMaxX: scaleMode
    let scaleMinY: scaleMode
    let scaleMaxY: scaleMode
    
    var xInputBuffer: DataBuffer?
    var yInputBuffer: DataBuffer
    
    let aspectRatio: CGFloat
    let partialUpdate: Bool
    let drawDots: Bool
    let history: UInt
    
    let lineWidth: CGFloat
    let color: UIColor
    
    init(label: String, translation: ExperimentTranslationCollection?, requiresAnalysis: Bool, xLabel: String, yLabel: String, xInputBuffer: DataBuffer?, yInputBuffer: DataBuffer, logX: Bool, logY: Bool, xPrecision: UInt, yPrecision: UInt, scaleMinX: scaleMode, scaleMaxX: scaleMode, scaleMinY: scaleMode, scaleMaxY: scaleMode, minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat, aspectRatio: CGFloat, drawDots: Bool, partialUpdate: Bool, forceFullDataset: Bool, history: UInt, lineWidth: CGFloat, color: UIColor) {
        self.xLabel = xLabel
        self.yLabel = yLabel
        
        self.logX = logX
        self.logY = logY
        
        self.xPrecision = xPrecision
        self.yPrecision = yPrecision
        
        self.minX = minX
        self.maxX = maxX
        self.minY = minY
        self.maxY = maxY
        
        self.scaleMinX = scaleMinX
        self.scaleMaxX = scaleMaxX
        self.scaleMinY = scaleMinY
        self.scaleMaxY = scaleMaxY
        
        self.xInputBuffer = xInputBuffer
        self.yInputBuffer = yInputBuffer
        
        self.aspectRatio = aspectRatio
        self.partialUpdate = partialUpdate
        self.drawDots = drawDots
        self.history = history
        
        self.lineWidth = lineWidth
        self.color = color
        
        super.init(label: label, translation: translation, requiresAnalysis: requiresAnalysis)
    }
    
    override func generateViewHTMLWithID(_ id: Int) -> String {
        return "<div style=\"font-size: 105%;\" class=\"graphElement\" id=\"element\(id)\"><span class=\"label\">\(localizedLabel)</span><div class=\"graphBox\"><div class=\"graphRatio\" style=\"padding-top: \(100.0/aspectRatio)%\"></div><div class=\"graph\"></div></div></div>"
    }
    
    override func generateDataCompleteHTMLWithID(_ id: Int) -> String {
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
        if scaleMinX == GraphViewDescriptor.scaleMode.fixed && minX.isFinite {
            scaleX += "\"min\": " + String(describing: minX) + ", "
        }
        if scaleMaxX == GraphViewDescriptor.scaleMode.fixed && maxX.isFinite {
            scaleX += "\"max\": " + String(describing: maxX) + ", "
        }
        var scaleY: String = ""
        if scaleMinY == GraphViewDescriptor.scaleMode.fixed && minY.isFinite {
            scaleY += "\"min\": " + String(describing: minY) + ", "
        }
        if scaleMaxY == GraphViewDescriptor.scaleMode.fixed && maxY.isFinite {
            scaleY += "\"max\": " + String(describing: maxY) + ", "
        }
        
        return "function () {" +
            "var d = [];" +
            "if (!elementData[\(id)].hasOwnProperty(\"y\"))return;" +
            "if (!elementData[\(id)].hasOwnProperty(\"x\") || elementData[\(id)][\"x\"].length < elementData[\(id)][\"y\"].length) {" +
            "elementData[\(id)][\"x\"] = [];" +
            "for (i = 0; i < elementData[\(id)][\"y\"].length; i++)" +
            "elementData[\(id)][\"x\"][i] = i" +
            "}" +
            "for (i = 0; i < elementData[\(id)][\"y\"].length; i++)" +
            "d[i] = [elementData[\(id)][\"x\"][i], elementData[\(id)][\"y\"][i]];" +
            "$.plot(\"#element\(id) .graph\", [{ \"color\": \"#\(color.hexStringValue!)\" , \"data\": d }], {\"lines\": {\"show\":\(drawDots ? "false" : "true"), \"lineWidth\":\(2.0*lineWidth)}, \"points\": {\"show\":\(drawDots ? "true" : "false")}, \"xaxis\": {\(scaleX) \(transformX)\"axisLabel\": \"\(localizedXLabel)\", \"tickColor\": \"#\(UIColor(white: 0.6, alpha: 1.0).hexStringValue!)\"}, \"yaxis\": {\(scaleY) \(transformY)\"axisLabel\": \"\(localizedYLabel)\", \"tickColor\": \"#\(UIColor(white: 0.6, alpha: 1.0).hexStringValue!)\"}, \"grid\": {\"borderColor\": \"#\(kTextColor.hexStringValue!)\", \"backgroundColor\": \"#\(kBackgroundColor.hexStringValue!)\"}});}"
    }
    
    override func setDataXHTMLWithID(_ id: Int) -> String {
        return "function (x) { elementData[\(id)][\"x\"] = x }"
    }
    
    override func setDataYHTMLWithID(_ id: Int) -> String {
        return "function (y) { elementData[\(id)][\"y\"] = y }"
    }
}
