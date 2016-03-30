//
//  ExperimentExportSet.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

enum ExportFileFormat {
    case CSV(separator: String)
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
        case .CSV(let separator):
            return serializeToCSVWithSeparator(separator)
        case .Excel:
            return serializeToExcel(additionalInfo as! JXLSWorkBook)
        }
    }
    
    private func serializeToCSVWithSeparator(separator: String) -> NSData? {
        var string = ""
        
        var index = 0
        
        let formatter = NSNumberFormatter()
        formatter.maximumFractionDigits = 3
        formatter.minimumIntegerDigits = 1
        formatter.decimalSeparator = "."
        
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
        
        let formatter = NSNumberFormatter()
        formatter.maximumFractionDigits = 3
        formatter.minimumIntegerDigits = 1
        formatter.decimalSeparator = "."
        
        func format(n: Double) -> String {
            return formatter.stringFromNumber(NSNumber(double: n))!
        }
        
        while true {
            var hadValue = false
            
            for (j, entry) in localizedData.enumerate() {
                if i == 0 {
                    hadValue = true
                    sheet.setCellAtRow(0, column: UInt32(j), toString: entry.name)
                }
                else {
                    let value = entry.buffer.objectAtIndex(i-1)
                    
                    if value != nil {
                        hadValue = true
                        sheet.setCellAtRow(UInt32(i), column: UInt32(j), toDoubleValue: value!)
                    }
                }
            }
            
            if !hadValue {
                break
            }
            
            i += 1
        }
        
        return sheet
    }
}
