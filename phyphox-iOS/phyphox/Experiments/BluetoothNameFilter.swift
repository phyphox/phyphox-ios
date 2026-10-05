//
//  BluetoothNameFilter.swift
//  phyphox
//
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import Foundation

///The name criteria of a bluetooth element: `name` is a substring test, `nameRegex` has to match the whole device
///name (rule ble-name-regex in phyphox-docs). Every criterion given has to hold. Equality is by the two pattern strings.
struct BluetoothNameFilter: Equatable {
    let name: String?
    let regex: String?
    private let pattern: NSRegularExpression?

    static let none = BluetoothNameFilter(name: nil)

    init(name: String?) {
        self.name = name
        self.regex = nil
        self.pattern = nil
    }

    ///Compiles the pattern once; a pattern that does not compile is the caller's parse error
    init(name: String?, regex: String?) throws {
        self.name = name
        self.regex = regex
        if let regex = regex, regex != "" {
            //Whole-name match with backtracking across alternatives (Java's matches()), not just a match starting at 0
            self.pattern = try NSRegularExpression(pattern: "^(?:" + regex + ")$")
        } else {
            self.pattern = nil
        }
    }

    var isEmpty: Bool {
        return (name ?? "") == "" && pattern == nil
    }

    func matches(_ deviceName: String) -> Bool {
        if let name = name, name != "", !deviceName.contains(name) {
            return false
        }
        if let pattern = pattern {
            let range = NSRange(location: 0, length: deviceName.utf16.count)
            if pattern.firstMatch(in: deviceName, options: [], range: range) == nil {
                return false
            }
        }
        return true
    }

    ///The criterion as shown to the user (scan dialog)
    var description: String {
        if let regex = regex, regex != "" {
            return regex
        }
        return name ?? ""
    }

    static func == (lhs: BluetoothNameFilter, rhs: BluetoothNameFilter) -> Bool {
        return lhs.name == rhs.name && lhs.regex == rhs.regex
    }
}
