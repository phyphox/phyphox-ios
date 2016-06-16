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
    
    func runExport(format: ExportFileFormat, callback: (errorMessage: String?, fileURL: NSURL?) -> Void) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            autoreleasepool {
                if format.isCSV() {
                    if self.sets.count == 1 {
                        let tmpFile = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent("phyphox-export.csv")
                        
                        do { try NSFileManager.defaultManager().removeItemAtPath(tmpFile) } catch {}
                        
                        let tmpFileURL = NSURL(fileURLWithPath: tmpFile)
                        
                        
                        let set = self.sets.first!
                        
                        let data = set.serialize(format, additionalInfo: nil) as! NSData?
                        
                        do {
                            try data!.writeToFile(tmpFile, options: [])
                            
                            mainThread {
                                callback(errorMessage: nil, fileURL: tmpFileURL)
                            }
                        }
                        catch let error {
                            print("File write error: \(error)")
                            mainThread {
                                callback(errorMessage: "Could not create csv file", fileURL: nil)
                            }
                        }
                    }
                    else {
                        let tmpFile = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent("phyphox-export.zip")
                        
                        do { try NSFileManager.defaultManager().removeItemAtPath(tmpFile) } catch {}
                        
                        let tmpFileURL = NSURL(fileURLWithPath: tmpFile)
                        
                        do {
                            let archive = try ZZArchive(URL: tmpFileURL, options: [ZZOpenOptionsCreateIfMissingKey : NSNumber(bool: true)])
                            
                            var entries = [ZZArchiveEntry]()
                            
                            for set in self.sets {
                                let data = set.serialize(format, additionalInfo: nil) as! NSData?
                                
                                entries.append(ZZArchiveEntry(fileName: set.localizedName + ".csv", compress: true, dataBlock: { error -> NSData? in
                                    return data
                                }))
                            }
                            
                            try archive.updateEntries(entries)
                            
                            mainThread {
                                callback(errorMessage: nil, fileURL: tmpFileURL)
                            }
                            
                        }
                        catch let error {
                            print("Zip error: \(error)")
                            mainThread {
                                callback(errorMessage: "Could not create csv file", fileURL: nil)
                            }
                        }
                    }
                }
                else {
                    let tmpFile = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent("phyphox-export.xls")
                    
                    do { try NSFileManager.defaultManager().removeItemAtPath(tmpFile) } catch {}
                    
                    let tmpFileURL = NSURL(fileURLWithPath: tmpFile)
                    
                    let workbook = JXLSWorkBook()
                    
                    for set in self.sets {
                        set.serialize(format, additionalInfo: workbook)
                    }
                    
                    let err = workbook.writeToFile(tmpFile)
                    
                    if err == 0 {
                        mainThread {
                            callback(errorMessage: nil, fileURL: tmpFileURL)
                        }
                    }
                    else {
                        print("Excel error: \(err)")
                        mainThread {
                            callback(errorMessage: "Could not create xls file", fileURL: nil)
                        }
                    }
                }
            }
        }
    }
}
