//
//  WebServerUtilities.swift
//  phyphox
//
//  Created by Jonas Gessner on 15.04.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//

import Foundation

final class WebServerUtilities {
    class func genPlaceHolderImage() -> UIImage {
        let s = CGSize(width: 30, height: 30)
        
        UIGraphicsBeginImageContextWithOptions(s, true, 0.0)
        
        UIColor.init(red: 0.0, green: 1.0, blue: 0, alpha: 1.0).setFill()
        
        UIBezierPath(rect: CGRect(origin: CGPoint.zero, size: s)).fill()
        
        let img = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return img!
    }
    
    class func genPlaceHolderBase64Image() -> String {
        return genPlaceHolderImage().pngData()!.base64EncodedString(options: [])
    }
    
    private class func prepareStyleFile(backgroundColor: UIColor, lightBackgroundColor: UIColor, lightBackgroundHoverColor: UIColor, mainColor: UIColor, highlightColor: UIColor) -> String {
        let raw = try! NSMutableString(contentsOfFile: Bundle.main.path(forResource: "phyphox-webinterface/style", ofType: "css")!, encoding: String.Encoding.utf8.rawValue)
        
        //These icons have been generated with the Android version of phyphox. Maybe, we should switch to a more flexible solution...?
        raw.replaceOccurrences(of: "###drawablePlay###", with: "iVBORw0KGgoAAAANSUhEUgAAAD8AAAA/CAYAAABXXxDfAAAABHNCSVQICAgIfAhkiAAAAUtJREFUaIHt12tRw1AUReETBgFIQAISKgEHBCXgAJxQFBQH4KA4IA4WP+AyQ/pIbnKfyf4EZM6ahm5qJiIiIiIiIoeAJ+Aq9x1Z8GMPbHLfkhz/vazqLeDQF3CX+64kjsQ7O+A6931RnYl3b8FD7hujGYh33oGb3LcGNzLeWdYsesbDkmZxQrxT/yzOiIfaZ3FmvLOjxlkMFA81zmLAeKeeWYwQ75Q/ixHjIeAsNiEe0gcQ47k9WzO7b5qmm/qAi4DHpHZrZntKm8XIr/0xj7mb/ySM7oB26p2XAZtTezWzds7ffBSRP+1PSv4RFDH8mRXu/Acr/A+vo6Rv8jEChb+xwl91s+YruxnhW0r/QhsyIbrs+fLhGV7+fPkYGV3PfPkYiK5vvnycCa9zvnyc+LTb3Hcl0Quvf758/EYvZ758sLT5EhERERERKdU3bpp4a7S0RxEAAAAASUVORK5CYII=", options: [], range: NSMakeRange(0, raw.length))
        raw.replaceOccurrences(of: "###drawableTimedPlay###", with: "iVBORw0KGgoAAAANSUhEUgAAAD8AAAA/CAYAAABXXxDfAAAABHNCSVQICAgIfAhkiAAAA7dJREFUaIHtW9tx2zAQXGTyH3YQdmCXwA7sVBCmAqsEd+B0ILkCqQMxFUiuQHIFoirYfIDKcOQ7EsSDlCfcTwq828XjCOBOwIwZM2b8JzBjOCGZAbgDcA8gA1AIzSoANYA9gDdjTD0GtyQgmZN8IrmjH7bN+/nUWpxB8qEhHhNbkg9Ta1NBsiB5iCz6GgeSxdRa/4FkRnKdWPQ11rRxJAhBAa8ZhTVsEHPBO4AjbFBrB7QMNhjmAL472qoB/DDGVI7t44E2GLlgQ7KkY+CiDZRl854LnhJL/UBw2UOoJvnsKrjDT97YqXv8LSNJ6yXUJ3zFCOvxymfG/pmQtgNILnpG+zGx/8eeWbBI5bjocLrnSJsR2qWw7+BSxHaYkTx1CI86zR35aB1wisqH+nd8dOEtTl0dsI7lRJvuNSfed9MuAS0GFDEcHBTjg4JbqhlCGwQlHFIZXnnY2pAsgwh12447+pRPZ7XPKJKsmveXsWcB7fqXpv/W12Cu9Oazp72qZWNH8t6LmG7/t8I39zGmbWiGG8MH8aT9JJU+thT72mAN3/gIZElyE0BOskdGXAaU13411EimEC0DiGniyUjLgPY0+AFa+y/Kc41IFUqww982pHMbVNJDKlF/iPh3Y8zRi5IbMgDLkGXQ8DsLP4mDqYmXnB99CHmghJ0FvstgLzwTO1MTXzgaTYWQZSDxLKSGmngJYycRfJeBM8+vwzmNjhL2orWMbXjIyE+FVwBJbmiGjPzY5/YzgIUxZjXwPWee2shXwrOoe/EevAEoPIQDMs9KaqiJl4KGazIhFK+wwn2/LnfCMzEIauIlxznT3tycAfwyxpS+6emGnzTtxY4cIh5QvpcREDLN2yiU5+7im55/E35KcS8fOs3bkPj9GTyTmP48X0c4yLTtRz3Pp7zJ2cc4wl7Zj3eTIxC+wCsp0LKVKpcnJVWqEKOf5fZWS6oUoYaPiuFbv7c/xjCuZWxOvI2MjZZDLGI50ZICu1Qj6sApo17m5n3RqjnScmKjd0CPcK+kSp/Drvz8juPm57sKG4tUjrsqM04cpzJDW+NkqsqMFoFVh3MyUo3clU+XWr9VTJ9dZPo64ETyhXGqsV56Rns84S1iXUugjTXJn64d0Qj+SfeqTu+pHqMCcwPgm+Mrl5JyrQLzUpLugjOAx0kqMC+gW41cbGw40f5CBO2nUNsKx8KRt1R1fQ3az1FXRtYH1U2LvgZt4FoEdETVvJ+n4jjmf2zaAa0QmlVoBcRP/R+bGTNmzLg1/AWXMEdyptzdlQAAAABJRU5ErkJggg==", options: [], range: NSMakeRange(0, raw.length))
        raw.replaceOccurrences(of: "###drawablePause###", with: "iVBORw0KGgoAAAANSUhEUgAAAD8AAAA/CAYAAABXXxDfAAAABHNCSVQICAgIfAhkiAAAAHtJREFUaIHtz7ENg0AQRNE9iwJcCiW4JVdCa3R0TghtCXMBOs178c5KvwoAAGBybWTce1+rajt5/m6t7Xf8/GW5Ojw8q+r1x+1dP796jIxnJz6V+FTiU4lPJT6V+FTiU4lPJT6V+FTiU4lPJT6V+FTiU4lPJR4AAIBJfQA9nAsMamJmWQAAAABJRU5ErkJggg==", options: [], range: NSMakeRange(0, raw.length))
        raw.replaceOccurrences(of: "###drawableTimedPause###", with: "iVBORw0KGgoAAAANSUhEUgAAAD8AAAA/CAYAAABXXxDfAAAABHNCSVQICAgIfAhkiAAAA2hJREFUaIHtW91Z4zAQHF8D5w7OHUAHpw7gKoAOoAQ6gA5IBwkVxFRAqCChgpgK5h6s3OcvtyuvE1kWd55H/e2MLK0i7QaYMWPGjP8ERQojJEsAFwAuAZQAnNCsBtAA2AB4L4qiScFtFJCsSN6RfONpWPv+1dRazCB55YnHxJrk1dTaVJB0JLeRRR9jS9JNrfUPSJYklyOLPsaSrR85C2c5PP8VlmidmAUfAHZonVrXoZVonWEF4IdxrAbAr6IoamP7eGDrjCxYkbyl0XGxdZS3vp8FdyNL/Yvgcw+hhuSDVXDATuXHaXrsPUeS1kuoT/iCEfbjkc2S/Sth3Akged/zta9Htn/dswruxzLsAkY3TPRjhO1W2AS4uNgGS5L7gPCoy9zIR5uAfVQ+1M/x5MI7nEITsIxlRFvuDSf+3c12C2g+wMUwsFUGH9W5WcHWCUrYjjXwIg71OKB+DLpzBl0LAzY07nMqW0ZpWwtNH4x2SsrLfx3q9y0wYAX50eEpt4cGz2chVDkG/JIqHoC2pyUjOeBJKVd901DxL0VR7IYwSgXP60WoGibe7+mfQtXqJGbpIPGTdADQv/ylUl4PZZMYtVSoef0h4j9yXfIHeH6fQpX4MTXx0lG2O41ScmyEMvFo1sQ746A5QuLppIYhb3+MrM72AMw8h4j/5zCLN2KSe/sJMPPUxNdCmXb25waJZy011MRLTsMaTJgaF0KZ6AQ18dJxUYVuSDnA85OWvXhMDxEPKOdlRnBKuV28vx+/C1VZPF0FIPF71d4fQt5+IZRd5br0PS8phq/eREPitU63dkpJoUVrhov3N6RXoerO+oaXCp7PjVD1evJNlF/n9VYLqrhzB94pA2fh/AIfaBdjcC1is5/a+bGN2GgxRBfLiBYUeOO0sTotzS3eWyP1oMAkE9Aj3BxUGWIwFJ9/Y9r4fCix0Y1lOJSZsWeazAxtj5NjZWZ0CCwCxslIOXJHNi25fouYNkNk+iZgT/KRcbKxHnu+djrhHWKhLdDFkuSNdSK84BvaszpPXuoxMjBXAL4buxxSyrUMzENKugWfAK4nycA8gLYcudhYMaf7BdujUPspHAs75pR1fQy2x5GUZXEO6qxFH4Ot47o/YyJq378ai2PK/9h0HZoTmtXoOMTcUl9mzJgx40vjNzmaRsZjF9NnAAAAAElFTkSuQmCC", options: [], range: NSMakeRange(0, raw.length))
        raw.replaceOccurrences(of: "###drawableClearData###", with: "iVBORw0KGgoAAAANSUhEUgAAAD8AAAA/CAYAAABXXxDfAAAABHNCSVQICAgIfAhkiAAAARBJREFUaIHt2sFtwlAQhOFZxD3pAEpIB6GEdBBKcTpIB1Y6oATTASW4hKSCyckHEJLlfc84zsx39lv2B9lcDJiZmZklkWyZ0y69e5GC8Id8AZE5RPIIYDdy2QuAt8z8GycAl7GLIuJj6uBsfAfgNXN2LhExuWUzxyJr4XhV2+S50QeQ2d+V+qsbkNwDeK+zSspXRPTZw9l7frAH0BTOKHEG0GcPSz/tHa/K8aocr8rxqhyvyvGqHK/K8aocr8rxqhyvyvGqHK/K8aocr6ro5QQAIPkN4KnCLlP9RMRzyYAav/xnhRlr+txrJLvCd2yn6pZuvkKyIdnPHN2TbGrtXHzP30PyUHtmRHS1Z5qZmf1zv5Fqd/pbkU7nAAAAAElFTkSuQmCC", options: [], range: NSMakeRange(0, raw.length))
        raw.replaceOccurrences(of: "###drawableMore###", with: "iVBORw0KGgoAAAANSUhEUgAAAD8AAAA/CAYAAABXXxDfAAAABHNCSVQICAgIfAhkiAAAAYBJREFUaIHt2uFtgzAQBeDnTpARPEI2KCN0BDZqNgjdoCOkEyQbhA3CBq8/4kgghdoS+K5B7/uHZIl3KOA7AiAiIiIi2xI8TkoyAngHEAH0AH5CCL1HFlMkD3zu0ztbVSS7mcIfjt4ZqyDZZAp/aKwyvVmdCEBbuO6jZogxy+Jj4bp9zRBjlsUPK69bzLL408rrXgfJHckh87AbSO68s1ZBcv/HBRhImt3vLkjGtN/3qeg+HUfvbCIim+U1z7eYzvOnEMKXRxYzqdE5z+zz5802OABA8pLp8M7eGasg2WYKf2itMlkONqVzelMzxJhl8aX3c6wZYsyy+H7ldYtpnrdS8LS/eGesJu3zcxfgYr3Pe3Z4DaYdXueRRUREauD97e2R5DVtcdd0HL2zVcX7e/vbzD5/41bf26cGZ67w8QUwa3Ss/6LOFbZD+V/Zi2me/2c2+bMvndjMJjvL4r9XXvdamP8aq/POWBXnv8M7WGfx/AKzwXSe7z2yiIiIiMiW/AKU60rEUati9QAAAABJRU5ErkJggg==", options: [], range: NSMakeRange(0, raw.length))
        raw.replaceOccurrences(of: "###drawableMaximize###", with: "iVBORw0KGgoAAAANSUhEUgAAAEIAAABCCAYAAADjVADoAAAABHNCSVQICAgIfAhkiAAAAYFJREFUeJzt2zFuwjAYhmFugISExIWQaJnYuEcnNjbG3i0LAzcpUd4OtYUVkcQxDq6d75HY4JfzLiDbLBYiIiIimQJ2wC71OpICtsCPeW1TrycJJ4I1vxjAvhVhfjFMhPuTCG6Mfep1TsojgnUvNgZw8IxQbgwToR4RobwYHhHO5tUX45D6OV4CHAciXJz3XnreV2cbw0RofCI4nykrRkgE57NlxODvKzIogjNjKMb//9EFrIAqNIIz57tjRgUsp3yGaEyMa2gEZ047RgWspljzZIA1cAuN4MyxMa7ZRbCADXCKMOcErGOsSURERERERERkFszGzFeEOSdgE2NNbzfBVt0tu12qiJu37W39fPYtgSVxtvO7zjby2MkGPvE87+yZ0XfA05DLCTnDJ+ChR34NcHzns7wsJEZxEawxMQYi1NlGsDxinD0i5HECPoTx96fKi2Dhf6POyv/KUJcRMcq5RNbFI0b5ESz6ryDPI4KFLqU/oL8pPAAfs48gIiIiWfsFQCcDdBccUmsAAAAASUVORK5CYII=", options: [], range: NSMakeRange(0, raw.length))
        raw.replaceOccurrences(of: "###drawableRestore###", with: "iVBORw0KGgoAAAANSUhEUgAAAEIAAABCCAYAAADjVADoAAAABHNCSVQICAgIfAhkiAAAAa5JREFUeJzt2jFrwkAYh/HXFtril1BcHKSLi4tTVz9uEXSwS/tRHAShCCJ06tPBO5qKMZeYmOby/4GT8TgfHfTymomIiIiISFMAU+AVeLpijS6wBKZl7u1mgAlw4GhVJAbwBLy7NQ7ApIq9VgYYA3v+yhXDRVidrLEHxlXuvTQuwo7zgmKkRPB2wHPZ+74re0Ez+3aPc17MbH4phntu7q7Nu/7/AoyAz5RPNPWbkfFNwK05quM9FZY3RkCEbeMieC7GNitGYIRh3e/nKsAwI8Yi+gheQIw0m2gieC7GJmeEQd37rgQwCIwRbwQvIEb8ETwXY30mwro1ETygdxJjDfTq3lctEjHaG8ED+q2PICIiIiJSHvcTu1/3PmqlP12mv+Fmlnkw044YAUd18Z9SBUTw4j23RMf5V9/giSNGQISFe8QbIyBC6E3g5t76I/BOeOL6+O6IU92gSHNiFI2QeH0tMaqYoXq8sO6bmc06nc5X2ovdczMz+0i55N7MHq7a4a1Qznhhl98ZS6+SibpKUc7AaTJGc2YsT3EcQV4WiZBYw48gN2vqVkRERESk3X4A/x/kf5jUj78AAAAASUVORK5CYII=", options: [], range: NSMakeRange(0, raw.length))
        raw.replaceOccurrences(of: "###drawableWarning###", with: "iVBORw0KGgoAAAANSUhEUgAAAEIAAABCCAYAAADjVADoAAAABHNCSVQICAgIfAhkiAAAAwhJREFUeJztmr1O3EAURr8JIQUdiWgRUlJRRKSh5OcNeAKSkgdIg0RHkYYGCSlKyROQV4COKhESVIkEKaGggoIEnRSzzs/i3bU993oWyUeiWZjr60/XY/uwUkdHR0fH+AM8B17k7iM7wB6wl7uPrADzwK/ez3zufrIBHPKXw9z9ZAFY4yFruftqFWASuCgJ4gKYzN1fawCbJSEUbOburxWAGeBmSBA3wEzuPt0B9oeEULCfu09XgIUKIRQs5O7XDeC4RhDHuft1AVivEULBeu6+TQGmgMsGQVwCU230+KSNg0jaktTkTjDTW/v4AWaBuwbTUHAHzOY+j2SAg4QQCg5yn0cSwJJBCAVLuc+nEcAEcGoYxCkw4dWv52a5IcnSMcz3aroQPIoC05K+S5o2Ln0t6WUI4dq4rttEbMs+BPVqbjvUtZ8IonI7keR1Pd9Leh1COLMs6hHEoaQqO/y+pPO+z+Ykva2w9iiEsFyvsxahXL8NYqVk/UqN9aZaz2yPICq2Xat6FdjFUOtZbpbvJbX5KDzbO6YJJkEQ1VqOl6MtjLSe1UTsSGrldbmPqd6xk0kOgqjUcgqUdQy0nsVEfDKokUpyD0lBEFXaYmoTBiySqPUaB0FUaCbXpxE7JGi9lIloqt+8SLpzNXrEJqqzb5JSHmhSHrEH8VPSqxDCj4Qa1cFGv3nRSOvVngiiMhv37zIshxCO6iyoFQRRlZ3I1jx5cKb4qn5fdUHdzdJav3lRW+tVngj89JsXtbRenYmw1m+roQ9Jq4b1a2m9SkEQ9ZubQXZkg4rf1qs6ER/l5yA9mVDsfSQjgyAqscf5X6bIEhW03tAgaF+/eTFS6z0dUcBTv73jocCdczpWofU+DPqDgbdPogI7Vx7z5MGtpLkQwlXZL4ddGrn0mxdDtUHpRBDV1xevjjLzJoTwtf/DQRMxDvrNi9JzexAE46PfvCjVev9dGkTVda7xMk8eXClunLfFB/0TMW76zYsHWu/PRPSm4bOkZy03lYs7SWv/TkVHR0dHR0dHRxN+A0HGYYklp0KrAAAAAElFTkSuQmCC", options: [], range: NSMakeRange(0, raw.length))
        
        
        
