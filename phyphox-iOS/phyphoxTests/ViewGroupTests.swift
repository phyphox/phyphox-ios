//
//  ViewGroupTests.swift
//  phyphoxTests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
@testable import phyphox

// phyphox-test: view-groups-layout
// phyphox-test: view-stack-transform
// phyphox-test: view-vertical-layout
// phyphox-test: grid-screen-unit
//View groups, the transform and the fixed plot area of file format 1.21 (phyphox-docs views/groups.md and graph.md,
//"Fixing the plot area"): the geometry the specification fixes, measured on the real modules of a loaded experiment,
//wired the way the experiment screen wires them. Mirrors Android's ViewGroupsTest. Images and the GL curve need a
//device; everything here is plain view layout.
final class ViewGroupTests: XCTestCase {
    private static let head = """
    <phyphox xmlns="http://phyphox.org/xml" version="1.21" locale="en">
    <title>t</title><category>c</category><description>d</description>
    <data-containers>
    <container size="1" init="1">show</container>
    <container size="1" init="0">hide</container>
    <container size="1">angle</container>
    <container size="1" init="7">v</container>
    <container size="1" init="0.25">fade</container>
    </data-containers><input></input><analysis></analysis><views><view label="v">
    """
    private static let tail = "</view></views></phyphox>"

    //The unit of maxWidth and of the separator's height
    private let unit = UIFont.preferredFont(forTextStyle: .footnote).pointSize

    private func load(_ body: String) throws -> Experiment {
        let xml = ViewGroupTests.head + body + ViewGroupTests.tail
        return try DocumentParser(documentHandler: PhyphoxDocumentHandler()).parse(stream: InputStream(data: Data(xml.utf8)))
    }

    ///The rows of the first view and the controller that owns them (it applies the visibility buffers in its init)
    private func rows(_ experiment: Experiment) throws -> (controller: ExperimentViewController, rows: [UIView]) {
        let collection = try XCTUnwrap(experiment.viewDescriptors?.first)
        let modules = ExperimentViewModuleFactory.createViews(collection, resourceFolder: nil)
        let controller = ExperimentViewController(modules: modules)
        return (controller, modules.compactMap { $0.view })
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

    ///A buffer notifies its observers on the main queue; one turn of the run loop delivers the write
    private func settle() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }

    private func group(_ view: UIView) throws -> ExperimentGroupView {
        return try XCTUnwrap(view as? ExperimentGroupView, "\(type(of: view)) is not a view group")
    }

    // MARK: - view-groups-layout

    func testHorizontalSplitsTheRowByWeightAndAHiddenChildGivesUpItsSpace() throws {
        let experiment = try load("""
            <horizontal>
                <value label="two" weight="2"><input>v</input></value>
                <value label="one"><input>v</input></value>
                <vertical><value label="a"><input>v</input></value><value label="b"><input>v</input></value></vertical>
            </horizontal>
            <horizontal>
                <value label="left"><input>v</input></value>
                <value label="gone" visibility="hide"><input>v</input></value>
                <value label="right"><input>v</input></value>
            </horizontal>
            """)
        let (controller, rows) = try self.rows(experiment)
        defer { _ = controller }

        let row = try group(rows[0])
        let rowSize = layout(row, width: 1000)
        let children = row.childModules
        XCTAssertEqual(children[0].frame.width, 500, accuracy: 1)
        XCTAssertEqual(children[1].frame.width, 250, accuracy: 1)
        XCTAssertEqual(children[2].frame.width, 250, accuracy: 1)
        XCTAssertEqual(children[0].frame.minX, 0, accuracy: 1)
        XCTAssertEqual(children[1].frame.minX, 500, accuracy: 1)
        XCTAssertEqual(children[2].frame.minX, 750, accuracy: 1)
        //the row is as tall as the two-value column, the single values sit centred in it
        let column = try group(children[2])
        XCTAssertEqual(rowSize.height, children[2].frame.height, accuracy: 0.5)
        XCTAssertGreaterThan(column.childModules[1].frame.minY, 0, "the column stacks its values")
        XCTAssertEqual(children[1].frame.midY, rowSize.height / 2, accuracy: 1)

        let row2 = try group(rows[1])
        layout(row2, width: 1000)
        XCTAssertTrue(row2.childModules[1].isHidden, "visibility=hide applies before the first write")
        XCTAssertEqual(row2.childModules[0].frame.width, 500, accuracy: 1)
        XCTAssertEqual(row2.childModules[2].frame.width, 500, accuracy: 1)
        XCTAssertEqual(row2.childModules[2].frame.minX, 500, accuracy: 1)
    }

    func testAChildHiddenAtRuntimeGivesItsSpaceToItsSiblings() throws {
        let experiment = try load("""
            <horizontal>
                <value label="a"><input>v</input></value>
                <value label="b" visibility="show"><input>v</input></value>
            </horizontal>
            """)
        let (controller, rows) = try self.rows(experiment)
        let row = try group(rows[0])
        layout(row, width: 1000)
        XCTAssertEqual(row.childModules[0].frame.width, 500, accuracy: 1)

        //The controller observes the buffer like on the experiment screen and hides the child in place
        let show = try XCTUnwrap(experiment.buffers["show"])
        show.replaceValues([0])
        controller.dataBufferUpdated(show)
        XCTAssertTrue(row.childModules[1].isHidden)
        layout(row, width: 1000)
        XCTAssertEqual(row.childModules[0].frame.width, 1000, accuracy: 1)

        show.replaceValues([1])
        controller.dataBufferUpdated(show)
        XCTAssertFalse(row.childModules[1].isHidden)
        layout(row, width: 1000)
        XCTAssertEqual(row.childModules[0].frame.width, 500, accuracy: 1)
    }

