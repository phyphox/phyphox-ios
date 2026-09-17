//
//  ViewSnapshotTests.swift
//  phyphoxTests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
import SnapshotTesting
@testable import phyphox

//Golden images of the non-graph view elements over phyphox-docs fixtures/views/ (test-matrix row
//view-snapshots), rendered from parsed descriptors by the real view factory in the README's matrix
//(light/dark, two font scales, phone/tablet width, one RTL pass). Graphs need GL: row graph-snapshots (T1).
final class ViewSnapshotTests: XCTestCase {
    //The five non-graph fixtures, in the order the README lists them
    private static let fixtures = ["values", "edits", "buttons-toggles", "sliders-dropdowns",
                                   "info-separator-image"]

    private struct Configuration {
        let name: String
        let width: CGFloat
        let style: UIUserInterfaceStyle
        let contentSize: UIContentSizeCategory
        let rightToLeft: Bool
        //set for the follow-system spot checks, which only run in the system appearance they pin
        let followsSystem: Bool

        //Colours come from the app's OWN theme setting (SettingBundleHelper), not the trait collection
        var appMode: String {
            if followsSystem { return Utility.SYSTEM_MODE }
            return style == .dark ? Utility.DARK_MODE : Utility.LIGHT_MODE
        }

        var traits: UITraitCollection {
            UITraitCollection(traitsFrom: [
                UITraitCollection(userInterfaceStyle: style),
                UITraitCollection(preferredContentSizeCategory: contentSize),
                UITraitCollection(layoutDirection: rightToLeft ? .rightToLeft : .leftToRight),
                //Without it the elements lay out in the compact-width form on every width
                UITraitCollection(horizontalSizeClass: width > 500 ? .regular : .compact),
                UITraitCollection(displayScale: 2)
            ])
        }
    }

    //Phone and tablet widths, both themes, two font scales, one RTL pass (layout mirroring only)
    private static let configurations: [Configuration] = {
        var configurations: [Configuration] = []
        for (widthName, width) in [("phone", CGFloat(390)), ("tablet", CGFloat(834))] {
            for (styleName, style) in [("light", UIUserInterfaceStyle.light), ("dark", .dark)] {
                for (scaleName, scale) in [("", UIContentSizeCategory.large),
                                           ("-xxxl", .extraExtraExtraLarge)] {
                    configurations.append(Configuration(name: "\(styleName)-\(widthName)\(scaleName)",
                                                        width: width, style: style,
                                                        contentSize: scale, rightToLeft: false,
                                                        followsSystem: false))
                }
            }
        }
        configurations.append(Configuration(name: "rtl-phone", width: 390, style: .light,
                                            contentSize: .large, rightToLeft: true,
                                            followsSystem: false))
        return configurations
    }()

    //Follow-system resolves against the SCREEN's appearance (UIColor.autoLightColor reads UIScreen.main),
    //which cannot be changed in-process, so each runs only when the simulator is in the appearance it pins
    private static let systemSpotChecks: [Configuration] = [
        Configuration(name: "system-light-phone", width: 390, style: .light, contentSize: .large,
                      rightToLeft: false, followsSystem: true),
        Configuration(name: "system-dark-phone", width: 390, style: .dark, contentSize: .large,
                      rightToLeft: false, followsSystem: true)
    ]

    private static let spotCheckFixture = "values"

    private func fixturesDirectory() throws -> URL {
        return try DocsCorpus.docsDirectory("fixtures/views", notTestedNotice: "view snapshots")
    }

    //One directory per fixture, one file per element and configuration
    private func snapshotDirectory(fixture: String) -> String {
        return DocsCorpus.repositoryRoot
            .appendingPathComponent("phyphox-iOS/phyphoxTests/Snapshots/views", isDirectory: true)
            .appendingPathComponent(fixture, isDirectory: true)
            .path
    }

    ///A file name for a view element's label: lower case, everything else folded to dashes
    private func slug(_ label: String) -> String {
        let allowed = label.lowercased().map { character -> Character in
            return character.isLetter || character.isNumber ? character : "-"
        }
        return String(allowed).split(separator: "-", omittingEmptySubsequences: true).joined(separator: "-")
    }

    ///The key an element is filed under: its label, or the element kind where it has none, deduplicated
    private func key(for descriptor: ViewDescriptor?, at index: Int, used: inout Set<String>) -> String {
        var base = slug(descriptor?.localizedLabel ?? "")
        if base.isEmpty {
            //Named after the element, not the position, which would shift whenever the fixture gains a line
            switch descriptor {
            case is SeparatorViewDescriptor: base = "separator"
            case is ImageViewDescriptor: base = "image"
            case is InfoViewDescriptor: base = "info"
            case is ButtonViewDescriptor: base = "button"
            case is SwitchViewDescriptor: base = "toggle"
            case is DropdownViewDescriptor: base = "dropdown"
            case is SliderViewDescriptor: base = "slider"
            case is EditViewDescriptor: base = "edit"
            case is ValueViewDescriptor: base = "value"
            default: base = "element-\(index)"
            }
        }

        var candidate = base
        var counter = 2
        while used.contains(candidate) {
            candidate = "\(base)-\(counter)"
            counter += 1
        }
        used.insert(candidate)
        return candidate
    }

