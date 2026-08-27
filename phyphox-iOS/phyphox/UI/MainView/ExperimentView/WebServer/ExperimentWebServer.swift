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
    
    //Answers whether the measurement (or, with a timed run, its countdown) actually began.
    //A start can be refused, most commonly by a Bluetooth device that is not connected yet,
    //and /control?cmd=start has to report that (control-start-refused).
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

    //CORS: allow cross-origin browser pages to read remote-access responses, matching the
    //Android implementation (RemoteServer.respond()). Wraps a handler's completion block so
    //every response, including error responses, carries the header.
    private static func cors(_ completionBlock: @escaping GCDWebServerCompletionBlock) -> GCDWebServerCompletionBlock {
        return { response in
            response?.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
            completionBlock(response)
        }
    }

    //An error response is never empty: it carries {"error": "<reason>"} as application/json
    //whatever the status code, the pattern /export and /res already use
    //(error-response-content-type in phyphox-docs; must stay in step with Android). The reason
    //is human-readable and not part of the contract - clients must not match on it.
    private static func errorResponse(statusCode: Int, reason: String) -> GCDWebServerResponse? {
        let response = GCDWebServerDataResponse(jsonObject: ["error": reason])
        response?.statusCode = statusCode
        return response
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
            cors(completionBlock)(errorResponse(statusCode: 400, reason: "Malformed request body."))
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
                //Unlike the other commands, the answer says whether the measurement began and
                //not merely that the command was accepted, so wait for the attempt on the main
                //thread and report its outcome (control-start-refused).
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

        //Bulk write of buffer values from a JSON body: the array-valued counterpart of
        //control?cmd=set, specified in phyphox-docs (openapi.yaml, path /set). GET is
        //registered so it can be answered with a clean result:false instead of a 405. Must
        //stay in step with Android (RemoteServer.handleSet), error messages included.
        addGETPOSTHandler(pathRegex: "/set", asyncProcessBlock: { [unowned self] (request, completionBlock) in
            let completionBlock = ExperimentWebServer.cors(completionBlock)
            func returnSetError(_ error: String) {
                completionBlock(GCDWebServerDataResponse(jsonObject: ["result": false, "error": error]))
            }

            //A GET or a form-encoded body is a well-formed request that cannot carry the
            //documented shape - rejected with result:false, while a body that is not
            //parseable JSON at all (or not a JSON object) is a 400 like everywhere else
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
                        //null is exactly the representation /get uses for every non-finite
                        //value, so /get output can be fed back unchanged
                        values.append(.nan)
                    }
                    else if let number = entry as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
                        values.append(number.doubleValue)
                    }
                    else if let string = entry as? String {
                        //The file format's number lexical space, with the same helper the
                        //experiment parser uses: "nan"/"Infinity"/"-infinity" work, "inf"
                        //does not
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

            //...then write: on any error above nothing was written. The buffer writes mark
            //the analysis as having new data through the observer mechanism, exactly like
            //cmd=set. An empty buffers object is a valid no-op.
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
            //A request without any parameters is fine: it answers an empty buffer object and
            //the status object, the natural way to poll only the status (get-no-parameters)
            
            var mainDict = [String: AnyObject]()

            var bufferDict = [String: AnyObject]()

            //Read the force-full flag once, so it is consistent with the snapshot below and with
            //the reset at the end of the request
            let forceFullUpdate = self.forceFullUpdate

            //Snapshot all requested buffers (and any referenced threshold buffers) in one read on
            //the experiment's data lock, so their lengths are mutually consistent even though inputs
            //and analysis keep writing during the measurement. Without this, a buffer written to
            //after another was already read comes back one sample longer (GitHub issue 22). The JSON
            //is built afterwards, outside the lock, to keep the writers blocked as briefly as
            //possible.
            var snapshots: [String: (raw: [Double], size: Int)] = [:]
            var extraSnapshots: [String: [Double]] = [:]
            self.experiment.dataLock.read {
                for (bufferName, value) in query {
                    guard let b = self.experiment.buffers[bufferName] else {
                        continue //Just ignore buffers that do not exist. The user might have changed to a different experiment, so we need to send a session id to inform the browser - even if we do not understand this request
                    }
                    snapshots[bufferName] = (raw: b.toArray(), size: b.size)

                    //A partial request may reference a second buffer (t) as the threshold axis;
                    //capture it in the same snapshot so it aligns with the data buffer
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

                    //After a clear, every requested buffer is upgraded to a full update,
                    //whatever its request asked for (get-force-full-update)
                    if value == "full" || forceFullUpdate {
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
                            returnErrorResponse("Invalid threshold.")
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
                    //JSON has no representation for NaN or infinity, so a non-finite value is
                    //null in every update mode (get-nonfinite-single-value)
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
        
        //-phyphoxRemotePort pins the port for unattended automation (see AutomationLaunchOptions
        //in AppDelegate); otherwise the user's setting applies
        let configuredPort = AutomationLaunchOptions.remotePort ?? UInt(UserDefaults.standard.string(forKey: "remoteAccessPort") ?? "80") ?? 80

        //If the port setting is at its default, we assume that the user does not care (or might
        //not even know) which port is used, so if the default port is taken, we try 8080 and then
        //count upwards from there until we find a free one. A custom port, however, is used
        //exactly as configured.
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
