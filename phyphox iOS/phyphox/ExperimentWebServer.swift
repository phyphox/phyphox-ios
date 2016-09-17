//
//  ExperimentWebServer.swift
//  phyphox
//
//  Created by Jonas Gessner on 20.04.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation
import GCDWebServers

protocol ExperimentWebServerDelegate: class {
    var timerRunning: Bool { get }
    var remainingTimerTime: Double { get }
    
    func startExperiment()
    func stopExperiment()
    func clearData()
    func runExport(format: ExportFileFormat, completion: (NSError?, NSURL?) -> Void)
}

final class ExperimentWebServer {
    var running: Bool {
        return server != nil
    }
    
    private(set) var path: String?
    
    private(set) var server: GCDWebServer?
    private var temporaryFiles = [String]()
    
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
        
        let startTime = NSDate()
        sessionID = String(Int(CFAbsoluteTimeGetCurrent()*1e9) & 0xffffff)
        
        server = GCDWebServer()
        path = WebServerUtilities.prepareWebServerFilesForExperiment(experiment)
        
        server!.addGETHandlerForBasePath("/", directoryPath: path, indexFilename: "index.html", cacheAge: 0, allowRangeRequests: false)
        
        server!.addHandlerForMethod("GET", pathRegex: "/logo", requestClass:GCDWebServerRequest.self, asyncProcessBlock: { (request, completionBlock) in
            let file = NSBundle.mainBundle().pathForResource("phyphox-webinterface/phyphox_orange", ofType: "png")
            let image = UIImage.init(contentsOfFile: file!)
            let response = GCDWebServerDataResponse(data: UIImagePNGRepresentation(image!), contentType: "image/png")
            
            completionBlock(response)
        })
        
        server!.addHandlerForMethod("GET", pathRegex: "/export", requestClass:GCDWebServerRequest.self, asyncProcessBlock: { [unowned self] (request, completionBlock) in
            func returnErrorResponse(response: AnyObject) {
                let response = GCDWebServerDataResponse(JSONObject: response)
                
                completionBlock(response)
            }
            
            let result: String
            
            let components = NSURLComponents(URL: request.URL, resolvingAgainstBaseURL: true)!
            let query = queryDictionary(components.query!)
            
            if let formatStr = query["format"], let format = WebServerUtilities.mapFormatString(formatStr) {
                var sets = [ExperimentExportSet]()
                
                self.delegate!.runExport(format) { error, URL in
                    if error == nil {
                        self.temporaryFiles.append(URL!.path!)
                        let response = GCDWebServerFileResponse(file: URL!.path, isAttachment: true)
                        completionBlock(response)
                    }
                    else {
                        returnErrorResponse(["error": error!.localizedDescription])
                    }
                }
            }
            else {
                returnErrorResponse(["error": "Format out of range"])
            }
            })
        
        server!.addHandlerForMethod("GET", pathRegex: "/control", requestClass:GCDWebServerRequest.self, asyncProcessBlock: { [unowned self] (request, completionBlock) in
            func returnErrorResponse() {
                let response = GCDWebServerDataResponse(JSONObject: ["result": false])
                
                completionBlock(response)
            }
            
            func returnSuccessResponse() {
                let response = GCDWebServerDataResponse(JSONObject: ["result": true])
                
                completionBlock(response)
            }
            
            let result: String
            
            let components = NSURLComponents(URL: request.URL, resolvingAgainstBaseURL: true)!
            let query = queryDictionary(components.query!)
            
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
                guard let bufferName = query["buffer"], let valueString = query["value"], let buffer = self.experiment.buffers.0?[bufferName], let value = Double(valueString) else {
                    returnErrorResponse()
                    return
                }
                
                if !isfinite(value) {
                    returnErrorResponse()
                }
                else {
                    buffer.append(value)
                    returnSuccessResponse()
                }
            }
            else {
                returnErrorResponse()
            }
            })
        
        server!.addHandlerForMethod("GET", pathRegex: "/get", requestClass:GCDWebServerRequest.self, asyncProcessBlock: { [unowned self] (request, completionBlock) in
            func returnErrorResponse() {
                let response = GCDWebServerResponse(statusCode: 400)
                
                completionBlock(response)
            }
            
            guard let queryString = request.URL.query?.stringByRemovingPercentEncoding else {
                returnErrorResponse()
                return
            }
            
            let query = queryDictionary(queryString)
            
            var mainDict = [String: AnyObject]()
            
            var bufferDict = [String: AnyObject]()
            
            for (bufferName, value) in query {
                guard let b = self.experiment.buffers.0?[bufferName] else {
                    continue //Just ignore buffers that do not exist. The user might have changed to a different experiment, so we need to send a session id to inform the browser - even if we do not understand this request
                }
                
                var dict = [String: AnyObject]()
                dict["size"] = b.size
                
                if value.characters.count > 0 {
                    let raw = b.toArray()
                    
                    if value == "full" || (value == "partial" && self.forceFullUpdate == true) {
                        dict["updateMode"] = "full"
                        dict["buffer"] = raw.map({$0.isFinite ? $0 : NSNull()}) //The array may contain NaN or Inf, which will throw an error in the JSON conversion.
                        //Detailed thoughts on this problem:
                        //Suppose we have two graphs which plot A vs. t and B vs. t (note: same x-axis!). If A contains invalid values (NaN or Inf), we cannot simply remove them as the indices of A would no longer align with t. Also, we cannot remove the value pair from A and t as t would not align with B, which might have a good value at this index. So, in the end we need to send some kind of "invalid" value
                    }
                    else {
                        let extraComponents = value.componentsSeparatedByString("|")
                        let threshold = Double(extraComponents.first!) ?? -Double.infinity
                        
                        var final: [Double] = []
                        
                        if extraComponents.count > 1 {
                            let extra = extraComponents.last!
                            
                            guard let extraBuffer = self.experiment.buffers.0?[extra] else {
                                let response = GCDWebServerResponse(statusCode: 400)
                                
                                completionBlock(response)
                                return
                            }
                            
                            let extraArray = extraBuffer.toArray()
                            
                            for (i, v) in extraArray.enumerate() {
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

                        dict["updateMode"] = "partial"
                        dict["buffer"] = final.map({$0.isFinite ? $0 : NSNull()}) //The array may contain NaN or Inf, which will throw an error in the JSON conversion. (See above)
                    }
                }
                else {
                    dict["updateMode"] = "single"
                    if let v = b.last {
                        if v.isFinite {
                            dict["buffer"] = [v]
                        } else {
                            dict["buffer"] = [String(v)]
                        }
                    } else {
                        dict["buffer"] = [NSNull()]
                    }
                }
                
                
                bufferDict[bufferName] = dict
            }
            
            mainDict["buffer"] = bufferDict
            mainDict["status"] = ["session": self.sessionID, "measuring": self.experiment.running, "timedRun": self.delegate!.timerRunning, "countDown": Int(round(1000*self.delegate!.remainingTimerTime))]
            
            self.forceFullUpdate = false
            
            let response = GCDWebServerDataResponse(JSONObject: mainDict)
            
            completionBlock(response)
            })
        
        if server!.start() {
            print("Webserver running on \(server!.serverURL)")
            return true
        }
        else {
            server!.stop()
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
            do { try NSFileManager.defaultManager().removeItemAtPath(file) } catch {}
        }
        
        temporaryFiles.removeAll()
        
        do { try NSFileManager.defaultManager().removeItemAtPath(path!) } catch {}
    }
}
