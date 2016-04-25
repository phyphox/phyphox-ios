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
    private let xLabel: String
    private let yLabel: String
    
    var localizedXLabel: String {
        return translation?.localize(xLabel) ?? xLabel
    }
    
    var localizedYLabel: String {
        return translation?.localize(yLabel) ?? yLabel
    }
    
    let logX: Bool
    let logY: Bool
    
    var xInputBuffer: DataBuffer?
    var yInputBuffer: DataBuffer
    
    let aspectRatio: CGFloat
    let partialUpdate: Bool
    let drawDots: Bool
    let forceFullDataset: Bool
    let history: UInt
    
    init(label: String, translation: ExperimentTranslationCollection?, xLabel: String, yLabel: String, xInputBuffer: DataBuffer?, yInputBuffer: DataBuffer, logX: Bool, logY: Bool, aspectRatio: CGFloat, drawDots: Bool, partialUpdate: Bool, forceFullDataset: Bool, history: UInt) {
        self.xLabel = xLabel
        self.yLabel = yLabel
        
        self.logX = logX
        self.logY = logY
        
        self.xInputBuffer = xInputBuffer
        self.yInputBuffer = yInputBuffer
        
        self.aspectRatio = aspectRatio
        self.partialUpdate = partialUpdate
        self.drawDots = drawDots
        self.forceFullDataset = forceFullDataset
        self.history = history
        
        super.init(label: label, translation: translation)
    }
    
    override func generateViewHTMLWithID(id: Int) -> String {
        return "<div class=\\\"graphElement\\\" id=\\\"element\(id)\\\"><span class=\\\"label\\\">\(localizedLabel)</span><div class=\\\"graphBox\\\"><div class=\\\"graphRatio\\\" style=\\\"padding-top: \(100.0/aspectRatio)%\\\"></div><div class=\\\"graph\\\"></div></div></div>"
    }
    
    override func generateDataCompleteHTMLWithID(id: Int) -> String {
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
            "$.plot(\"#element\(id) .graph\", [{ \"color\": \"#\(kHighlightColor.hexStringValue)\" , \"data\": d }], {\"xaxis\": {\(transformX)\"axisLabel\": \"\(xLabel)\", \"tickColor\": \"#\(UIColor(white: 0.4, alpha: 1.0).hexStringValue)\"}, \"yaxis\": {\(transformY)\"axisLabel\": \"\(yLabel)\", \"tickColor\": \"#\(UIColor(white: 0.4, alpha: 1.0).hexStringValue)\"}, \"grid\": {\"borderColor\": \"#\(UIColor(white: 0.0, alpha: 0.5).hexStringValue)\"}});}"
    }
    
    override func setDataXHTMLWithID(id: Int) -> String {
        return "function (x) { elementData[\(id)][\"x\"] = x }"
    }
    
    override func setDataYHTMLWithID(id: Int) -> String {
        return "function (y) { elementData[\(id)][\"y\"] = y }"
    }
}
