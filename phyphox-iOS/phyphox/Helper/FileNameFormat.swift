//
//  FileNameFormat.swift
//  phyphox
//
//  Created by Sebastian Staacks on 07.08.26.
//  Copyright © 2026 RWTH Aachen. All rights reserved.
//

import Foundation

//Generates default file names for data exports, screenshots and saved states from a user-defined
// template (see settings). The template may contain placeholders like {title} or {date}, which
// are replaced by the corresponding values of the current experiment.
class FileNameFormat {

    static let prefKey = "fileNameFormat"
    static let defaultFormat = "{title} {date} {time}"

    private static let fallbackName = "phyphox"

    static func getFormat() -> String {
        guard let format = UserDefaults.standard.string(forKey: prefKey), !format.trimmingCharacters(in: .whitespaces).isEmpty else {
            return defaultFormat
        }
        return format
    }

    //Replaces all placeholders in the user's template. The result is not sanitized and may be
    // used as a title. Use sanitize() or formatFilename() if the result is used as a file name.
    static func format(title: String, timeReference: ExperimentTimeReference?) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "HH-mm-ss"

        let now = Date()
        var start = now
        var duration = 0.0
        if let timeReference = timeReference, let first = timeReference.timeMappings.first {
            start = first.systemTime
            duration = timeReference.getExperimentTime()
        }

        return getFormat()
            .replacingOccurrences(of: "{title}", with: title.isEmpty ? fallbackName : title)
            .replacingOccurrences(of: "{date}", with: dateFormatter.string(from: now))
            .replacingOccurrences(of: "{time}", with: timeFormatter.string(from: now))
            .replacingOccurrences(of: "{startDate}", with: dateFormatter.string(from: start))
            .replacingOccurrences(of: "{startTime}", with: timeFormatter.string(from: start))
            .replacingOccurrences(of: "{duration}", with: String(format: "%.1fs", locale: Locale(identifier: "en_US_POSIX"), duration))
    }

    //Removes characters that are problematic in file names
    static func sanitize(_ name: String) -> String {
        let sanitized = name.replacingOccurrences(of: "[\\\\/:*?\"<>|\\u0000-\\u001f]", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        return sanitized.isEmpty ? fallbackName : sanitized
    }

    //Formatted template, sanitized for use as a file name (without extension)
    static func formatFilename(title: String, timeReference: ExperimentTimeReference?) -> String {
        return sanitize(format(title: title, timeReference: timeReference))
    }
}
