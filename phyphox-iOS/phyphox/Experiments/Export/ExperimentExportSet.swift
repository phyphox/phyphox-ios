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

struct ExperimentExportSet {
    let name: String
    let data: [(name: String, buffer: DataBuffer)]
    
    init(name: String, data: [(name: String, buffer: DataBuffer)]) {
        self.name = name
        self.data = data
    }
    
    func serializeToCSV(separator: String, decimalPoint: String) -> Data? {
        var string = ""
        
        var index = 0
        
        let formatter = NumberFormatter()
        formatter.maximumSignificantDigits = 10
        formatter.minimumSignificantDigits = 10
        formatter.decimalSeparator = decimalPoint
        formatter.numberStyle = .scientific
        
        func format(_ n: Double) -> String {
            return formatter.string(from: NSNumber(value: n as Double))!
        }
        
        while true {
            var line = ""
            
            var addedValue = false
            
            
            if index == 0 {
                for (j, entry) in data.enumerated() {
                    if j == 0 {
                        line += "\"\(getSecureName(entry.name))\""
                    }
                    else {
                        line += separator + "\"\(getSecureName(entry.name))\""
                    }
                }
                
                addedValue = true
            }
            else {
                for (j, entry) in data.enumerated() {
                    let val = entry.buffer.objectAtIndex(index-1)
                    
                    let str = val != nil ? format(val!) : "\"\""
                    
                    if j == 0 {
                        line += "\n" + str
                    }
                    else {
                        line += separator + str
                    }
                    
                    if val != nil {
                        addedValue = true
                    }
                }
            }
            
            if addedValue {
                string += line
            }
            else {
                break
            }
            
            index += 1
        }
        
        return string.count > 0 ? string.data(using: .utf8) : nil
    }
    
    //Writes this set as one sheet into an xlsx file, laid out like the Android implementation
    //(DataExport.ExcelFormat): a bold header row, then one row per value of the first column,
    //with cells of shorter columns filled with the text "NaN"
    func serializeToXlsx(_ xlsx: XlsxWriter) throws {
        try xlsx.startSheet(name)

        xlsx.startRow()
        for entry in data {
            xlsx.stringCell(getSecureName(entry.name), bold: true)
        }
        xlsx.endRow()

        //Snapshot the buffers so the row count and cell values are consistent even if the
        //experiment keeps writing during the export
        let columns = data.map { $0.buffer.toArray() }
        for i in 0..<(columns.first?.count ?? 0) {
            xlsx.startRow()
            for column in columns {
                if i < column.count {
                    xlsx.numberCell(column[i])
                } else {
                    xlsx.stringCell("NaN")
                }
            }
            xlsx.endRow()
        }
        try xlsx.endSheet()
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
