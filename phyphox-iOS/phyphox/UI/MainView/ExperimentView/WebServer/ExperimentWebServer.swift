//
//  ExperimentWebServer.swift
//  phyphox
//
//  Created by Jonas Gessner on 20.04.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation
import GCDWebServer

protocol ExperimentWebServerDelegate: AnyObject {
    var timerRunning: Bool { get }
    var remainingTimerTime: Double { get }
    
    func startExperiment()
    func stopExperiment()
    func clearData(clearGroups: [String])
    func buttonPressed(viewDescriptor: ButtonViewDescriptor, buttonViewTriggerCallback: ButtonViewTriggerCallback?)
    func runExport(_ export: ExperimentExport, singleSet: Bool, format: ExportFileFormat, completion: @escaping (NSError?, URL?) -> Void)
}

final class ExperimentWebServer {
    var running: Bool {
        return server != nil
    }
    
    var port: UInt = 80
    
    private(set) var path: String = ""
    
    private(set) var server: GCDWebServer?
    private var temporaryFiles = [String]()
    
    var htmlId2ViewElement: [ViewDescriptor] = []
    
    private var sessionID: String = ""
    
    weak var delegate: ExperimentWebServerDelegate?
    
    unowned let experiment: Experiment
    
    var forceFullUpdate = false
    
    init(experiment: Experiment) {
        self.experiment = experiment
    }

    //CORS: allow cross-origin browser pages to read remote-access responses, matching the
    //Android implementation (RemoteServer.respond()). Wraps a handler's completion block so
    //every response, including error responses, carries the header.
    private static func cors(_ completionBlock: @escaping GCDWebServerCompletionBlock) -> GCDWebServerCompletionBlock {
        return { response in
            response?.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
            completionBlock(response)
        }
    }

    //Registers a handler for both GET and POST: every endpoint accepts POST as well as GET with
    //the same parameters (see control-post in phyphox-docs). POST is registered with
    //GCDWebServerDataRequest so the request body is available to requestParams.
    private func addGETPOSTHandler(pathRegex: String, asyncProcessBlock: @escaping (GCDWebServerRequest, @escaping GCDWebServerCompletionBlock) -> Void) {
        server!.addHandler(forMethod: "GET", pathRegex: pathRegex, request: GCDWebServerRequest.self, asyncProcessBlock: asyncProcessBlock)
        server!.addHandler(forMethod: "POST", pathRegex: pathRegex, request: GCDWebServerDataRequest.self, asyncProcessBlock: asyncProcessBlock)
    }

    //Form decoding: + means space, the rest is percent-encoded
    private static func formDecode(_ s: String) -> String? {
        return s.replacingOccurrences(of: "+", with: " ").removingPercentEncoding
    }

