//
//  LegacyStateSerializer.swift
//  phyphox
//
//  Created by Sebastian Kuhlen on 26.05.17.
//  Copyright © 2017 RWTH Aachen. All rights reserved.
//

import Foundation

final class LegacyStateSerializer {
    
    enum stateError: Error {
        case SourceError(String)
    }
    
    class func renameStateFile(customTitle: String, file: URL) throws {
        let data = try String(contentsOf: file, encoding: .utf8)
        let modifiedData = data.replacingOccurrences(
            of: "<state-title>.*<\\/state-title>",
            with: "<state-title>\(customTitle.replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;"))</state-title>",
            options: .regularExpression
        )
        try modifiedData.write(to: file, atomically: true, encoding: .utf8)
    }
    
    class func writeStateFile(customTitle: String, target: String, experiment: Experiment, callback: @escaping (_ errorMessage: String?, _ fileURL: URL?) -> Void) -> Void {
        let str: String
        do {
            str = try serializeState(customTitle: customTitle, experiment: experiment)
        } catch stateError.SourceError(let error) {
            mainThread {
                callback("State error: \(error).", nil)
            }
            return
        } catch {
            mainThread {
                callback("Unknown error.", nil)
            }
            return
        }
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            autoreleasepool {
                do { try FileManager.default.removeItem(atPath: target) } catch {}
                
                let fileURL = URL(fileURLWithPath: target)
                
                do {
                    try str.write(toFile: target, atomically: true, encoding: String.Encoding.utf8)
                } catch {
                    mainThread {
                        callback("Error: Could not write to file. " + target, nil)
                    }
                    return
                }
                
                mainThread {
                    callback(nil, fileURL)
                }
            }
        }
    }
    
    class func serializeState(customTitle: String, experiment: Experiment) throws -> String {
        let formatter = NumberFormatter()
        formatter.maximumSignificantDigits = 10
        formatter.minimumSignificantDigits = 1
        formatter.decimalSeparator = "."
        formatter.numberStyle = .scientific
        
        func format(_ n: Double) -> String {
            return formatter.string(from: NSNumber(value: n as Double))!
        }
        
        guard let source = experiment.source
            else {
                throw stateError.SourceError("Source of experiment unknown.")
        }
        var sourceStr: String
        do {
            try sourceStr = String(contentsOf: source, encoding: String.Encoding.utf8)
        } catch {
            throw stateError.SourceError("Cannot load experiment source.")
        }
        sourceStr = sourceStr.replacingOccurrences(
            of: "<state-title>.*<\\/state-title>",
            with: "",
            options: .regularExpression
        )
        sourceStr = sourceStr.replacingOccurrences(
            of: "<color>.*<\\/color>",
            with: "",
            options: .regularExpression
        )
        sourceStr = sourceStr.replacingOccurrences(
            of: "<events>.*<\\/events>",
            with: "",
            options: .regularExpression
        )
        let dataContainersBlockStart = sourceStr.range(of: "<data-containers>", options: .caseInsensitive)
        let dataContainersBlockStop = sourceStr.range(of: "</data-containers>", options: .caseInsensitive)
        if dataContainersBlockStop == nil || dataContainersBlockStart == nil {
            throw stateError.SourceError("No valid data containers block found.")
        }
        let endLocation = sourceStr.range(of: "</phyphox>", options: .caseInsensitive)
        if dataContainersBlockStop == nil || dataContainersBlockStart == nil || endLocation == nil {
            throw stateError.SourceError("No valid data containers block found.")
        }
        
        var newBlock = ""
        for buffer in experiment.buffers {
            newBlock += "<container "
            newBlock += "size=\"\(buffer.value.size)\" "
            newBlock += "static=\"\(buffer.value.staticBuffer ? "true" : "false")\" "
            newBlock += "init=\""
            for (i, v) in buffer.value.toArray().enumerated() {
                if i > 0 {
                    newBlock += ","
                }
                newBlock += format(v)
            }
            newBlock += "\" "
            newBlock += ">"
            newBlock += buffer.value.name
            newBlock += "</container>\n"
        }
        let customTitle = "<state-title>\(customTitle.replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;"))</state-title>"
        let color = "<color>blue</color>"
        var events = "<events>"
        for event in experiment.timeReference.timeMappings {
            events += "<\(event.event.rawValue.lowercased()) experimentTime=\"\(event.experimentTime)\" systemTime=\"\(Int64(event.systemTime.timeIntervalSince1970*1000))\" />"
        }
        events += "</events>"
        return sourceStr[..<dataContainersBlockStart!.upperBound] + "\n" + newBlock + "\n" + sourceStr[dataContainersBlockStop!.lowerBound..<endLocation!.lowerBound] + "\n" + customTitle + "\n" + color + "\n" + events + "\n" + "</phyphox>"
    }
}
