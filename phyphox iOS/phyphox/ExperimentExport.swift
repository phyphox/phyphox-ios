//
//  ExperimentExport.swift
//  phyphox
//
//  Created by Jonas Gessner on 13.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation

final class ExperimentExport {
    let sets: [ExperimentExportSet]
    
    init(sets: [ExperimentExportSet]) {
        self.sets = sets
    }
    
    func runExport(_ format: ExportFileFormat, callback: @escaping (_ errorMessage: String?, _ fileURL: URL?) -> Void) {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            autoreleasepool {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
                
                if format.isCSV() {
                    if self.sets.count == 1 {
                        let tmpFile = (NSTemporaryDirectory() as NSString).appendingPathComponent("phyphox \(dateFormatter.string(from: Date())).csv")
                        
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
                        let tmpFile = (NSTemporaryDirectory() as NSString).appendingPathComponent("phyphox \(dateFormatter.string(from: Date())).zip")
                        
                        do { try FileManager.default.removeItem(atPath: tmpFile) } catch {}
                        
                        let tmpFileURL = URL(fileURLWithPath: tmpFile)
                        
                        do {
                            let archive = try ZZArchive(url: tmpFileURL, options: [ZZOpenOptionsCreateIfMissingKey : NSNumber(value: true as Bool)])
                            
                            var entries = [ZZArchiveEntry]()
                            
                            for set in self.sets {
                                let data = set.serialize(format, additionalInfo: nil) as! Data?
                                
                                entries.append(ZZArchiveEntry(fileName: set.localizedName + ".csv", compress: true, dataBlock: { error -> Data? in
                                    return data
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
                }
                else {
                    let tmpFile = (NSTemporaryDirectory() as NSString).appendingPathComponent("phyphox \(dateFormatter.string(from: Date())).xls")
                    
                    do { try FileManager.default.removeItem(atPath: tmpFile) } catch {}
                    
                    let tmpFileURL = URL(fileURLWithPath: tmpFile)
                    
                    let workbook = JXLSWorkBook()
                    
                    for set in self.sets {
                        _ = set.serialize(format, additionalInfo: workbook)
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
