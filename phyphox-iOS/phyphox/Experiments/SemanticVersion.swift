//
//  SemanticVersion.swift
//  phyphox
//
//  Created by Jonas Gessner on 11.09.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation

public struct SemanticVersion: Comparable {
    let major: UInt
    let minor: UInt
    let patch: UInt

    init(major: UInt, minor: UInt, patch: UInt) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init?(string: String) {
        let components = string.components(separatedBy: ".")

        guard components.count >= 2 else { return nil }

        guard let major = UInt(components[0]) else { return nil }
        guard let minor = UInt(components[1]) else { return nil }

        self.major = major
        self.minor = minor

        if components.count >= 3 {
            guard let patch = UInt(components[2]) else { return nil }

            self.patch = patch
        }
        else {
            self.patch = 0
        }
    }

    public static func <(lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        guard lhs.major <= rhs.major else { return false }
        guard lhs.major == rhs.major else { return true }

        guard lhs.minor <= rhs.minor else { return false }
        guard lhs.minor == rhs.minor else { return true }

        guard lhs.patch <= rhs.patch else { return false }
        guard lhs.patch == rhs.patch else { return true }

        return false
    }
}
