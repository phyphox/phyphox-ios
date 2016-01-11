//
//  ExperimentDeserializer.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

func getElemetArrayFromValue(value: AnyObject) -> [AnyObject] {
    var values: [AnyObject] = []
    
    if value.isKindOfClass(NSMutableArray) {
        for item in (value as! NSMutableArray) {
            values.append(item)
        }
    }
    else if value.isKindOfClass(NSArray) {
        values.appendContentsOf(value as! Array)
    }
    else {
        values.append(value)
    }
    
    return values
}

func getElementsWithKey(xml: NSDictionary, key: String) -> [AnyObject]? {
    let read = xml[key]
    
    if let v = read {
        return getElemetArrayFromValue(v)
    }
    
    return nil
}

final class ExperimentDeserializer: NSObject {
    private let parser: NSXMLParser
    
    init(data: NSData) {
        parser = NSXMLParser(data: data)
        super.init()
    }
    
    init(inputStream: NSInputStream) {
        parser = NSXMLParser(stream: inputStream)
        super.init()
    }
    
    func deserialize() throws -> Experiment {
        XMLDictionaryParser.sharedInstance().attributesMode = XMLDictionaryAttributesMode.Dictionary
        
        let dictionary = XMLDictionaryParser.sharedInstance().dictionaryWithParser(parser)
        
        let description = dictionary["description"] as! String
        let category = dictionary["category"] as! String
        let title = dictionary["title"] as! String
        
        let buffers = parseDataContainers(dictionary["data-containers"] as! NSDictionary?)
        
        if buffers == nil || buffers.count == 0 {
            throw SerializationError.InvalidExperimentFile
        }
        
        let sensorInputs = parseInputs(dictionary["input"] as! NSDictionary?, buffers: buffers)
        
        let translations = parseTranslations(dictionary["translations"] as! NSDictionary?)

        let viewDescriptors = parseViews(dictionary["views"] as! NSDictionary?, buffers: buffers)
        
        parseAnalysis(dictionary["analysis"] as! NSDictionary?, buffers: buffers)
        
        parseExports(dictionary["export"] as! NSDictionary?)
        
        parseOutputs(dictionary["output"] as! NSDictionary?)
        
        let iconRaw = dictionary["icon"]
        let icon = parseIcon(iconRaw != nil ? iconRaw! : title)
        
        if icon == nil {
            throw SerializationError.InvalidExperimentFile
        }
        
        let experiment = Experiment(title: title, description: description, category: category, icon: icon!, local: true, translations: translations, sensorInputs: sensorInputs, viewDescriptors: viewDescriptors)
        
        return experiment
    }
    
    func deserializeAsynchronous(completion: (experiment: Experiment?, error: SerializationError?) -> Void) {
        dispatch_async(serializationQueue) { () -> Void in
            do {
                let experiment = try self.deserialize()
                
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    completion(experiment: experiment, error: nil)
                })
            }
            catch {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    completion(experiment: nil, error: error as? SerializationError)
                })
            }
        }
    }
    
    //MARK: - Parsing
    
    func parseDataContainers(dataContainers: NSDictionary?) -> [String: DataBuffer]! {
        if dataContainers != nil {
            let parser = ExperimentDataContainersParser(dataContainers!)
            
            return parser.parse()
        }
        
        return nil
    }
    
    func parseIcon(icon: AnyObject) -> ExperimentIcon? {
        let parser = ExperimentIconParser(icon)
        
        return parser.parse()
    }
    
    func parseOutputs(outputs: NSDictionary?) {
        if (outputs != nil) {
            let parser = ExperimentOutputParser(outputs!)
            
            parser.parse()
        }
    }
    
    func parseExports(exports: NSDictionary?) {
        if (exports != nil) {
            let parser = ExperimentExportParser(exports!)
            
            parser.parse()
        }
    }
    
    func parseInputs(inputs: NSDictionary?, buffers: [String : DataBuffer]) -> [SensorInput]? {
        if (inputs != nil) {
            let parser = ExperimentInputsParser(inputs!)
            
            return parser.parse(buffers)
        }
        
        return nil
    }
    
    func parseViews(views: NSDictionary?, buffers: [String : DataBuffer]) -> [ExperimentViewDescriptor]? {
        if (views != nil) {
            let parser = ExperimentViewsParser(views!)
            
            return parser.parse(buffers)
        }
        
        return nil
    }
    
    func parseAnalysis(analysis: NSDictionary?, buffers: [String : DataBuffer]) {
        if (analysis != nil) {
            let parser = ExperimentAnalysisParser(analysis!)
            parser.parse(buffers)
        }
    }
    
    func parseTranslations(translations: NSDictionary?) -> [String: ExperimentTranslation]? {
        if (translations != nil) {
            let parser = ExperimentTranslationsParser(translations!)
            
            return parser.parse()
        }
        
        return nil
    }
}
