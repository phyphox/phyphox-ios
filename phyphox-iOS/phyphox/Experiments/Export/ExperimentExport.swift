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
    
    ///Copies the values of every set out of the buffers in ONE go, under the experiment's data
    ///lock. Without it an export of a running experiment reads containers that the analysis and
    ///the sensor threads keep writing: an analysis cycle clears a container before it refills it,
    ///and an export landing in that window wrote a set with nothing but its header - reproduced
    ///twice by the device lab on camera_stopwatch_luma, each time in a single one of the six
    ///formats. One acquisition for all sets also keeps the sets consistent with each other. The
    ///files are written from the copy, outside the lock: holding the barrier across file I/O
    ///would stall the measurement for as long as the export takes. (Android: 2b8d7acf.)
    func snapshot() -> [ExperimentExportSetData] {
        let lock = sets.lazy.flatMap({ $0.data }).compactMap({ $0.buffer.dataLock }).first
        guard let lock = lock else {
            //A standalone set, as in unit tests: there is nothing writing concurrently
            return sets.map { $0.snapshot() }
        }
        return lock.read { sets.map { $0.snapshot() } }
    }

    //filename is expected to be a complete file name base (without extension), typically generated
    // from the user's template by FileNameFormat
    func runExport(_ format: ExportFileFormat, singleSet: Bool, filename: String, timeReference: ExperimentTimeReference?, callback: @escaping (_ errorMessage: String?, _ fileURL: URL?) -> Void) {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            autoreleasepool {
                let sets = self.snapshot()

                switch format {
                case .csv(let separator, let decimalPoint):
                    if singleSet {
                        let tmpFile = (NSTemporaryDirectory() as NSString).appendingPathComponent("\(filename).csv")
                        
                        do { try FileManager.default.removeItem(atPath: tmpFile) } catch {}
                        
                        let tmpFileURL = URL(fileURLWithPath: tmpFile)
                        
                        
                        let set = sets.first!

                        let data = set.serializeToCSV(separator: separator, decimalPoint: decimalPoint)
                        
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

                            for set in sets {
                                let data = set.serializeToCSV(separator: separator, decimalPoint: decimalPoint)

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
                    let tmpFile = (NSTemporaryDirectory() as NSString).appendingPathComponent("\(filename).xlsx")

                    do { try FileManager.default.removeItem(atPath: tmpFile) } catch {}

                    let tmpFileURL = URL(fileURLWithPath: tmpFile)

                    do {
                        let xlsx = try XlsxWriter(url: tmpFileURL)

                        for set in sets {
                            try set.serializeToXlsx(xlsx)
                        }

                        if !singleSet {
                            //Metadata
                            try xlsx.startSheet("Metadata Device")
                            xlsx.startRow()
                            xlsx.stringCell("property", bold: true)
                            xlsx.stringCell("value", bold: true)
                            xlsx.endRow()
                            for metadata in Metadata.allNonSensorCases {
                                switch metadata {
                                case .uniqueId:
                                    continue
                                default:
                                    xlsx.startRow()
                                    xlsx.stringCell(metadata.identifier)
                                    xlsx.stringCell(metadata.get(hash: "") ?? "")
                                    xlsx.endRow()
                                }
                            }

                            //Time references
                            if let reference = timeReference {
                                let dateFormatter = DateFormatter()
                                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS 'UTC'XXX"

                                try xlsx.startSheet("Metadata Time")
                                xlsx.startRow()
                                xlsx.stringCell("event", bold: true)
                                xlsx.stringCell("experiment time", bold: true)
                                xlsx.stringCell("system time", bold: true)
                                xlsx.stringCell("system time text", bold: true)
                                xlsx.endRow()

                                for mapping in reference.timeMappings {
                                    xlsx.startRow()
                                    xlsx.stringCell(mapping.event.rawValue)
                                    xlsx.numberCell(mapping.experimentTime)
                                    xlsx.numberCell(mapping.systemTime.timeIntervalSince1970)
                                    xlsx.stringCell(dateFormatter.string(from: mapping.systemTime))
                                    xlsx.endRow()
                                }
                            }
                        }

                        try xlsx.close()

                        mainThread {
                            callback(nil, tmpFileURL)
                        }
                    }
                    catch let error {
                        print("Excel error: \(error)")
                        mainThread {
                            callback("Could not create xlsx file", nil)
                        }
                    }
                }
            }
        }
    }
}
