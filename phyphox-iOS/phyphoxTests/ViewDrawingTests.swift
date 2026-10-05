//
//  ViewDrawingTests.swift
//  phyphoxTests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
@testable import phyphox

// phyphox-test: view-geometry-draw
// phyphox-test: view-scale-draw
//The drawing elements of file format 1.21 (phyphox-docs views/drawing.md): the "Drawing" view of
//corpus/generated/view-drawing.phyphox built by the real factory and rendered, with the pixels where the shapes, the
//baseline, the tics and the needle must (and must not) be; the box geometry; the range bound to containers; and the
//stack's one touch: a tap on the label of an untransformed scale opens the unit dialog, also under a transformed
//needle, while a tap anywhere else on the stack does nothing. Mirrors Android's ViewDrawingTest, which compares
//goldens instead; the geometry asserted here is the specification's.
final class ViewDrawingTests: XCTestCase {
    private var savedMode: String?
    private var savedSetting: String?
    private var window: UIWindow?

    override func setUpWithError() throws {
        savedMode = UserDefaults.standard.string(forKey: SettingBundleHelper.UserDefaultKeys.APP_MODE.rawValue)
        savedSetting = UserDefaults.standard.string(forKey: Units.Setting.key)
        //The dark theme leaves the experiment's colours as given, so the probes can name them
        UserDefaults.standard.set(Utility.DARK_MODE, forKey: SettingBundleHelper.UserDefaultKeys.APP_MODE.rawValue)
        UserDefaults.standard.set(Units.Setting.experiment.rawValue, forKey: Units.Setting.key)
    }

    override func tearDownWithError() throws {
        UserDefaults.standard.set(savedMode, forKey: SettingBundleHelper.UserDefaultKeys.APP_MODE.rawValue)
        UserDefaults.standard.set(savedSetting, forKey: Units.Setting.key)
        window?.isHidden = true
        window = nil
    }

    private func loadCorpusFixture() throws -> Experiment {
        let corpus = try DocsCorpus.directory("generated", notTestedNotice: "drawing elements")
        return try ExperimentSerialization.readExperimentFromURL(corpus.appendingPathComponent("view-drawing.phyphox"))
    }

