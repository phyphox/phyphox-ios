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
    let hideTimeMarkers: Bool
    
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
    
    let xPrecision: Int
    let yPrecision: Int
    let zPrecision: Int
    
    let suppressScientificNotation: Bool
    
    enum ScaleMode: String, CaseInsensitiveAttributeDecodable, CaseIterable {
        case auto, extend, fixed
    }
    
    enum GraphStyle: String, CaseInsensitiveAttributeDecodable, CaseIterable {
        case lines
        case dots
        case hbars
        case vbars
        case map
        case mapZ //Accepted for compatibility with old files; the map style's z buffer is a separate input, not a style
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
    
    let followX: Bool
    
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
    let customColorMap: Bool //Whether the experiment set its own mapColor stops or colorMap is the default scale
    let showColorScale: Bool
    let interpolateMapColors: Bool
    
    //Data picker slots of six (x, xcal, y, ycal, z, zcal), repeating per further pick on the axis; a cal slot prompts
    //the user for a value assigned to the preceding plain slot's pick
    struct PickOutput: Equatable {
        let label: String
        let buffer: DataBuffer
    }
    let pickLabel: String
    let pickOutputs: [PickOutput?]

    ///The plot rectangle as fractions of the element's box (file format 1.21, graph.md "Fixing the plot area")
    struct PlotArea: Equatable {
        let left: CGFloat
        let top: CGFloat
        let right: CGFloat
        let bottom: CGFloat
    }

    //The attributes as given (the remote interface receives them one by one); any one of them fixes the layout
    let plotLeft: CGFloat?
    let plotTop: CGFloat?
    let plotRight: CGFloat?
    let plotBottom: CGFloat?

    var plotArea: PlotArea? {
        guard plotLeft != nil || plotTop != nil || plotRight != nil || plotBottom != nil else { return nil }
        return PlotArea(left: plotLeft ?? 0, top: plotTop ?? 0, right: plotRight ?? 1, bottom: plotBottom ?? 1)
    }

    var localizedPickLabel: String? {
        guard !pickLabel.isEmpty else { return nil }
        return translation?.localizeString(pickLabel) ?? pickLabel
    }

    let label: String
    let translation: ExperimentTranslationCollection?
    var visibilityBuffer: DataBuffer?

    init(label: String, visibilityBuffer: DataBuffer?, translation: ExperimentTranslationCollection?, xLabel: String, yLabel: String, zLabel: String?, xUnit: String?, yUnit: String?, zUnit: String?, yxUnit: String?, timeReference: ExperimentTimeReference, timeOnX: Bool, timeOnY: Bool, systemTime: Bool, linearTime: Bool, hideTimeMarkers: Bool, xInputBuffers: [DataBuffer?], yInputBuffers: [DataBuffer], zInputBuffers: [DataBuffer?], logX: Bool, logY: Bool, logZ: Bool, xPrecision: Int, yPrecision: Int, zPrecision: Int, suppressScientificNotation: Bool, scaleMinX: ScaleMode, scaleMaxX: ScaleMode, scaleMinY: ScaleMode, scaleMaxY: ScaleMode, scaleMinZ: ScaleMode, scaleMaxZ: ScaleMode, minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat, minZ: CGFloat, maxZ: CGFloat, followX: Bool, aspectRatio: CGFloat, partialUpdate: Bool, history: UInt, style: [GraphViewDescriptor.GraphStyle], lineWidth: [CGFloat], color: [UIColor], mapWidth: UInt, colorMap: [UIColor], showColorScale: Bool, interpolateMapColors: Bool, pickLabel: String, pickOutputs: [PickOutput?], plotLeft: CGFloat? = nil, plotTop: CGFloat? = nil, plotRight: CGFloat? = nil, plotBottom: CGFloat? = nil) {
        self.plotLeft = plotLeft
        self.plotTop = plotTop
        self.plotRight = plotRight
        self.plotBottom = plotBottom
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
        self.hideTimeMarkers = hideTimeMarkers
        
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
        
        self.suppressScientificNotation = suppressScientificNotation
        
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
        
        self.followX = followX
        
        self.xInputBuffers = xInputBuffers
        self.yInputBuffers = yInputBuffers
        self.zInputBuffers = zInputBuffers
        
        self.aspectRatio = aspectRatio
        self.partialUpdate = partialUpdate
        self.history = history
        
        self.style = style
        self.lineWidth = lineWidth //width of the curve
        self.color = color

        self.mapWidth = mapWidth
        self.customColorMap = colorMap.count > 1
        if customColorMap {
            self.colorMap = colorMap
        } else {
            self.colorMap = [UIColor(white: 0.0, alpha: 1.0), kHighlightColor, UIColor(white: 1.0, alpha: 1.0)]
        }
        self.showColorScale = showColorScale
        self.interpolateMapColors = interpolateMapColors
        
        self.label = label
        self.visibilityBuffer = visibilityBuffer
        self.translation = translation
        
        self.pickLabel = pickLabel
        self.pickOutputs = pickOutputs
    }
    
    //The remote interface builds a graph from the configuration object below (phyphox-webinterface readme.md, "The graph
    //configuration"), so there is no markup and no JavaScript to generate here
    func generateViewHTMLWithID(_ id: Int) -> String {
        return ""
    }

    //The buffers the remote interface polls for this graph: (y, x) pairs with nil for a missing x; a color map is y, x, z, nil
    var webDataInputs: [DataBuffer?] {
        if style[0] == .map {
            return [yInputBuffers[0], xInputBuffers.first ?? nil, zInputBuffers.first ?? nil, nil]
        }
        return (0..<yInputBuffers.count).flatMap { [yInputBuffers[$0], $0 < xInputBuffers.count ? xInputBuffers[$0] : nil] }
    }

    var webUpdateMode: String {
        guard partialUpdate else { return "full" }
        return style[0] == .map ? "partialXYZ" : "partial"
    }

    //The "graph" object of the view layout, key for key like Android's GraphElement.getWebGraphConfig(): every key present,
    //null for an unset string or number, the experiment's colors as given (the interface adapts them to its bright mode)
    func webGraphConfig() -> String {
        func number(_ value: CGFloat) -> Double? { return value.isFinite ? Double(value) : nil }
        func text(_ value: String) -> String? { return value.isEmpty ? nil : value }
        func hex(_ color: UIColor) -> String { return "#" + color.webHexString }

        var datasets: [WebJSON.Object] = []
        for i in 0..<yInputBuffers.count {
            datasets.append([
                ("x", i < xInputBuffers.count ? xInputBuffers[i]?.name : nil),
                ("y", yInputBuffers[i].name),
                ("z", style[i] == .map && i < zInputBuffers.count ? zInputBuffers[i]?.name : nil),
                ("style", style[i] == .mapZ ? GraphStyle.map.rawValue : style[i].rawValue),
                ("lineWidth", Double(lineWidth[i])),
                ("color", hex(color[i]))
            ])
        }

        //Slots of (value, assigned value) cycling through the x, y and z axes, see pickOutputs
        var picks: [WebJSON.Object] = []
        let axes = ["x", "y", "z"]
        for i in stride(from: 0, to: pickOutputs.count, by: 2) {
            guard let output = pickOutputs[i] else { continue }
            let cal = i + 1 < pickOutputs.count ? pickOutputs[i + 1] : nil
            picks.append([
                ("axis", axes[(i / 2) % 3]),
                ("buffer", output.buffer.name),
                ("label", translation?.localizeString(output.label) ?? output.label),
                ("calBuffer", cal?.buffer.name),
                ("calLabel", cal.map { translation?.localizeString($0.label) ?? $0.label })
            ])
        }

        var config: WebJSON.Object = [
            ("aspectRatio", Double(aspectRatio)),
            ("labelX", text(localizedXLabel)),
            ("labelY", text(localizedYLabel)),
            ("labelZ", text(localizedZLabel)),
            ("unitX", text(localizedXUnit)),
            ("unitY", text(localizedYUnit)),
            ("unitZ", text(localizedZUnit)),
            ("unitYX", yxUnit.map { translation?.localizeString($0) ?? $0 }),
            ("logX", logX),
            ("logY", logY),
            ("logZ", logZ),
            ("xPrecision", xPrecision),
            ("yPrecision", yPrecision),
            ("zPrecision", zPrecision),
            ("suppressScientificNotation", suppressScientificNotation),
            ("timeOnX", timeOnX),
            ("timeOnY", timeOnY),
            ("systemTime", systemTime),
            ("linearTime", linearTime),
            ("scaleMinX", scaleMinX.rawValue),
            ("scaleMaxX", scaleMaxX.rawValue),
            ("scaleMinY", scaleMinY.rawValue),
            ("scaleMaxY", scaleMaxY.rawValue),
            ("scaleMinZ", scaleMinZ.rawValue),
            ("scaleMaxZ", scaleMaxZ.rawValue),
            ("minX", number(minX)),
            ("maxX", number(maxX)),
            ("minY", number(minY)),
            ("maxY", number(maxY)),
            ("minZ", number(minZ)),
            ("maxZ", number(maxZ)),
            ("followX", followX),
            ("partialUpdate", partialUpdate),
            ("mapWidth", Int(mapWidth)),
            ("plotLeft", plotLeft.flatMap(number)),
            ("plotTop", plotTop.flatMap(number)),
            ("plotRight", plotRight.flatMap(number)),
            ("plotBottom", plotBottom.flatMap(number)),
            ("showColorScale", showColorScale),
            ("interpolateMapColors", interpolateMapColors)
        ]
        if customColorMap {
            config.append(("colorScale", colorMap.map(hex)))
        }
        config.append(("datasets", datasets))
        config.append(("pickLabel", localizedPickLabel))
        config.append(("pickOutputs", picks))
        return WebJSON.encode(config)
    }
}