    func testGridChoosesItsColumnsFromTheWidthAndFillsTheLastRowOnRequest() throws {
        let values = (1...4).map { "<value label=\"v\($0)\"><input>v</input></value>" }.joined()
        let experiment = try load("<grid maxWidth=\"25\" fillLastRow=\"true\">\(values)</grid><grid maxWidth=\"25\">\(values)</grid>")
        let (controller, rows) = try self.rows(experiment)
        defer { _ = controller }
        let filling = try group(rows[0])
        let plain = try group(rows[1])

        //one column while the width is at most maxWidth, two up to twice it, and so on
        XCTAssertEqual(filling.gridColumns(width: 25 * unit), 1)
        XCTAssertEqual(filling.gridColumns(width: 25 * unit + 1), 2)
        XCTAssertEqual(filling.gridColumns(width: 50 * unit), 2)
        XCTAssertEqual(filling.gridColumns(width: 50 * unit + 1), 3)

        let narrow = 25 * unit
        layout(filling, width: narrow)
        let single = filling.childModules
        XCTAssertEqual(single[0].frame.width, narrow, accuracy: 1)
        XCTAssertEqual(single[1].frame.minY, single[0].frame.maxY, accuracy: 0.5, "one column: the children stack")
        XCTAssertEqual(single[3].frame.minX, 0, accuracy: 0.5)

        let wide = 2.5 * 25 * unit
        let columnWidth = wide / 3
        layout(filling, width: wide)
        let three = filling.childModules
        XCTAssertEqual(three[0].frame.width, columnWidth, accuracy: 1)
        XCTAssertEqual(three[1].frame.minX, columnWidth, accuracy: 1)
        XCTAssertEqual(three[2].frame.minX, 2 * columnWidth, accuracy: 1)
        XCTAssertEqual(three[2].frame.minY, three[0].frame.minY, accuracy: 0.5, "three columns: one row of three")
        XCTAssertGreaterThan(three[3].frame.minY, three[0].frame.maxY - 0.5, "and the fourth on the next row")
        XCTAssertEqual(three[3].frame.width, wide, accuracy: 1, "fillLastRow stretches the single child over the row")

        layout(plain, width: wide)
        XCTAssertEqual(plain.childModules[3].frame.width, columnWidth, accuracy: 1, "without fillLastRow it keeps the column width")
        XCTAssertEqual(plain.childModules[3].frame.minX, 0, accuracy: 1)
    }

    // MARK: - view-stack-transform

