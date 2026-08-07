//
//  ExperimentExport.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation
import ZIPFoundation

struct ExperimentExport: Equatable {
    let sets: [ExperimentExportSet]
    
    init(sets: [ExperimentExportSet]) {
        self.sets = sets
    }
    
    //filename is expected to be a complete file name base (without extension), typically generated
    // from the user's template by FileNameFormat
    func runExport(_ format: ExportFileFormat, singleSet: Bool, filename: String, timeReference: ExperimentTimeReference?, callback: @escaping (_ errorMessage: String?, _ fileURL: URL?) -> Void) {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            autoreleasepool {
                switch format {
                case .csv(let separator, let decimalPoint):
                    if singleSet {
                        let tmpFile = (NSTemporaryDirectory() as NSString).appendingPathComponent("\(filename).csv")
                        
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
                        let tmpFile = (NSTemporaryDirectory() as NSString).appendingPathComponent("\(filename).zip")
                        
                        do { try FileManager.default.removeItem(atPath: tmpFile) } catch {}
                        
                        let tmpFileURL = URL(fileURLWithPath: tmpFile)
                        
                        do {
                            let archive = try Archive(url: tmpFileURL, accessMode: .create)

                            func addEntry(fileName: String, data: Data?) throws {
                                guard let data = data else {
                                    throw SerializationError.genericError(message: "No data for \(fileName).")
                                }
                                try archive.addEntry(with: fileName, type: .file, uncompressedSize: Int64(data.count), compressionMethod: .deflate, provider: { position, size in
                                    let start = Int(position)
                                    return data.subdata(in: start..<(start + size))
                                })
                            }

                            for set in self.sets {
                                let data = set.serialize(format, additionalInfo: nil) as! Data?

                                try addEntry(fileName: set.name + ".csv", data: data)
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
                            try addEntry(fileName: "meta/device.csv", data: metaCSV.data(using: .utf8))
                            
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
                                try addEntry(fileName: "meta/time.csv", data: timeCSV.data(using: .utf8))
                            }

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
                    let tmpFile = (NSTemporaryDirectory() as NSString).appendingPathComponent("\(filename).xls")
                    
                    do { try FileManager.default.removeItem(atPath: tmpFile) } catch {}
                    
                    let tmpFileURL = URL(fileURLWithPath: tmpFile)
                    
                    let workbook = JXLSWorkBook()
                    
                    for set in self.sets {
                        _ = set.serialize(format, additionalInfo: workbook)
                    }
                    
                    if !singleSet {
                        //Metadata
                        let metaSheet = workbook.workSheet(withName: "Metadata Device")
                        metaSheet?.setCellAtRow(0, column: 0, to: "property")
                        metaSheet?.setCellAtRow(0, column: 1, to: "value")
                        var i: UInt32 = 1;
                        for metadata in Metadata.allNonSensorCases {
                            switch metadata {
                            case .uniqueId:
                                continue
                            default:
                                metaSheet?.setCellAtRow(i, column: 0, to: metadata.identifier)
                                metaSheet?.setCellAtRow(i, column: 1, to: metadata.get(hash: "") ?? "")
                                i += 1
                            }
                        }

                        //Time references
                        if let reference = timeReference {
                            let dateFormatter = DateFormatter()
                            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS 'UTC'XXX"
                            
                            let timeSheet = workbook.workSheet(withName: "Metadata Time")
                            timeSheet?.setCellAtRow(0, column: 0, to: "event")
                            timeSheet?.setCellAtRow(0, column: 1, to: "experiment time")
                            timeSheet?.setCellAtRow(0, column: 2, to: "system time")
                            timeSheet?.setCellAtRow(0, column: 3, to: "system time text")
                            
                            i = 1
                            for mapping in reference.timeMappings {
                                let dateString = dateFormatter.string(from: mapping.systemTime)
                                
                                timeSheet?.setCellAtRow(i, column: 0, to: mapping.event.rawValue)
                                timeSheet?.setCellAtRow(i, column: 1, toDoubleValue: mapping.experimentTime)
                                timeSheet?.setCellAtRow(i, column: 2, toDoubleValue: mapping.systemTime.timeIntervalSince1970)
                                timeSheet?.setCellAtRow(i, column: 3, to: dateString)
                                i += 1
                            }
                        }
                    }
                    
                    let err = workbook.write(toFile: tmpFile)
                    
                    if err == 0 {
                        mainThread {
                            callback(nil, tmpFileURL)
                        }
                    }
                    else {
                        print("Excel error: \(err)")
                        mainThread {
                            callback("Could not create xls file", nil)
                        }
                    }
                }
            }
        }
    }
}
