//
//  AppDelegate.swift
//  phyphox
//
//  Created by Jonas Gessner on 04.12.15.
//  Copyright © 2015 Jonas Gessner. All rights reserved.
//

import UIKit


//Launch-argument seam for unattended automation (the lab driver of the cross-platform test
//strategy). Launch arguments can only be set through simctl, devicectl or Xcode - never by
//another app or by a user of an installed build - so these switches ship ungated in release
//builds:
//
//  -phyphoxUrl <url>          opens the URL exactly as if it had been opened from outside the
//                             app, but without the system's open-in confirmation dialog, which
//                             cannot be suppressed and would block every scripted
//                             phyphox://asset= launch. The URL goes through the same handler as
//                             a real open, so the semantics cannot drift. Android needs no
//                             counterpart - "adb shell am start" opens URLs without a dialog.
//  -phyphoxRemote             enables remote access for the launched experiment session, exactly
//                             as the menu toggle would but without its confirmation dialog.
//                             Android mirrors this with the shell-only system property
//                             "debug.phyphox.remote" - one host-controlled switch, two platform
//                             idioms.
//  -phyphoxRemotePort <n>     serves remote access on this port instead of the configured one,
//                             so a host script does not have to discover the port the fallback
//                             ladder picked.
//  -phyphoxBleConnect <name>  opens the Bluetooth scan and loads the experiment offered by the
//                             device advertising under that name, which is what the Bluetooth
//                             compatibility suite needs: picking a device out of a scan has no
//                             remote-API equivalent, and the boards it drives sit next to each
//                             other, so the name decides. It replaces the tapping and nothing
//                             else - the scan, the name matching, the transfer and the loading
//                             are the app's own, the experiment is left NOT started, and the
//                             host takes over through the remote API from there. Android has
//                             the same seam as an instrumentation argument (bleDevice).
//  -phyphoxAutoConfirm        confirms the notices an experiment shows when it opens - the
//                             network privacy warning, the photosensitivity warning - and
//                             declines the offer to save a downloaded experiment locally. They
//                             are informational (their only action is OK), but unattended they
//                             stall the run: the network privacy notice in particular gates the
//                             connection setup, so the network fixture experiments cannot run
//                             without this. It skips no user choice and no system permission
//                             dialog, which the app cannot dismiss anyway.
//  -phyphoxAssumeSensors      treats every sensor the device could have as present while an
//                             experiment is loaded, so no entry of the collection is greyed out
//                             as unavailable. This one is for the store screenshot system, not
//                             for the lab driver: the simulators it captures on report almost
//                             every sensor as missing, which would turn the collection
//                             screenshot into a wall of greyed-out entries. It only affects
//                             whether an experiment loads - one that is started anyway still
//                             finds no sensor and records nothing, which is fine for a
//                             generated copy that carries its data as init values. Sensor types
//                             iOS supports on no device at all (ambient light, temperature,
//                             humidity) keep failing, because there the greyed-out entry is the
//                             truth rather than a simulator artefact. Android mirrors this with
//                             the shell-only system property "debug.phyphox.assumeSensors".
//  -phyphoxView <n>           the view (tab) index the experiment opens on, counting from 0 in
//                             the order the views appear in the file. Absent, not a number or
//                             out of range means the first view, i.e. the normal behaviour.
//                             Also for the screenshot system: one scene shows the second view,
//                             and tapping a tab at coordinates that differ per form factor is
//                             what made the old screenshot tests unmaintainable. Android:
//                             "debug.phyphox.view".
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

    ///Whether every sensor the device could have should be treated as available, for the store
    ///screenshot system
    static let assumeSensors = arguments.contains("-phyphoxAssumeSensors")

    ///The view (tab) index an experiment should open on, or 0 if the argument is absent or does
    ///not name a positive index. The caller still has to check it against the number of views
    ///the experiment actually has.
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