        return raw as String
    }
    
    private class func prepareIndexFile(_ experiment: Experiment) -> (String, [ViewDescriptor]) {
        let raw = try! NSMutableString(contentsOfFile: Bundle.main.path(forResource: "phyphox-webinterface/index", ofType: "html")!, encoding: String.Encoding.utf8.rawValue)
        
        raw.replaceOccurrences(of: "<!-- [[title]] -->", with: experiment.displayTitle, options: [], range: NSMakeRange(0, raw.length))
        
        raw.replaceOccurrences(of: "<!-- [[clearDataTranslation]] -->", with: localize("clear_data"), options: [], range: NSMakeRange(0, raw.length))
        raw.replaceOccurrences(of: "<!-- [[clearConfirmTranslation]] -->", with: localize("clear_data_question"), options: [], range: NSMakeRange(0, raw.length))
        raw.replaceOccurrences(of: "<!-- [[exportTranslation]] -->", with: localize("export"), options: [], range: NSMakeRange(0, raw.length))
        raw.replaceOccurrences(of: "<!-- [[switchToPhoneLayoutTranslation]] -->", with: localize("switchToPhoneLayout"), options: [], range: NSMakeRange(0, raw.length))
        raw.replaceOccurrences(of: "<!-- [[switchColumns1Translation]] -->", with: localize("switchColumns1"), options: [], range: NSMakeRange(0, raw.length))
        raw.replaceOccurrences(of: "<!-- [[switchColumns2Translation]] -->", with: localize("switchColumns2"), options: [], range: NSMakeRange(0, raw.length))
        raw.replaceOccurrences(of: "<!-- [[switchColumns3Translation]] -->", with: localize("switchColumns3"), options: [], range: NSMakeRange(0, raw.length))
        raw.replaceOccurrences(of: "<!-- [[toggleBrightModeTranslation]] -->", with: localize("toggleBrightMode"), options: [], range: NSMakeRange(0, raw.length))
        raw.replaceOccurrences(of: "<!-- [[fontSizeTranslation]] -->", with: localize("fontSize"), options: [], range: NSMakeRange(0, raw.length))
        
