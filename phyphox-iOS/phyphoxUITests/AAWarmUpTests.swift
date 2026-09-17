//
//  AAWarmUpTests.swift
//  phyphoxUITests
//
//  Created by Sebastian Staacks on 07.09.26.
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest

//Runs first in every UI test invocation (alphabetical order): xcodebuild reinstalls the app before the first test,
//and on a slow CI runner that first launch may never attach to the automation session. Whichever test ran first
//then failed while everything after it passed (t1 interaction job, 2026-09-07). Taking that launch here, with the
//failure expected but not required, keeps a runner hiccup from reading as an app defect.
final class AAWarmUpTests: XCTestCase {
    func testColdLaunchAfterInstall() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLocale", "en_US", "-AppleLanguages", "(en)"]
        let options = XCTExpectedFailure.Options()
        options.isStrict = false
        XCTExpectFailure("the first launch after the reinstall may not attach on a slow runner", options: options) {
            app.launch()
        }
        app.terminate()
    }
}
