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
    private let yxUnit: String?
    
    let timeReference: ExperimentTimeReference
    let timeOnX: Bool
    let timeOnY: Bool
    let systemTime: Bool
    let linearTime: Bool
    
    private var legacyXLabel: String? = nil
    private var legacyXUnit: String? = nil
    private var legacyYLabel: String? = nil
    private var legacyYUnit: String? = nil
    
    var localizedXLabelWithUnit: String {
        let label = legacyXLabel ?? localizedXLabel
        let unit = legacyXUnit ?? localizedXUnit
        if unit != "" {
            return label + " (" + unit + ")"
        } else {
            return label
        }
    }
    
    var localizedXLabelWithTimezone: String {
        let offset = TimeZone.current.secondsFromGMT()
        let hours = offset / (60*60)
        let minutes = abs(offset / 60) % 60
        let offsetStr = String(format: "%+d:%02d", hours, minutes)
        return localizedXLabel + " (UTC" + offsetStr + ")"
    }
    
    var localizedYLabelWithUnit: String {
        let label = legacyYLabel ?? localizedYLabel
        let unit = legacyYUnit ?? localizedYUnit
        if unit != "" {
            return label + " (" + unit + ")"
        } else {
            return label
        }
    }
    
    var localizedYLabelWithTimezone: String {
        let offset = TimeZone.current.secondsFromGMT()
        let hours = offset / (60*60)
        let minutes = abs(offset / 60) % 60
        let offsetStr = String(format: "%+d:%02d", hours, minutes)
        return localizedYLabel + " (UTC" + offsetStr + ")"
    }
    
    var localizedZLabelWithUnit: String {
        let label = localizedZLabel
        let unit = localizedZUnit
        if unit != "" {
            return label + " (" + unit + ")"
        } else {
            return label
        }
    }
    
    var localizedXLabel: String {
        if legacyXLabel != nil {
            return legacyXLabel!
        }
        return translation?.localizeString(xLabel) ?? xLabel
    }
    
    var localizedYLabel: String {
        if legacyYLabel != nil {
            return legacyYLabel!
        }
        return translation?.localizeString(yLabel) ?? yLabel
    }
    
    var localizedZLabel: String {
        return translation?.localizeString(zLabel ?? "") ?? zLabel ?? ""
    }
    
    var localizedXUnit: String {
        if legacyXUnit != nil {
            return legacyXUnit!
        }
        return translation?.localizeString(xUnit ?? "") ?? xUnit ?? ""
    }
    
    var localizedYUnit: String {
        if legacyYUnit != nil {
            return legacyYUnit!
        }
        return translation?.localizeString(yUnit ?? "") ?? yUnit ?? ""
    }
    
    var localizedZUnit: String {
        return translation?.localizeString(zUnit ?? "") ?? zUnit ?? ""
    }
    
    var localizedYXUnit: String {
        if let yxUnit = yxUnit {
            return translation?.localizeString(yxUnit) ?? yxUnit
        }
        return (localizedYUnit != "" ? localizedYUnit : "") + " / " + (localizedXUnit != "" ? localizedXUnit : "")
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
        case mapZ //This is only used in the remote interface to identify the third buffer for z data as the remote interface treats all axes in pairs of two
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

    init(label: String, translation: ExperimentTranslationCollection?, xLabel: String, yLabel: String, zLabel: String?, xUnit: String?, yUnit: String?, zUnit: String?, yxUnit: String?, timeReference: ExperimentTimeReference, timeOnX: Bool, timeOnY: Bool, systemTime: Bool, linearTime: Bool, xInputBuffers: [DataBuffer?], yInputBuffers: [DataBuffer], zInputBuffers: [DataBuffer?], logX: Bool, logY: Bool, logZ: Bool, xPrecision: UInt, yPrecision: UInt, zPrecision: UInt, scaleMinX: ScaleMode, scaleMaxX: ScaleMode, scaleMinY: ScaleMode, scaleMaxY: ScaleMode, scaleMinZ: ScaleMode, scaleMaxZ: ScaleMode, minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat, minZ: CGFloat, maxZ: CGFloat, aspectRatio: CGFloat, partialUpdate: Bool, history: UInt, style: [GraphViewDescriptor.GraphStyle], lineWidth: [CGFloat], color: [UIColor], mapWidth: UInt, colorMap: [UIColor]) {
        self.xLabel = xLabel
        self.yLabel = yLabel
        self.zLabel = zLabel
        self.xUnit = xUnit
        self.yUnit = yUnit
        self.zUnit = zUnit
        self.yxUnit = yxUnit
        
        self.timeReference = timeReference
        self.timeOnX = timeOnX
        self.timeOnY = timeOnY
        self.systemTime = systemTime
        self.linearTime = linearTime
        
        //Parse units from old experiments, where the unit is part of the label
        if xUnit == nil {
            let pattern = "^(.+)\\ \\((.+)\\)$"
            let regex = try? NSRegularExpression(pattern: pattern)
            let source = translation?.localizeString(xLabel) ?? xLabel
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
            let source = translation?.localizeString(yLabel) ?? yLabel
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
            self.colorMap = [UIColor(white: 0.0, alpha: 1.0), kHighlightColor, UIColor(white: 1.0, alpha: 1.0)]
        }
        
        self.label = label
        self.translation = translation
    }
    
    func generateViewHTMLWithID(_ id: Int) -> String {
        let warningText = localize("remoteColorMapWarning").replacingOccurrences(of: "\"", with: "\\\"")
        return "<div style=\"font-size: 105%;\" class=\"graphElement\" id=\"element\(id)\"><span class=\"label\" onclick=\"toggleExclusive(\(id));\">\(localizedLabel)</span>\(style[0] == .map ? "<div class=\"warningIcon\" onclick=\"alert('\(warningText)')\"></div>" : "")<div class=\"graphBox\"><div class=\"graphRatio\" style=\"padding-top: \(100.0/aspectRatio)%\"></div><div class=\"graph\"><canvas></canvas></div></div></div>"
    }
    
    func generateDataCompleteHTMLWithID(_ id: Int) -> String {
        var rescale = ""
        var scaleX = ""
        if scaleMinX == .fixed && minX.isFinite {
            scaleX += "\"min\":\(minX), "
        } else {
            rescale += "elementData[\(id)][\"graph\"].options.scales.xAxes[0].ticks.min = minX;"
        }
        if scaleMaxX == .fixed && maxX.isFinite {
            scaleX += "\"max\":\(maxX), "
        } else {
            rescale += "elementData[\(id)][\"graph\"].options.scales.xAxes[0].ticks.max = maxX;"
        }
        var scaleY = ""
        if scaleMinY == .fixed && minY.isFinite {
            scaleY += "\"min\":\(minY), "
        } else {
            rescale += "elementData[\(id)][\"graph\"].options.scales.yAxes[0].ticks.min = minY;"
        }
        if scaleMaxY == .fixed && maxY.isFinite {
            scaleY += "\"max\":\(maxY), "
        } else {
            rescale += "elementData[\(id)][\"graph\"].options.scales.yAxes[0].ticks.max = maxY;"
        }
        
        var scaleZ = ""
        var colorScale = "["
        if style[0] == .map {
            if scaleMinZ == .fixed && minZ.isFinite {
                scaleZ += "minZ = \(minZ);"
            }
            if scaleMaxZ == .fixed && maxZ.isFinite {
                scaleZ += "maxZ = \(maxZ);"
            }
            scaleZ += "elementData[\(id)][\"graph\"].logZ = \(logZ ? "true" : "false");";
            scaleZ += "elementData[\(id)][\"graph\"].minZ = minZ;";
            scaleZ += "elementData[\(id)][\"graph\"].maxZ = maxZ;";
            
            colorScale += colorMap.map{"\($0.rgbHex)"}.joined(separator: ",")
        }
        colorScale += "]";
        
        let type = (style[0] == .map ? "colormap" : "scatter");
        
        var styleDetection = "switch (i/2) {";
        var graphSetup = "[";
        for i in 0..<yInputBuffers.count {
            graphSetup += ("{" +
            "type: \"\(type)\"," +
                "showLine: \(style[i] == .dots || style[i] == .map ? "false" : "true")," +
                    "fill: \(style[i] == .vbars || style[i] == .hbars ? "\"origin\"" : "false")," +
                    "pointRadius: \(style[i] == .dots ? 2.0*lineWidth[i] : 0)*scaleFactor," +
                        "pointHitRadius: \(4.0*lineWidth[i])*scaleFactor," +
                            "pointHoverRadius: \(4.0*lineWidth[i])*scaleFactor," +
                                "lineTension: 0," +
                                "borderCapStyle: \"butt\"," +
                                "borderJoinStyle: \"round\"," +
                                "spanGaps: false," +
                                "borderColor: adjustableColor(\"#\(color[i].hexStringValue!)\")," +
                                "backgroundColor: adjustableColor(\"#\(color[i].hexStringValue!)\")," +
                                "borderWidth: \(style[i] == .vbars || style[i] == .hbars ? 0.0 : lineWidth[i])*scaleFactor," +
                                "xAxisID: \"xaxis\"," +
                                "yAxisID: \"yaxis\"" +
            "},")
            
            styleDetection += "case \(i): type = \"\(style[i])\"; lineWidth = \(lineWidth[i])*scaleFactor; break;"
        }
        if zInputBuffers.count > 0 && zInputBuffers[0] != nil {
            graphSetup += ("{" +
                "type: \"\(type)\"," +
                "showLine: false," +
                "fill: false," +
                "pointRadius: 0," +
                "pointHitRadius: \(4.0*lineWidth[0])*scaleFactor," +
                "pointHoverRadius: \(4.0*lineWidth[0])*scaleFactor," +
                "lineTension: 0," +
                "borderCapStyle: \"butt\"," +
                "borderJoinStyle: \"round\"," +
                "spanGaps: false," +
                "borderColor: adjustableColor(\"#\(color[0].hexStringValue!)\")," +
                "backgroundColor: adjustableColor(\"#\(color[0].hexStringValue!)\")," +
                "borderWidth: \(lineWidth[0])*scaleFactor," +
                "xAxisID: \"xaxis\"," +
                "yAxisID: \"yaxis\"" +
                "},")
            
            styleDetection += "case 1: type = \"\(GraphStyle.mapZ)\"; lineWidth = 1.0*scaleFactor; break;"
        }
        styleDetection += "}"
        graphSetup += "],"
        
        let gridColor = UIColor(white: 0.6, alpha: 1.0).hexStringValue!
        
        return "function () {" +
            "if (elementData[\(id)][\"datasets\"].length < 1)" +
            "   return;" +
            "var changed = false;" +
            "for (var i = 0; i < elementData[\(id)][\"datasets\"].length; i++) {" +
            "   if (elementData[\(id)][\"datasets\"][i][\"changed\"])" +
            "       changed = true;" +
            "}" +
            "if (!changed)" +
            "   return;" +
            "var d = [];" +
            "var minX = Number.POSITIVE_INFINITY; " +
            "var maxX = Number.NEGATIVE_INFINITY; " +
            "var minY = Number.POSITIVE_INFINITY; " +
            "var maxY = Number.NEGATIVE_INFINITY; " +
            "var minZ = Number.POSITIVE_INFINITY; " +
            "var maxZ = Number.NEGATIVE_INFINITY; " +
            "for (var i = 0; i < elementData[\(id)][\"datasets\"].length; i+=2) {" +
            "   d[i/2] = [];" +
            "   var xIndexed = ((i+1 >= elementData[\(id)][\"datasets\"].length) || elementData[\(id)][\"datasets\"][i+1][\"data\"].length == 0);" +
            "   var type;" +
            "   var lineWidth;" +
                styleDetection +
            "   if (type == \"\(GraphStyle.mapZ)\" || (type == \"\(GraphStyle.map)\" && elementData[\(id)][\"datasets\"].length < i+2)) {" +
            "       continue;" +
            "   }" +
            "   var lastX = false;" +
            "   var lastY = false;" +
            "   var nElements = elementData[\(id)][\"datasets\"][i][\"data\"].length;" +
            "   if (!xIndexed)" +
            "       nElements = Math.min(nElements, elementData[\(id)][\"datasets\"][i+1][\"data\"].length);" +
            "   if (type == \"\(GraphStyle.map)\")" +
            "       nElements = Math.min(nElements, elementData[\(id)][\"datasets\"][i+2][\"data\"].length);" +
            "   for (j = 0; j < nElements; j++) {" +
            "       var x = xIndexed ? j : elementData[\(id)][\"datasets\"][i+1][\"data\"][j];" +
            "       var y = elementData[\(id)][\"datasets\"][i][\"data\"][j];" +
            "       if (x < minX)" +
            "           minX = x;" +
            "       if (x > maxX)" +
            "           maxX = x;" +
            "       if (y < minY)" +
            "           minY = y;" +
            "       if (y > maxY)" +
            "           maxY = y;" +
            "       if (type == \"\(GraphStyle.vbars)\") {" +
            "           if (lastX !== false && lastY !== false) {" +
            "               var offset = (x-lastX)*(1.0-lineWidth)/2.;" +
            "               d[i/2][j*3+0] = {x: lastX+offset, y: lastY};" +
            "               d[i/2][j*3+1] = {x: x-offset, y: lastY};" +
            "               d[i/2][j*3+2] = {x: NaN, y: NaN};" +
            "           }" +
            "       } else if (type == \"\(GraphStyle.hbars)\") {" +
            "           if (lastX !== false && lastY !== false) {" +
            "               var offset = (y-lastX)*(1.0-lineWidth)/2.;" +
            "               d[i/2][j*3+0] = {x: lastX, y: lastY+offset};" +
            "               d[i/2][j*3+1] = {x: lastX, y: y-offset};" +
            "               d[i/2][j*3+2] = {x: NaN, y: NaN};" +
            "           }" +
            "       } else if (type == \"\(GraphStyle.map)\") {" +
            "           var z = elementData[\(id)][\"datasets\"][i+2][\"data\"][j];" +
            "           if (z < minZ)" +
            "               minZ = z;" +
            "           if (z > maxZ)" +
            "               maxZ = z;" +
            "           d[i/2][j] = {x: x, y: y, z: z};" +
            "       } else {" +
            "           d[i/2][j] = {x: x, y: y};" +
            "       }" +
            "       lastX = x;" +
            "       lastY = y;" +
            "   }" +
            
            "}" +
            "if (minX > maxX) {" +
            "   minX = 0;" +
            "   maxX = 1;" +
            "}" +
            "if (minY > maxY) {" +
            "   minY = 0;" +
            "   maxY = 1;" +
            "}" +
            "if (minZ > maxZ) {" +
            "   minZ = 0;" +
            "   maxZ = 1;" +
            "}" +
            
            "if (!elementData[\(id)][\"graph\"]) {" +
            "   var ctx = document.getElementById(\"element\(id)\").getElementsByClassName(\"graph\")[0].getElementsByTagName(\"canvas\")[0];" +
            "   elementData[\(id)][\"graph\"] = new Chart(ctx, {" +
            "   type: \"" + type + "\"," +
            "   mapwidth: \(mapWidth)," +
            "   colorscale: \(colorScale)," +
            "   data: {datasets: " +
                    graphSetup +
            "   }," +
            "   options: {" +
            "      responsive: true, " +
            "       maintainAspectRatio: false, " +
            "       animation: false," +
            "       legend: false," +
            "       tooltips: {" +
            "           titleFontSize: 15*scaleFactor," +
            "           bodyFontSize: 15*scaleFactor," +
            "           mode: \"nearest\"," +
            "           intersect: \(style[0] == GraphStyle.map ? "false" : "true")," +
            "           callbacks: {" +
            "               title: function() {}," +
            "               label: function(tooltipItem, data) {" +
            "                   var lines = [];" +
            "                   lines.push(data.datasets[tooltipItem.datasetIndex].data[tooltipItem.index].x + \"\(localizedXUnit)\");" +
            "                   lines.push(data.datasets[tooltipItem.datasetIndex].data[tooltipItem.index].y + \"\(localizedYUnit)\");" +
                                (style[0] == GraphStyle.map ? "lines.push(data.datasets[tooltipItem.datasetIndex].data[tooltipItem.index].z + \"\(localizedZUnit)\");" : "") +
            "                   return lines;" +
            "               }" +
            "           }" +
            "       }," +
                "   hover: {" +
                "       mode: \"nearest\"," +
                "       intersect: \(style[0] == GraphStyle.map ? "false" : "true")," +
                "   }, " +
                "   scales: {" +
                "       xAxes: [{" +
                "           id: \"xaxis\"," +
                "           type: \"\(logX && !(style[0] == GraphStyle.map) ? "logarithmic" : "linear")\"," +
                "           position: \"bottom\"," +
                "           gridLines: {" +
                "               color: adjustableColor(\"#\(gridColor)\")," +
                "               zeroLineColor: adjustableColor(\"#\(gridColor)\")," +
                "               tickMarkLength: 0," +
                "           }," +
                "           scaleLabel: {" +
                "               display: true," +
                "               labelString: \"\(localizedXLabelWithUnit)\"," +
                "               fontColor: adjustableColor(\"#ffffff\")," +
                "               fontSize: 15*scaleFactor," +
                "               padding: 0, " +
                "           }," +
                "           ticks: {" +
                "               fontColor: adjustableColor(\"#ffffff\")," +
                "               fontSize: 15*scaleFactor," +
                "               padding: 3*scaleFactor, " +
                "               autoSkip: true," +
                "               maxTicksLimit: 10," +
                "               maxRotation: 0," +
                                scaleX +
                "           }," +
                "           afterBuildTicks: filterEdgeTicks" +
                "       }]," +
                "       yAxes: [{" +
                "           id: \"yaxis\"," +
                "           type: \"\(logX && !(style[0] == GraphStyle.map) ? "logarithmic" : "linear")\"," +
                "           position: \"bottom\"," +
                "           gridLines: {" +
                "               color: adjustableColor(\"#"+gridColor+"\")," +
                "               zeroLineColor: adjustableColor(\"#"+gridColor+"\")," +
                "               tickMarkLength: 0," +
                "           }," +
                "           scaleLabel: {" +
                "               display: true," +
                "               labelString: \"\(localizedYLabelWithUnit)\"," +
                "               fontColor: adjustableColor(\"#ffffff\")," +
                "               fontSize: 15*scaleFactor," +
                "               padding: 3*scaleFactor, " +
                "           }," +
                "           ticks: {" +
                "               fontColor: adjustableColor(\"#ffffff\")," +
                "               fontSize: 15*scaleFactor," +
                "               padding: 3*scaleFactor, " +
                "               autoSkip: true," +
                "               maxTicksLimit: 7," +
                                scaleY +
                "           }," +
                "           afterBuildTicks: filterEdgeTicks" +
                "       }]," +
                "   }" +
                "}" +
            "});" +
            "}" +
            "for (var i = 0; i < elementData[\(id)][\"datasets\"].length; i+=2) {" +
            "   elementData[\(id)][\"graph\"].data.datasets[i/2].data = d[i/2];" +
            "}" +
            scaleZ +
            rescale +
            "elementData[\(id)][\"graph\"].update();" +
        "}";
    }
    
    func setDataHTMLWithID(_ id: Int) -> String {
        var code = "function (data) {"
        code +=    "     elementData[\(id)][\"datasets\"] = [];"
        var inputs: [DataBuffer?] = []
        if (style[0] == .map) {
            inputs = [yInputBuffers[0], xInputBuffers[0], zInputBuffers[0], nil]
        } else {
            for i in 0..<yInputBuffers.count {
                inputs.append(yInputBuffers[i])
                inputs.append(xInputBuffers[i])
            }
        }
        for (i, input) in inputs.enumerated() {
            if let input = input {
                let bufferName = input.name.replacingOccurrences(of: "\"", with: "\\\"")
                code += "if (!data.hasOwnProperty(\"\(bufferName)\"))"
                code += "    return;"
                code += "elementData[\(id)][\"datasets\"][\(i)] = data[\"\(bufferName)\"];"
            }
        }
        code += "}"
        
        return code
    }
    
}
