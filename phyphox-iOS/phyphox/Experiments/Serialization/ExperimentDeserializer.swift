//
//  ExperimentDeserializer.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
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

let pars = XMLElementParser(rootHandler: ExperimentFileHandler())

final class ExperimentDeserializer {
    private let parser: XMLParser
    private let local: Bool

    private let data: Data
    init(data: Data, local: Bool) {
        self.local = local
        parser = XMLParser(data: data)
        self.data = data
    }

    func deserialize() throws -> Experiment {
        // TODO set local
        let newExperiment = try pars.parse(data: data)

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

        var links: [ExperimentLink] = []

        if (dictionary["link"] != nil) {
            for dict in getElemetArrayFromValue(dictionary["link"]! as AnyObject) as! [NSDictionary] {
                guard let url = URL(string: dict[XMLDictionaryTextKey] as? String ?? "") else { continue }
                
                let attributes = dict[XMLDictionaryAttributesKey] as! [String: AnyObject]?

                let label = stringFromXML(attributes, key: "label", defaultValue: "Link")

                let highlight = boolFromXML(attributes, key: "highlight", defaultValue: false)

                links.append(ExperimentLink(label: label, url: url, highlighted: highlight))
            }
        }

        let experimentPersistentStorageURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)

        let analysisDictionary = dictionary["analysis"] as? NSDictionary

        let analysisInputBufferNames = getInputBufferNames(for: analysisDictionary)

        let buffers = try parseDataContainers(dictionary["data-containers"] as? NSDictionary, analysisInputBufferNames: analysisInputBufferNames, experimentPersistentStorageURL: experimentPersistentStorageURL)

        guard !buffers.isEmpty else {
            throw SerializationError.invalidExperimentFile(message: "Could not load data containers.")
        }

        let iconRaw = dictionary["icon"]
        guard let icon = parseIcon((iconRaw ?? title ?? "") as AnyObject) else {
            throw SerializationError.invalidExperimentFile(message: "Icon could not be parsed.")
        }

        let translation = try parseTranslations(dictionary["translations"] as? NSDictionary, defaultLanguage: defaultLanguage)

        guard let anyTitle = title ?? translation?.selectedTranslation?.titleString,
            let anyCategory = category ?? translation?.selectedTranslation?.categoryString
            else {
                throw SerializationError.invalidExperimentFile(message: "Experiment must define a title and a category.")
        }

        let (sensorInputs, gpsInputs, audioInputs) = try parseInputs(dictionary["input"] as? NSDictionary, buffers: buffers)

        let viewDescriptors = try parseViews(dictionary["views"] as? NSDictionary, buffers: buffers, translation: translation)

        let export = parseExport(dictionary["export"] as? NSDictionary, buffers: buffers, translation: translation)

        let output = parseOutput(dictionary["output"] as? NSDictionary, buffers: buffers)

        let analysis = try parseAnalysis(analysisDictionary, buffers: buffers)

        let experiment = Experiment(title: anyTitle, description: description, links: links, category: anyCategory, icon: icon, local: local, persistentStorageURL: experimentPersistentStorageURL, translation: translation, buffers: buffers, sensorInputs: sensorInputs, gpsInputs: gpsInputs, audioInputs: audioInputs, output: output, viewDescriptors: viewDescriptors, analysis: analysis, export: export)

        return newExperiment
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

    func parseDataContainers(_ dataContainers: NSDictionary?, analysisInputBufferNames: Set<String>, experimentPersistentStorageURL: URL) throws -> [String: DataBuffer] {
        guard let dataContainers = dataContainers else { return [:] }

        let parser = ExperimentDataContainersParser(dataContainers)

        return try parser.parse(analysisInputBufferNames: analysisInputBufferNames, experimentPeristentStorageURL: experimentPersistentStorageURL)
    }

    func parseIcon(_ icon: AnyObject) -> ExperimentIcon? {
        let parser = ExperimentIconParser(icon)

        return parser.parse()
    }

    func parseOutput(_ outputs: NSDictionary?,  buffers: [String : DataBuffer]) -> ExperimentOutput? {
        guard let outputs = outputs else { return nil }

        let parser = ExperimentOutputParser(outputs)

        return parser.parse(buffers)
    }

    func parseExport(_ exports: NSDictionary?, buffers: [String : DataBuffer], translation: ExperimentTranslationCollection?) -> ExperimentExport? {
        guard let exports = exports else { return nil }

        let parser = ExperimentExportParser(exports)

        return parser.parse(buffers, translation: translation)
    }

    func parseInputs(_ inputs: NSDictionary?, buffers: [String : DataBuffer]) throws -> ([ExperimentSensorInput], [ExperimentGPSInput], [ExperimentAudioInput]) {
        guard let inputs = inputs else { return ([], [], []) }

        let parser = ExperimentInputsParser(inputs)

        return try parser.parse(buffers)
    }

    func parseViews(_ views: NSDictionary?, buffers: [String : DataBuffer], translation: ExperimentTranslationCollection?) throws -> [ExperimentViewCollectionDescriptor]? {
        guard let views = views else { return nil }

        let parser = ExperimentViewsParser(views)

        return try parser.parse(buffers, translation: translation)
    }

    func getInputBufferNames(for analysis: NSDictionary?) -> Set<String> {
        guard let analysis = analysis else { return [] }

        let parser = ExperimentAnalysisParser(analysis)
        return parser.getInputBufferNames()
    }

    func parseAnalysis(_ analysis: NSDictionary?, buffers: [String : DataBuffer]) throws -> ExperimentAnalysis? {
        guard let analysis = analysis else { return nil }

        let parser = ExperimentAnalysisParser(analysis)
        return try parser.parse(buffers)
    }

    func parseTranslations(_ translations: NSDictionary?, defaultLanguage: String) throws -> ExperimentTranslationCollection? {
        guard let translations = translations else { return nil }

        let parser = ExperimentTranslationsParser(translations, defaultLanguage: defaultLanguage)

        return try parser.parse()
    }
}
