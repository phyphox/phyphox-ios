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
    func clearData()
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
        
        server!.addGETHandler(forBasePath: "/", directoryPath: path, indexFilename: "index.html", cacheAge: 0, allowRangeRequests: false)
        
        server!.addHandler(forMethod: "GET", pathRegex: "/logo", request:GCDWebServerRequest.self, asyncProcessBlock: { (request, completionBlock) in
            let file = Bundle.main.path(forResource: "phyphox-webinterface/phyphox_orange", ofType: "png")
            let image = UIImage.init(contentsOfFile: file!)
            let response = GCDWebServerDataResponse(data: image!.pngData()!, contentType: "image/png")
            
            completionBlock(response)
        })
        
        server!.addHandler(forMethod: "GET", pathRegex: "/res", request:GCDWebServerRequest.self, asyncProcessBlock: { (request, completionBlock) in
            
            func returnErrorResponse(_ response: AnyObject) {
                let response = GCDWebServerDataResponse(jsonObject: response)
                
                completionBlock(response)
            }
            
            let components = URLComponents(url: (request.url), resolvingAgainstBaseURL: true)
            let query = queryDictionary(components?.query ?? "")
            if let src = query["src"] {
                if self.experiment.resources.contains(src) {
                    if let file = self.experiment.resourceFolder?.appendingPathComponent(src) {
                        if FileManager.default.fileExists(atPath: file.path) {
                            completionBlock(GCDWebServerFileResponse(file: file.path))
                            return
                        }
                    }
                }
                returnErrorResponse(["error": "Unknown file."] as AnyObject)
            } else {
                returnErrorResponse(["error": "No file requested."] as AnyObject)
            }
        })
        
        server!.addHandler(forMethod: "GET", pathRegex: "/export", request:GCDWebServerRequest.self, asyncProcessBlock: { [unowned self] (request, completionBlock) in
            func returnErrorResponse(_ response: AnyObject) {
                let response = GCDWebServerDataResponse(jsonObject: response)
                
                completionBlock(response)
            }
                        
            let components = URLComponents(url: (request.url), resolvingAgainstBaseURL: true)
            let query = queryDictionary(components?.query ?? "")
            
            if let formatStr = query["format"], let format = WebServerUtilities.mapFormatString(formatStr) {
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
                returnErrorResponse(["error": "Format out of range"] as AnyObject)
            }
            })
        
        server!.addHandler(forMethod: "GET", pathRegex: "/control", request:GCDWebServerRequest.self, asyncProcessBlock: { [unowned self] (request, completionBlock) in
            func returnErrorResponse() {
                let response = GCDWebServerDataResponse(jsonObject: ["result": false])
                
                completionBlock(response)
            }
            
            func returnSuccessResponse() {
                let response = GCDWebServerDataResponse(jsonObject: ["result": true])
                
                completionBlock(response)
            }
                        
            let components = URLComponents(url: (request.url), resolvingAgainstBaseURL: true)!
            let query = queryDictionary(components.query ?? "")
            
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
                mainThread {
                    self.delegate!.clearData()
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
                
                if (self.htmlId2ViewElement.count > elementIndex) {
                    if let buttonDescriptor = self.htmlId2ViewElement[elementIndex] as? ButtonViewDescriptor {
                        self.delegate?.buttonPressed(viewDescriptor: buttonDescriptor, buttonViewTriggerCallback: nil)
                    }
                }
                
                returnSuccessResponse()
            }
            else {
                returnErrorResponse()
            }
            })
        
        server!.addHandler(forMethod: "GET", pathRegex: "/get", request:GCDWebServerRequest.self, asyncProcessBlock: { [unowned self] (request, completionBlock) in
            func returnErrorResponse() {
                let response = GCDWebServerResponse(statusCode: 400)
                
                completionBlock(response)
            }
            
            guard let queryString = request.url.query?.removingPercentEncoding else {
                returnErrorResponse()
                return
            }
            
            let query = queryDictionary(queryString)
            
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
                    
                    if value == "full" || (value == "partial" && self.forceFullUpdate == true) {
                        dict["updateMode"] = "full" as AnyObject
                        dict["buffer"] = raw.map({$0.isFinite ? $0 as AnyObject : NSNull() as AnyObject}) as AnyObject //The array may contain NaN or Inf, which will throw an error in the JSON conversion.
                        //Detailed thoughts on this problem:
                        //Suppose we have two graphs which plot A vs. t and B vs. t (note: same x-axis!). If A contains invalid values (NaN or Inf), we cannot simply remove them as the indices of A would no longer align with t. Also, we cannot remove the value pair from A and t as t would not align with B, which might have a good value at this index. So, in the end we need to send some kind of "invalid" value
                    }
                    else {
                        let extraComponents = value.components(separatedBy: "|")
                        let thresholdGiven = (Double(extraComponents.first!) ?? -Double.infinity)
                        
                        //We only offer 8-digit precision, so we need to move the threshold to avoid receiving a close number multiple times.
                        //Missing something will probably not be visible on a remote graph and a missing value will be recent after stopping anyway.
                        let threshold = thresholdGiven.isFinite ? thresholdGiven + pow(10.0, floor(log10(thresholdGiven/1e7))) : -Double.infinity
                        
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
                    if let v = b.last {
                        if v.isFinite {
                            dict["buffer"] = [v] as AnyObject
                        } else {
                            dict["buffer"] = [String(v)] as AnyObject
                        }
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
        
        server!.addHandler(forMethod: "GET", pathRegex: "/config", request:GCDWebServerRequest.self, asyncProcessBlock: { [unowned self] (request, completionBlock) in
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
        
        server!.addHandler(forMethod: "GET", pathRegex: "/meta", request:GCDWebServerRequest.self, asyncProcessBlock: { (request, completionBlock) in
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
                    json[metadata.identifier] = metadata.get(hash: "") as AnyObject
                }
            }
            
            let response = GCDWebServerDataResponse(jsonObject: json)
            
            completionBlock(response)
        })
        
        server!.addHandler(forMethod: "GET", pathRegex: "/time", request:GCDWebServerRequest.self, asyncProcessBlock: { [unowned self] (request, completionBlock) in
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
