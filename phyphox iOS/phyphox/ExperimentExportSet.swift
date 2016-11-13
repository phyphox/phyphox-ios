//
//  ExperimentExportSet.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation

enum ExportFileFormat {
    case CSV(separator: String, decimalPoint: String)
    case Excel
    
    func isCSV() -> Bool {
        switch self {
        case .CSV(_):
            return true
        default:
            return false
        }
    }
}

let exportTypes = [("Excel", ExportFileFormat.Excel),
                   ("CSV (Comma, decimal point)", ExportFileFormat.CSV(separator: ",", decimalPoint: ".")),
                   ("CSV (Tabulator, decimal point)", ExportFileFormat.CSV(separator: "\t", decimalPoint: ".")),
                   ("CSV (Semicolon, decimal point)", ExportFileFormat.CSV(separator: ";", decimalPoint: ".")),
                   ("CSV (Tabulator, decimal comma)", ExportFileFormat.CSV(separator: "\t", decimalPoint: ",")),
                   ("CSV (Semicolon, decimal comma)", ExportFileFormat.CSV(separator: ";", decimalPoint: ","))]

final class ExperimentExportSet {
    private let name: String
    private let data: [(name: String, buffer: DataBuffer)]
    
    weak var translation: ExperimentTranslationCollection?
    
    var localizedName: String {
        return translation?.localize(name) ?? name
    }
    
    var localizedData: [(name: String, buffer: DataBuffer)] {
        var t: [(name: String, buffer: DataBuffer)] = []
        t.reserveCapacity(data.count)
        
        for entry in data {
            let name = entry.name
            
            t.append((name: translation?.localize(name) ?? name, buffer: entry.buffer))
        }
        
        return t
    }
    
    init(name: String, data: [(name: String, buffer: DataBuffer)], translation: ExperimentTranslationCollection?) {
        self.translation = translation
        self.name = name
        self.data = data
    }
    
    func serialize(format: ExportFileFormat, additionalInfo: AnyObject?) -> AnyObject? {
        switch format {
        case .CSV(let separator, let decimalPoint):
            return serializeToCSVWithSeparator(separator, decimalPoint: decimalPoint)
        case .Excel:
            return serializeToExcel(additionalInfo as! JXLSWorkBook)
        }
    }
    
    private func serializeToCSVWithSeparator(separator: String, decimalPoint: String) -> NSData? {
        var string = ""
        
        var index = 0
        
        let formatter = NSNumberFormatter()
        formatter.maximumSignificantDigits = 10
        formatter.minimumSignificantDigits = 10
        formatter.decimalSeparator = decimalPoint
        formatter.numberStyle = .ScientificStyle
        
        func format(n: Double) -> String {
            return formatter.stringFromNumber(NSNumber(double: n))!
        }
        
        while true {
            var line = ""
            
            var addedValue = false
            
            
            if index == 0 {
                for (j, entry) in localizedData.enumerate() {
                    if j == 0 {
                        line += "\"\(entry.name)\""
                    }
                    else {
                        line += separator + "\"\(entry.name)\""
                    }
                }
                
                addedValue = true
            }
            else {
                for (j, entry) in localizedData.enumerate() {
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
        
        return string.characters.count > 0 ? string.dataUsingEncoding(NSUTF8StringEncoding) : nil
    }
    
    private func serializeToExcel(workbook: JXLSWorkBook) -> JXLSWorkSheet {
        let sheet = workbook.workSheetWithName(localizedName)
        
        var i = 0
        
        while true {
            var addedValue = false
            
            if i == 0 {
                addedValue = true
                for (j, entry) in localizedData.enumerate() {
                    sheet.setCellAtRow(0, column: UInt32(j), toString: entry.name)
                }
            }
            else {
                for (j, entry) in localizedData.enumerate() {
                    let value = entry.buffer.objectAtIndex(i-1)
                    
                    if value != nil {
                        addedValue = true
                        sheet.setCellAtRow(UInt32(i), column: UInt32(j), toDoubleValue: value!)
                    }
                }
            }
            
            if !addedValue {
                break
            }
            
            i += 1
        }
        
        return sheet
    }
}