    func testStackSharesOneRectangleAndTheTransformFollowsItsContainers() throws {
        let experiment = try load("""
            <stack>
                <separator height="6" color="39a2ff40" />
                <transform originX="0.5" originY="0.8">
                    <input as="rotate" min="0" max="360" mapMin="0" mapMax="6.2832" clamp="true">angle</input>
                    <input as="opacity">fade</input>
                    <info label="needle" />
                </transform>
                <transform>
                    <input as="scale" type="value">0.5</input>
                    <input as="translateX" type="value">0.25</input>
                    <value label="" unit="%"><input>v</input></value>
                </transform>
            </stack>
            """)
        let (controller, rows) = try self.rows(experiment)
        defer { _ = controller }
        let stack = try group(rows[0])
        XCTAssertTrue(stack.isStack)
        XCTAssertFalse(stack.isUserInteractionEnabled, "a stack is not interactive")

        let size = layout(stack, width: 600)
        let layers = stack.childModules
        XCTAssertEqual(size.height, 6 * unit, accuracy: 0.5, "the separator is the tallest child and sets the height")
        XCTAssertEqual(layers[0].frame.height, 6 * unit, accuracy: 0.5)
        for layer in layers {
            XCTAssertGreaterThanOrEqual(layer.frame.minX, -0.5)
            XCTAssertLessThanOrEqual(layer.frame.maxX, 600.5)
            XCTAssertEqual(layer.frame.midX, 300, accuracy: 1, "every child is centred in the full width")
            XCTAssertEqual(layer.frame.midY, size.height / 2, accuracy: 1, "shorter children are centred vertically")
        }
        //document order is the z-order: later children lie above earlier ones
        XCTAssertGreaterThan(try XCTUnwrap(stack.subviews.firstIndex(of: layers[2])), try XCTUnwrap(stack.subviews.firstIndex(of: layers[0])))

        let rotating = try XCTUnwrap(layers[1] as? ExperimentTransformView)
        let constant = try XCTUnwrap(layers[2] as? ExperimentTransformView)
        //an empty container leaves the neutral value, the opacity follows fade, the origin is the anchor
        XCTAssertEqual(rotating.appliedState.rotate, 0)
        XCTAssertEqual(rotating.child.alpha, 0.25, accuracy: 1e-6)
        XCTAssertEqual(rotating.child.layer.anchorPoint.x, 0.5, accuracy: 1e-6)
        XCTAssertEqual(rotating.child.layer.anchorPoint.y, 0.8, accuracy: 1e-6)
        XCTAssertEqual(rotating.child.center.x, rotating.bounds.width / 2, accuracy: 0.5)
        XCTAssertEqual(rotating.child.center.y, rotating.bounds.height * 0.8, accuracy: 0.5)
        XCTAssertTrue(rotating.child.transform.isIdentity)
        //the constant bindings: scale about the centre, shift by a quarter of the width
        XCTAssertEqual(constant.child.transform.a, 0.5, accuracy: 1e-6)
        XCTAssertEqual(constant.child.transform.d, 0.5, accuracy: 1e-6)
        XCTAssertEqual(constant.child.transform.tx, 0.25 * constant.bounds.width, accuracy: 0.5)
        XCTAssertEqual(constant.child.transform.ty, 0, accuracy: 1e-6)

        //90 of 0..360 maps to pi/2: a quarter turn clockwise on screen (positive angle in UIKit's y-down coordinates)
        let angle = try XCTUnwrap(experiment.buffers["angle"])
        let link = DisplayLink(refreshRate: 0)
        angle.replaceValues([90])
        settle()
        rotating.display(link)
        XCTAssertEqual(rotating.appliedState.rotate, Double.pi / 2, accuracy: 0.01)
        XCTAssertEqual(rotating.child.transform.a, 0, accuracy: 0.01)
        XCTAssertEqual(rotating.child.transform.b, 1, accuracy: 0.01)
        //outside the range the clamp holds the end of the map
        angle.replaceValues([540])
        settle()
        rotating.display(link)
        XCTAssertEqual(rotating.appliedState.rotate, 6.2832, accuracy: 1e-9)
        //NaN is neutral again
        angle.replaceValues([Double.nan])
        settle()
        rotating.display(link)
        XCTAssertEqual(rotating.appliedState.rotate, 0)
        XCTAssertTrue(rotating.child.transform.isIdentity)
    }

    func testTheLinearMapAndItsNeutralCases() throws {
        let buffer = try DataBuffer(name: "b", size: 1, baseContents: [], static: false)
        let input = TransformInput(property: .rotate, buffer: buffer, value: nil, min: 0, max: 100, mapMin: -2.35, mapMax: 2.35, clamp: true)
        XCTAssertNil(input.mappedValue(), "an empty container is neutral")
        buffer.replaceValues([50])
        XCTAssertEqual(try XCTUnwrap(input.mappedValue()), 0, accuracy: 1e-9)
        buffer.replaceValues([100])
        XCTAssertEqual(try XCTUnwrap(input.mappedValue()), 2.35, accuracy: 1e-9)
        buffer.replaceValues([250])
        XCTAssertEqual(try XCTUnwrap(input.mappedValue()), 2.35, accuracy: 1e-9, "clamped at the end of the map")
        buffer.replaceValues([-50])
        XCTAssertEqual(try XCTUnwrap(input.mappedValue()), -2.35, accuracy: 1e-9)
        buffer.replaceValues([Double.infinity])
        XCTAssertNil(input.mappedValue(), "a non-finite value is neutral")

        let unclamped = TransformInput(property: .scale, buffer: buffer, value: nil, min: 0, max: 100, mapMin: -2.35, mapMax: 2.35, clamp: false)
        buffer.replaceValues([250])
        XCTAssertEqual(try XCTUnwrap(unclamped.mappedValue()), 9.4, accuracy: 1e-9)

        let degenerate = TransformInput(property: .scale, buffer: nil, value: 3, min: 1, max: 1, mapMin: 0, mapMax: 1, clamp: false)
        XCTAssertNil(degenerate.mappedValue(), "min == max is neutral")
        let identity = TransformInput(property: .scale, buffer: nil, value: 0.4, min: 0, max: 1, mapMin: 0, mapMax: 1, clamp: false)
        XCTAssertEqual(try XCTUnwrap(identity.mappedValue()), 0.4, accuracy: 1e-9, "the defaults are the identity")

        //opacity outside 0...1 is clamped; a later input for the same property wins
        let descriptor = TransformViewDescriptor(visibilityBuffer: nil, originX: 0.5, originY: 0.5, inputs: [
            TransformInput(property: .opacity, buffer: nil, value: 4, min: 0, max: 1, mapMin: 0, mapMax: 1, clamp: false),
            TransformInput(property: .scaleX, buffer: nil, value: 2, min: 0, max: 1, mapMin: 0, mapMax: 1, clamp: false),
            TransformInput(property: .scaleX, buffer: nil, value: 3, min: 0, max: 1, mapMin: 0, mapMax: 1, clamp: false)
        ], child: SeparatorViewDescriptor(height: 1, color: kBackgroundColor, visibilityBuffer: nil))
        let state = descriptor.currentState()
        XCTAssertEqual(state.opacity, 1)
        XCTAssertEqual(state.scaleX, 3)
        XCTAssertEqual(state.scale, 1)
        XCTAssertEqual(state.translateY, 0)
    }

