//
//  AppDelegate.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

import UIKit

let EndBackgroundMotionSessionNotification = "EndBackgroundMotionSessionNotification"

var iOS9: Bool {
    return ptHelperFunctionIsIOS9()
}

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    var main: MainNavigationViewController!
    var mainNavViewController: ScalableViewController!
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        window = UIWindow(frame: UIScreen.mainScreen().bounds)
        window!.tintColor = UIColor.blackColor()
        
        main = MainNavigationViewController(navigationBarClass: MainNavigationBar.self, toolbarClass: nil)
        main.pushViewController(ExperimentsCollectionViewController(), animated: false)
        
        mainNavViewController = ScalableViewController(hostedVC: main)
        window!.rootViewController = mainNavViewController
        
        window!.makeKeyAndVisible()
        
        return true
    }
    
    
    func application(application: UIApplication, openURL url: NSURL, options: [String: AnyObject]) -> Bool {
        cleanInbox(url.lastPathComponent)
        return launchExperimentByURL(url)
    }
    

    func applicationWillResignActive(application: UIApplication) {
        var id = UIBackgroundTaskInvalid
        
        id = UIApplication.sharedApplication().beginBackgroundTaskWithName("task") {
            if id != UIBackgroundTaskInvalid {
                UIApplication.sharedApplication().endBackgroundTask(id)
                
                if UIApplication.sharedApplication().applicationState == .Background {
                    NSNotificationCenter.defaultCenter().postNotificationName(EndBackgroundMotionSessionNotification, object: nil)
                }
            }
        }
        
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


    func launchExperimentByURL(url: NSURL) -> Bool {
        print("Opening \(url)")
        
        let experiment: Experiment
        do {
            experiment = try ExperimentSerialization.readExperimentFromURL(url)
        } catch let error {
            let controller = UIAlertController(title: "Experiment error", message: "Could not load experiment: \(error)", preferredStyle: .Alert)
            controller.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .Cancel, handler:nil))
            main.presentViewController(controller, animated: true, completion: nil)
            return false
        }
        
        if let sensors = experiment.sensorInputs {
            for sensor in sensors {
                do {
                    try sensor.verifySensorAvailibility()
                }
                catch SensorError.SensorUnavailable(let type) {
                    let controller = UIAlertController(title: NSLocalizedString("sensorNotAvailableWarningTitle", comment: ""), message: NSLocalizedString("sensorNotAvailableWarningText1", comment: "") + " \(type) " + NSLocalizedString("sensorNotAvailableWarningText2", comment: ""), preferredStyle: .Alert)
                    
                    controller.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .Cancel, handler:nil))
                    main.presentViewController(controller, animated: true, completion: nil)
                    return false
                }
                catch {}
            }
        }
        
        while (main.viewControllers.count > 1) {
            main.popViewControllerAnimated(true)
        }
        
        let controller = ExperimentPageViewController(experiment: experiment)
        
        var denied = false
        var showing = false
        
        experiment.willGetActive {
            denied = true
            if showing {
                self.main.popViewControllerAnimated(true)
            }
        }
        
        if !denied {
            main.pushViewController(controller, animated: true)
            showing = true
        } else {
            return false
        }
        
        return true
    }
    
    func cleanInbox(skipFile: String?) {
        let fileMgr = NSFileManager.defaultManager()
        let inbox = fileMgr.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0].URLByAppendingPathComponent("Inbox")
        do {
            for file in try fileMgr.contentsOfDirectoryAtURL(inbox, includingPropertiesForKeys: nil, options: .SkipsHiddenFiles) {
                if (skipFile != file.lastPathComponent) {
                    try fileMgr.removeItemAtURL(file)
                }
            }
        } catch {
            
        }
    }
    
    
}

