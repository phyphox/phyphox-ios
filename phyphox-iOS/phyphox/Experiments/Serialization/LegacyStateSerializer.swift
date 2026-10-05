//
//  LegacyStateSerializer.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 26.05.17.
//  Copyright © 2017 RWTH Aachen. All rights reserved.
//

import Foundation

//The legacy saved state (phyphox up to 1.2): a single .phyphox file with the data in init attributes, a state-title and an
//events block. Read by the ordinary parser and kept loadable forever, but never written again since the container format
//of SavedState; what remains here is the rename of such a file in the collection.
final class LegacyStateSerializer {
    class func renameStateFile(customTitle: String, file: URL) throws {
        let data = try String(contentsOf: file, encoding: .utf8)
        let modifiedData = data.replacingOccurrences(
            of: "<state-title>.*<\\/state-title>",
            with: "<state-title>\(customTitle.xmlEscaped)</state-title>",
            options: .regularExpression
        )
        try modifiedData.write(to: file, atomically: true, encoding: .utf8)
    }
}
