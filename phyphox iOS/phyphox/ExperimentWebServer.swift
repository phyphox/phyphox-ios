//
//  ExperimentWebServer.swift
//  phyphox
//
//  Created by Jonas Gessner on 20.04.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation
import GCDWebServers

protocol ExperimentWebServerDelegate: class {
    var timerRunning: Bool { get }
    var remainingTimerTime: Double { get }
    
    func startExperiment()
    func stopExperiment()
    func runExport(sets: [ExperimentExportSet], format: ExportFileFormat, completion: (NSError?, NSURL?) -> Void)
}

final class ExperimentWebServer {
    var running: Bool {
        return server != nil
    }
    
    private(set) var path: String?
    
    private var server: GCDWebServer?
    private var temporaryFiles = [String]()
    
    weak var delegate: ExperimentWebServerDelegate?
    
    unowned let experiment: Experiment
    
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
        
        server = GCDWebServer()
        path = WebServerUtilities.prepareWebServerFilesForExperiment(experiment)
        
        server!.addGETHandlerForBasePath("/", directoryPath: path, indexFilename: "index.html", cacheAge: 0, allowRangeRequests: false)
        
        server!.addHandlerForMethod("GET", pathRegex: "/logo", requestClass:GCDWebServerRequest.self, asyncProcessBlock: { (request, completionBlock) in
            let response = GCDWebServerDataResponse(data: UIImagePNGRepresentation(WebServerUtilities.genPlaceHolderImage()), contentType: "image/png")
            
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
                
                for (i, set) in self.experiment.export!.sets.enumerate() {
                    if query["set\(i)"] != nil {
                        sets.append(set)
                    }
                }
                
                if sets.count == 0 {
                    sets = self.experiment.export!.sets
                }
                
                self.delegate!.runExport(sets, format: format) { error, URL in
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
                    returnErrorResponse()
                    return
                }
                
                var dict = [String: AnyObject]()
                dict["size"] = b.size
                
                if value.characters.count > 0 {
                    let raw = b.toArray()
                    
                    if value == "full" {
                        dict["updateMode"] = "full"
                        dict["buffer"] = raw
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
                        dict["buffer"] = final
                    }
                }
                else {
                    dict["updateMode"] = "single"
                    dict["buffer"] = [b.last ?? 0.0]
                }
                
                
                bufferDict[bufferName] = dict
            }
            
            mainDict["buffer"] = bufferDict
            mainDict["status"] = ["measuring": self.experiment.running, "timedRun": self.delegate!.timerRunning, "countDown": Int(round(1000*self.delegate!.remainingTimerTime))]
            
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
