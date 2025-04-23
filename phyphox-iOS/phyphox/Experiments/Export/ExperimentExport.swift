//
//  ExperimentExport.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation
import ZipZap
import libxlsxwriter

struct ExperimentExport: Equatable {
    let sets: [ExperimentExportSet]
    
    init(sets: [ExperimentExportSet]) {
        self.sets = sets
    }
    
    func runExport(_ format: ExportFileFormat, singleSet: Bool, filename: String, timeReference: ExperimentTimeReference?, callback: @escaping (_ errorMessage: String?, _ fileURL: URL?) -> Void) {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            autoreleasepool {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
                
                switch format {
                case .csv(let separator, let decimalPoint):
                    if singleSet {
                        let tmpFile = (NSTemporaryDirectory() as NSString).appendingPathComponent("\(filename) \(dateFormatter.string(from: Date())).csv")
                        
                        do { try FileManager.default.removeItem(atPath: tmpFile) } catch {}
                        
                        let tmpFileURL = URL(fileURLWithPath: tmpFile)
                        
                        
                        let set = self.sets.first!
                        
                        let data = set.serialize(format, additionalInfo: nil) as! Data?
                        
                        do {
                            try data!.write(to: URL(fileURLWithPath: tmpFile), options: [])
                            
                            mainThread {
                                callback(nil, tmpFileURL)
                            }
                        }
                        catch let error {
                            print("File write error: \(error)")
                            mainThread {
                                callback("Could not create csv file", nil)
                            }
                        }
                    }
                    else {
                        let tmpFile = (NSTemporaryDirectory() as NSString).appendingPathComponent("\(filename) \(dateFormatter.string(from: Date())).zip")
                        
                        do { try FileManager.default.removeItem(atPath: tmpFile) } catch {}
                        
                        let tmpFileURL = URL(fileURLWithPath: tmpFile)
                        
                        do {
                            let archive = try ZZArchive(url: tmpFileURL, options: [ZZOpenOptionsCreateIfMissingKey : NSNumber(value: true)])
                            
                            var entries = [ZZArchiveEntry]()
                            
                            for set in self.sets {
                                let data = set.serialize(format, additionalInfo: nil) as! Data?
                                
                                entries.append(ZZArchiveEntry(fileName: set.name + ".csv", compress: true, dataBlock: { error -> Data? in
                                    return data
                                }))
                            }
                            
                            //Metadata
                            var metaCSV = "\"property\"\(separator)\"value\"\n"
                            for metadata in Metadata.allNonSensorCases {
                                switch metadata {
                                case .uniqueId:
                                    continue
                                default:
                                    metaCSV += "\"\(metadata.identifier)\"\(separator)\"\(metadata.get(hash: "") ?? "")\"\n"
                                }
                            }
                            let data = metaCSV.data(using: .utf8)
                            entries.append(ZZArchiveEntry(fileName: "meta/device.csv", compress: true, dataBlock: { error -> Data? in
                                return data
                            }))
                            
                            //Time references
                            if let reference = timeReference {
                                let dateFormatter = DateFormatter()
                                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS 'UTC'XXX"
                                let formatter = NumberFormatter()
                                formatter.maximumSignificantDigits = 16
                                formatter.minimumSignificantDigits = 16
                                formatter.decimalSeparator = decimalPoint
                                formatter.numberStyle = .scientific
                                
                                var timeCSV = "\"event\"\(separator)\"experiment time\"\(separator)\"system time\"\(separator)\"system time text\"\n"
                                for mapping in reference.timeMappings {
                                    let dateString = dateFormatter.string(from: mapping.systemTime)
                                    timeCSV += "\"\(mapping.event.rawValue)\"\(separator)\(formatter.string(from: NSNumber(value: mapping.experimentTime)) ?? "NaN")\(separator)\(formatter.string(from: NSNumber(value: mapping.systemTime.timeIntervalSince1970)) ?? "NaN")\(separator)\"\(dateString)\"\n"
                                }
                                let timeData = timeCSV.data(using: .utf8)
                                entries.append(ZZArchiveEntry(fileName: "meta/time.csv", compress: true, dataBlock: { error -> Data? in
                                    return timeData
                                }))
                            }
                            
                            try archive.updateEntries(entries)
                            
                            mainThread {
                                callback(nil, tmpFileURL)
                            }
                            
                        }
                        catch let error {
                            print("Zip error: \(error)")
                            mainThread {
                                callback("Could not create csv file", nil)
                            }
                        }
                    }
                case .excel:
                    
                    let tmpFileXLSX = (NSTemporaryDirectory() as NSString).appendingPathComponent("\(filename) \(dateFormatter.string(from: Date())).xlsx")
                    do { try FileManager.default.removeItem(atPath: tmpFileXLSX) } catch {}
                    let tmpFileURL = URL(fileURLWithPath: tmpFileXLSX)
                    
                    let workbook: UnsafeMutablePointer<lxw_workbook>? = workbook_new(tmpFileXLSX)
                    let worksheet: UnsafeMutablePointer<lxw_worksheet>? = workbook_add_worksheet(workbook, "Metadata Device")
                    
                    let format_header: UnsafeMutablePointer<lxw_format>?
                    let format_1: UnsafeMutablePointer<lxw_format>?
                    
                    for set in self.sets {
                        _ = set.serialize(format, additionalInfo: workbook as AnyObject?)
                    }
                    
                    if !singleSet {
                       
                        format_header = workbook_add_format(workbook)
                        format_set_bold(format_header)
                        format_1 = workbook_add_format(workbook)
                        format_set_bg_color(format_1, 0xDDDDDD)
                        
                        worksheet_write_string(worksheet, 0, 0, "property", nil)
                        worksheet_write_string(worksheet, 0, 1, "value", nil)
                        
                        var i: UInt32 = 1;
                        for metadata in Metadata.allNonSensorCases {
                            switch metadata {
                            case .uniqueId:
                                continue
                            default:
                                worksheet_write_string(worksheet, i, 0, metadata.identifier, nil)
                                worksheet_write_string(worksheet, i, 1, metadata.get(hash: "") ?? "", nil)
                                _ = worksheet_set_column(worksheet, 0, 1, 25, nil)
                                i += 1
                            }
                        }
                        
                        //Time references
                        if let reference = timeReference {
                            let dateFormatter = DateFormatter()
                            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS 'UTC'XXX"
                            
                            let timeSheet = workbook_add_worksheet(workbook, "Metadata Time")
                            worksheet_write_string(timeSheet, 0, 0, "event", nil)
                            worksheet_write_string(timeSheet, 0, 1, "experiment time", nil)
                            worksheet_write_string(timeSheet, 0, 2, "system time", nil)
                            worksheet_write_string(timeSheet, 0, 3, "system time text", nil)
                            _ = worksheet_set_column(worksheet, 0, 3, 25, nil)
                            
                            i = 1
                            for mapping in reference.timeMappings {
                                let dateString = dateFormatter.string(from: mapping.systemTime)
                                worksheet_write_string(timeSheet, i, 0, mapping.event.rawValue, nil)
                                worksheet_write_string(timeSheet, i, 1, String(mapping.experimentTime), nil)
                                worksheet_write_string(timeSheet, i, 2, String(mapping.systemTime.timeIntervalSince1970), nil)
                                worksheet_write_string(timeSheet, i, 3, dateString, nil)
                                _ = worksheet_set_column(worksheet, 0, 3, 25, nil)
                                
                                i += 1
                            }
                        }
                        
                    }
                    
                    let error = workbook_close(workbook)
                    
                    if error == LXW_NO_ERROR {
                        mainThread {
                            callback(nil, tmpFileURL)
                        }
                    } else {
                        let message = String(cString: lxw_strerror(error))
                        print("Excel error: \(message)")
                        mainThread {
                            callback("Could not create xls file", nil)
                        }
                    }
                    
                }
            }
        }
    }
}