        var viewLayout = "var views = ["
        var viewOptions = ""
        
        var htmlId2ViewElement: [ViewDescriptor] = []
        
        if let views = experiment.viewDescriptors {
            var idx = 0
            
            for (i, v) in views.enumerated() {
                if i > 0 {
                    viewLayout += ",\n"
                    viewOptions += "\n"
                }
                
                viewLayout += "{\"name\": \"\(v.localizedLabel)\", \"elements\": ["
                
                viewOptions += "<li>\(v.localizedLabel)</li>"
                
                var ffirst = true
                
                for element in v.views {
                    htmlId2ViewElement.append(element)
                    
                    if !ffirst {
                        viewLayout += ", "
                    }
                    ffirst = false
                    
                    let escapedLabel = element.localizedLabel.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                    let escapedHTML = element.generateViewHTMLWithID(idx).replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                    
                    viewLayout += "{\"label\": \"\(escapedLabel)\", \"index\": \(idx), \"html\": \"\(escapedHTML)\",\"dataCompleteFunction\": \(element.generateDataCompleteHTMLWithID(idx))"

                    if let graph = element as? GraphViewDescriptor {
                        var dataInput = ""
                        let updateMode: String
                        if graph.style[0] == .map {
                            dataInput += "\"" +  graph.yInputBuffers[0].name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\","
                            dataInput += "\"" + (graph.xInputBuffers[0]?.name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") ?? "") + "\","
                            dataInput += "\"" + (graph.zInputBuffers[0]?.name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") ?? "") + "\""
                            updateMode = "partialXYZ"
                        } else {
                            for i in 0..<graph.yInputBuffers.count {
                                if (dataInput != "") {
                                    dataInput += ","
                                }
                                dataInput += "\"" +  graph.yInputBuffers[i].name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
                                dataInput += ","
                                let xName = i < graph.xInputBuffers.count ? graph.xInputBuffers[i]?.name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") ?? nil : nil
                                dataInput += xName != nil ? "\"" + xName! + "\"" : "null"
                            }
                            updateMode = "partial"
                        }
                        viewLayout += ", \"updateMode\": \"\(graph.partialUpdate ? updateMode : "full")\", \"dataInput\": [\(dataInput)], \"dataInputFunction\":\n\(graph.setDataHTMLWithID(idx))\n"
                    }
                    else if element is InfoViewDescriptor {
                        viewLayout += ", \"updateMode\": \"none\""
                    }
                    else if element is SeparatorViewDescriptor {
                        viewLayout += ", \"updateMode\": \"none\""
                    }
                    else if let value = element as? ValueViewDescriptor {
                        viewLayout += ", \"updateMode\": \"single\", \"dataInput\":[\"\(value.buffer.name)\"], \"dataInputFunction\":\n\(value.setDataHTMLWithID(idx))\n"
                    }
                    else if let edit = element as? EditViewDescriptor {
                        viewLayout += ", \"updateMode\": \"input\", \"dataInput\":[\"\(edit.buffer.name)\"], \"dataInputFunction\":\n\(edit.setDataHTMLWithID(idx))\n"
                    }
                    else if element is ButtonViewDescriptor {
                        viewLayout += ", \"updateMode\": \"none\""
                    }
                    
                    viewLayout += "}"
                    
                    idx += 1
                }
                
                viewLayout += "]}"
            }
        }
        
        viewLayout += "];\n"
        
        /*var exportStr = ""
        
        if let export = experiment.export {
            for (i, set) in export.sets.enumerate() {
                exportStr += "<div class=\"setSelector\"><input type=\"checkbox\" id=\"set\(i)\" name=\"set\(i)\" /><label for=\"set\(i)\"\">\(set.localizedName)</label></div>\n"
            }
        }*/
       
        
        var exportFormats = ""
        for i in 0..<exportTypes.count {
            exportFormats += "<option value=\"\(i)\">\(exportTypes[i].0)</option>"
        }
        
        
        raw.replaceOccurrences(of: "<!-- [[viewLayout]] -->", with: viewLayout, options: [], range: NSMakeRange(0, raw.length))
        raw.replaceOccurrences(of: "<!-- [[viewOptions]] -->", with: viewOptions, options: [], range: NSMakeRange(0, raw.length))
        raw.replaceOccurrences(of: "<!-- [[exportFormatOptions]] -->", with: exportFormats, options: [], range: NSMakeRange(0, raw.length))
        //raw.replaceOccurrencesOfString("<!-- [[exportSetSelectors]] -->", withString: exportStr, options: [], range: NSMakeRange(0, raw.length))
        
        return (raw as String, htmlId2ViewElement)
    }
    
    class func mapFormatString(_ str: String) -> ExportFileFormat? {
        return exportTypes[Int(str) ?? 0].1
    }
    
    class func prepareWebServerFilesForExperiment(_ experiment: Experiment) -> (String, [ViewDescriptor]) {
        let path = NSTemporaryDirectory() + "/" + UUID().uuidString
        
        try! FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
        
        let css = prepareStyleFile(backgroundColor: kBackgroundColor, lightBackgroundColor: kLightBackgroundColor, lightBackgroundHoverColor: kLightBackgroundHoverColor, mainColor: kTextColor, highlightColor: kHighlightColor)
        
        let (html, htmlId2ViewElement) = prepareIndexFile(experiment)
        
        try! css.write(toFile: path + "/style.css", atomically: true, encoding: String.Encoding.utf8)
        try! html.write(toFile: path + "/index.html", atomically: true, encoding: String.Encoding.utf8)
        
        return (path, htmlId2ViewElement)
    }
}
