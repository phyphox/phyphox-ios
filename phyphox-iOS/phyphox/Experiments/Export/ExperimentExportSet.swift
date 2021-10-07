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
    
    func serialize(_ format: ExportFileFormat, additionalInfo: AnyObject?) -> AnyObject? {
        switch format {
        case .csv(let separator, let decimalPoint):
            return serializeToCSVWithSeparator(separator, decimalPoint: decimalPoint) as AnyObject
        case .excel:
            return serializeToExcel(additionalInfo as! JXLSWorkBook)
        }
    }
    
    private func serializeToCSVWithSeparator(_ separator: String, decimalPoint: String) -> Data? {
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
    
    private func serializeToExcel(_ workbook: JXLSWorkBook) -> JXLSWorkSheet {
        let sheet = workbook.workSheet(withName: name)
        
        var i = 0
        
        while true {
            var addedValue = false
            
            if i == 0 {
                addedValue = true
                for (j, entry) in data.enumerated() {
                    _ = sheet?.setCellAtRow(0, column: UInt32(j), to: getSecureName(entry.name))
                }
            }
            else {
                for (j, entry) in data.enumerated() {
                    let value = entry.buffer.objectAtIndex(i-1)
                    
                    if value != nil {
                        addedValue = true
                        _ = sheet?.setCellAtRow(UInt32(i), column: UInt32(j), toDoubleValue: value!)
                    }
                }
            }
            
            if !addedValue {
                break
            }
            
            i += 1
        }
        
        return sheet!
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
