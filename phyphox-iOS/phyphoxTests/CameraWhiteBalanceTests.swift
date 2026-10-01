//
//  CameraWhiteBalanceTests.swift
//  phyphoxTests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
@testable import phyphox

private struct UnwrapError: Error {}

fileprivate extension Optional {
    func unwrap() throws -> Wrapped {
        guard let value = self else { throw UnwrapError() }
        return value
    }
}

// phyphox-test: camera-white-balance
//The white_balance and white_balance_tint entries of the camera input's locked attribute (file format 1.21, phyphox-docs
//docs/file-format/input.md "White balance") from the corpus fixtures through the real parser into the camera's settings
//state, and the state's behaviour: the value-less lock engages when the measurement is first started and stays, a
//temperature with a tint is held as requested and shown as the value in effect, either form disables the camera-gui
//control; a lock chosen in the GUI engages at once, a temperature out of reach is shown clamped, automatic releases.
//The state is what the camera-gui shows and what CameraService pushes to the device; the gains themselves need a
//camera, which the simulator has not (WhiteBalanceMathTests covers the colour math offscreen).
final class CameraWhiteBalanceTests: XCTestCase {

    private func parse(_ xml: String) throws -> Experiment {
        let stream = InputStream(data: xml.data(using: .utf8)!)
        return try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: stream)
    }

    private func fixture(_ name: String) throws -> Experiment {
        let generated = try DocsCorpus.directory("generated", notTestedNotice: "camera white balance")
        return try ExperimentSerialization.readExperimentFromURL(generated.appendingPathComponent(name))
    }

    private func settings(for experiment: Experiment) throws -> CameraSettingsModel {
        let locked = try (experiment.cameraInput?.locked).unwrap()
        let model = CameraSettingsModel()
        model.applyFileWhiteBalance(locked: locked)
        return model
    }

    private func inline(locked: String) -> String {
        return """
        <phyphox version="1.21">
            <title>t</title>
            <category>c</category>
            <description>d</description>
            <data-containers>
                <container>buffer</container>
            </data-containers>
            <input>
                <camera locked="\(locked)">
                    <output component="luminance">buffer</output>
                </camera>
            </input>
            <views>
                <view label="v">
                    <camera-gui label="p" exposure_adjustment_level="3"/>
                </view>
            </views>
        </phyphox>
        """
    }

    func testValuelessLockFreezesAtTheFirstStartAndDisablesTheControl() throws {
        let model = try settings(for: fixture("camera-white-balance-lock.phyphox"))
        XCTAssertEqual(model.whiteBalanceMode, .locked)
        XCTAssertTrue(model.whiteBalanceLockedByFile, "the camera-gui control is disabled")
        XCTAssertFalse(model.whiteBalanceFrozen, "automatic until the first start")
        XCTAssertEqual(model.whiteBalanceLabel, "Locked")

        XCTAssertTrue(model.freezeWhiteBalanceAtStart(), "the first start engages the lock on the device")
        XCTAssertTrue(model.whiteBalanceFrozen)
        XCTAssertFalse(model.freezeWhiteBalanceAtStart(), "a later start changes nothing")
        XCTAssertTrue(model.whiteBalanceFrozen, "the lock stays for the rest of the experiment")
        XCTAssertEqual(model.whiteBalanceLabel, "Locked")
    }

    func testTemperatureAndTintAreHeldAndShownInEffect() throws {
        let model = try settings(for: fixture("camera-white-balance-temperature.phyphox"))
        XCTAssertEqual(model.whiteBalanceMode, .temperature)
        XCTAssertEqual(model.whiteBalanceTemperature, 3200)
        XCTAssertEqual(model.whiteBalanceTint, -0.004, accuracy: 1e-9)
        XCTAssertEqual(model.whiteBalanceTemperatureInEffect, 3200, "nothing to clamp at 3200 K")
        XCTAssertEqual(model.whiteBalanceTintInEffect, -0.004, accuracy: 1e-9)
        XCTAssertEqual(model.whiteBalanceLabel, "3200 K")
        XCTAssertTrue(model.whiteBalanceLockedByFile, "the camera-gui control is disabled")
        XCTAssertFalse(model.whiteBalanceFrozen, "custom gains need no lock")
        XCTAssertFalse(model.freezeWhiteBalanceAtStart(), "a start does not lock a temperature held by gains")

        //A camera without custom gains falls back to holding the automatic result from the first start
        model.whiteBalanceGainsSupported = false
        XCTAssertTrue(model.whiteBalanceNeedsLock)
        XCTAssertTrue(model.freezeWhiteBalanceAtStart())
        XCTAssertTrue(model.whiteBalanceFrozen)
    }

    func testGuiLockEngagesAtOnceATemperatureIsClampedAndAutomaticReleases() throws {
        let model = try settings(for: fixture("camera-rgb.phyphox"))
        XCTAssertEqual(model.whiteBalanceMode, .auto)
        XCTAssertFalse(model.whiteBalanceLockedByFile)
        XCTAssertEqual(model.whiteBalanceLabel, "Auto")
        XCTAssertFalse(model.freezeWhiteBalanceAtStart(), "nothing to freeze without a lock")

        model.selectWhiteBalanceMode(.locked)
        XCTAssertTrue(model.whiteBalanceFrozen, "a lock chosen in the GUI freezes at once")
        XCTAssertEqual(model.whiteBalanceLabel, "Locked")

        model.selectWhiteBalanceMode(.temperature)
        XCTAssertFalse(model.whiteBalanceFrozen)
        model.selectWhiteBalanceTemperature(1000000)
        XCTAssertEqual(model.whiteBalanceTemperature, 1000000, "the request is kept")
        XCTAssertEqual(model.whiteBalanceTemperatureInEffect, model.whiteBalanceTemperatureRange.upperBound, "clamped to the top of the range")
        XCTAssertEqual(model.whiteBalanceLabel, "\(WhiteBalance.maxTemperature) K", "shown as clamped")
        model.selectWhiteBalanceTint(0.05)
        XCTAssertEqual(model.whiteBalanceTintInEffect, WhiteBalance.maxTint, accuracy: 1e-9, "the tint is clamped as well")
        model.selectWhiteBalanceTint(-1.0)
        XCTAssertEqual(model.whiteBalanceTintInEffect, -WhiteBalance.maxTint, accuracy: 1e-9)

        model.selectWhiteBalanceMode(.auto)
        XCTAssertFalse(model.whiteBalanceFrozen, "automatic releases the lock")
        XCTAssertEqual(model.whiteBalanceLabel, "Auto")
        XCTAssertFalse(model.whiteBalanceLockedByFile, "the control stays enabled")
    }

    func testTheRangeOfTheDeviceClampsTheValueInEffect() {
        let model = CameraSettingsModel()
        model.whiteBalanceTemperatureRange = 2000...8000
        model.selectWhiteBalanceMode(.temperature)
        model.selectWhiteBalanceTemperature(12000)
        XCTAssertEqual(model.whiteBalanceTemperatureInEffect, 8000)
        model.selectWhiteBalanceTemperature(1000)
        XCTAssertEqual(model.whiteBalanceTemperatureInEffect, 2000)
    }

    //The parser's side of the contract: the value-less entry keeps its key, an unreadable value is dropped
    func testUnreadableAndIncompleteEntriesLeaveTheAutomaticWhiteBalance() throws {
        var locked = try (parse(inline(locked: "white_balance")).cameraInput?.locked).unwrap()
        XCTAssertTrue(locked.keys.contains("white_balance"), "the value-less entry is kept as a key")
        XCTAssertNil(locked["white_balance"] ?? nil)
        XCTAssertEqual(WhiteBalance.settings(fromLocked: locked).mode, .locked)

        locked = try (parse(inline(locked: "white_balance=abc")).cameraInput?.locked).unwrap()
        XCTAssertFalse(locked.keys.contains("white_balance"), "an unreadable value is ignored, not taken as a lock")
        var model = CameraSettingsModel()
        model.applyFileWhiteBalance(locked: locked)
        XCTAssertEqual(model.whiteBalanceMode, .auto)
        XCTAssertFalse(model.whiteBalanceLockedByFile, "the camera-gui control stays enabled")

        locked = try (parse(inline(locked: "white_balance_tint=-0.004")).cameraInput?.locked).unwrap()
        model = CameraSettingsModel()
        model.applyFileWhiteBalance(locked: locked)
        XCTAssertEqual(model.whiteBalanceMode, .auto, "a tint without a temperature is ignored")
        XCTAssertEqual(model.whiteBalanceTint, 0.0)
        XCTAssertFalse(model.whiteBalanceLockedByFile)

        locked = try (parse(inline(locked: "White_Balance=5600, white_balance_tint=0.002, iso")).cameraInput?.locked).unwrap()
        XCTAssertEqual(Set(locked.keys), ["white_balance", "white_balance_tint", "iso"], "names fold case, a value-less exposure entry keeps its key")
        model = CameraSettingsModel()
        model.applyFileWhiteBalance(locked: locked)
        XCTAssertEqual(model.whiteBalanceMode, .temperature)
        XCTAssertEqual(model.whiteBalanceTemperature, 5600)
        XCTAssertEqual(model.whiteBalanceTint, 0.002, accuracy: 1e-9)
    }

    //The camera-gui's panel reflects the state: the toggle, the scales only in temperature mode, the values in effect
    func testControlPanelShowsTheState() throws {
        let model = try settings(for: fixture("camera-white-balance-temperature.phyphox"))
        let panel = WhiteBalanceControlView(settings: model)
        XCTAssertEqual(panel.modeControl.numberOfSegments, 3, "automatic, locked, temperature - no presets")
        XCTAssertEqual(panel.modeControl.selectedSegmentIndex, 2)
        XCTAssertFalse(panel.temperatureSlider.isHidden)
        XCTAssertFalse(panel.tintSlider.isHidden)
        XCTAssertEqual(panel.temperatureLabel.text, "3200 K")
        XCTAssertEqual(panel.tintLabel.text, "Tint -0.004")
        XCTAssertEqual(panel.temperatureSlider.value, WhiteBalance.position(ofTemperature: 3200, range: model.whiteBalanceTemperatureRange), accuracy: 1e-6)
        XCTAssertEqual(panel.tintSlider.value, -4.0, accuracy: 1e-6, "thousandths of Duv")

        model.selectWhiteBalanceMode(.locked)
        panel.update()
        XCTAssertEqual(panel.modeControl.selectedSegmentIndex, 1)
        XCTAssertTrue(panel.temperatureSlider.isHidden, "the scales only in temperature mode")
        XCTAssertTrue(panel.tintSlider.isHidden)

        model.selectWhiteBalanceMode(.auto)
        panel.update()
        XCTAssertEqual(panel.modeControl.selectedSegmentIndex, 0)

        //Both layouts place every control inside the panel
        panel.frame = CGRect(x: 0, y: 0, width: 300, height: WhiteBalanceControlView.horizontalHeight)
        panel.layoutSubviews()
        for view in [panel.modeControl, panel.temperatureLabel, panel.temperatureSlider, panel.tintLabel, panel.tintSlider] {
            XCTAssertTrue(panel.bounds.contains(view.frame), "\(view) in rows: \(view.frame)")
        }
        panel.vertical = true
        panel.frame = CGRect(x: 0, y: 0, width: WhiteBalanceControlView.verticalWidth, height: 300)
        panel.layoutSubviews()
        for view in [panel.modeControl, panel.temperatureLabel, panel.temperatureSlider, panel.tintLabel, panel.tintSlider] {
            XCTAssertTrue(panel.bounds.insetBy(dx: -1, dy: -1).contains(view.frame), "\(view) in columns: \(view.frame)")
        }
        XCTAssertGreaterThan(panel.temperatureSlider.frame.height, panel.temperatureSlider.frame.width, "the sliders stand in the column")
    }

    func testTheSkeletonCarriesTheEntries() throws {
        let url = try Bundle(for: CameraWhiteBalanceTests.self).url(forResource: "full-skeleton", withExtension: "phyphox").unwrap()
        let model = try settings(for: ExperimentSerialization.readExperimentFromURL(url))
        XCTAssertEqual(model.whiteBalanceMode, .temperature)
        XCTAssertEqual(model.whiteBalanceTemperature, 5600)
        XCTAssertEqual(model.whiteBalanceTint, 0.002, accuracy: 1e-9)
    }
}
