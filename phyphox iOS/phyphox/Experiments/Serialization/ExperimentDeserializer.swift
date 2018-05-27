//
//  ExperimentDeserializer.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import Foundation

func getElemetArrayFromValue(_ value: AnyObject) -> [AnyObject] {
    var values: [AnyObject] = []
    
    if value is NSMutableArray {
        for item in (value as! NSMutableArray) {
            values.append(item as AnyObject)
        }
    }
    else if value is NSArray {
        values.append(contentsOf: value as! Array)
    }
    else {
        values.append(value)
    }
    
    return values
}

func getElementsWithKey(_ xml: NSDictionary, key: String) -> [AnyObject]? {
    let read = xml[key]
    
    if let v = read {
        return getElemetArrayFromValue(v as AnyObject)
    }
    
    return nil
}

final class ExperimentDeserializer: NSObject {
    private let parser: XMLParser
    
    init(data: Data) {
        parser = XMLParser(data: data)
        super.init()
    }
    
    init(inputStream: InputStream) {
        parser = XMLParser(stream: inputStream)
        super.init()
    }
    
    func deserialize() throws -> Experiment {
        XMLDictionaryParser.sharedInstance().attributesMode = XMLDictionaryAttributesMode.dictionary
        
        let dictionary = XMLDictionaryParser.sharedInstance().dictionary(with: parser)! as NSDictionary
        guard dictionary.nodeName() == "phyphox" else {
            throw SerializationError.invalidExperimentFile(message: "phyphox root node not present.")
        }
        
        //Check file version
        let supported_major = 1
        let supported_minor = 6
        if let version = dictionary.attributes()?["version"] as? String {
            let versionArray = version.split{$0 == "."}.map(String.init)
            let major = Int(versionArray[0]) ?? 1
            let minor = Int(versionArray[1]) ?? 0
            if (major > supported_major || (major == supported_major && minor > supported_minor)) {
                throw SerializationError.newExperimentFileVersion(phyphoxFormat: "\(supported_major).\(supported_minor)", fileFormat: version)
            }
        }
        
        let attributes = dictionary[XMLDictionaryAttributesKey] as! [String: AnyObject]?
        let appleBan = boolFromXML(attributes, key: "appleBan", defaultValue: false)
        let defaultLanguage = stringFromXML(attributes, key: "locale", defaultValue: "")
        
        var d = dictionary["description"]
        let descriptionRAW: String? = (d != nil ? try textFromXML(d! as AnyObject) : nil)
        let description: String?
        if descriptionRAW == nil {
            description = descriptionRAW
        } else {
            description = descriptionRAW!.replacingOccurrences(of: "(?m)((?:^\\s+)|(?:\\s+$))", with: "\n", options: NSString.CompareOptions.regularExpression, range: nil)
        }
        d = dictionary["category"]
        let category: String? = (d != nil ? try textFromXML(d! as AnyObject) : nil)
        d = dictionary["title"]
        let title: String? = (d != nil ? try textFromXML(d! as AnyObject) : nil)
        d = dictionary["state-title"]
        let stateTitle: String? = (d != nil ? try textFromXML(d! as AnyObject) : nil)
        
        var links: [String: String] = [:]
        var highlightedLinks: [String: String] = [:]
        if (dictionary["link"] != nil) {
            for dict in getElemetArrayFromValue(dictionary["link"]! as AnyObject) as! [NSDictionary] {
                let url = dict[XMLDictionaryTextKey] as? String ?? ""
                let attributes = dict[XMLDictionaryAttributesKey] as! [String: AnyObject]?
                
                let label = stringFromXML(attributes, key: "label", defaultValue: "Link")
                
                let highlight = boolFromXML(attributes, key: "highlight", defaultValue: false)
                
                links[label] = url
                if (highlight) {
                    highlightedLinks[label] = url
                }
            }
        }
        
        let buffersRaw = try parseDataContainers(dictionary["data-containers"] as! NSDictionary?)
        
        guard let buffers = buffersRaw.0 else {
            throw SerializationError.invalidExperimentFile(message: "Could not load data containers.")
        }
        
        let translation = try parseTranslations(dictionary["translations"] as! NSDictionary?, defaultLanguage: defaultLanguage)
        
        let analysis = try parseAnalysis(dictionary["analysis"] as! NSDictionary?, buffers: buffers)
        
        let inputs = try parseInputs(dictionary["input"] as! NSDictionary?, buffers: buffers, analysis: analysis)
        
        let sensorInputs = inputs.0
        let gpsInputs = inputs.1
        let gpsInput = gpsInputs?.count ?? 0 > 0 ? gpsInputs![0] : nil
        let audioInputs = inputs.2
        let audioInput = audioInputs?.count ?? 0 > 0 ? audioInputs![0] : nil
        
        let viewDescriptors = try parseViews(dictionary["views"] as! NSDictionary?, buffers: buffers, analysis: analysis, translation: translation)
        
        let export = parseExport(dictionary["export"] as! NSDictionary?, buffers: buffers, translation: translation)
        
        let output = parseOutput(dictionary["output"] as! NSDictionary?, buffers: buffers)
        
        let iconRaw = dictionary["icon"]
        let icon = parseIcon((iconRaw ?? title ?? "") as AnyObject)
        guard icon != nil else {
            throw SerializationError.invalidExperimentFile(message: "Icon could not be parsed.")
        }
        
        let anyTitle = title ?? translation?.selectedTranslation?.titleString
        let anyCategory = category ?? translation?.selectedTranslation?.categoryString
        
        guard anyTitle != nil && anyCategory != nil else {
            throw SerializationError.invalidExperimentFile(message: "Experiment must define a title and a category.")
        }
        
        let experiment = Experiment(title: anyTitle!, stateTitle: stateTitle, description: description, links: links, highlightedLinks: highlightedLinks, category: anyCategory!, icon: icon!, appleBan: appleBan, local: true, translation: translation, buffers: buffersRaw, sensorInputs: sensorInputs, gpsInput: gpsInput, audioInput: audioInput, output: output, viewDescriptors: viewDescriptors, analysis: analysis, export: export)
        
        return experiment
    }