    private func load(_ xml: String) throws -> Experiment {
        return try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: InputStream(data: Data(xml.utf8)))
    }

    ///The rows of the first view and the controller that owns them (it applies the visibility buffers in its init)
    private func rows(_ experiment: Experiment) throws -> (controller: ExperimentViewController, rows: [UIView]) {
        let collection = try XCTUnwrap(experiment.viewDescriptors?.first)
        let modules = ExperimentViewModuleFactory.createViews(collection, resourceFolder: nil)
        let controller = ExperimentViewController(modules: modules)
        return (controller, modules.compactMap { $0.view })
    }

    private func group(_ view: UIView) throws -> ExperimentGroupView {
        return try XCTUnwrap(view as? ExperimentGroupView, "\(type(of: view)) is not a view group")
    }

    ///Lays a row out at the given width, as its table cell would
    @discardableResult
    private func layout(_ view: UIView, width: CGFloat) -> CGSize {
        let size = view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        view.frame = CGRect(origin: .zero, size: CGSize(width: width, height: size.height))
        view.setNeedsLayout()
        view.layoutIfNeeded()
        return size
    }

    ///Hosts the view in a window under a view controller, so it draws and can present dialogs
    private func host(_ view: UIView, width: CGFloat) -> UIViewController {
        let size = layout(view, width: width)
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        controller.view.addSubview(view)
        self.window?.isHidden = true
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: max(size.height, 1)))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window
        view.setNeedsLayout()
        view.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        return controller
    }

    ///The view as drawn, one pixel per point
    private func render(_ view: UIView) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
    }

    private struct Pixel {
        let r: Int, g: Int, b: Int, a: Int
    }

    ///The straight (un-premultiplied) colour of the pixel at (x, y) from the top left
    private func pixel(_ image: UIImage, _ x: Int, _ y: Int) throws -> Pixel {
        let cgImage = try XCTUnwrap(image.cgImage)
        var bytes = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cgImage, in: CGRect(x: -x, y: -(cgImage.height - 1 - y), width: cgImage.width, height: cgImage.height))
        let a = Int(bytes[3])
        guard a > 0 else { return Pixel(r: 0, g: 0, b: 0, a: 0) }
        return Pixel(r: Int(bytes[0]) * 255 / a, g: Int(bytes[1]) * 255 / a, b: Int(bytes[2]) * 255 / a, a: a)
    }

    private func assertColor(_ p: Pixel, _ r: Int, _ g: Int, _ b: Int, tolerance: Int = 12, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        //A probe sits inside the shape, but a stroke two points wide still anti-aliases a little
        XCTAssertGreaterThan(p.a, 240, message + " (alpha)", file: file, line: line)
        XCTAssertEqual(p.r, r, accuracy: tolerance, message + " (red)", file: file, line: line)
        XCTAssertEqual(p.g, g, accuracy: tolerance, message + " (green)", file: file, line: line)
        XCTAssertEqual(p.b, b, accuracy: tolerance, message + " (blue)", file: file, line: line)
    }

    // MARK: - view-geometry-draw

    func testTheBoxIsTheFullWidthAndWidthOverAspectRatioTall() throws {
        let (controller, rows) = try self.rows(try loadCorpusFixture())
        defer { _ = controller }
        let vertical = try group(rows[1])
        layout(vertical, width: 800)
        let trough = try XCTUnwrap(vertical.childModules[0] as? ExperimentGeometryView)
        let thermometer = try XCTUnwrap(vertical.childModules[1] as? ExperimentScaleView)
        XCTAssertEqual(trough.frame.width, 800, accuracy: 0.5)
        XCTAssertEqual(trough.frame.height, 200, accuracy: 0.5, "aspectRatio 4")
        XCTAssertEqual(thermometer.frame.height, 200, accuracy: 0.5)
        XCTAssertEqual(thermometer.frame.minY, 200, accuracy: 0.5, "below the trough")

        let gauge = try group(rows[0])
        let size = layout(gauge, width: 600)
        XCTAssertEqual(size.height, 600, accuracy: 0.5, "the default aspect ratio is a square, shared by every child")
        XCTAssertEqual(gauge.childModules[0].frame.height, 600, accuracy: 0.5)
        XCTAssertEqual(gauge.childModules[2].frame.height, 600, accuracy: 0.5)
    }

    func testTheShapesAreDrawnWhereTheAttributesPutThem() throws {
        let (controller, rows) = try self.rows(try loadCorpusFixture())
        defer { _ = controller }

        //The gauge: a dark face with an orange rim, a half-transparent red band between 90° and 135°, the needle at
        //42 % (rotated by -2.3562 + 0.42 * 4.7124 = -0.377 rad), nothing outside the face
        let gauge = try group(rows[0])
        _ = host(gauge, width: 400)
        let image = render(gauge)
        assertColor(try pixel(image, 200, 370), 0x20, 0x20, 0x20, "the face at six o'clock, in the gap of the scale")
        let band = try pixel(image, 363, 267) //angle 112.5°, radius 0.44
        XCTAssertEqual(band.a, 255, "the band over the face")
        XCTAssertGreaterThan(band.r, 110, "fe005d at half opacity over 202020 is reddish")
        XCTAssertLessThan(band.g, 50)
        let needle = try pixel(image, Int((200 - 60 * sin(0.377)).rounded()), Int((200 - 60 * cos(0.377)).rounded()))
        assertColor(needle, 0xff, 0x7e, 0x22, tolerance: 24, "the needle 60 px from the pivot along -0.377 rad")
        XCTAssertEqual(try pixel(image, 5, 5).a, 0, "nothing outside the circle: the stack is transparent")
        XCTAssertEqual(try pixel(image, 395, 395).a, 0)

        //The thermometer: a rounded rectangle 303030 from (0.05, 0.2) to (0.95, 0.6) with an orange outline, the scale
        //below it with a white baseline at y = 0.25 and a tic down from min
        let vertical = try group(rows[1])
        _ = host(vertical, width: 800)
        let thermometer = render(vertical)
        assertColor(try pixel(thermometer, 400, 80), 0x30, 0x30, 0x30, "inside the trough")
        assertColor(try pixel(thermometer, 400, 40), 0xff, 0x7e, 0x22, tolerance: 40, "the outline on the top edge")
        XCTAssertEqual(try pixel(thermometer, 400, 20).a, 0, "above the trough")
        assertColor(try pixel(thermometer, 400, 250), 0xff, 0xff, 0xff, tolerance: 40, "the baseline of the scale at y = 200 + 0.25 * 200")
        assertColor(try pixel(thermometer, 40, 262), 0xff, 0xff, 0xff, tolerance: 40, "the major tic at min, 24 px below the baseline")
        XCTAssertEqual(try pixel(thermometer, 400, 296).a, 0, "between the baseline and the values nothing is drawn")

        //The horizontal group: a blue line from (0.1, 0.9) to (0.9, 0.1) of its third, the scale in the other two
        let horizontal = try group(rows[2])
        _ = host(horizontal, width: 600)
        let diagonal = render(horizontal)
        let lineBox = horizontal.childModules[0].frame
        XCTAssertEqual(lineBox.width, 200, accuracy: 1, "weight 1 of 3")
        let mid = CGPoint(x: lineBox.midX, y: lineBox.midY)
        //"blue" is the named phyphox colour, not pure blue
        let blue = try XCTUnwrap(mapColorString("blue"))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        blue.getRed(&r, green: &g, blue: &b, alpha: &a)
        assertColor(try pixel(diagonal, Int(mid.x), Int(mid.y)), Int(r * 255), Int(g * 255), Int(b * 255), tolerance: 40, "the line through the centre of its box")
        XCTAssertEqual(try pixel(diagonal, Int(lineBox.minX) + 10, Int(lineBox.minY) + 10).a, 0, "off the line")
    }

    // MARK: - view-scale-draw

    func testABoundContainerReRangesTheTicsButNotTheBaseline() throws {
        let experiment = try loadCorpusFixture()
        let (controller, rows) = try self.rows(experiment)
        defer { _ = controller }
        let grid = try group(rows[3])
        let bound = try XCTUnwrap(grid.childModules[2] as? ExperimentScaleView) //min from "lower" (-10), max from "upper" (250)
        bound.update()
        XCTAssertEqual(bound.effectiveMin, -10)
        XCTAssertEqual(bound.effectiveMax, 250)
        var tics = bound.computeTics(width: 400, textSize: 16)
        XCTAssertEqual(tics.first?.value, 0)
        XCTAssertEqual(tics.last?.value, 250)
        //the positions of min and max do not move: -10 is at the start of the baseline, 250 at its end
        XCTAssertEqual(try XCTUnwrap(tics.last).fraction, 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(tics.first).fraction, 10.0 / 260.0, accuracy: 1e-9)

        //a new range from the experiment
        experiment.buffers["upper"]?.replaceValues([50])
        bound.update()
        XCTAssertEqual(bound.effectiveMax, 50)
        tics = bound.computeTics(width: 400, textSize: 16)
        XCTAssertEqual(tics.filter { $0.major }.map { $0.value }, [-10, 0, 10, 20, 30, 40, 50])

        //an empty or NaN container leaves the attribute value
        experiment.buffers["upper"]?.replaceValues([])
        bound.update()
        XCTAssertEqual(bound.effectiveMax, 100)
        experiment.buffers["lower"]?.replaceValues([Double.nan])
        bound.update()
        XCTAssertEqual(bound.effectiveMin, 0)
    }

    func testATapOnTheLabelOfAnUntransformedScaleInAStackOpensTheUnitDialogAndNothingElseDoes() throws {
        let experiment = try load("""
            <phyphox xmlns="http://phyphox.org/xml" version="1.21" locale="en">
            <title>t</title><category>c</category><description>d</description>
            <data-containers><container size="1" init="0.5">v</container></data-containers>
            <views><view label="v">
            <stack>
                <geometry shape="circle" radius="0.48" color="202020" />
                <scale shape="circular" min="0" max="10" unit="@meter" label="Distance" labelPositionX="0.5" labelPositionY="0.5" />
                <transform originX="0.5" originY="0.5">
                    <input as="rotate" min="0" max="1" mapMin="0" mapMax="3.14">v</input>
                    <geometry shape="line" startX="0.5" startY="0.5" endX="0.5" endY="0.1" lineColor="orange" lineWidth="0.02" />
                </transform>
                <transform><input as="opacity">v</input><scale shape="linear" min="0" max="1" unit="@second" label="Time" labelPositionX="0.5" labelPositionY="0.9" /></transform>
                <geometry shape="circle" radius="0.04" color="orange" />
            </stack>
            <scale shape="linear" min="0" max="1" unit="@meter" label="Alone" aspectRatio="3" labelPositionY="0.8" />
            </view></views></phyphox>
            """)
        let (viewController, rows) = try self.rows(experiment)
        defer { _ = viewController }
        let stack = try group(rows[0])
        let controller = host(stack, width: 400)

        //the label sits at the centre, where the needle's pivot and the needle itself are drawn over it
        let scale = try XCTUnwrap(stack.childModules[1] as? ExperimentScaleView)
        let label = try XCTUnwrap(scale.labelFrame())
        XCTAssertTrue(label.contains(CGPoint(x: 200, y: 200)))
        //the topmost child under the centre is the hub, below it the needle: the tap still reaches the scale
        XCTAssertTrue(stack.scaleLabel(at: CGPoint(x: 200, y: 200)) === scale)
        XCTAssertTrue(stack.hitTest(CGPoint(x: 200, y: 200), with: nil) === scale)
        scale.openUnitDialog()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        let dialog = try XCTUnwrap(controller.presentedViewController as? UIAlertController, "the unit dialog is presented")
        XCTAssertNotNil(dialog.view.viewWithAccessibilityIdentifier("unit.dialog"), "the unit table")
        //The presentation animates; the dismissal waits for it
        var deadline = Date().addingTimeInterval(3)
        while dialog.isBeingPresented && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        dialog.dismiss(animated: false)
        deadline = Date().addingTimeInterval(3)
        while controller.presentedViewController != nil && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertNil(controller.presentedViewController)

        //the transformed scale's label is not offered the tap, even though it is a convertible scale
        let transformed = try XCTUnwrap(try XCTUnwrap(stack.childModules[3] as? ExperimentTransformView).child as? ExperimentScaleView)
        let transformedLabel = try XCTUnwrap(transformed.labelFrame())
        let onTransformedLabel = transformed.convert(CGPoint(x: transformedLabel.midX, y: transformedLabel.midY), to: stack)
        XCTAssertTrue(transformed.hitsLabel(CGPoint(x: transformedLabel.midX, y: transformedLabel.midY)), "the scale itself would take it")
        XCTAssertNil(stack.scaleLabel(at: onTransformedLabel))
        XCTAssertNil(stack.hitTest(onTransformedLabel, with: nil))

        //a tap anywhere else on the stack does nothing and is left to the page
        XCTAssertNil(stack.hitTest(CGPoint(x: 30, y: 30), with: nil))
        XCTAssertNil(stack.hitTest(CGPoint(x: 200, y: 60), with: nil), "on the needle, off the label")

        //the choice in the dialog converts the scale: 10 m become 32.8 ft, the geometry stays
        scale.setDisplayUnit("foot")
        XCTAssertTrue(scale.isConverted)
        XCTAssertEqual(scale.labelText, "Distance (ft)")
        XCTAssertEqual(scale.effectiveMax, 10)
        let tics = scale.computeTics(width: 400, textSize: 16)
        XCTAssertEqual(tics.last?.text, "30")
        XCTAssertEqual(try XCTUnwrap(tics.last).fraction, 30 * 0.3048 / 10, accuracy: 1e-9)

        //outside a stack the scale takes the tap on its label itself and leaves everything else to the page
        let alone = try XCTUnwrap(rows[1] as? ExperimentScaleView)
        layout(alone, width: 400)
        let aloneLabel = try XCTUnwrap(alone.labelFrame())
        XCTAssertNil(alone.hitTest(CGPoint(x: 10, y: 10), with: nil))
        XCTAssertTrue(alone.hitTest(CGPoint(x: aloneLabel.midX, y: aloneLabel.midY), with: nil) === alone)
    }

    func testATextUnitHasNoTapTarget() throws {
        let (controller, rows) = try self.rows(try loadCorpusFixture())
        defer { _ = controller }
        let gauge = try group(rows[0])
        layout(gauge, width: 400)
        let load = try XCTUnwrap(gauge.childModules[2] as? ExperimentScaleView) //unit "%": known, not convertible
        let label = try XCTUnwrap(load.labelFrame())
        XCTAssertEqual(load.labelText, "Load (%)")
        XCTAssertFalse(load.isConvertible)
        let point = load.convert(CGPoint(x: label.midX, y: label.midY), to: gauge)
        XCTAssertNil(gauge.scaleLabel(at: point))
        XCTAssertNil(gauge.hitTest(point, with: nil))
    }

    func testTheValueOrientationsAndTheSwitchedOffPartsRenderWithoutDrawingOutsideTheBox() throws {
        let (controller, rows) = try self.rows(try loadCorpusFixture())
        defer { _ = controller }
        //the grid: a bare geometry (a full rectangle, no fill and no outline: nothing), a heading dial with every part
        //but the label switched off, and the bound tangential scale; the horizontal group holds the tangential text unit
        let grid = try group(rows[3])
        _ = host(grid, width: 600)
        let image = render(grid)
        let bare = grid.childModules[0].frame
        XCTAssertEqual(try pixel(image, Int(bare.midX), Int(bare.midY)).a, 0, "a geometry without color and lineColor draws nothing")
        let heading = try XCTUnwrap(grid.childModules[1] as? ExperimentScaleView)
        XCTAssertEqual(heading.labelText, "Heading")
        XCTAssertEqual(heading.computeTics(width: 400, textSize: 16).filter { $0.major }.count, 5, "the tics are laid out even when they are not drawn")
        XCTAssertTrue(heading.computeTics(width: 400, textSize: 16).allSatisfy { $0.text == nil }, "valueEvery 0 shows no values")
        //the baseline of the heading dial (lineWidth 0) is not drawn: the point on its circle at twelve o'clock is empty
        let headingBox = heading.frame
        XCTAssertEqual(try pixel(image, Int(headingBox.midX), Int(headingBox.minY + 0.1 * headingBox.width)).a, 0)
        //the tangential scale of the horizontal group draws its values rotated along the vertical baseline
        let horizontal = try group(rows[2])
        _ = host(horizontal, width: 600)
        let tangential = try XCTUnwrap(horizontal.childModules[1] as? ExperimentScaleView)
        XCTAssertEqual(tangential.descriptor.attributes.valueOrientation, .tangential)
        let rendered = render(horizontal)
        let box = tangential.frame
        //the baseline runs up the middle of the box from y = 0.9 to y = 0.1
        assertColor(try pixel(rendered, Int(box.midX), Int(box.midY)), 0xff, 0xff, 0xff, tolerance: 40, "the vertical baseline")
    }
}

private extension UIView {
    ///The first view below this one with the accessibility identifier
    func viewWithAccessibilityIdentifier(_ id: String) -> UIView? {
        if accessibilityIdentifier == id { return self }
        for subview in subviews {
            if let found = subview.viewWithAccessibilityIdentifier(id) { return found }
        }
        return nil
    }
}
