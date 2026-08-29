//
//  TranslationsBuildTests.swift
//  phyphoxTests
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import XCTest
@testable import phyphox

//Which languages this build enables, and how that compares to the canonical list and to Android
//(test-matrix row translations-build).
//
//The hard assertion is narrow on purpose: every language the build enables must actually load
//its strings. Everything else - a language the canonical list has and this build does not, or a
//difference between the platforms - is a WARNING printed into the report, because development
//drift is harmless and should stay visible rather than block. The release gate is T2, against
//the built artifact.
final class TranslationsBuildTests: XCTestCase {
    ///What the platforms spell differently, mapped onto the canonical BCP-47 code
    private static func normalize(_ code: String) -> String {
        switch code {
        case "zh_Hans", "zh-rCN": return "zh-Hans"
        case "zh_Hant", "zh-rTW": return "zh-Hant"
        case "sr_Latn", "sr-Latn", "b+sr+Latn": return "sr-Latn"
        default: return code
        }
    }

    ///The languages this build ships, as the bundle reports them
    private var enabledLanguages: Set<String> {
        return Set(Bundle.main.localizations
            .filter { $0 != "Base" }
            .map { TranslationsBuildTests.normalize($0) })
    }

    ///The canonical list, read from phyphox-docs without a YAML dependency: a flat sequence
    ///under "languages:", one "- code" per line
    private func canonicalLanguages() throws -> Set<String> {
        guard let docs = DocsCorpus.docs else {
            throw XCTSkip("phyphox-docs is not checked out next to this repository - language comparison not run")
        }
        let text = try String(contentsOf: docs.appendingPathComponent("languages.yml"), encoding: .utf8)
        var languages: Set<String> = []
        var inList = false
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("languages:") { inList = true; continue }
            if inList {
                guard trimmed.hasPrefix("- ") else {
                    if !trimmed.isEmpty && !trimmed.hasPrefix("#") { inList = false }
                    continue
                }
                languages.insert(TranslationsBuildTests.normalize(String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)))
            }
        }
        return languages
    }

    ///Android's build-enabled set, read from its build.gradle next to this repository
    private func androidLanguages() -> Set<String>? {
        let gradle = DocsCorpus.repositoryRoot.deletingLastPathComponent()
            .appendingPathComponent("phyphox-android/app/build.gradle")
        guard let text = try? String(contentsOf: gradle, encoding: .utf8),
              let line = text.components(separatedBy: .newlines).first(where: { $0.contains("def locales") }),
              let open = line.firstIndex(of: "["), let close = line.lastIndex(of: "]") else { return nil }
        let codes = line[line.index(after: open)..<close]
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " '\"")) }
            .filter { !$0.isEmpty }
        return Set(codes.map { TranslationsBuildTests.normalize($0) })
    }

    // phyphox-test: translations-build
    func testEveryEnabledLanguageLoadsItsStrings() throws {
        let enabled = enabledLanguages
        XCTAssertFalse(enabled.isEmpty, "the bundle reports no localizations at all")
        XCTAssertTrue(enabled.contains("en"), "English is always there")

        //A key that every translation carries: if the table is missing or unreadable, localized
        //lookup falls back to the key itself
        let key = "cancel"
        for language in enabled.sorted() {
            //The bundle stores them under the platform's own spelling, so denormalize by lookup
            let candidates = Bundle.main.localizations.filter { TranslationsBuildTests.normalize($0) == language }
            var loaded = false
            for candidate in candidates {
                guard let path = Bundle.main.path(forResource: candidate, ofType: "lproj"),
                      let bundle = Bundle(path: path) else { continue }
                let value = bundle.localizedString(forKey: key, value: nil, table: nil)
                if !value.isEmpty && value != key { loaded = true }
            }
            XCTAssertTrue(loaded, "\(language) is enabled but its strings do not load")
        }
    }

    // phyphox-test: translations-build
    func testDeviationsFromTheCanonicalListAreReported() throws {
        let enabled = enabledLanguages
        let canonical = try canonicalLanguages()
        XCTAssertFalse(canonical.isEmpty, "languages.yml lists no languages - format changed?")

        //Warnings, never failures: the release gate is T2, against the built artifact
        let missing = canonical.subtracting(enabled).sorted()
        let extra = enabled.subtracting(canonical).sorted()
        if missing.isEmpty && extra.isEmpty {
            print("translations-build: this build matches the canonical list (\(canonical.count) languages)")
        } else {
            if !missing.isEmpty {
                print("translations-build WARNING: canonical but not enabled here: \(missing.joined(separator: ", "))")
            }
            if !extra.isEmpty {
                print("translations-build WARNING: enabled here but not canonical: \(extra.joined(separator: ", "))")
            }
        }

        if let android = androidLanguages() {
            let onlyIOS = enabled.subtracting(android).sorted()
            let onlyAndroid = android.subtracting(enabled).sorted()
            if onlyIOS.isEmpty && onlyAndroid.isEmpty {
                print("translations-build: the platforms enable the same \(enabled.count) languages")
            } else {
                if !onlyIOS.isEmpty {
                    print("translations-build WARNING: enabled on iOS only: \(onlyIOS.joined(separator: ", "))")
                }
                if !onlyAndroid.isEmpty {
                    print("translations-build WARNING: enabled on Android only: \(onlyAndroid.joined(separator: ", "))")
                }
            }
        } else {
            print("translations-build: phyphox-android is not checked out next to this repository - "
                  + "no platform comparison")
        }
    }
}
