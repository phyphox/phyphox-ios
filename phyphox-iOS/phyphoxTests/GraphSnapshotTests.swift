//
//  GraphSnapshotTests.swift
//  phyphoxTests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
import SnapshotTesting
@testable import phyphox

//Golden images of the graph elements, over the graphs-* fixtures in phyphox-docs fixtures/views/
//(test-matrix row graph-snapshots). Separate from the other view elements because these are
//drawn by OpenGL: the plot lives in a GLKView, which renders through a real context and does not
//appear in a layer-based capture at all - the view has to be in a key window and captured from
//the rendered hierarchy, which is why the row is T1 rather than T0.
//
//Same fixtures, naming and configuration matrix as the non-graph goldens, under
//phyphoxTests/Snapshots/graphs/<fixture>/<element>.<configuration>.png. The follow-system theme
//spot checks are not repeated here; the contract puts them on one fixture, and that is values.
final class GraphSnapshotTests: XCTestCase {
    private static let fixtures = ["graphs-styles", "graphs-axes", "graphs-special"]

    //The GPU is not bit-identical across machines: antialiased lines and the colour-map
    //interpolation differ in the last bits between a development Mac and a CI runner. The
    //tolerance is deliberately tight enough that a changed curve, scale or label still fails.
    private static let precision: Float = 0.99
    private static let perceptualPrecision: Float = 0.98

    private struct Configuration {
        let name: String
        let width: CGFloat
        let style: UIUserInterfaceStyle
        let contentSize: UIContentSizeCategory
        let rightToLeft: Bool

        var appMode: String { style == .dark ? Utility.DARK_MODE : Utility.LIGHT_MODE }

        var traits: UITraitCollection {
            UITraitCollection(traitsFrom: [
                UITraitCollection(userInterfaceStyle: style),
                UITraitCollection(preferredContentSizeCategory: contentSize),
                UITraitCollection(layoutDirection: rightToLeft ? .rightToLeft : .leftToRight),
                UITraitCollection(horizontalSizeClass: width > 500 ? .regular : .compact),
                //1x rather than the 2x of the other goldens: what these pin is the curve, the
                //scale and the labels, not hairline antialiasing - and at 2x the colour maps
                //alone are two megabytes of gradient each, in a repository that keeps its
                //goldens in plain git
                UITraitCollection(displayScale: 1)
            ])
        }
    }

    private static let configurations: [Configuration] = {
        var configurations: [Configuration] = []
        for (widthName, width) in [("phone", CGFloat(390)), ("tablet", CGFloat(834))] {
            for (styleName, style) in [("light", UIUserInterfaceStyle.light), ("dark", .dark)] {
                for (scaleName, scale) in [("", UIContentSizeCategory.large),
                                           ("-xxxl", .extraExtraExtraLarge)] {
                    configurations.append(Configuration(name: "\(styleName)-\(widthName)\(scaleName)",
                                                        width: width, style: style,
                                                        contentSize: scale, rightToLeft: false))
                }
            }
        }
        configurations.append(Configuration(name: "rtl-phone", width: 390, style: .light,
                                            contentSize: .large, rightToLeft: true))
        return configurations
    }()

    private func snapshotDirectory(fixture: String) -> String {
        return DocsCorpus.repositoryRoot
            .appendingPathComponent("phyphox-iOS/phyphoxTests/Snapshots/graphs", isDirectory: true)
            .appendingPathComponent(fixture, isDirectory: true)
            .path
    }

    private func slug(_ label: String) -> String {
        let allowed = label.lowercased().map { character -> Character in
            return character.isLetter || character.isNumber ? character : "-"
        }
        return String(allowed).split(separator: "-", omittingEmptySubsequences: true).joined(separator: "-")
    }

