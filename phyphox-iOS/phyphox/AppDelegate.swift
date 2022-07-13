//
//  AppDelegate.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import UIKit

let EndBackgroundMotionSessionNotification = "EndBackgroundMotionSessionNotification"
let ResignActiveNotification = "ResignActiveNotification"
let DidBecomeActiveNotification = "DidBecomeActiveNotification"

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    var main: MainNavigationViewController!
    var mainNavViewController: ScalableViewController!

    func initApp(url: URL?) -> Bool {
        KeyboardTracker.startTracking()
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window!.tintColor = UIColor.black
        
        let experimentsCollectionViewController = ExperimentsCollectionViewController(willBeFirstViewForUser: url == nil || ProcessInfo.processInfo.arguments.contains("screenshot"))
        
        main = MainNavigationViewController(navigationBarClass: MainNavigationBar.self, toolbarClass: nil)
        main.pushViewController(experimentsCollectionViewController, animated: false)
        
        mainNavViewController = ScalableViewController(hostedVC: main)
        window!.rootViewController = mainNavViewController
        window!.makeKeyAndVisible()
        
        if let url = url {
            return experimentsCollectionViewController.launchExperimentByURL(url, chosenPeripheral: nil)
        }

        //The following is used by the UI test to automatically generate screenshots for the App Store using fastlane. The UI test sets the argument "screenshot" and the app will launch a pre-recorded experiment to allow for screenshots with data.
        if ProcessInfo.processInfo.arguments.contains("screenshot") {
            return experimentsCollectionViewController.launchExperimentByURL(URL(string: "https://rwth-aachen.sciebo.de/s/mezViL5TH4gyEe5/download")!, chosenPeripheral: nil)
        }
        
        return true
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return initApp(url: nil)
    }
    
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        
        cleanInbox(url.lastPathComponent)
        return initApp(url: url)
    }
    
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        cleanInbox(url.lastPathComponent)
        return initApp(url: url)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: ResignActiveNotification), object: nil)
        
        
        //Original implementation below by Jonas. Should be re-enabled at some point as it "usually" nicely leaves the measurement running in the background.
        //Unfortunately, this does not work for every input (audio!) and sometimes the experiment is interrupted nevertheless, leading to a gap / jump in the data, sometimes even to a crash.
        //So, for now we will choose the "uncool" solution and stop the experiment whenever we lose focus as this behaviour is reliable and can be anticipated by the user.
        
        /*
        var id = UIBackgroundTaskInvalid
        
        id = UIApplication.sharedApplication().beginBackgroundTaskWithName("task") {
            if id != UIBackgroundTaskInvalid {
                UIApplication.sharedApplication().endBackgroundTask(id)
                
                if UIApplication.sharedApplication().applicationState == .Background {
                    NSNotificationCenter.defaultCenter().postNotificationName(EndBackgroundMotionSessionNotification, object: nil)
                }
            }
        }*/
        
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: DidBecomeActiveNotification), object: nil)
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    var lockPortrait: Bool = false
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if lockPortrait {
            return UIInterfaceOrientationMask.portrait
        } else {
            return UIInterfaceOrientationMask.all
        }
    }


    func cleanInbox(_ skipFile: String?) {
        let fileMgr = FileManager.default
        let inbox = fileMgr.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Inbox")
        do {
            for file in try fileMgr.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                if (skipFile != file.lastPathComponent) {
                    try fileMgr.removeItem(at: file)
                }
            }
        } catch {
            
        }
    }
}
