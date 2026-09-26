//
//  ColorAlphaTests.swift
//  phyphoxTests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
@testable import phyphox

// phyphox-test: colors-alpha
//Colours with an alpha byte (file format 1.21, phyphox-docs colors.md): eight hex digits RRGGBBAA are read on every
//colour attribute, six digits stay opaque, the light-mode adjustment keeps the alpha, and the remote interface receives
//#rrggbbaa where the alpha is not ff. Mirrors the colors-alpha part of Android's ViewGroupsTest.
final class ColorAlphaTests: XCTestCase {
    private var savedAppMode: String?

    override func setUpWithError() throws {
        savedAppMode = UserDefaults.standard.string(forKey: SettingBundleHelper.UserDefaultKeys.APP_MODE.rawValue)
    }

    override func tearDownWithError() throws {
        UserDefaults.standard.set(savedAppMode, forKey: SettingBundleHelper.UserDefaultKeys.APP_MODE.rawValue)
    }

    private func components(_ color: UIColor) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    func testEightDigitColorsCarryTheirAlpha() throws {
        let alpha = components(try XCTUnwrap(mapColorString("ff7e2280")))
        XCTAssertEqual(alpha.r, 1, accuracy: 1e-6)
        XCTAssertEqual(alpha.g, 0x7e / 255.0, accuracy: 1e-6)
        XCTAssertEqual(alpha.b, 0x22 / 255.0, accuracy: 1e-6)
        XCTAssertEqual(alpha.a, 0x80 / 255.0, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(mapColorString("ff7e2280")).webHexString, "FF7E2280")

        let hashed = components(try XCTUnwrap(mapColorString("#FF7E22")))
        XCTAssertEqual(hashed.a, 1, "six digits stay opaque")
        XCTAssertEqual(try XCTUnwrap(mapColorString("#FF7E22")).webHexString, "FF7E22")
        XCTAssertEqual(components(try XCTUnwrap(mapColorString("#ff7e22ff"))).a, 1)
        XCTAssertEqual(try XCTUnwrap(mapColorString("#ff7e22ff")).webHexString, "FF7E22", "an opaque alpha byte is not emitted")
        XCTAssertEqual(components(try XCTUnwrap(mapColorString("00000000"))).a, 0)
        XCTAssertEqual(try XCTUnwrap(mapColorString("orange")).webHexString, "FF7E22")

        //neither seven nor nine digits, nor other characters (color-invalid-value)
        XCTAssertNil(mapColorString("ff7e228"))
        XCTAssertNil(mapColorString("ff7e22800"))
        XCTAssertNil(mapColorString("ff7e22gg"))
        XCTAssertNil(mapColorString("#"))
    }

    func testTheLightModeAdjustmentKeepsTheAlpha() throws {
        let color = try XCTUnwrap(mapColorString("edf66880"))
        let adjusted = ColorConverterHelper().adjustColorForLightTheme(colorName: color)
        XCTAssertEqual(components(adjusted).a, 0x80 / 255.0, accuracy: 1e-6)
        XCTAssertNotEqual(components(adjusted).r, components(color).r, "the colour itself is adjusted for the light background")
        XCTAssertEqual(components(ColorConverterHelper().adjustColorForLightTheme(colorName: try XCTUnwrap(mapColorString("edf668")))).a, 1)
    }

    func testTheAlphaReachesTheViewsAndTheRemoteInterface() throws {
        let xml = """
        <phyphox version="1.21">
            <title>t</title><category>c</category><description>d</description>
            <data-containers><container size="10">t</container><container size="10">x</container><container size="100">z</container></data-containers>
            <views><view label="v">
                <graph label="g" color="#2bfb4cc0" mapWidth="10" style="map" mapColor1="0000ff00" mapColor2="ff0000c0" mapColor3="ffffff">
                    <input axis="x">t</input><input axis="y">x</input><input axis="z">z</input>
                </graph>
                <graph label="h" color="2bfb4c"><input axis="x">t</input><input axis="y" color="edf66840">x</input></graph>
                <separator height="1" color="39a2ff40" />
                <value label="val" color="ff7e2280"><input>x</input></value>
                <info label="txt" color="ffffff80" />
            </view></views>
        </phyphox>
        """
        let experiment = try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: InputStream(data: Data(xml.utf8)))
        let views = try XCTUnwrap(experiment.viewDescriptors?.first?.views)
        let map = try XCTUnwrap(views[0] as? GraphViewDescriptor)
        let lines = try XCTUnwrap(views[1] as? GraphViewDescriptor)
        let separator = try XCTUnwrap(views[2] as? SeparatorViewDescriptor)
        let value = try XCTUnwrap(views[3] as? ValueViewDescriptor)
        let info = try XCTUnwrap(views[4] as? InfoViewDescriptor)

        XCTAssertEqual(components(map.color[0]).a, 0xc0 / 255.0, accuracy: 1e-6)
        XCTAssertEqual(map.colorMap.map { $0.webHexString }, ["0000FF00", "FF0000C0", "FFFFFF"])
        XCTAssertEqual(components(lines.color[0]).a, 0x40 / 255.0, accuracy: 1e-6, "the colour of the input tag")
        XCTAssertEqual(components(separator.color).a, 0x40 / 255.0, accuracy: 1e-6)
        XCTAssertEqual(components(value.color).a, 0x80 / 255.0, accuracy: 1e-6)

        //the markup and the graph configuration carry #rrggbbaa (phyphox-webinterface readme.md)
        XCTAssertTrue(separator.generateViewHTMLWithID(0).contains("background: #39A2FF40"))
        XCTAssertTrue(value.generateViewHTMLWithID(1).contains("color:#FF7E2280"))
        XCTAssertTrue(info.generateViewHTMLWithID(2).contains("color:#FFFFFF80"))
        let mapConfig = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(map.webGraphConfig().utf8)) as? [String: Any])
        XCTAssertEqual(mapConfig["colorScale"] as? [String], ["#0000FF00", "#FF0000C0", "#FFFFFF"])
        let linesConfig = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(lines.webGraphConfig().utf8)) as? [String: Any])
        XCTAssertEqual((linesConfig["datasets"] as? [[String: Any]])?.first?["color"] as? String, "#EDF66840")

        //the modules keep the alpha in dark mode, where the colour is used as given
        UserDefaults.standard.set(Utility.DARK_MODE, forKey: SettingBundleHelper.UserDefaultKeys.APP_MODE.rawValue)
        let separatorView = try XCTUnwrap(ExperimentSeparatorView(descriptor: separator, resourceFolder: nil))
        XCTAssertEqual(components(try XCTUnwrap(separatorView.backgroundColor)).a, 0x40 / 255.0, accuracy: 1e-6)
        let graph = try XCTUnwrap(ExperimentGraphView(descriptor: lines, resourceFolder: nil))
        XCTAssertEqual(graph.graphRenderer.plotView.lineColor.first?.a ?? 0, Float(0x40) / 255, accuracy: 1e-6, "the GL line colour blends")
        //and in light mode the adjusted colour still carries it
        UserDefaults.standard.set(Utility.LIGHT_MODE, forKey: SettingBundleHelper.UserDefaultKeys.APP_MODE.rawValue)
        let lightSeparator = try XCTUnwrap(ExperimentSeparatorView(descriptor: separator, resourceFolder: nil))
        XCTAssertEqual(components(try XCTUnwrap(lightSeparator.backgroundColor)).a, 0x40 / 255.0, accuracy: 1e-6)
    }
}
