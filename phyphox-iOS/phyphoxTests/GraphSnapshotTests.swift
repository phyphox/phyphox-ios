//
//  GraphSnapshotTests.swift
//  phyphoxTests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
import SnapshotTesting
@testable import phyphox

//Golden images of the graph elements over the graphs-* fixtures (test-matrix row graph-snapshots).
//Separate from the other views because the plot is a GLKView, which only renders in a key window (hence
//T1). Same naming and matrix, under phyphoxTests/Snapshots/graphs/<fixture>/<element>.<configuration>.png.
final class GraphSnapshotTests: XCTestCase {
    private static let fixtures = ["graphs-styles", "graphs-axes", "graphs-special"]

    //GPUs are not bit-identical across machines, so a small per-pixel difference is allowed (not a share
    //of freely differing pixels); the dithered colour-map gradients need more room than the line plots
    private static let precision: Float = 0.99
    private static func perceptualPrecision(forMap isMap: Bool) -> Float {
        return isMap ? 0.95 : 0.98
    }

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
                //1x, not 2x: what is pinned is curve, scale and labels, and 2x colour maps are megabytes each in git
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
                //Set before the graphs are built: grid and plot read the theme colours in their initialisers
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

                    //The GL views draw on a display-link tick, so nothing exists before a turn of the run loop
                    window.addSubview(host)
                    host.setNeedsLayout()
                    host.layoutIfNeeded()
                    if let listener = view as? DisplayLinkListener {
                        listener.display(DisplayLink(refreshRate: 0))
                    }
                    RunLoop.current.run(until: Date().addingTimeInterval(0.2))

                    func compare() -> String? {
                        return verifySnapshot(
                            of: host,
                            as: .image(drawHierarchyInKeyWindow: true,
                                       precision: GraphSnapshotTests.precision,
                                       perceptualPrecision: GraphSnapshotTests.perceptualPrecision(forMap: key.contains("map")),
                                       size: CGSize(width: configuration.width, height: height),
                                       traits: configuration.traits),
                            named: configuration.name,
                            snapshotDirectory: snapshotDirectory(fixture: fixture),
                            testName: key)
                    }

                    var failure = compare()

                    //A capture can land on an unsettled GPU frame (a colour map flaked on CI once), so an
                    //existing golden gets one more tick and attempt; a missing one is still reported from the first
                    let reference = (snapshotDirectory(fixture: fixture) as NSString)
                        .appendingPathComponent("\(key).\(configuration.name).png")
                    if failure != nil, FileManager.default.fileExists(atPath: reference) {
                        if let listener = view as? DisplayLinkListener {
                            listener.display(DisplayLink(refreshRate: 0))
                        }
                        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
                        failure = compare()
                    }

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
