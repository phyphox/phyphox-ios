//
//  Units.swift
//  phyphox
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import Foundation

//The known units of the phyphox file format (phyphox-docs spec/units.yml, docs/file-format/units.md) and the
//conversion rules the apps and the web interface share. A unit attribute written as "@<id>" (file format 1.21) or
//the deprecated "[[unit_short_<id>]]" refers to one of these; its symbol is the string common_unit_short_<id>.
//Units of one quantity convert through the quantity's base unit: base = v * scale + offset.
//This is the only copy on iOS; Android (Units.java) and the web interface (index.html, PhyphoxUnits) carry the same table.
enum Units {
    enum System {
        case metric, imperial, common
    }

    //The "Unit system" setting: units as the experiment names them, or every unit of the other system replaced
    //by its declared counterpart
    enum Setting: String {
        case experiment, metric, imperial

        static let key = "unitSystem"

        static func from(_ s: String?) -> Setting {
            return s.flatMap { Setting(rawValue: $0) } ?? .experiment
        }
    }

    struct Definition {
        let id: String
        let symbol: String //English, the string table translates it
        let quantity: String? //nil: known but not convertible (dB, %, arb. unit)
        let scale: Double
        let offset: Double
        let system: System
        let counterpart: String? //the unit the setting switches to, nil: stays
    }

    private static func def(_ id: String, _ symbol: String, _ quantity: String?, _ scale: Double, _ offset: Double, _ system: System, _ counterpart: String? = nil) -> Definition {
        return Definition(id: id, symbol: symbol, quantity: quantity, scale: scale, offset: offset, system: system, counterpart: counterpart)
    }

    static let all: [Definition] = [
        def("nano_meter", "nm", "length", 1e-9, 0, .metric),
        def("micro_meter", "µm", "length", 1e-6, 0, .metric),
        def("milli_meter", "mm", "length", 1e-3, 0, .metric, "inch"),
        def("centi_meter", "cm", "length", 1e-2, 0, .metric, "inch"),
        def("meter", "m", "length", 1, 0, .metric, "foot"),
        def("kilo_meter", "km", "length", 1000, 0, .metric, "mile"),
        def("inch", "in", "length", 0.0254, 0, .imperial, "centi_meter"),
        def("foot", "ft", "length", 0.3048, 0, .imperial, "meter"),
        def("yard", "yd", "length", 0.9144, 0, .imperial, "meter"),
        def("mile", "mi", "length", 1609.344, 0, .imperial, "kilo_meter"),
        def("micro_second", "µs", "time", 1e-6, 0, .common),
        def("milli_second", "ms", "time", 1e-3, 0, .common),
        def("second", "s", "time", 1, 0, .common),
        def("minute", "min", "time", 60, 0, .common),
        def("hour", "h", "time", 3600, 0, .common),
        def("hertz", "Hz", "frequency", 1, 0, .common),
        def("kilo_hertz", "kHz", "frequency", 1000, 0, .common),
        def("per_minute", "1/min", "frequency", 1.0 / 60.0, 0, .common),
        def("meter_per_second", "m/s", "speed", 1, 0, .metric, "foot_per_second"),
        def("kilo_meter_per_hour", "km/h", "speed", 1.0 / 3.6, 0, .metric, "mile_per_hour"),
        def("foot_per_second", "ft/s", "speed", 0.3048, 0, .imperial, "meter_per_second"),
        def("mile_per_hour", "mph", "speed", 0.44704, 0, .imperial, "kilo_meter_per_hour"),
        def("meter_per_square_second", "m/s²", "acceleration", 1, 0, .metric, "foot_per_square_second"),
        def("foot_per_square_second", "ft/s²", "acceleration", 0.3048, 0, .imperial, "meter_per_square_second"),
        def("standard_gravity", "g", "acceleration", 9.80665, 0, .common),
        def("radian_per_second", "rad/s", "angular_velocity", 1, 0, .common),
        def("degree_per_second", "°/s", "angular_velocity", Double.pi / 180.0, 0, .common),
        def("revolution_per_minute", "rpm", "angular_velocity", 2.0 * Double.pi / 60.0, 0, .common),
        def("degree", "°", "angle", Double.pi / 180.0, 0, .common),
        def("radian", "rad", "angle", 1, 0, .common),
        def("micro_tesla", "µT", "magnetic_flux_density", 1e-6, 0, .common),
        def("milli_tesla", "mT", "magnetic_flux_density", 1e-3, 0, .common),
        def("tesla", "T", "magnetic_flux_density", 1, 0, .common),
        def("gauss", "G", "magnetic_flux_density", 1e-4, 0, .common),
        def("lux", "lx", "illuminance", 1, 0, .metric, "foot_candle"),
        def("foot_candle", "fc", "illuminance", 10.7639, 0, .imperial, "lux"),
        def("pascal", "Pa", "pressure", 1, 0, .metric),
        def("hecto_pascal", "hPa", "pressure", 100, 0, .metric, "inch_of_mercury"),
        def("kilo_pascal", "kPa", "pressure", 1000, 0, .metric, "psi"),
        def("milli_bar", "mbar", "pressure", 100, 0, .metric, "inch_of_mercury"),
        def("bar", "bar", "pressure", 100000, 0, .metric),
        def("inch_of_mercury", "inHg", "pressure", 3386.389, 0, .imperial, "hecto_pascal"),
        def("psi", "psi", "pressure", 6894.757, 0, .imperial, "kilo_pascal"),
        def("degree_celsius", "°C", "temperature", 1, 273.15, .metric, "degree_fahrenheit"),
        def("kelvin", "K", "temperature", 1, 0, .common),
        def("degree_fahrenheit", "°F", "temperature", 5.0 / 9.0, 255.37222222222223, .imperial, "degree_celsius"),
        def("decibel", "dB", nil, 1, 0, .common),
        def("percent", "%", nil, 1, 0, .common),
        def("arbitrary_unit", "arb. unit", nil, 1, 0, .common)
    ]

