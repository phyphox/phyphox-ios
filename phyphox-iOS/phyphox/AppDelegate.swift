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
//  -phyphoxSyntheticSensors   like -phyphoxAssumeSensors, and a sensor the device lacks delivers a constant reading at its
//                             rate - the simulator's stand-in for the emulator's virtual sensors (web interface T1 run)
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

    ///Whether a sensor the device lacks should be fed a constant reading instead of failing the experiment
    static let syntheticSensors = arguments.contains("-phyphoxSyntheticSensors")

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

    //Called from SceneDelegate: iOS 27 refuses to launch an app built against its SDK without the scene lifecycle
    func initApp(windowScene: UIWindowScene, url: URL?) -> Bool {
        KeyboardTracker.startTracking()

        window = UIWindow(windowScene: windowScene)
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

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    func openURL(_ url: URL) {
        cleanInbox(url.lastPathComponent)
        _ = experimentsCollectionViewController.launchExperimentByURL(url, chosenPeripheral: nil)
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

//With the scene lifecycle, UIKit sends URLs and activation changes here instead of to the AppDelegate
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private var appDelegate: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let url = connectionOptions.urlContexts.first?.url
        _ = appDelegate.initApp(windowScene: windowScene, url: url)
        window = appDelegate.window
        //A URL that launched the app arrives here and not in scene(_:openURLContexts:)
        if let url = url {
            appDelegate.openURL(url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        appDelegate.openURL(url)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        
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
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        NotificationCenter.default.post(name: .experimentsReloadedNotification, object: nil)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        SettingBundleHelper.registerDefaults()
        SettingBundleHelper.setAppMode(window: window)
        NotificationCenter.default.post(name: .didBecomeActiveNotification, object: nil)
    }
}
