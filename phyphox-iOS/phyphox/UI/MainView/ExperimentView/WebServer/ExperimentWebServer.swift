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
    
    //Whether the measurement (or its countdown) actually began; /control?cmd=start reports a refusal (control-start-refused)
    func startExperiment() -> Bool
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

    //CORS on every response including errors, matching Android (RemoteServer.respond())
    private static func cors(_ completionBlock: @escaping GCDWebServerCompletionBlock) -> GCDWebServerCompletionBlock {
        return { response in
            response?.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
            completionBlock(response)
        }
    }

    //Error responses carry {"error": "<reason>"} as application/json whatever the status (error-response-content-type in
    //phyphox-docs, in step with Android); the reason is not part of the contract
    private static func errorResponse(statusCode: Int, reason: String) -> GCDWebServerResponse? {
        let response = GCDWebServerDataResponse(jsonObject: ["error": reason])
        response?.statusCode = statusCode
        return response
    }

    //Every endpoint accepts POST as well as GET (control-post); POST uses GCDWebServerDataRequest so requestParams sees the body
    private func addGETPOSTHandler(pathRegex: String, asyncProcessBlock: @escaping (GCDWebServerRequest, @escaping GCDWebServerCompletionBlock) -> Void) {
        server!.addHandler(forMethod: "GET", pathRegex: pathRegex, request: GCDWebServerRequest.self, asyncProcessBlock: asyncProcessBlock)
        server!.addHandler(forMethod: "POST", pathRegex: pathRegex, request: GCDWebServerDataRequest.self, asyncProcessBlock: asyncProcessBlock)
    }

    //Form decoding: + means space, the rest is percent-encoded
    private static func formDecode(_ s: String) -> String? {
        return s.replacingOccurrences(of: "+", with: " ").removingPercentEncoding
    }

    //Adds the key=value pairs of a form body or URL query, the first occurrence of a key winning like on Android
    private static func addFormParams(_ encoded: String, to params: inout [String: String]) {
        for item in encoded.components(separatedBy: "&") {
            let c = item.components(separatedBy: "=")
            guard let key = formDecode(c[0]), !key.isEmpty, params[key] == nil else { continue }
            params[key] = c.count > 1 ? (formDecode(c.dropFirst().joined(separator: "=")) ?? "") : ""
        }
    }

    //Scalars stringify, null becomes empty like an empty form field, nested values just stringify; in step with Android
    //(RemoteServer.requestParamsList)
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

    //Query string plus a JSON or form body chosen by Content-Type, body winning over query (control-post, in step with
    //Android's requestParams); answers 400 and returns nil for a malformed or oversized body
    private static func requestParams(_ request: GCDWebServerRequest, orRespond completionBlock: @escaping GCDWebServerCompletionBlock) -> [String: String]? {
        var params: [String: String] = [:]

        func malformed() -> [String: String]? {
            cors(completionBlock)(errorResponse(statusCode: 400, reason: "Malformed request body."))
            return nil
        }

        if let dataRequest = request as? GCDWebServerDataRequest, dataRequest.data.count > 0 {
            guard dataRequest.data.count <= 2097152 else { //2 MB, matching the Android limit
                return malformed()
            }
            let contentType = (request.contentType ?? "").lowercased()
            if contentType.hasPrefix("application/json") {
                //Only a flat JSON object; anything else, including bare Infinity/NaN, is a malformed body
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
                addFormParams(body, to: &params)
            }
            //Any other content type: the body is ignored, like on Android
        }

        if let queryString = URLComponents(url: request.url, resolvingAgainstBaseURL: true)?.percentEncodedQuery {
            addFormParams(queryString, to: &params)
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
        
        //Replaces GCDWebServer's addGETHandler so the static files carry the CORS header as well
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
            //Experiment res folder with fallback to the bundled images, like the image view element. Always application/octet-stream
            //(res-content-type); a missing src answers "Unknown file." like an unknown one (res-fallback)
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

            //Error messages match Android: "Invalid format." for missing/non-numeric, "Format out of range." otherwise
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
                //The answer says whether the measurement began, so wait for the attempt on the main thread (control-start-refused)
                mainThread {
                    if self.delegate!.startExperiment() {
                        returnSuccessResponse()
                    } else {
                        returnErrorResponse()
                    }
                }
            }
            else if cmd == "stop" {
                mainThread {
                    self.delegate!.stopExperiment()
                }
                returnSuccessResponse()
            }
            else if cmd == "clear" {
                //Like Android: clearGroup1, clearGroup2, ... up to the first gap
                var clearGroups: [String] = []
                var i = 1
                while let clearGroup = query["clearGroup\(i)"] {
                    clearGroups.append(clearGroup)
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
                
                //Out-of-range index or non-button element answers {"result": false} (control-trigger-out-of-range)
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

        //Bulk write from a JSON body, the array-valued counterpart of control?cmd=set (openapi.yaml, path /set); in step with
        //Android (RemoteServer.handleSet), error messages included. GET is registered to answer result:false instead of a 405
        addGETPOSTHandler(pathRegex: "/set", asyncProcessBlock: { [unowned self] (request, completionBlock) in
            let completionBlock = ExperimentWebServer.cors(completionBlock)
            func returnSetError(_ error: String) {
                completionBlock(GCDWebServerDataResponse(jsonObject: ["result": false, "error": error]))
            }

            //GET or a form body is well-formed but cannot carry the documented shape: result:false; unparseable JSON is a 400
            guard let dataRequest = request as? GCDWebServerDataRequest, (request.contentType ?? "").lowercased().hasPrefix("application/json") else {
                returnSetError("A JSON body of the form {\"buffers\": {...}} is required.")
                return
            }
            guard dataRequest.data.count <= 2097152, //2 MB, matching the Android limit
                  let obj = try? JSONSerialization.jsonObject(with: dataRequest.data),
                  let json = obj as? [String: Any] else {
                completionBlock(ExperimentWebServer.errorResponse(statusCode: 400, reason: "Malformed request body."))
                return
            }

            //Validate everything first: the mode, every buffer name and every entry...
            var append = false
            if let mode = json["mode"] {
                if (mode as? String) == "append" {
                    append = true
                }
                else if (mode as? String) != "replace" { //Anything but the two enum strings, including null
                    returnSetError("Unknown mode \"\(mode is NSNull ? "null" : mode)\".")
                    return
                }
            }

            guard let buffersObject = json["buffers"] as? [String: Any] else {
                returnSetError("A \"buffers\" object is required.")
                return
            }

            var writes: [(DataBuffer, [Double])] = []
            for (name, entriesAny) in buffersObject {
                guard let buffer = self.experiment.buffers[name] else {
                    returnSetError("Unknown buffer \"\(name)\".")
                    return
                }
                guard let entries = entriesAny as? [Any] else {
                    returnSetError("The values for buffer \"\(name)\" must be an array.")
                    return
                }
                var values: [Double] = []
                values.reserveCapacity(entries.count)
                for entry in entries {
                    if entry is NSNull {
                        //null is what /get uses for non-finite values, so /get output feeds back unchanged
                        values.append(.nan)
                    }
                    else if let number = entry as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
                        values.append(number.doubleValue)
                    }
                    else if let string = entry as? String {
                        //The file format's number lexical space: "nan"/"Infinity"/"-infinity" work, "inf" does not
                        guard let value = parseExperimentNumber(string) else {
                            returnSetError("Invalid value \"\(string)\" for buffer \"\(name)\".")
                            return
                        }
                        values.append(value)
                    }
                    else {
                        //Booleans, nested arrays/objects
                        returnSetError("Invalid entry for buffer \"\(name)\": must be a number, null or a number string.")
                        return
                    }
                }
                writes.append((buffer, values))
            }

            //...then write; the writes mark the analysis through the observers like cmd=set. An empty buffers object is a valid no-op
            for (buffer, values) in writes {
                if !append {
                    buffer.clear(reset: false) //Normal buffer semantics apply, so this cannot clear a written static buffer
                }
                buffer.appendFromArray(values)
            }
            completionBlock(GCDWebServerDataResponse(jsonObject: ["result": true]))
            })

        addGETPOSTHandler(pathRegex: "/get", asyncProcessBlock: { [unowned self] (request, completionBlock) in
            let completionBlock = ExperimentWebServer.cors(completionBlock)
            func returnErrorResponse(_ reason: String) {
                completionBlock(ExperimentWebServer.errorResponse(statusCode: 400, reason: reason))
            }
            
            guard let query = ExperimentWebServer.requestParams(request, orRespond: completionBlock) else { return }
            //No parameters is fine: answers an empty buffer object plus the status (get-no-parameters)
            
            var mainDict = [String: AnyObject]()

            var bufferDict = [String: AnyObject]()

            //Read once, so it is consistent with the snapshot and the reset at the end
            let forceFullUpdate = self.forceFullUpdate

            //Snapshot all requested buffers (and threshold buffers) under one data lock, so their lengths are mutually consistent
            //(GitHub issue 22); the JSON is built outside the lock
            var snapshots: [String: (raw: [Double], size: Int)] = [:]
            var extraSnapshots: [String: [Double]] = [:]
            self.experiment.dataLock.read {
                for (bufferName, value) in query {
                    guard let b = self.experiment.buffers[bufferName] else {
                        continue //Just ignore buffers that do not exist. The user might have changed to a different experiment, so we need to send a session id to inform the browser - even if we do not understand this request
                    }
                    snapshots[bufferName] = (raw: b.toArray(), size: b.size)

                    //A partial request's threshold axis buffer (t) goes into the same snapshot so it aligns
                    if value.count > 0 && value != "full" && !forceFullUpdate {
                        let extraComponents = value.components(separatedBy: "|")
                        if extraComponents.count > 1, let extra = extraComponents.last, let extraBuffer = self.experiment.buffers[extra] {
                            extraSnapshots[extra] = extraBuffer.toArray()
                        }
                    }
                }
            }

            for (bufferName, value) in query {
                guard let snapshot = snapshots[bufferName] else {
                    continue //Buffer does not exist, see above
                }

                var dict = [String: AnyObject]()
                dict["size"] = snapshot.size as AnyObject

                if value.count > 0 {
                    let raw = snapshot.raw

                    //After a clear every buffer gets a full update (get-force-full-update)
                    if value == "full" || forceFullUpdate {
                        dict["updateMode"] = "full" as AnyObject
                        dict["buffer"] = raw.map({$0.isFinite ? $0 as AnyObject : NSNull() as AnyObject}) as AnyObject //The array may contain NaN or Inf, which will throw an error in the JSON conversion.
                        //Detailed thoughts on this problem:
                        //Suppose we have two graphs which plot A vs. t and B vs. t (note: same x-axis!). If A contains invalid values (NaN or Inf), we cannot simply remove them as the indices of A would no longer align with t. Also, we cannot remove the value pair from A and t as t would not align with B, which might have a good value at this index. So, in the end we need to send some kind of "invalid" value
                    }
                    else {
                        let extraComponents = value.components(separatedBy: "|")
                        //A non-numeric threshold is a malformed request (get-invalid-threshold)
                        guard let thresholdGiven = Double(extraComponents.first!) else {
                            returnErrorResponse("Invalid threshold.")
                            return
                        }
                        
                        //We only offer 8-digit precision, so we need to move the threshold to avoid receiving a close number multiple times.
                        //Missing something will probably not be visible on a remote graph and a missing value will be recent after stopping anyway.
                        //Nudge magnitude from the absolute value (log10 of a negative would be NaN), direction stays positive
                        //(get-negative-threshold)
                        let threshold = thresholdGiven.isFinite ? thresholdGiven + pow(10.0, floor(log10(abs(thresholdGiven)/1e7))) : thresholdGiven
                        
                        var final: [Double] = []
                        
                        if extraComponents.count > 1 {
                            let extra = extraComponents.last!

                            guard let extraArray = extraSnapshots[extra] else {
                                returnErrorResponse("Unknown reference buffer.")
                                return
                            }

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
                    //JSON has no NaN/infinity: non-finite is null in every update mode (get-nonfinite-single-value)
                    if let v = snapshot.raw.last, v.isFinite {
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
                completionBlock(ExperimentWebServer.errorResponse(statusCode: 400, reason: "Bad request."))
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
                completionBlock(ExperimentWebServer.errorResponse(statusCode: 400, reason: "Bad request."))
            }
            
            var json = [String: AnyObject]()
            
            for metadata in Metadata.allNonSensorCases {
                switch metadata {
                case .uniqueId:
                    continue
                default:
                    //An unavailable value omits its key instead of answering null (meta-missing-value-representation)
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
                completionBlock(ExperimentWebServer.errorResponse(statusCode: 400, reason: "Bad request."))
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
        
        //-phyphoxRemotePort (AutomationLaunchOptions) pins the port for automation; otherwise the user's setting applies
        let configuredPort = AutomationLaunchOptions.remotePort ?? UInt(UserDefaults.standard.string(forKey: "remoteAccessPort") ?? "80") ?? 80

        //Default port: if 80 is taken, try 8080 and count upwards; a custom port is used exactly as configured
        var candidates: [UInt] = [configuredPort]
        if configuredPort == 80 {
            candidates.append(contentsOf: (8080...8180).map { UInt($0) })
        }

        for candidate in candidates {
            if server!.start(withPort: candidate, bonjourName: nil) {
                port = candidate
                print("Webserver running on \(String(describing: server!.serverURL))")
                return true
            }
        }

        //No free port found. Clean up and report the configured port as blocked.
        port = configuredPort
        server = nil
        return false
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