    ///The modules the experiment screen would build, activated once so they pull their static values in
    private func elements(of url: URL) throws -> [(key: String, view: UIView)] {
        let experiment = try ExperimentSerialization.readExperimentFromURL(url)
        var elements: [(key: String, view: UIView)] = []
        var used: Set<String> = []

        for collection in experiment.viewDescriptors ?? [] {
            let modules = ExperimentViewModuleFactory.createViews(collection, resourceFolder: experiment.resourceFolder)
            for (index, module) in modules.enumerated() {
                guard let view = module.view else { continue }
                let descriptor = index < collection.views.count ? collection.views[index] : nil

                if var dynamic = view as? DynamicViewModule {
                    dynamic.active = true
                    dynamic.setNeedsUpdate()
                }
                //Dynamic elements pull their value on a display-link tick; one tick by hand settles them
                if let listener = view as? DisplayLinkListener {
                    listener.display(DisplayLink(refreshRate: 0))
                }
                elements.append((key: key(for: descriptor, at: index, used: &used), view: view))
            }
        }

        //Image decoding and layout on the main queue settle in one short run-loop turn
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))

        return elements
    }

    // phyphox-test: view-snapshots
    func testViewElementSnapshots() throws {
        let directory = try fixturesDirectory()
        var rendered = 0
        var skippedSystemChecks = 0

        for fixture in ViewSnapshotTests.fixtures {
            let url = directory.appendingPathComponent("\(fixture).phyphox")
            guard FileManager.default.fileExists(atPath: url.path) else {
                XCTFail("the fixture \(fixture).phyphox is missing from \(directory.path)")
                continue
            }

            var configurations = ViewSnapshotTests.configurations
            if fixture == ViewSnapshotTests.spotCheckFixture {
                configurations += ViewSnapshotTests.systemSpotChecks
            }

            for configuration in configurations {
                //A follow-system golden can only be produced while the simulator is in that appearance
                if configuration.followsSystem,
                   UIScreen.main.traitCollection.userInterfaceStyle != configuration.style {
                    skippedSystemChecks += 1
                    continue
                }

                //Set before the elements are built: they read the colours in their initialiser
                UserDefaults.standard.set(configuration.appMode,
                                          forKey: SettingBundleHelper.UserDefaultKeys.APP_MODE.rawValue)

                let elements = try self.elements(of: url)
                XCTAssertFalse(elements.isEmpty, "\(fixture) produced no view elements")

                for (key, view) in elements {
                    let size = view.sizeThatFits(CGSize(width: configuration.width,
                                                        height: .greatestFiniteMagnitude))
                    let height = max(size.height, 44)
                    if configuration.rightToLeft {
                        view.semanticContentAttribute = .forceRightToLeft
                    } else {
                        view.semanticContentAttribute = .unspecified
                    }

                    //Laid out before rendering (subviews are sized in layoutSubviews) and drawn on the
                    //experiment screen's background - the light text would be invisible on white
                    let host = UIView(frame: CGRect(x: 0, y: 0, width: configuration.width, height: height))
                    //Colours are picked up in traitCollectionDidChange, so the style must precede layout
                    host.overrideUserInterfaceStyle = configuration.style
                    if #available(iOS 17.0, *) {
                        host.traitOverrides.preferredContentSizeCategory = configuration.contentSize
                        host.traitOverrides.layoutDirection = configuration.rightToLeft ? .rightToLeft : .leftToRight
                        host.traitOverrides.horizontalSizeClass = configuration.width > 500 ? .regular : .compact
                    }
                    host.backgroundColor = UIColor(named: "mainBackground") ?? kBackgroundColor
                    view.frame = host.bounds
                    host.addSubview(view)
                    host.setNeedsLayout()
                    host.layoutIfNeeded()

                    //verifySnapshot, not assertSnapshot: only it takes the directory; goldens are keyed by element
                    let failure = verifySnapshot(
                        of: host,
                        as: .image(size: CGSize(width: configuration.width, height: height),
                                   traits: configuration.traits),
                        named: configuration.name,
                        snapshotDirectory: snapshotDirectory(fixture: fixture),
                        testName: key)
                    if let failure = failure {
                        XCTFail("\(fixture)/\(key)/\(configuration.name): \(failure)")
                    }
                    rendered += 1
                }
            }
        }

        XCTAssertGreaterThan(rendered, 0, "no view element was rendered - fixture layout changed?")
        if skippedSystemChecks > 0 {
            //Not a failure: the run simply cannot flip the simulator's system appearance
            print("view-snapshots: \(skippedSystemChecks) follow-system golden(s) skipped, the "
                  + "simulator is in \(UIScreen.main.traitCollection.userInterfaceStyle == .dark ? "dark" : "light") "
                  + "appearance - the other appearance is covered by the second run")
        }
    }
}
