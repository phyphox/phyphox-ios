//
//  ViewSnapshotTests.swift
//  phyphoxTests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
import SnapshotTesting
@testable import phyphox

//Golden images of the non-graph view elements, over the fixtures in phyphox-docs
//fixtures/views/ (test-matrix row view-snapshots). Every fixture is loaded through the real
//parser and its elements are built by the same factory the experiment screen uses, so what is
//pinned is the rendering of a parsed descriptor, not a hand-built view.
//
//Each element is rendered on its own, in the configuration matrix the fixtures' README states:
//light and dark, two font scales, phone and tablet width, plus one forced right-to-left layout
//pass. The goldens live in this repository - they are renderer output and platform-specific by
//nature - under phyphoxTests/Snapshots/views/<fixture>/<element>/<configuration>.png, so a
//failure names the fixture line it came from.
//
//The graph fixtures are deliberately absent: the OpenGL renderer needs a real context, which
//makes it row graph-snapshots (T1) instead.
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
        //nil for the two explicit themes; set for the follow-system spot checks, which only run
        //when the simulator's system appearance is the one they pin
        let followsSystem: Bool

        //The app picks its colours from its OWN light/dark setting (SettingBundleHelper), not
        //from the trait collection - it defaults to dark whatever the system does, and can be
        //set to light, dark or follow-system. The goldens drive that setting, which is what the
        //elements actually read.
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

    //Phone and tablet portrait widths, both themes, the default font scale and a large Dynamic
    //Type step, and one RTL smoke pass (layout mirroring only - no RTL language ships yet)
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

    //The follow-system setting resolves against the SCREEN's appearance (UIColor.autoLightColor
    //reads UIScreen.main), which no API changes from inside the process - so these two are spot
    //checks on one fixture rather than a doubling of the matrix, and each runs only when the
    //simulator is in the appearance it pins. The T0 workflow runs the suite once per appearance.
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

    //Snapshots go next to the tests, one directory per fixture and one file per element and
    //configuration, so the path reads like the fixture line it renders
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

    ///The key an element is filed under: its label, or the element kind where a label would be
    ///meaningless (separators and images carry none), and a counter where that repeats
    private func key(for descriptor: ViewDescriptor?, at index: Int, used: inout Set<String>) -> String {
        var base = slug(descriptor?.localizedLabel ?? "")
        if base.isEmpty {
            //Separators and images carry no label at all, and a button may take its label from a
            //buffer (dynamicLabel) - name those after the element instead of the position, which
            //would shift whenever the fixture gains a line
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

    ///Builds the elements of one fixture, ready to render: the modules the experiment screen
    ///would build, activated once so they pull their (static) buffer values in.
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
                //The dynamic elements pull their value on a display-link tick. The values here
                //are static, so one tick delivered by hand settles them - and does not depend on
                //a display link firing in a test host with no visible window.
                if let listener = view as? DisplayLinkListener {
                    listener.display(DisplayLink(refreshRate: 0))
                }
                elements.append((key: key(for: descriptor, at: index, used: &used), view: view))
            }
        }

        //Anything that still schedules work on the main queue (image decoding, layout) settles
        //in one short turn of the run loop
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
                //A follow-system golden can only be produced while the simulator is in that
                //appearance; the other one is left to the run that is
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

                    //These modules lay their subviews out in layoutSubviews from the bounds, so
                    //they have to be sized and laid out before anything is rendered - and they
                    //draw on the experiment screen's background (their text is the app's light
                    //text colour, invisible on the renderer's white), so they are rendered inside
                    //the same background the table view gives them.
                    let host = UIView(frame: CGRect(x: 0, y: 0, width: configuration.width, height: height))
                    //The elements pick their colours up in traitCollectionDidChange, so the
                    //appearance has to be in place before they are laid out - the renderer's own
                    //traits arrive too late for that
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

                    //verifySnapshot rather than assertSnapshot: only it takes the directory, and
                    //the goldens are keyed by fixture, element and configuration rather than by
                    //test function (element as the file stem, configuration as the name after it)
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