    //Coerce every scalar to its string form; JSON null becomes an empty value, as an empty form
    //field would. Nested objects/arrays are not part of this flat API and simply stringify (and
    //will then fail the value parsing of the endpoint). Must stay in step with Android
    //(RemoteServer.requestParamsList).
    private static func coerceJSONValue(_ value: Any) -> String {
        if value is NSNull {
            return ""
        }
        if let s = value as? String {
            return s
        }
        if let n = value as? NSNumber {
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                return n.boolValue ? "true" : "false"
            }
            return n.stringValue
        }
        if let data = try? JSONSerialization.data(withJSONObject: value, options: []), let s = String(data: data, encoding: .utf8) {
            return s
        }
        return ""
    }

    //Reads the request's parameters: the query string plus, for a POST, a JSON or form-encoded
    //body chosen by Content-Type, with body parameters taking precedence over query parameters
    //of the same name (control-post; must stay in step with Android's requestParams). Answers
    //400 and returns nil for a malformed or oversized body.
    private static func requestParams(_ request: GCDWebServerRequest, orRespond completionBlock: @escaping GCDWebServerCompletionBlock) -> [String: String]? {
        var params: [String: String] = [:]

        func malformed() -> [String: String]? {
            cors(completionBlock)(GCDWebServerResponse(statusCode: 400))
            return nil
        }

        if let dataRequest = request as? GCDWebServerDataRequest, dataRequest.data.count > 0 {
            guard dataRequest.data.count <= 2097152 else { //2 MB, matching the Android limit
                return malformed()
            }
            let contentType = (request.contentType ?? "").lowercased()
            if contentType.hasPrefix("application/json") {
                //A flat JSON object; anything else, including bare Infinity/NaN, is a malformed
                //body
                guard let obj = try? JSONSerialization.jsonObject(with: dataRequest.data), let dict = obj as? [String: Any] else {
                    return malformed()
                }
                for (key, value) in dict {
                    params[key] = coerceJSONValue(value)
                }
            } else if contentType.hasPrefix("application/x-www-form-urlencoded") {
                guard let body = String(data: dataRequest.data, encoding: .utf8) else {
                    return malformed()
                }
                for item in body.components(separatedBy: "&") {
                    let c = item.components(separatedBy: "=")
                    guard let key = formDecode(c[0]), !key.isEmpty, params[key] == nil else { continue }
                    params[key] = c.count > 1 ? (formDecode(c.dropFirst().joined(separator: "=")) ?? "") : ""
                }
            }
            //Any other content type: the body is ignored, like on Android
        }

        if let queryString = URLComponents(url: request.url, resolvingAgainstBaseURL: true)?.query {
            for (key, value) in queryDictionary(queryString) where params[key] == nil && !key.isEmpty {
                params[key] = value
            }
        }

        return params
    }

    //Relative path resolved against the served directory without ever escaping it
    private static func sanitizedRelativePath(_ urlPath: String) -> String {
        var components: [String] = []
        for component in urlPath.components(separatedBy: "/") {
            switch component {
            case "", ".":
                continue
            case "..":
                if !components.isEmpty {
                    components.removeLast()
                }
            default:
                components.append(component)
            }
        }
        return components.joined(separator: "/")
    }
    
    convenience init(experiment: Experiment, delegate: ExperimentWebServerDelegate) {
        self.init(experiment: experiment)
        self.delegate = delegate
    }
    
    func start() -> Bool {
        if running {
            return true
        }
        
        precondition(delegate != nil, "Cannot start web server without a delegate")
        
        (path, htmlId2ViewElement) = WebServerUtilities.prepareWebServerFilesForExperiment(experiment)
        
        sessionID = String(Int64(CFAbsoluteTimeGetCurrent()*1e9) & 0xffffff)
        
        server = GCDWebServer()
        
        //Serves the prepared web interface files. Replaces GCDWebServer's addGETHandler so the
        //CORS header is present on the static files as well.
        let staticPath = path
        addGETPOSTHandler(pathRegex: "/.*", asyncProcessBlock: { (request, completionBlock) in
            let completionBlock = ExperimentWebServer.cors(completionBlock)
            var filePath = (staticPath as NSString).appendingPathComponent(ExperimentWebServer.sanitizedRelativePath(request.path))
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory), isDirectory.boolValue {
                filePath = (filePath as NSString).appendingPathComponent("index.html")
            }
            if FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory), !isDirectory.boolValue, let response = GCDWebServerFileResponse(file: filePath) {
                completionBlock(response)
            } else {
                completionBlock(GCDWebServerResponse(statusCode: 404))
            }
        })
        
        addGETPOSTHandler(pathRegex: "/logo", asyncProcessBlock: { (request, completionBlock) in
            let completionBlock = ExperimentWebServer.cors(completionBlock)
            let file = Bundle.main.path(forResource: "phyphox-webinterface/phyphox_orange", ofType: "png")
            let image = UIImage.init(contentsOfFile: file!)
            let response = GCDWebServerDataResponse(data: image!.pngData()!, contentType: "image/png")
            
            completionBlock(response)
        })
        
        addGETPOSTHandler(pathRegex: "/res", asyncProcessBlock: { (request, completionBlock) in
            let completionBlock = ExperimentWebServer.cors(completionBlock)
            
            func returnErrorResponse(_ response: AnyObject) {
                let response = GCDWebServerDataResponse(jsonObject: response)
                
                completionBlock(response)
            }
            
            guard let query = ExperimentWebServer.requestParams(request, orRespond: completionBlock) else { return }
            //Resolves against the experiment's res folder with a fallback to the images
            //bundled with phyphox, matching the fallback of the image view element. The content
            //type is always application/octet-stream - the client determines what it received
            //(res-content-type) - and a missing src answers the same "Unknown file." as an
            //unknown one (res-fallback).
            if let src = query["src"], self.experiment.resources.contains(src), let file = self.experiment.resolveResource(src), let data = try? Data(contentsOf: file) {
                completionBlock(GCDWebServerDataResponse(data: data, contentType: "application/octet-stream"))
                return
            }
            returnErrorResponse(["error": "Unknown file."] as AnyObject)
        })
        
        addGETPOSTHandler(pathRegex: "/export", asyncProcessBlock: { [unowned self] (request, completionBlock) in
            let completionBlock = ExperimentWebServer.cors(completionBlock)
            func returnErrorResponse(_ response: AnyObject) {
                let response = GCDWebServerDataResponse(jsonObject: response)
                
                completionBlock(response)
            }
                        
            guard let query = ExperimentWebServer.requestParams(request, orRespond: completionBlock) else { return }

            //Error messages match the Android implementation: a missing or non-numeric format
            //is "Invalid format.", a numeric one outside the format list "Format out of range."
            if let formatStr = query["format"], Int(formatStr) != nil {
                if let format = WebServerUtilities.mapFormatString(formatStr) {
                    self.delegate!.runExport(self.experiment.export!, singleSet: false, format: format) { error, URL in
                        if error == nil {
                            self.temporaryFiles.append(URL!.path)
                            let response = GCDWebServerFileResponse(file: URL!.path, isAttachment: true)
                            completionBlock(response)
                        }
                        else {
                            returnErrorResponse(["error": error!.localizedDescription] as AnyObject)
                        }
                    }
                }
                else {
                    returnErrorResponse(["error": "Format out of range."] as AnyObject)
                }
            }
            else {
                returnErrorResponse(["error": "Invalid format."] as AnyObject)
            }
            })
        
        addGETPOSTHandler(pathRegex: "/control", asyncProcessBlock: { [unowned self] (request, completionBlock) in
            let completionBlock = ExperimentWebServer.cors(completionBlock)
            func returnErrorResponse() {
                let response = GCDWebServerDataResponse(jsonObject: ["result": false])
                
                completionBlock(response)
            }
            
            func returnSuccessResponse() {
                let response = GCDWebServerDataResponse(jsonObject: ["result": true])
                
                completionBlock(response)
            }
                        
            guard let query = ExperimentWebServer.requestParams(request, orRespond: completionBlock) else { return }

            let cmd = query["cmd"]
            
            if cmd == "start" {
                mainThread {
                    self.delegate!.startExperiment()
                }
                
                returnSuccessResponse()
            }
            else if cmd == "stop" {
                mainThread {
                    self.delegate!.stopExperiment()
                }
                returnSuccessResponse()
            }
            else if cmd == "clear" {
                //Like on Android, clearGroup1, clearGroup2, ... name the clear groups the user
                //selected; the first gap ends the list. The web interface sends them
                //form-encoded, so a "+" stands for a space (the rest of the query arrives
                //percent-decoded already).
                var clearGroups: [String] = []
                var i = 1
                while let clearGroup = query["clearGroup\(i)"] {
                    clearGroups.append(clearGroup.replacingOccurrences(of: "+", with: " "))
                    i += 1
                }
                mainThread {
                    self.delegate!.clearData(clearGroups: clearGroups)
                }
                returnSuccessResponse()
            }
            else if cmd == "set" {
                guard let bufferName = query["buffer"], let valueString = query["value"], let buffer = self.experiment.buffers[bufferName], let value = Double(valueString) else {
                    returnErrorResponse()
                    return
                }
                
                if !value.isFinite {
                    returnErrorResponse()
                }
                else {
                    buffer.append(value)
                    returnSuccessResponse()
                }
            }
            else if cmd == "trigger" {
                guard let indexStr = query["element"], let elementIndex = Int(indexStr) else {
                    returnErrorResponse()
                    return
                }
                
                //An out-of-range index or an element that is not a button is a bad request:
                //answer {"result": false} instead of reporting success for a trigger that was
                //not performed (control-trigger-out-of-range)
                if elementIndex >= 0 && self.htmlId2ViewElement.count > elementIndex, let buttonDescriptor = self.htmlId2ViewElement[elementIndex] as? ButtonViewDescriptor {
                    self.delegate?.buttonPressed(viewDescriptor: buttonDescriptor, buttonViewTriggerCallback: nil)
                    returnSuccessResponse()
                } else {
                    returnErrorResponse()
                }
            }
            else {
                returnErrorResponse()
            }
            })
        
        addGETPOSTHandler(pathRegex: "/get", asyncProcessBlock: { [unowned self] (request, completionBlock) in
            let completionBlock = ExperimentWebServer.cors(completionBlock)
            func returnErrorResponse() {
                let response = GCDWebServerResponse(statusCode: 400)
                
                completionBlock(response)
            }
            
            guard let query = ExperimentWebServer.requestParams(request, orRespond: completionBlock) else { return }
            //A request without any parameters is fine: it answers an empty buffer object and
            //the status object, the natural way to poll only the status (get-no-parameters)
            
            var mainDict = [String: AnyObject]()
            
            var bufferDict = [String: AnyObject]()
            
            for (bufferName, value) in query {
                guard let b = self.experiment.buffers[bufferName] else {
                    continue //Just ignore buffers that do not exist. The user might have changed to a different experiment, so we need to send a session id to inform the browser - even if we do not understand this request
                }
                
                var dict = [String: AnyObject]()
                dict["size"] = b.size as AnyObject
                
                if value.count > 0 {
                    let raw = b.toArray()
                    
                    //After a clear, every requested buffer is upgraded to a full update,
                    //whatever its request asked for (get-force-full-update)
                    if value == "full" || self.forceFullUpdate {
                        dict["updateMode"] = "full" as AnyObject
                        dict["buffer"] = raw.map({$0.isFinite ? $0 as AnyObject : NSNull() as AnyObject}) as AnyObject //The array may contain NaN or Inf, which will throw an error in the JSON conversion.
                        //Detailed thoughts on this problem:
                        //Suppose we have two graphs which plot A vs. t and B vs. t (note: same x-axis!). If A contains invalid values (NaN or Inf), we cannot simply remove them as the indices of A would no longer align with t. Also, we cannot remove the value pair from A and t as t would not align with B, which might have a good value at this index. So, in the end we need to send some kind of "invalid" value
                    }
                    else {
                        let extraComponents = value.components(separatedBy: "|")
                        //A threshold that does not parse as a number is a malformed request
                        //(get-invalid-threshold)
                        guard let thresholdGiven = Double(extraComponents.first!) else {
                            returnErrorResponse()
                            return
                        }
                        
                        //We only offer 8-digit precision, so we need to move the threshold to avoid receiving a close number multiple times.
                        //Missing something will probably not be visible on a remote graph and a missing value will be recent after stopping anyway.
                        //The nudge magnitude derives from the absolute value (log10 of a negative
                        //threshold would be NaN and break the request); its direction stays
                        //positive (get-negative-threshold)
                        let threshold = thresholdGiven.isFinite ? thresholdGiven + pow(10.0, floor(log10(abs(thresholdGiven)/1e7))) : thresholdGiven
                        
                        var final: [Double] = []
                        
                        if extraComponents.count > 1 {
                            let extra = extraComponents.last!

                            guard let extraBuffer = self.experiment.buffers[extra] else {
                                let response = GCDWebServerResponse(statusCode: 400)
                                
                                completionBlock(response)
                                return
                            }
                            
                            let extraArray = extraBuffer.toArray()
                            
                            for (i, v) in extraArray.enumerated() {
                                if i >= raw.count {
                                    break
                                }
                                
                                if v > threshold {
                                    let val = raw[i]
                                    
                                    final.append(val)
                                }
                            }
                        }
                        else {
                            final = raw.filter{ $0 > threshold }
                        }

                        dict["updateMode"] = "partial" as AnyObject
                        dict["buffer"] = final.map({$0.isFinite ? $0 as AnyObject : NSNull() as AnyObject}) as AnyObject //The array may contain NaN or Inf, which will throw an error in the JSON conversion. (See above)
                    }
                }
                else {
                    dict["updateMode"] = "single" as AnyObject
                    //JSON has no representation for NaN or infinity, so a non-finite value is
                    //null in every update mode (get-nonfinite-single-value)
                    if let v = b.last, v.isFinite {
                        dict["buffer"] = [v] as AnyObject
                    } else {
                        dict["buffer"] = [NSNull()] as AnyObject
                    }
                }
                
                
                bufferDict[bufferName] = dict as AnyObject
            }
            
            mainDict["buffer"] = bufferDict as AnyObject
            mainDict["status"] = ["session": self.sessionID, "measuring": self.experiment.running, "timedRun": self.delegate!.timerRunning, "countDown": Int(round(1000*self.delegate!.remainingTimerTime))] as AnyObject
            
            self.forceFullUpdate = false
            
            let response = GCDWebServerDataResponse(jsonObject: mainDict)
            
            completionBlock(response)
        })
        
        addGETPOSTHandler(pathRegex: "/config", asyncProcessBlock: { [unowned self] (request, completionBlock) in
            let completionBlock = ExperimentWebServer.cors(completionBlock)
            func returnErrorResponse() {
                let response = GCDWebServerResponse(statusCode: 400)
                
                completionBlock(response)
            }
            
            var json = [String: AnyObject]()
            
            json["crc32"] = String(format:"%02x", self.experiment.crc32 ?? 0) as AnyObject
            json["title"] = self.experiment.title as AnyObject
            json["localTitle"] = self.experiment.localizedTitle as AnyObject
            json["category"] = self.experiment.category as AnyObject
            json["localCategory"] = self.experiment.localizedCategory as AnyObject
            
            var buffers = [AnyObject]()
            for (name, buffer) in self.experiment.buffers {
                buffers.append(["name": name, "size": buffer.size] as AnyObject)
            }
            json["buffers"] = buffers as AnyObject
            
            var inputs = [AnyObject]()
            if self.experiment.audioInputs.count > 0 {
                var outputs = [AnyObject]()
                outputs.append(["out": self.experiment.audioInputs[0].outBuffer.name] as AnyObject)
                if let rateBuffer = self.experiment.audioInputs[0].sampleRateInfoBuffer {
                    outputs.append(["rate": rateBuffer.name] as AnyObject)
                }
                inputs.append(["source": "audio", "outputs": outputs] as AnyObject)
            }
            if self.experiment.gpsInputs.count > 0 {
                var outputs = [AnyObject]()
                if let buffer = self.experiment.gpsInputs[0].latBuffer {
                    outputs.append(["lat": buffer.name] as AnyObject)
                }
                if let buffer = self.experiment.gpsInputs[0].lonBuffer {
                    outputs.append(["lon": buffer.name] as AnyObject)
                }
                if let buffer = self.experiment.gpsInputs[0].zBuffer {
                    outputs.append(["z": buffer.name] as AnyObject)
                }
                if let buffer = self.experiment.gpsInputs[0].zWgs84Buffer {
                    outputs.append(["zwgs84": buffer.name] as AnyObject)
                }
                if let buffer = self.experiment.gpsInputs[0].vBuffer {
                    outputs.append(["v": buffer.name] as AnyObject)
                }
                if let buffer = self.experiment.gpsInputs[0].dirBuffer {
                    outputs.append(["dir": buffer.name] as AnyObject)
                }
                if let buffer = self.experiment.gpsInputs[0].tBuffer {
                    outputs.append(["t": buffer.name] as AnyObject)
                }
                if let buffer = self.experiment.gpsInputs[0].accuracyBuffer {
                    outputs.append(["accuracy": buffer.name] as AnyObject)
                }
                if let buffer = self.experiment.gpsInputs[0].zAccuracyBuffer {
                    outputs.append(["zAccuracy": buffer.name] as AnyObject)
                }
                if let buffer = self.experiment.gpsInputs[0].statusBuffer {
                    outputs.append(["status": buffer.name] as AnyObject)
                }
                if let buffer = self.experiment.gpsInputs[0].satellitesBuffer {
                    outputs.append(["satellites": buffer.name] as AnyObject)
                }
                inputs.append(["source": "location", "outputs": outputs] as AnyObject)
            }
            for input in self.experiment.sensorInputs {
                var outputs = [AnyObject]()
                if let buffer = input.xBuffer {
                    outputs.append(["x": buffer.name] as AnyObject)
                }
                if let buffer = input.yBuffer {
                    outputs.append(["y": buffer.name] as AnyObject)
                }
                if let buffer = input.zBuffer {
                    outputs.append(["z": buffer.name] as AnyObject)
                }
                if let buffer = input.absBuffer {
                    outputs.append(["abs": buffer.name] as AnyObject)
                }
                if let buffer = input.tBuffer {
                    outputs.append(["t": buffer.name] as AnyObject)
                }
                if let buffer = input.accuracyBuffer {
                    outputs.append(["accuracy": buffer.name] as AnyObject)
                }
                inputs.append(["source": input.sensorType.description, "outputs": outputs] as AnyObject)
            }
            if self.experiment.bluetoothInputs.count > 0 {
                inputs.append(["source": "bluetooth"] as AnyObject)
            }
            json["inputs"] = inputs as AnyObject
            
            var export = [AnyObject]()
            if let sets = self.experiment.export?.sets {
                for set in sets {
                    var sources = [AnyObject]()
                    for source in set.data {
                        sources.append(["label": source.name, "buffer": source.buffer.name] as AnyObject)
                    }
                    export.append(["set": set.name, "sources": sources] as AnyObject)
                }
            }
            json["export"] = export as AnyObject
            
            let response = GCDWebServerDataResponse(jsonObject: json)
            
            completionBlock(response)
        })
        
        addGETPOSTHandler(pathRegex: "/meta", asyncProcessBlock: { (request, completionBlock) in
            let completionBlock = ExperimentWebServer.cors(completionBlock)
            func returnErrorResponse() {
                let response = GCDWebServerResponse(statusCode: 400)
                
                completionBlock(response)
            }
            
            var json = [String: AnyObject]()
            
            for metadata in Metadata.allNonSensorCases {
                switch metadata {
                case .uniqueId:
                    continue
                default:
                    //An unavailable value omits its key entirely instead of answering null
                    //(meta-missing-value-representation)
                    if let value = metadata.get(hash: "") {
                        json[metadata.identifier] = value as AnyObject
                    }
                }
            }
            
            let response = GCDWebServerDataResponse(jsonObject: json)
            
            completionBlock(response)
        })
        
        addGETPOSTHandler(pathRegex: "/time", asyncProcessBlock: { [unowned self] (request, completionBlock) in
            let completionBlock = ExperimentWebServer.cors(completionBlock)
            func returnErrorResponse() {
                let response = GCDWebServerResponse(statusCode: 400)
                
                completionBlock(response)
            }
            
            var json = [AnyObject]()
            
            for mapping in experiment.timeReference.timeMappings {
                var eventJson = [String: AnyObject]()
                eventJson["event"] = mapping.event.rawValue as AnyObject
                eventJson["experimentTime"] = mapping.experimentTime as AnyObject
                eventJson["systemTime"] = mapping.systemTime.timeIntervalSince1970 as AnyObject
                json.append(eventJson as AnyObject)
            }
            
            let response = GCDWebServerDataResponse(jsonObject: json)
            
            completionBlock(response)
        })
        
        port = UInt(UserDefaults.standard.string(forKey: "remoteAccessPort") ?? "80") ?? 80
        
        if server!.start(withPort: port, bonjourName: nil){
            print("Webserver running on \(String(describing: server!.serverURL))")
            return true
        } else if server!.start(withPort: 8080, bonjourName: nil) {
            port = 8080
            print("Webserver running on \(String(describing: server!.serverURL))")
            return true
        }
        else {
            server = nil
            return false
        }
    }
    
    func stop() {
        if !running {
            return
        }
        
        server!.stop()
        server = nil
        
        for file in temporaryFiles {
            do { try FileManager.default.removeItem(atPath: file) } catch {}
        }
        
        temporaryFiles.removeAll()
        
        do { try FileManager.default.removeItem(atPath: path) } catch {}
    }
}