    ///The graph elements of one fixture, activated so they pull their (static) buffer values in
    private func graphs(of url: URL) throws -> [(key: String, view: UIView)] {
        let experiment = try ExperimentSerialization.readExperimentFromURL(url)
        var graphs: [(key: String, view: UIView)] = []
        var used: Set<String> = []

        for collection in experiment.viewDescriptors ?? [] {
            let modules = ExperimentViewModuleFactory.createViews(collection, resourceFolder: experiment.resourceFolder)
            for (index, module) in modules.enumerated() {
                guard let view = module.view else { continue }
                let descriptor = index < collection.views.count ? collection.views[index] : nil
                var key = slug(descriptor?.localizedLabel ?? "")
                if key.isEmpty { key = "graph-\(index)" }
                while used.contains(key) { key += "-2" }
                used.insert(key)

                if var dynamic = view as? DynamicViewModule {
                    dynamic.active = true
                    dynamic.setNeedsUpdate()
                }
                graphs.append((key: key, view: view))
            }
        }

        return graphs
    }

    // phyphox-test: graph-snapshots
    func testGraphSnapshots() throws {
        let directory = try DocsCorpus.docsDirectory("fixtures/views", notTestedNotice: "graph snapshots")
        var rendered = 0

        //One window for the whole run: the GL views only draw once they are in a visible window
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 834, height: 1200))
        window.isHidden = false
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        for fixture in GraphSnapshotTests.fixtures {
            let url = directory.appendingPathComponent("\(fixture).phyphox")
            guard FileManager.default.fileExists(atPath: url.path) else {
                XCTFail("the fixture \(fixture).phyphox is missing from \(directory.path)")
                continue
            }

            for configuration in GraphSnapshotTests.configurations {
                //Set before the graphs are built: the grid and the plot read the colours of the
                //app's own theme setting in their initialisers
                UserDefaults.standard.set(configuration.appMode,
                                          forKey: SettingBundleHelper.UserDefaultKeys.APP_MODE.rawValue)

                let graphs = try self.graphs(of: url)
                XCTAssertFalse(graphs.isEmpty, "\(fixture) produced no graph elements")

                for (key, view) in graphs {
                    let size = view.sizeThatFits(CGSize(width: configuration.width,
                                                        height: .greatestFiniteMagnitude))
                    let height = max(size.height, 200)

                    let host = UIView(frame: CGRect(x: 0, y: 0, width: configuration.width, height: height))
                    host.overrideUserInterfaceStyle = configuration.style
                    if #available(iOS 17.0, *) {
                        host.traitOverrides.preferredContentSizeCategory = configuration.contentSize
                        host.traitOverrides.layoutDirection = configuration.rightToLeft ? .rightToLeft : .leftToRight
                        host.traitOverrides.horizontalSizeClass = configuration.width > 500 ? .regular : .compact
                    }
                    host.backgroundColor = UIColor(named: "mainBackground") ?? kBackgroundColor
                    view.semanticContentAttribute = configuration.rightToLeft ? .forceRightToLeft : .unspecified
                    view.frame = host.bounds
                    host.addSubview(view)

                    //In the window, laid out and given a turn of the run loop: the GL views draw
                    //on a display-link tick, and nothing of the plot exists before they have
                    window.addSubview(host)
                    host.setNeedsLayout()
                    host.layoutIfNeeded()
                    if let listener = view as? DisplayLinkListener {
                        listener.display(DisplayLink(refreshRate: 0))
                    }
                    RunLoop.current.run(until: Date().addingTimeInterval(0.2))

                    let failure = verifySnapshot(
                        of: host,
                        as: .image(drawHierarchyInKeyWindow: true,
                                   precision: GraphSnapshotTests.precision,
                                   perceptualPrecision: GraphSnapshotTests.perceptualPrecision,
                                   size: CGSize(width: configuration.width, height: height),
                                   traits: configuration.traits),
                        named: configuration.name,
                        snapshotDirectory: snapshotDirectory(fixture: fixture),
                        testName: key)
                    if let failure = failure {
                        XCTFail("\(fixture)/\(key)/\(configuration.name): \(failure)")
                    }
                    rendered += 1
                    host.removeFromSuperview()
                }
            }
        }

        XCTAssertGreaterThan(rendered, 0, "no graph was rendered - fixture layout changed?")
    }
}