    private static let table: [String: Definition] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func definition(_ id: String?) -> Definition? {
        return id.flatMap { table[$0] }
    }

    static func isKnown(_ id: String?) -> Bool {
        return definition(id) != nil
    }

    //A unit with a quantity can be shown in every other unit of that quantity
    static func isConvertible(_ id: String?) -> Bool {
        return definition(id)?.quantity != nil
    }

    static func sameQuantity(_ a: String?, _ b: String?) -> Bool {
        guard let qa = definition(a)?.quantity, let qb = definition(b)?.quantity else { return false }
        return qa == qb
    }

    //Every unit of the tapped unit's quantity, in table order; empty for a unit without one
    static func alternatives(_ id: String?) -> [Definition] {
        guard let quantity = definition(id)?.quantity else { return [] }
        return all.filter { $0.quantity == quantity }
    }

    //The unit shown under a setting: metric replaces imperial units, imperial replaces metric units that have a
    //counterpart; everything else stays
    static func forSetting(_ id: String, _ setting: Setting) -> String {
        guard let d = definition(id), d.quantity != nil, let counterpart = d.counterpart else { return id }
        switch (setting, d.system) {
        case (.metric, .imperial), (.imperial, .metric): return counterpart
        default: return id
        }
    }

    //Display factor from one unit to another of the same quantity (m -> cm: 100); 1 where no conversion applies
    static func scale(from: String, to: String) -> Double {
        guard let df = definition(from), let dt = definition(to), from != to, sameQuantity(from, to) else { return 1 }
        return df.scale / dt.scale
    }

    //A position (value, range end, tick, picked point): scale and offset
    static func convert(_ v: Double, from: String, to: String) -> Double {
        guard let df = definition(from), let dt = definition(to), from != to, sameQuantity(from, to) else { return v }
        return (v * df.scale + df.offset - dt.offset) / dt.scale
    }

    //A difference (Δ read-out, slope, window width): scale only
    static func convertDifference(_ v: Double, from: String, to: String) -> Double {
        return v * scale(from: from, to: to)
    }

    //Decimals after a conversion by display factor f: never coarser than the author's resolution
    static func precision(_ p: Int, factor f: Double) -> Int {
        guard p >= 0, f > 0 else { return p }
        return max(0, p - Int(floor(log10(f))))
    }

    //The (translated) symbol of a known unit from the string table, the English symbol if the string is missing
    static func symbol(_ id: String) -> String {
        guard let d = definition(id) else { return id }
        let key = "common_unit_short_" + id
        let localized = localize(key)
        return localized == key ? d.symbol : localized
    }

    //The group title of the unit dialog and the web interface's placeholders share these strings
    static func systemTitle(_ system: System) -> String {
        switch system {
        case .metric: return localize("settingsUnitSystemMetric")
        case .imperial: return localize("settingsUnitSystemImperial")
        case .common: return localize("unit_dialog_other")
        }
    }
}

//A parsed unit attribute: a reference to a known unit (id, convertible, shown with the app's symbol) or text shown as
//written (docs/file-format/units.md)
struct Unit: Equatable {
    let id: String? //known unit, or nil
    let text: String //custom text, "" for a reference or an absent attribute

    static func reference(_ id: String) -> Unit {
        return Unit(id: id, text: "")
    }

    static func text(_ text: String) -> Unit {
        return Unit(id: nil, text: text)
    }

    static let empty = Unit(id: nil, text: "")

    var isReference: Bool {
        return id != nil
    }

    var isEmpty: Bool {
        return id == nil && text.isEmpty
    }

    var isConvertible: Bool {
        return Units.isConvertible(id)
    }

    //The symbol of the experiment's unit
    var symbol: String {
        if let id = id {
            return Units.symbol(id)
        }
        return text
    }

    //A unit attribute (units.md, rules.yml "unit-reference"): "@<id>" with a known id is a unit reference from file
    //format 1.21 on, the deprecated "[[unit_short_<id>]]" resolves to the same logical unit in every version, and
    //anything else (custom text, an unknown id, a reference in an older file) is text shown as written, translated like
    //any other string
    static func parse(_ raw: String, version: SemanticVersion, translation: ExperimentTranslationCollection?) -> Unit {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if version >= SemanticVersion(major: 1, minor: 21, patch: 0) && s.hasPrefix("@") && Units.isKnown(String(s.dropFirst())) {
            return .reference(String(s.dropFirst()))
        }
        if s.hasPrefix("[[unit_short_") && s.hasSuffix("]]") {
            let id = String(s.dropFirst(13).dropLast(2))
            if Units.isKnown(id) {
                return .reference(id)
            }
        }
        return .text(translation?.localizeString(raw) ?? raw)
    }

    //The web interface receives the unit logically (webinterface readme.md, "Value and edit elements")
    var webJSON: WebJSON.Object {
        return [("id", id), ("text", id == nil ? text : nil)]
    }
}

//Between the experiment's unit and the unit currently shown, both of one quantity
struct UnitConversion {
    let from: String
    let to: String

    var scale: Double {
        return Units.scale(from: from, to: to)
    }

    func toDisplay(_ v: Double) -> Double {
        return Units.convert(v, from: from, to: to)
    }

    func fromDisplay(_ v: Double) -> Double {
        return Units.convert(v, from: to, to: from)
    }
}
