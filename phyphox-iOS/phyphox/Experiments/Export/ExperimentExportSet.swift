//
//  ExperimentExportSet.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation

enum ExportFileFormat {
    case csv(separator: String, decimalPoint: String)
    case excel
    
    func isCSV() -> Bool {
        switch self {
        case .csv(_, _):
            return true
        default:
            return false
        }
    }
}

let exportTypes = [("Excel", ExportFileFormat.excel),
                   ("CSV (Comma, decimal point)", ExportFileFormat.csv(separator: ",", decimalPoint: ".")),
                   ("CSV (Tabulator, decimal point)", ExportFileFormat.csv(separator: "\t", decimalPoint: ".")),
                   ("CSV (Semicolon, decimal point)", ExportFileFormat.csv(separator: ";", decimalPoint: ".")),
                   ("CSV (Tabulator, decimal comma)", ExportFileFormat.csv(separator: "\t", decimalPoint: ",")),
                   ("CSV (Semicolon, decimal comma)", ExportFileFormat.csv(separator: ";", decimalPoint: ","))]

func getSecureName(_ name: String) -> String {
    if name.starts(with: "=") || name.starts(with: "+") || name.starts(with: "-") || name.starts(with: "@") {
        return "'" + name
    }
    return name
}

//The values of an export set, copied out of its buffers under the data lock (ExperimentExport.snapshot) so an export of
//a running experiment never sees an analysis cycle half applied. Android does the same since 2b8d7acf.
struct ExperimentExportSetData {
    let name: String
    let columns: [(name: String, values: [Double])]

    //Rows, one entry per column, nil where a column has no value. The LONGEST column decides the row count (ruled 2026-08-25)
    var rowValues: [[Double?]] {
        let rows = columns.map({ $0.values.count }).max() ?? 0

        return (0..<rows).map { row in
            columns.map { row < $0.values.count ? $0.values[row] : nil }
        }
    }

    func serializeToCSV(separator: String, decimalPoint: String) -> Data? {
        let formatter = NumberFormatter()
        formatter.maximumSignificantDigits = 10
        formatter.minimumSignificantDigits = 10
        formatter.decimalSeparator = decimalPoint
        formatter.numberStyle = .scientific

        func format(_ n: Double) -> String {
            return formatter.string(from: NSNumber(value: n as Double))!
        }

        var string = ""
        for (j, entry) in columns.enumerated() {
            string += (j == 0 ? "" : separator) + "\"\(getSecureName(entry.name))\""
        }

        for row in rowValues {
            var line = ""
            for (j, value) in row.enumerated() {
                //A missing cell of a shorter column is padded NaN in every format on every platform (ruled 2026-08-25)
                line += (j == 0 ? "\n" : separator) + (value != nil ? format(value!) : "NaN")
            }
            string += line
        }

        return string.count > 0 ? string.data(using: .utf8) : nil
    }

    //Laid out like Android's DataExport.ExcelFormat: bold header, one row per value of the longest column, "NaN" padding
    func serializeToXlsx(_ xlsx: XlsxWriter) throws {
        try xlsx.startSheet(name)

        xlsx.startRow()
        for entry in columns {
            xlsx.stringCell(getSecureName(entry.name), bold: true)
        }
        xlsx.endRow()

        for row in rowValues {
            xlsx.startRow()
            for value in row {
                if let value = value {
                    xlsx.numberCell(value)
                } else {
                    xlsx.stringCell("NaN")
                }
            }
            xlsx.endRow()
        }
        try xlsx.endSheet()
    }
}

struct ExperimentExportSet {
    let name: String
    let data: [(name: String, buffer: DataBuffer)]
    
    init(name: String, data: [(name: String, buffer: DataBuffer)]) {
        self.name = name
        self.data = data
    }

    ///Copy of the values; exporting several sets takes all copies together under the data lock, see ExperimentExport.snapshot
    func snapshot() -> ExperimentExportSetData {
        return ExperimentExportSetData(name: name,
                                       columns: data.map { (name: $0.name, values: $0.buffer.toArray()) })
    }

    func serializeToCSV(separator: String, decimalPoint: String) -> Data? {
        return snapshot().serializeToCSV(separator: separator, decimalPoint: decimalPoint)
    }

    func rowValues() -> [[Double?]] {
        return snapshot().rowValues
    }

    func serializeToXlsx(_ xlsx: XlsxWriter) throws {
        try snapshot().serializeToXlsx(xlsx)
    }
}

extension ExperimentExportSet: Equatable {
    static func == (lhs: ExperimentExportSet, rhs: ExperimentExportSet) -> Bool {
        return lhs.data.elementsEqual(rhs.data, by: { (l, r) -> Bool in
            return l.buffer == r.buffer && l.name == r.name
        }) &&
            lhs.name == rhs.name
    }
}