    func testGraphInAStackIsStaticAndAFixedPlotAreaPinsThePlot() throws {
        let experiment = try load("""
            <stack>
                <separator height="1" />
                <graph label="Overlay" plotLeft="0.1" plotBottom="0.9"><input axis="x">v</input><input axis="y">v</input></graph>
            </stack>
            <graph label="Plain"><input axis="x">v</input><input axis="y">v</input></graph>
            """)
        let (controller, rows) = try self.rows(experiment)
        defer { _ = controller }
        let stack = try group(rows[0])
        let overlay = try XCTUnwrap(stack.childModules[1] as? ExperimentGraphView)
        let plain = try XCTUnwrap(rows[1] as? ExperimentGraphView)

        XCTAssertTrue(overlay.isStatic, "no tap-to-maximize inside a stack")
        XCTAssertFalse(plain.isStatic)
        XCTAssertEqual(overlay.descriptor.plotArea, GraphViewDescriptor.PlotArea(left: 0.1, top: 0, right: 1, bottom: 0.9), "unset edges default to the element's edges")
        XCTAssertNil(plain.descriptor.plotArea)

        //the plot rectangle follows the fractions of the element's box, whatever the labels need
        overlay.frame = CGRect(x: 0, y: 0, width: 400, height: 200)
        overlay.setNeedsLayout()
        overlay.layoutIfNeeded()
        let plot = overlay.layoutManager.graphFrame
        XCTAssertEqual(plot.minX, 40, accuracy: 0.5)
        XCTAssertEqual(plot.minY, 0, accuracy: 0.5)
        XCTAssertEqual(plot.maxX, 400, accuracy: 0.5)
        XCTAssertEqual(plot.maxY, 180, accuracy: 0.5)

        plain.frame = CGRect(x: 0, y: 0, width: 400, height: 200)
        plain.setNeedsLayout()
        plain.layoutIfNeeded()
        XCTAssertGreaterThan(plain.layoutManager.graphFrame.minY, 0, "the automatic layout leaves room for the label")

        //the web config carries the attributes as given
        let overlayConfig = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(overlay.descriptor.webGraphConfig().utf8)) as? [String: Any])
        XCTAssertEqual(overlayConfig["plotLeft"] as? Double, 0.1)
        XCTAssertTrue(overlayConfig["plotTop"] is NSNull)
        XCTAssertEqual(overlayConfig["plotBottom"] as? Double, 0.9)
        let plainConfig = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(plain.descriptor.webGraphConfig().utf8)) as? [String: Any])
        XCTAssertTrue(plainConfig["plotLeft"] is NSNull)
    }

    func testAMaximizedLeafInsideAGroupTakesTheRowAndTheOthersHide() throws {
        let experiment = try load("""
            <horizontal>
                <graph label="g"><input axis="x">v</input><input axis="y">v</input></graph>
                <value label="a"><input>v</input></value>
            </horizontal>
            <value label="b"><input>v</input></value>
            """)
        let (controller, rows) = try self.rows(experiment)
        let row = try group(rows[0])
        let graph = try XCTUnwrap(row.childModules[0] as? ExperimentGraphView)

        controller.presentExclusiveLayout(graph)
        XCTAssertEqual(graph.resizableState, .exclusive)
        XCTAssertTrue(row.childModules[1].isHidden, "the sibling in the group hides")
        XCTAssertTrue(rows[1].isHidden, "and so does the other row")
        XCTAssertFalse(row.isHidden)
        let full = CGSize(width: 400, height: 700)
        XCTAssertEqual(row.sizeThatFits(full), full, "the group's row takes the whole screen")
        row.frame = CGRect(origin: .zero, size: full)
        row.setNeedsLayout()
        row.layoutIfNeeded()
        XCTAssertEqual(graph.frame, CGRect(origin: .zero, size: full))

        controller.restoreLayout()
        XCTAssertEqual(graph.resizableState, .normal)
        XCTAssertFalse(row.childModules[1].isHidden)
        XCTAssertFalse(rows[1].isHidden)
        layout(row, width: 400)
        XCTAssertEqual(graph.frame.width, 200, accuracy: 1, "back to the equal split")
    }

    // MARK: - the parser

    func testTheGroupsNestAndTheInvalidFormsAreRefused() throws {
        let experiment = try load("""
            <horizontal label="ignored on a group" visibility="show">
                <button label="Start" weight="2"><input type="value">1</input><output>v</output></button>
                <vertical>
                    <value label="Count"><input>v</input></value>
                    <grid maxWidth="12"><info label="deep" /><stack><image src="a.png" /></stack></grid>
                </vertical>
            </horizontal>
            """)
        let views = try XCTUnwrap(experiment.viewDescriptors?.first?.views)
        let horizontal = try XCTUnwrap(views[0] as? HorizontalViewDescriptor)
        XCTAssertEqual(horizontal.weights, [2, 1])
        XCTAssertTrue(horizontal.visibilityBuffer === experiment.buffers["show"])
        XCTAssertEqual(horizontal.localizedLabel, "", "label has no effect on a group")
        let vertical = try XCTUnwrap(horizontal.children[1] as? VerticalViewDescriptor)
        let grid = try XCTUnwrap(vertical.children[1] as? GridViewDescriptor)
        XCTAssertEqual(grid.maxWidth, 12)
        XCTAssertFalse(grid.fillLastRow)
        XCTAssertTrue(grid.children[1] is StackViewDescriptor)
        XCTAssertEqual(horizontal.leaves.count, 4, "button, value, info, image")
        XCTAssertEqual(experiment.resources, ["a.png"], "an image inside groups is a resource")

        //An experiment equals itself with groups in it (the view descriptors compare recursively)
        XCTAssertEqual(experiment, experiment)

        let invalid = [
            "transform outside a stack": "<transform><input as=\"rotate\">angle</input><info label=\"x\" /></transform>",
            "two wrapped elements": "<stack><transform><input as=\"rotate\">angle</input><info label=\"one\" /><info label=\"two\" /></transform></stack>",
            "no wrapped element": "<stack><transform><input as=\"rotate\">angle</input></transform></stack>",
            "unknown property": "<stack><transform><input as=\"skew\">angle</input><info label=\"x\" /></transform></stack>",
            "user input in a stack": "<stack><info label=\"x\" /><edit label=\"e\"><output>v</output></edit></stack>",
            "a group in a stack": "<stack><vertical><info label=\"x\" /></vertical></stack>",
            "a grid without maxWidth": "<grid><info label=\"x\" /></grid>",
            "an unknown container": "<stack><transform><input as=\"rotate\">nosuch</input><info label=\"x\" /></transform></stack>",
            "a nested transform": "<stack><transform><input as=\"rotate\">angle</input><transform><info label=\"x\" /></transform></transform></stack>",
            "an unknown grid unit": "<grid maxWidth=\"300\" maxWidthUnit=\"pixels\"><info label=\"x\" /></grid>"
        ]
        for (name, body) in invalid {
            XCTAssertThrowsError(try load(body), name)
        }
    }

    func testDocsFixtureLoadsAndNestsAsWritten() throws {
        let corpus = try DocsCorpus.directory("generated", notTestedNotice: "the view-groups fixture")
        let url = corpus.appendingPathComponent("view-groups.phyphox")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("the phyphox-docs checkout has no corpus/generated/view-groups.phyphox")
        }
        let experiment = try ExperimentSerialization.readExperimentFromURL(url)
        let views = try XCTUnwrap(experiment.viewDescriptors)
        XCTAssertEqual(views.count, 2)

        let groups = views[0].views
        let horizontal = try XCTUnwrap(groups[0] as? HorizontalViewDescriptor)
        XCTAssertEqual(horizontal.weights, [2, 1, 1])
        XCTAssertTrue(horizontal.children[2] is VerticalViewDescriptor)
        XCTAssertTrue(groups[1] is SeparatorViewDescriptor)
        let grid = try XCTUnwrap(groups[2] as? GridViewDescriptor)
        XCTAssertEqual(grid.maxWidth, 25)
        XCTAssertTrue(grid.fillLastRow)
        XCTAssertEqual(grid.children.count, 4)
        XCTAssertTrue(grid.children[2] is HorizontalViewDescriptor)
        let inner = try XCTUnwrap(grid.children[3] as? GridViewDescriptor)
        XCTAssertEqual(inner.maxWidthUnit, .screen)
        XCTAssertEqual(grid.maxWidthUnit, .text)
        XCTAssertEqual(inner.children.count, 9)
        XCTAssertFalse(inner.children[2].hasLabel, "a value without a label")
        XCTAssertFalse(inner.children[6].hasLabel, "a graph without a label")
        XCTAssertTrue(inner.children[7] is InfoViewDescriptor)
        XCTAssertTrue(inner.children[8] is ButtonViewDescriptor)
        let nested = try XCTUnwrap(grid.children[2] as? HorizontalViewDescriptor)
        XCTAssertTrue(try XCTUnwrap(nested.children[0] as? EditViewDescriptor).verticalLayout)
        XCTAssertTrue(try XCTUnwrap(nested.children[1] as? SliderViewDescriptor).verticalLayout)

        let vertical = try XCTUnwrap(views[1].views[0] as? VerticalViewDescriptor)
        let gauge = try XCTUnwrap(vertical.children[0] as? StackViewDescriptor)
        XCTAssertEqual(gauge.children.count, 6)
        let needle = try XCTUnwrap(gauge.children[1] as? TransformViewDescriptor)
        XCTAssertEqual(needle.originY, 0.8)
        XCTAssertEqual(needle.inputs.count, 2)
        XCTAssertEqual(needle.inputs[0].property, .rotate)
        XCTAssertTrue(needle.inputs[0].buffer === experiment.buffers["percent"])
        XCTAssertEqual(needle.inputs[0].mapMin, -2.35)
        XCTAssertTrue(needle.inputs[0].clamp)
        XCTAssertTrue(needle.child is ImageViewDescriptor)
        let marker = try XCTUnwrap(gauge.children[2] as? TransformViewDescriptor)
        XCTAssertEqual(marker.inputs[2].value, 0.1, "a constant input")
        XCTAssertNil(marker.inputs[2].buffer)
        let map = try XCTUnwrap(vertical.children[1] as? StackViewDescriptor)
        let overlay = try XCTUnwrap((map.children[2] as? TransformViewDescriptor)?.child as? GraphViewDescriptor)
        XCTAssertEqual(overlay.plotArea, GraphViewDescriptor.PlotArea(left: 0.1, top: 0, right: 1, bottom: 0.9))

        XCTAssertEqual(Set(experiment.resources), ["gauge-face.png", "gauge-needle.png", "marker.png", "campus-map.png"], "images inside groups are resources, so /res serves them")

        //The nested view layout for the remote interface (phyphox-webinterface readme.md, "The view layout")
        let (path, elements) = WebServerUtilities.prepareWebServerFilesForExperiment(experiment)
        defer { try? FileManager.default.removeItem(atPath: path) }
        let html = try String(contentsOfFile: path + "/index.html", encoding: .utf8)
        XCTAssertEqual(elements.count, 30, "the leaves get the global indices, in document order")
        XCTAssertTrue(elements[0] is ButtonViewDescriptor)
        XCTAssertTrue(elements[29] is GraphViewDescriptor)
        XCTAssertTrue(html.contains("\"index\": 29,"))
        XCTAssertFalse(html.contains("\"index\": 30,"))
        XCTAssertTrue(html.contains("{\"type\":\"horizontal\",\"visibilityInput\":\"show\",\"elements\":["))
        XCTAssertTrue(html.contains("\"index\": 0, \"html\": \"<div style=\\\"font-size: 105%;\\\" class=\\\"buttonElement\\\" id=\\\"element0\\\">"))
        XCTAssertTrue(html.contains("\"dataCompleteFunction\": function() {},\"weight\":2.0"), "weight on a direct child of a horizontal")
        XCTAssertTrue(html.contains("{\"type\":\"vertical\",\"weight\":1.0,\"elements\":["), "a group child of a horizontal carries its weight too")
        XCTAssertTrue(html.contains("{\"type\":\"grid\",\"maxWidth\":25.0,\"maxWidthUnit\":\"text\",\"fillLastRow\":true,\"visibilityInput\":\"show\",\"elements\":["))
        XCTAssertTrue(html.contains("{\"type\":\"grid\",\"maxWidth\":1.0,\"maxWidthUnit\":\"screen\",\"fillLastRow\":false,\"elements\":["))
        XCTAssertTrue(html.contains("class=\\\"editElement verticalLayout\\\""), "verticalLayout on the edit's div")
        XCTAssertTrue(html.contains("class=\\\"sliderElement verticalLayout\\\""), "and on the slider with showValue")
        XCTAssertTrue(html.contains("{\"type\":\"transform\",\"originX\":0.5,\"originY\":0.8,\"transformInputs\":[{\"as\":\"rotate\",\"buffer\":\"percent\",\"value\":null,\"min\":0.0,\"max\":100.0,\"mapMin\":-2.35,\"mapMax\":2.35,\"clamp\":true},{\"as\":\"opacity\",\"buffer\":\"fade\",\"value\":null,\"min\":0.0,\"max\":1.0,\"mapMin\":0.0,\"mapMax\":1.0,\"clamp\":false}],\"visibilityInput\":\"show\",\"elements\":["))
        XCTAssertTrue(html.contains("{\"as\":\"scale\",\"buffer\":null,\"value\":0.1,"))
        XCTAssertTrue(html.contains("\"plotLeft\":0.0,\"plotTop\":0.0,\"plotRight\":1.0,\"plotBottom\":1.0"))
        XCTAssertTrue(html.contains("\"colorScale\":[\"#0000FF00\",\"#FF0000C0\"]"), "eight-digit colours where the alpha is not ff")
    }

    // MARK: - view-vertical-layout

    func testVerticalLayoutStacksLabelAboveTheControlLeftAligned() throws {
        let experiment = try load("""
            <value label="Frequency" unit="Hz" verticalLayout="true"><input>v</input></value>
            <edit label="Length" unit="m" verticalLayout="true"><output>v</output></edit>
            <toggle label="Run" verticalLayout="true"><output>show</output></toggle>
            <dropdown label="Choice" verticalLayout="true"><map value="1">one</map><map value="2">two</map><output>v</output></dropdown>
            <slider label="Level" minValue="0" maxValue="10" showValue="true" verticalLayout="true"><output>v</output></slider>
            <value label="Default" unit="Hz"><input>v</input></value>
            """)
        let (controller, rows) = try self.rows(experiment)
        defer { _ = controller }
        for row in rows {
            layout(row, width: 600)
        }
        let value = try XCTUnwrap(rows[0] as? ExperimentValueView)
        let edit = try XCTUnwrap(rows[1] as? ExperimentEditView)
        let toggle = try XCTUnwrap(rows[2] as? ExperimentSwitchView)
        let dropdown = try XCTUnwrap(rows[3] as? ExperimentDropdownView)
        let slider = try XCTUnwrap(rows[4] as? ExperimentSliderView)
        XCTAssertTrue(value.descriptor.verticalLayout)

        let pairs: [(String, UILabel, UIView)] = [
            ("value", value.label, value.valueLabel), ("edit", edit.label, edit.textField), ("toggle", toggle.label, toggle.switchUI),
            ("dropdown", dropdown.label, dropdown.dropdown), ("slider", slider.label, slider.sliderValue)
        ]
        for (name, label, control) in pairs {
            XCTAssertGreaterThanOrEqual(label.frame.width, 560, "\(name): the label takes the full width")
            XCTAssertGreaterThan(label.frame.height, 0, "\(name): the label has its own line")
            XCTAssertGreaterThanOrEqual(control.frame.minY, label.frame.maxY - 0.5, "\(name): the control sits below the label")
            XCTAssertEqual(label.textAlignment, .natural, "\(name): left-aligned")
            XCTAssertLessThanOrEqual(label.frame.minX, 10.5, "\(name): at the left edge")
            XCTAssertLessThanOrEqual(control.frame.minX, 10.5, "\(name): and so is the control")
        }
        //the controls take the full width where they can stretch
        XCTAssertGreaterThanOrEqual(edit.textField.frame.width, 500)
        XCTAssertGreaterThanOrEqual(dropdown.dropdown.frame.width, 560)
        XCTAssertGreaterThanOrEqual(slider.sliderValue.frame.width, 560)
        //the slider: label, value and slider in three rows
        XCTAssertGreaterThanOrEqual(slider.uiSlider.frame.minY, slider.sliderValue.frame.maxY - 0.5)
        XCTAssertEqual(slider.frame.height, slider.sizeThatFits(CGSize(width: 600, height: 1000)).height, accuracy: 0.5)

        //the default stays side by side, label right-aligned in the left half
        let plain = try XCTUnwrap(rows[5] as? ExperimentValueView)
        XCTAssertFalse(plain.descriptor.verticalLayout)
        XCTAssertEqual(plain.label.textAlignment, .right)
        XCTAssertLessThanOrEqual(plain.label.frame.maxX, 300.5)
        XCTAssertGreaterThanOrEqual(plain.valueLabel.frame.minX, 299.5)
        XCTAssertEqual(plain.label.frame.minY, plain.valueLabel.frame.minY, accuracy: 0.5)
    }

    func testWithoutALabelTheControlTakesTheRowAndInfoAndButtonKeepTheirSize() throws {
        let experiment = try load("""
            <value unit="%"><input>v</input></value>
            <edit unit="s"><output>v</output></edit>
            <toggle><output>show</output></toggle>
            <dropdown><map value="1">one</map><map value="2">two</map><output>v</output></dropdown>
            <graph><input axis="x">v</input><input axis="y">v</input></graph>
            <info />
            <info label="text" />
            <button><input type="value">1</input><output>v</output></button>
            <button label="Go"><input type="value">1</input><output>v</output></button>
            <value label="With" verticalLayout="true"><input>v</input></value>
            <graph label="Titled"><input axis="x">v</input><input axis="y">v</input></graph>
            <slider minValue="0" maxValue="10" showValue="true"><output>v</output></slider>
            """)
        let (controller, rows) = try self.rows(experiment)
        defer { _ = controller }
        for row in rows {
            layout(row, width: 600)
        }
        let value = try XCTUnwrap(rows[0] as? ExperimentValueView)
        let edit = try XCTUnwrap(rows[1] as? ExperimentEditView)
        let toggle = try XCTUnwrap(rows[2] as? ExperimentSwitchView)
        let dropdown = try XCTUnwrap(rows[3] as? ExperimentDropdownView)
        let slider = try XCTUnwrap(rows[11] as? ExperimentSliderView)

        let pairs: [(String, UILabel, UIView)] = [
            ("value", value.label, value.valueLabel), ("edit", edit.label, edit.textField), ("toggle", toggle.label, toggle.switchUI),
            ("dropdown", dropdown.label, dropdown.dropdown), ("slider", slider.label, slider.sliderValue)
        ]
        for (name, label, control) in pairs {
            XCTAssertTrue(label.isHidden, "\(name): no label view")
            XCTAssertLessThanOrEqual(control.frame.minX, 10.5, "\(name): the control starts at the left")
            XCTAssertLessThan(control.frame.midY, max(label.frame.height, 1) + control.frame.height, "\(name): in the only row, not below an empty label row")
        }
        XCTAssertGreaterThanOrEqual(edit.textField.frame.width, 500, "the field takes the row, minus its unit")
        XCTAssertGreaterThanOrEqual(dropdown.dropdown.frame.width, 560)
        XCTAssertGreaterThanOrEqual(slider.sliderValue.frame.width, 560)
        XCTAssertEqual(value.frame.height, value.valueLabel.frame.height, accuracy: 0.5, "no label row")

        //a graph without a label has no title row
        let untitled = try XCTUnwrap(rows[4] as? ExperimentGraphView)
        let titled = try XCTUnwrap(rows[10] as? ExperimentGraphView)
        for graph in [untitled, titled] {
            graph.frame = CGRect(x: 0, y: 0, width: 400, height: 200)
            graph.setNeedsLayout()
            graph.layoutIfNeeded()
        }
        XCTAssertLessThan(untitled.layoutManager.graphFrame.minY, 6)
        XCTAssertGreaterThan(titled.layoutManager.graphFrame.minY, untitled.layoutManager.graphFrame.minY + 10)

        //info and button keep their size with an empty caption
        let fits = CGSize(width: 600, height: 1000)
        XCTAssertEqual(rows[5].sizeThatFits(fits).height, rows[6].sizeThatFits(fits).height, accuracy: 0.5, "an empty info is one line tall")
        XCTAssertEqual(rows[7].sizeThatFits(fits).height, rows[8].sizeThatFits(fits).height, accuracy: 0.5, "an empty button keeps its height")

        //the web markup omits the label span without a label and carries the verticalLayout class with one
        let views = try XCTUnwrap(experiment.viewDescriptors?.first?.views)
        XCTAssertFalse(views[0].generateViewHTMLWithID(0).contains("class=\"label\""))
        XCTAssertFalse(views[1].generateViewHTMLWithID(1).contains("class=\"label\""))
        XCTAssertFalse(views[2].generateViewHTMLWithID(2).contains("class=\"label\""))
        XCTAssertFalse(views[3].generateViewHTMLWithID(3).contains("class=\"label\""))
        XCTAssertFalse(views[11].generateViewHTMLWithID(11).contains("class=\"label\""))
        XCTAssertFalse(views[11].generateViewHTMLWithID(11).contains("verticalLayout"), "no class without a label")
        let with = views[9].generateViewHTMLWithID(9)
        XCTAssertTrue(with.contains("valueElement adjustableColor verticalLayout"), with)
        XCTAssertTrue(with.contains("<span class=\"label\">With</span>"))
    }

    // MARK: - grid-screen-unit

    func testGridScreenUnitCountsColumnsInWindowShorterSides() throws {
        let experiment = try load("""
            <grid maxWidth="1" maxWidthUnit="screen"><info label="a" /><info label="b" /><info label="c" /><info label="d" /></grid>
            <grid maxWidth="0.5" maxWidthUnit="SCREEN"><info label="a" /><info label="b" /></grid>
            <grid maxWidth="10"><info label="a" /></grid>
            """)
        let views = try XCTUnwrap(experiment.viewDescriptors?.first?.views)
        XCTAssertEqual(try XCTUnwrap(views[0] as? GridViewDescriptor).maxWidthUnit, .screen)
        XCTAssertEqual(try XCTUnwrap(views[1] as? GridViewDescriptor).maxWidthUnit, .screen, "the enum matches case-insensitively")
        XCTAssertEqual(try XCTUnwrap(views[2] as? GridViewDescriptor).maxWidthUnit, .text, "text is the default")

        let (controller, rows) = try self.rows(experiment)
        defer { _ = controller }
        //A phone window of 411 x 891 points: maxWidth 1 screen = 411 points, whichever way the window is turned
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 411, height: 891))
        let host = UIView(frame: window.bounds)
        window.addSubview(host)
        for row in rows {
            host.addSubview(row)
        }
        let grid = try group(rows[0])
        XCTAssertEqual(grid.gridColumns(width: 411), 1, "portrait: the available width is the shorter side")
        XCTAssertEqual(grid.gridColumns(width: 891), 3, "landscape: the width is the long side, the unit stays the shorter one")
        XCTAssertEqual(grid.gridColumns(width: 891, windowSize: CGSize(width: 891, height: 411)), 3)
        XCTAssertEqual(grid.gridColumns(width: 411, windowSize: CGSize(width: 891, height: 411)), 1)

        layout(grid, width: 411)
        XCTAssertGreaterThanOrEqual(grid.childModules[1].frame.minY, grid.childModules[0].frame.maxY - 0.5)
        layout(grid, width: 891)
        XCTAssertEqual(grid.childModules[2].frame.minY, grid.childModules[0].frame.minY, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(grid.childModules[3].frame.minY, grid.childModules[0].frame.maxY - 0.5)

        //half a screen gives two columns in portrait
        let half = try group(rows[1])
        layout(half, width: 411)
        XCTAssertEqual(half.childModules[1].frame.minY, half.childModules[0].frame.minY, accuracy: 0.5)
        XCTAssertEqual(half.childModules[1].frame.midX, 411 * 0.75, accuracy: 1)

        //the text unit is the footnote line height, independent of the window
        let text = try group(rows[2])
        XCTAssertEqual(text.gridColumns(width: 10 * unit), 1)
        XCTAssertEqual(text.gridColumns(width: 10 * unit + 1), 2)
    }

    func testTheSkeletonCarriesTheGroups() throws {
        let path = try XCTUnwrap(Bundle(for: ViewGroupTests.self).path(forResource: "full-skeleton", ofType: "phyphox"))
        let experiment = try ExperimentSerialization.readExperimentFromURL(URL(fileURLWithPath: path))
        let views = try XCTUnwrap(experiment.viewDescriptors).flatMap { $0.views }
        XCTAssertTrue(views.contains { $0 is HorizontalViewDescriptor })
        XCTAssertTrue(views.contains { $0 is GridViewDescriptor })
        XCTAssertTrue(views.contains { ($0 as? StackViewDescriptor)?.children.contains { $0 is TransformViewDescriptor } ?? false })
    }
}
