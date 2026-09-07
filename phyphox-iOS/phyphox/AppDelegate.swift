//
//  AppDelegate.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import UIKit


//Launch-argument seam for unattended automation; only settable via simctl/devicectl/Xcode, so ungated in release builds:
//  -phyphoxUrl <url>          opens the URL like an external open, without the open-in confirmation dialog
//  -phyphoxRemote             enables remote access for the session like the confirmed menu toggle (Android: debug.phyphox.remote)
//  -phyphoxRemotePort <n>     serves remote access on this port instead of the configured one
//  -phyphoxBleConnect <name>  scans for that device and loads the experiment it offers, left NOT started (Android: bleDevice)
//  -phyphoxAutoConfirm        confirms the informational notices on open (network privacy, photosensitivity), declines the save offer
//  -phyphoxAssumeSensors      treats every sensor iOS could have as present and suppresses the simulator's camera loading error
//                             (store screenshot system; Android: debug.phyphox.assumeSensors)
//  -phyphoxView <n>           the 0-based view (tab) index to open on; absent or out of range means the first
//                             (Android: debug.phyphox.view)
//
//Example:
//xcrun simctl launch <udid> de.rwth-aachen.physics.phyphox -phyphoxUrl "phyphox://asset=accelerometer.phyphox" -phyphoxRemote
enum AutomationLaunchOptions {
    private static let arguments = ProcessInfo.processInfo.arguments

    private static func value(after flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    static let url: URL? = value(after: "-phyphoxUrl").flatMap { URL(string: $0) }

    static let remoteEnabled = arguments.contains("-phyphoxRemote")

    static let remotePort: UInt? = value(after: "-phyphoxRemotePort").flatMap { UInt($0) }

    static let autoConfirm = arguments.contains("-phyphoxAutoConfirm")

    ///The Bluetooth device to take an experiment from, for the compatibility suite
    static let bluetoothDeviceName: String? = value(after: "-phyphoxBleConnect")

    ///Whether every sensor the device could have should be treated as available (store screenshot system)
    static let assumeSensors = arguments.contains("-phyphoxAssumeSensors")

    ///The view index to open on, or 0 if absent or not a positive index; the caller checks it against the number of views
    static let startView: Int = {
        guard let view = value(after: "-phyphoxView").flatMap({ Int($0) }), view > 0 else { return 0 }
        return view
    }()
}

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    var main: MainNavigationViewController!
    var mainNavViewController: ScalableViewController!
    var experimentsCollectionViewController: ExperimentsCollectionViewController!

    func initApp(url: URL?) -> Bool {
        KeyboardTracker.startTracking()

        window = UIWindow(frame: UIScreen.main.bounds)
        window!.tintColor = UIColor(named: "textColor")

        UILabel.appearance().adjustsFontForContentSizeCategory = true

        //The automation launch arguments are documented at AutomationLaunchOptions above
        let automationURL = AutomationLaunchOptions.url

        experimentsCollectionViewController = ExperimentsCollectionViewController(willBeFirstViewForUser: url == nil && automationURL == nil)

        main = MainNavigationViewController(navigationBarClass: MainNavigationBar.self, toolbarClass: nil)
        main.pushViewController(experimentsCollectionViewController, animated: false)

        mainNavViewController = ScalableViewController(hostedVC: main)
        window!.rootViewController = mainNavViewController
        window!.makeKeyAndVisible()

        if let automationURL = automationURL {
            return experimentsCollectionViewController.launchExperimentByURL(automationURL, chosenPeripheral: nil)
        }

        return true
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return initApp(url: launchOptions?[.url] as? URL)
    }
    
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        
        cleanInbox(url.lastPathComponent)
        return experimentsCollectionViewController.launchExperimentByURL(url, chosenPeripheral: nil)
    }
    
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        cleanInbox(url.lastPathComponent)
        return experimentsCollectionViewController.launchExperimentByURL(url, chosenPeripheral: nil)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        
        NotificationCenter.default.post(name: .resignActiveNotification, object: nil)
        
        
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
        NotificationCenter.default.post(name: .experimentsReloadedNotification, object: nil)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        SettingBundleHelper.registerDefaults()
        SettingBundleHelper.setAppMode(window: window)
        NotificationCenter.default.post(name: .didBecomeActiveNotification, object: nil)
        
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