    func deserializeAsynchronous(_ completion: @escaping (_ experiment: Experiment?, _ error: SerializationError?) -> Void) {
        serializationQueue.async { () -> Void in
            do {
                let experiment = try self.deserialize()
                
                mainThread({
                    completion(experiment, nil)
                })
            }
            catch {
                mainThread({
                    completion(nil, error as? SerializationError)
                })
            }
        }
    }
    
    //MARK: - Parsing
    
    func parseDataContainers(_ dataContainers: NSDictionary?) throws -> ([String: DataBuffer]?, [DataBuffer]?) {
        if dataContainers != nil {
            let parser = ExperimentDataContainersParser(dataContainers!)
            
            return try parser.parse()
        }
        
        return (nil, nil)
    }
    
    func parseIcon(_ icon: AnyObject) -> ExperimentIcon? {
        let parser = ExperimentIconParser(icon)
        
        return parser.parse()
    }
    
    func parseOutput(_ outputs: NSDictionary?,  buffers: [String : DataBuffer]) -> ExperimentOutput? {
        if (outputs != nil) {
            let parser = ExperimentOutputParser(outputs!)
            
            return parser.parse(buffers)
        }
        
        return nil
    }
    
    func parseExport(_ exports: NSDictionary?, buffers: [String : DataBuffer], translation: ExperimentTranslationCollection?) -> ExperimentExport? {
        if (exports != nil) {
            let parser = ExperimentExportParser(exports!)
            
            return parser.parse(buffers, translation: translation)
        }
        
        return nil
    }
    
    func parseInputs(_ inputs: NSDictionary?, buffers: [String : DataBuffer], analysis: ExperimentAnalysis?) throws -> ([ExperimentSensorInput]?, [ExperimentGPSInput]?, [ExperimentAudioInput]?, [ExperimentBluetoothInput]?) {
        if (inputs != nil) {
            let parser = ExperimentInputsParser(inputs!)
            
            return try parser.parse(buffers, analysis: analysis)
        }
        
        return (nil, nil, nil, nil)
    }
    
    func parseViews(_ views: NSDictionary?, buffers: [String : DataBuffer], analysis: ExperimentAnalysis?, translation: ExperimentTranslationCollection?) throws -> [ExperimentViewCollectionDescriptor]? {
        if (views != nil) {
            let parser = ExperimentViewsParser(views!)
            
            return try parser.parse(buffers, analysis: analysis, translation: translation)
        }
        
        return nil
    }
    
    func parseAnalysis(_ analysis: NSDictionary?, buffers: [String : DataBuffer]) throws -> ExperimentAnalysis? {
        if (analysis != nil) {
            let parser = ExperimentAnalysisParser(analysis!)
            return try parser.parse(buffers)
        }
        
        return nil
    }
    
    func parseTranslations(_ translations: NSDictionary?, defaultLanguage: String) throws -> ExperimentTranslationCollection? {
        if (translations != nil) {
            let parser = ExperimentTranslationsParser(translations!, defaultLanguage: defaultLanguage)
            
            return try parser.parse()
        }
        
        return nil
    }
}
