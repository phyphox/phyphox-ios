//
//  ExperimentDeserializer.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 RWTH Aachen. All rights reserved.
//

import Foundation

func getElemetArrayFromValue(value: AnyObject) -> [NSDictionary] {
    var values: [NSDictionary] = []
    
    if value.isKindOfClass(NSArray) {
        values.appendContentsOf((value as! NSArray) as! Array)
    }
    else {
        values.append(value as! NSDictionary)
    }
    
    return values
}

func getElementsWithKey(xml: NSDictionary, key: String) -> [NSDictionary]? {
    let read = xml[key]
    
    if let v = read {
        return getElemetArrayFromValue(v)
    }
    
    return nil
}

final class ExperimentDeserializer: NSObject {
    private var dictionary: NSDictionary!
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
        
        let inputs = dictionary["input"] as! NSDictionary?
        parseInputs(inputs)
        
        let analysis = dictionary["analysis"] as! NSDictionary?
        parseAnalysis(analysis)
        
        let translations = dictionary["translations"] as! NSDictionary?
        parseTranslations(translations)
        
        let views = dictionary["views"] as! NSDictionary?
        parseViews(views)
        
        let export = dictionary["export"] as! NSDictionary?
        parseExports(export)
        
        let icon = dictionary["icon"] as! String?
        
        let description = dictionary["description"] as! String
        let category = dictionary["category"] as! String
        let title = dictionary["title"] as! String
        
        
        let experiment = Experiment(title: title, description: description, category: category)
        
        throw SerializationError.GenericError
    }
    
    func parseExports(_exports: NSDictionary?) {
        
    }
    
    func parseInputs(_inputs: NSDictionary?) {
        if let inputs = _inputs {
            var sensors = getElementsWithKey(inputs, key: "sensors")
            var audio = getElementsWithKey(inputs, key: "audio")
            
        }
    }
    
    func parseAnalysis(_analysis: NSDictionary?) {
        if let analysis_ = _analysis {
            for (key, value) in analysis_ {
                var analysis = getElemetArrayFromValue(value)
                
            }
        }
    }
    
    func parseTranslations(_translations: NSDictionary?) {
        if let translations_ = _translations {
            var translations = getElementsWithKey(translations_, key: "translation")
            
        }
    }
    
    func parseViews(_views: NSDictionary?) {
        if let views_ = _views {
            var views = getElementsWithKey(views_, key: "view")!
            
        }
    }
    
    func deserializeAsynchronous(completion: (experiment: Experiment?, error: SerializationError?) -> Void) {
        dispatch_async(serializationQueue) { () -> Void in
            do {
                let experiment = try self.deserialize()
                
                completion(experiment: experiment, error: nil)
            }
            catch {
                completion(experiment: nil, error: error as? SerializationError)
            }
        }
    }
}
