//
//  WebServerUtilities.swift
//  phyphox
//
//  Created by Jonas Gessner on 15.04.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

import Foundation

final class WebServerUtilities {
    class func genPlaceHolderImage() -> UIImage {
        let s = CGSizeMake(30, 30)
        
        UIGraphicsBeginImageContextWithOptions(s, true, 0.0)
        
        UIColor.greenColor().setFill()
        
        UIBezierPath(rect: CGRect(origin: CGPoint.zero, size: s)).fill()
        
        let img = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return img
    }
    
    class func genPlaceHolderBase64Image() -> String {
        return UIImagePNGRepresentation(genPlaceHolderImage())!.base64EncodedStringWithOptions([])
    }
    
    private class func prepareStyleFile(backgroundColor backgroundColor: UIColor, mainColor: UIColor, highlightColor: UIColor) -> String {
        let raw = try! NSMutableString(contentsOfFile: NSBundle.mainBundle().pathForResource("phyphox-webinterface/style", ofType: "css")!, encoding: NSUTF8StringEncoding)
        
        raw.replaceOccurrencesOfString("###background-color###", withString: backgroundColor.hexStringValue, options: [], range: NSMakeRange(0, raw.length))
        
        raw.replaceOccurrencesOfString("###main-color###", withString: mainColor.hexStringValue, options: [], range: NSMakeRange(0, raw.length))
        
        raw.replaceOccurrencesOfString("###highlight-color###", withString: highlightColor.hexStringValue, options: [], range: NSMakeRange(0, raw.length))
        
        let placeholder = genPlaceHolderBase64Image()
        
        for str in ["###drawablePlay###", "###drawableTimedPlay###", "###drawablePause###", "###drawableTimedPause###", "###drawableExport###", "###drawableColumns###"] {
            raw.replaceOccurrencesOfString(str, withString: placeholder, options: [], range: NSMakeRange(0, raw.length))
        }
        
        return raw as String
    }
    
    private class func prepareIndexFile(experiment: Experiment) -> String {
        let raw = try! NSMutableString(contentsOfFile: NSBundle.mainBundle().pathForResource("phyphox-webinterface/index", ofType: "html")!, encoding: NSUTF8StringEncoding)
        
        raw.replaceOccurrencesOfString("<!-- [[title]] -->", withString: experiment.localizedTitle, options: [], range: NSMakeRange(0, raw.length))
        
        var viewLayout = "var views = ["
        var viewOptions = ""
        
        if let views = experiment.viewDescriptors {
            var idx = 0
            
            for (i, v) in views.enumerate() {
                if i > 0 {
                    viewLayout += ",\n"
                    viewOptions += "\n"
                }
                
                viewLayout += "{\"name\": \"\(v.localizedLabel)\", \"elements\": ["
                
                viewOptions += "<option value=\"\(i)\">\(v.localizedLabel)</option>"
                
                var ffirst = true
                
                for element in v.views {
                    if !ffirst {
                        viewLayout += ", "
                    }
                    ffirst = false
                    
                    viewLayout += "{\"label\": \"\(element.localizedLabel)\", \"index\": \(idx), \"html\": \"\(element.generateViewHTMLWithID(idx))\",\"dataCompleteFunction\": \(element.generateDataCompleteHTMLWithID(idx))"

                    if let graph = element as? GraphViewDescriptor {
                        viewLayout += ", \"partialUpdate\": \"\(graph.partialUpdate ? "partial" : "full")\", \"dataYInput\": \"\(graph.yInputBuffer.name)\", \"dataYInputFunction\":\n\(graph.setDataYHTMLWithID(idx))\n"
                        
                        if let x = graph.xInputBuffer {
                            viewLayout += ", \"dataXInput\": \"\(x.name)\", \"dataXInputFunction\":\n\(graph.setDataXHTMLWithID(idx))\n"
                        }
                    }
                    else if element is InfoViewDescriptor {
                        viewLayout += ", \"partialUpdate\": \"none\""
                    }
                    else if let value = element as? ValueViewDescriptor {
                        viewLayout += ", \"partialUpdate\": \"single\", \"valueInput\":\"\(value.buffer.name)\", \"valueInputFunction\":\n\(value.setValueHTMLWithID(idx))\n"
                    }
                    else if let edit = element as? EditViewDescriptor {
                        viewLayout += ", \"partialUpdate\": \"input\", \"valueInput\":\"\(edit.buffer.name)\", \"valueInputFunction\":\n\(edit.setValueHTMLWithID(idx))\n"
                    }
                    
                    viewLayout += "}"
                    
                    idx += 1
                }
                
                viewLayout += "]}"
            }
        }
        
        viewLayout += "];\n"
        
        var exportStr = ""
        
        if let export = experiment.export {
            for (i, set) in export.sets.enumerate() {
                exportStr += "<div class=\"setSelector\"><input type=\"checkbox\" id=\"set\(i)\" name=\"set\(i)\" /><label for=\"set\(i)\"\">\(set.localizedName)</label></div>\n"
            }
        }
       
        let exportFormats = "<option value=\"0\">CSV</option> <option value=\"1\">Excel</option> <option value=\"2\">CSV (tab separated)</option>"
        
        raw.replaceOccurrencesOfString("<!-- [[viewLayout]] -->", withString: viewLayout, options: [], range: NSMakeRange(0, raw.length))
        raw.replaceOccurrencesOfString("<!-- [[viewOptions]] -->", withString: viewOptions, options: [], range: NSMakeRange(0, raw.length))
        raw.replaceOccurrencesOfString("<!-- [[exportFormatOptions]] -->", withString: exportFormats, options: [], range: NSMakeRange(0, raw.length))
        raw.replaceOccurrencesOfString("<!-- [[exportSetSelectors]] -->", withString: exportStr, options: [], range: NSMakeRange(0, raw.length))
        
        return raw as String
    }
    
    class func mapFormatString(str: String) -> ExportFileFormat? {
        if str == "0" {
            return ExportFileFormat.CSV(separator: ",")
        }
        else if str == "1" {
            return ExportFileFormat.Excel
        }
        else if str == "2" {
            return ExportFileFormat.CSV(separator: "\t")
        }
        
        return nil
    }
    
    class func prepareWebServerFilesForExperiment(experiment: Experiment) -> String {
        let path = NSTemporaryDirectory().stringByAppendingString("/\(NSUUID().UUIDString)")
        
        try! NSFileManager.defaultManager().createDirectoryAtPath(path, withIntermediateDirectories: false, attributes: nil)
        
        let css = prepareStyleFile(backgroundColor: kBackgroundColor, mainColor: UIColor.blackColor(), highlightColor: kHighlightColor)
        
        let html = prepareIndexFile(experiment)
        
        try! css.writeToFile(path.stringByAppendingString("/style.css"), atomically: true, encoding: NSUTF8StringEncoding)
        try! html.writeToFile(path.stringByAppendingString("/index.html"), atomically: true, encoding: NSUTF8StringEncoding)
        
        return path
    }
}
