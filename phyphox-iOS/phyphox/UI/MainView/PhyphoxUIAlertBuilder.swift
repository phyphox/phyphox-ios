//
//  PhyphoxUIBuilder.swift
//  phyphox
//
//  Created by Gaurav Tripathee on 21.02.23.
//  Copyright © 2023 RWTH Aachen. All rights reserved.
//

import Foundation

extension UIAlertController {
    
    class PhyphoxUIAlertBuilder: NSObject{
        
        
        typealias PhyphoxUIAlertBuilderCompletion = (Int) -> Void
        
        private var alertTitle = ""
        private var alertMessage = ""
        private var alertRootVC: UIViewController?
        private var alertStyle: UIAlertController.Style = .actionSheet
        private var actions:[UIAlertAction] = [UIAlertAction]()
        private var isConfigHandlerProvided: Bool = false
        private var configHandler: ((UITextField) -> Void)?
        private var popoverSourceView: UIView?
        private var popoverSourceRect: CGRect?
        private var popoverPermittedArrowDir: UIPopoverArrowDirection? = []
        
        private var heightProvided: Bool = false
        private var height: CGFloat = 500
        
        private var alertValueProvided: Bool = false
        private var alertValue: Any?
        private var alertValueKey: String = ""
        
        private var textFieldValue: UITextField?

        
        override init() {}
        
        func title(title: String) -> PhyphoxUIAlertBuilder {
            alertTitle = title
            return self
        }
        
        func message(message: String?) -> PhyphoxUIAlertBuilder {
            alertMessage = message ?? ""
            return self
        }
        
        
        func preferredStyle(style: UIAlertController.Style) -> PhyphoxUIAlertBuilder {
            alertStyle = style
            return self
        }
        
        func sourceView(popoverSourceView: UIView?) -> PhyphoxUIAlertBuilder {
            self.popoverSourceView = popoverSourceView
            return self
        }
        
        func sourceRect(popoverSourceRect: CGRect?) -> PhyphoxUIAlertBuilder {
            self.popoverSourceRect = popoverSourceRect
            return self
        }
        
        func permittedArrowDir(popoverPermittedArrowDir: UIPopoverArrowDirection?) -> PhyphoxUIAlertBuilder {
            self.popoverPermittedArrowDir = popoverPermittedArrowDir
            return self
        }
        
        
        func parentViewController(rootVC: UIViewController) -> PhyphoxUIAlertBuilder {
            alertRootVC = rootVC
            return self
        }
        
        func setAlertDialogHeight(height: CGFloat) -> PhyphoxUIAlertBuilder{
            heightProvided = true
            self.height = height
            return self
        }
        
        func setAlertValue(value: Any?, key: String) -> PhyphoxUIAlertBuilder {
            alertValueProvided = true
            self.alertValue = value
            self.alertValueKey = key
            return self
        }
        
        func getTextFieldValue() -> UITextField {
            return self.textFieldValue!
        }
        
        
        func addOkAction(handler:((UIAlertAction) -> Swift.Void)? = nil) -> PhyphoxUIAlertBuilder {
            return addDefaultActionWithTitle(localize("ok"), handler: handler)
        }
        
        func addDeleteAction(handler:((UIAlertAction) -> Swift.Void)? = nil) -> PhyphoxUIAlertBuilder {
            return addDestructiveActionWithTitle(localize("delete"), handler: handler)
        }
        
        func addCancelAction(handler:((UIAlertAction) -> Swift.Void)? = nil) -> PhyphoxUIAlertBuilder {
            return addCancelActionWithTitle(localize("cancel"), handler: handler)
        }
        
        func addCloseAction(handler:((UIAlertAction) -> Swift.Void)? = nil) -> PhyphoxUIAlertBuilder {
            return addCancelActionWithTitle(localize("close"), handler: handler)
        }
        
        func addDestructiveActionWithTitle(_ title:String, handler:((UIAlertAction) -> Swift.Void)? = nil) -> PhyphoxUIAlertBuilder {
            return addActionWithTitle(title, style: .destructive, handler: handler)
        }
        
        func addCancelActionWithTitle(_ title:String, handler:((UIAlertAction) -> Swift.Void)? = nil) -> PhyphoxUIAlertBuilder {
            return addActionWithTitle(title, style: .cancel, handler: handler)
        }
        
        func addActionWithTitle(_ title:String, style:UIAlertAction.Style, handler:((UIAlertAction) -> Swift.Void)?) -> PhyphoxUIAlertBuilder {
            let action = UIAlertAction(title: NSLocalizedString(title, comment: ""), style: style, handler: handler)
            actions.append(action)
            return self
        }
        
        func addDefaultActionWithTitle(_ title:String, handler:((UIAlertAction) -> Swift.Void)? = nil) -> PhyphoxUIAlertBuilder {
            return addActionWithTitle(title, style: .default, handler: handler)
        }
        
        func addDefinedAction(action: UIAlertAction) -> PhyphoxUIAlertBuilder{
            actions.append(action)
            return self
        }
        
        func addAlertWithCondition(isValueNull: Bool, action: UIAlertAction) -> PhyphoxUIAlertBuilder {
            if(!isValueNull){
                actions.append(action)
            }
            return self
        }
        
        func addTextField(configHandler: ((UITextField) -> Void)?) -> PhyphoxUIAlertBuilder {
            isConfigHandlerProvided = true
            self.configHandler = configHandler
            return self
        }
        
        
        func show(in viewController:UIViewController, animated:Bool = true, completion:(() -> Swift.Void)? = nil) {
            viewController.present(build(), animated: animated, completion: completion)
        }
        
        
        private func build() -> UIAlertController {
            let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: alertStyle)
            if #available(iOS 13.0, *) {
                if(Utility.appMode ==  Utility.DARK_MODE){
                    alert.overrideUserInterfaceStyle = .dark
                } else if(Utility.appMode == Utility.LIGHT_MODE) {
                    alert.overrideUserInterfaceStyle = .light
                }
            } else {
                // Fallback on earlier versions
            }
            
            
            
            if let popover = alert.popoverPresentationController {
                popover.sourceView = popoverSourceView
                popover.sourceRect = popoverSourceRect ?? CGRect()
                popover.permittedArrowDirections = popoverPermittedArrowDir ?? []
            }
            
            if(heightProvided){
                let height : NSLayoutConstraint = NSLayoutConstraint(item: alert.view!, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: self.height )
                
                alert.view.addConstraint(height)
            }
            
            if(alertValueProvided){
                alert.setValue(self.alertValue, forKey: self.alertValueKey)
            }
            
            actions.forEach { (action) in
                alert.addAction(action)
            }
            
            if(isConfigHandlerProvided) {
                alert.addTextField(configurationHandler: self.configHandler)
                textFieldValue = (alert.textFields?[0])! as UITextField
            }
               
           
            return alert
        }
        
    }
    
    
}

