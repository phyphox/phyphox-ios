# phyphox-ios

Phyphox is an app that uses the sensors in a smartphone for physics experiments. You can find additional details and examples on http://phyphox.org.

Copyright 2016 Dr. Sebastian Staacks, 2nd Institute of Physics, RWTH Aachen University.

This project has been created at the RWTH Aachen University and is released under the GNU General Public Licence (see licence file) since version 1.1.0.

**The names "phyphox" and "RWTH Aachen University" as well as the RWTH Aachen logo are registered trademarks.**

## Coding style

The app and all of its parts are developed by students and researchers who do not necessarily have a software development background. Therefore, you will find many passages in our code that is not best practice. Any help in improving our code is welcome.

## Structure

This repository contains the source for the iOS version of the app. The whole project is spread across several repositories:

* **phyphox-android**
  Android source, includes phyphox-experiments and phyphox-webinterface as subrepositories
* **phyphox-experiments**
  Phyphox experiment definitions, which are provided with the app
* **phyphox-ios**
  iOS source, includes phyphox-experiments and phyphox-webinterface as subrepositories
* **phyphox-translation**
  This contains the translations from experiment definitions and app store entries. It is synchronized manually to the experiments repository through a python script. Its main purpose is to conveniently provide translatable resources to our translation system.
* **phyphox-webeditor**
  The web-based editor to create and modify phyphox experiment-files in a GUI
* **phyphox-webinterface**
  This is the webinterface served by the webserver in the app when the "remote access" feature is activated

The overarching documentation (for example of the phyphox file format or the REST API) can be found in our [Wiki on phyphox.org](https://phyphox.org/wiki).

## Building

You need a Mac with a current Xcode. The experiment definitions and the web interface are git submodules, so clone with them:

```
git clone --recurse-submodules https://github.com/phyphox/phyphox-ios.git
```

Open `phyphox-iOS/phyphox.xcodeproj` in Xcode and build the scheme `phyphox` (the only shared scheme; it also runs the unit and UI tests). Third-party libraries are Swift packages declared in the project, so the first build needs network access while Xcode resolves them. Nothing has to be built separately. From the command line:

```
xcodebuild -project phyphox-iOS/phyphox.xcodeproj -scheme phyphox -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Pick a simulator that exists on your machine for `name=`. The deployment target is iOS 12; leave it as it is. A build phase increments the build number in `Info.plist` on every build, so that file shows up as modified afterwards. Simply do not commit that change.

## Branches

We keep the code of the most recent published version in "master", while minor development is done in "development". Larger changes and long-term development occurs in additional branches, which at some point converge in a "dev-next" branch. In some repositories you will also find a "translation" branch, which usually is identical or very close to the current "development" or "dev-next" branch and linked to our translation system to control when our translators are able to work on new text passages.

## Contributing

We encourage any contribution to our project. However, due to the complexity of the project and the fact that it is used in schools around the world, there are some things to consider before any code makes it into the final version of phyphox that is distributed in the app stores:

* Be careful about changes of the UI. Many teachers rely on a simple and consistent workflow without too much distraction for their students. Also, they might have created some worksheets, which need updates when the interface changes. Therefore, try to add new features in a simple and lean way.
* Android and iOS versions should remain as similar as possible. We do accept slight variations of the UI of both versions if they follow the obvious design standards of each platform (for example using checkmarks on Android but buttons telling the action on iOS, or a FAB on Android and a Actionbar entry on iOS) and one version might get features that are impossible on the other platform (for example reading the light sensor on Android, which cannot be done on iOS or getting the number of satellites for GPS on Android). But if you provide a new feature that can be implemented on the other platform as well, we will not include it in the final app until we (or you or somebody) has ported it to the other platform as well. Once again, this app is used in classes around the world and we want to provide a very similar experience on both platforms, so the teachers don't have to explain the usage of phyphox twice.
* Translation is not done via git directly. If you want to translate the app, contact us, so we can set up an account for you on our translation system. In any case, if you plan on contibuting more than a little bugfix or optimization, it is probably a good idea to contact us first, so we can plan together and consider your plans in our development as well.

## Used libraries

The list of third-party libraries in the iOS app and their licences can be found [here](phyphox-iOS/phyphox/Licenses/Licenses.ptf). Libraries used by common parts (i.e. the webinterface) or the Android version can be found in the respective readme files of each sub-project.