echo Refreshing GitHub Sources

#No need for fancy CocoaPods or Carthage...

echo Not checking out XMLDictionary, because the local version contains changes.

sleep 3s

#rm -rf XMLDictionary
#git clone https://github.com/nicklockwood/XMLDictionary
#rm -rf XMLDictionary/.git

rm -rf EZAudio
git clone https://github.com/syedhali/EZAudio
rm -rf EZAudio/.git

rm -rf OrderedDictionary
git clone -b development https://github.com/JonasGessner/OrderedDictionary
rm -rf OrderedDictionary/.git

rm -rf pop
git clone https://github.com/facebook/pop
rm -rf pop/.git

rm -rf VBFPopFlatButton
git clone https://github.com/victorBaro/VBFPopFlatButton
rm -rf VBFPopFlatButton/.git

rm -rf Surge
git clone https://github.com/mattt/Surge
rm -rf Surge/.git

#Fix pop import
sed -i -e 's/\"POP.h\"/<POP\/POP.h>/g' VBFPopFlatButton/VBFPopFlatButton/VBFPopFlatButtonClasses/VBFDoubleSegment.m

rm VBFPopFlatButton/VBFPopFlatButton/VBFPopFlatButtonClasses/VBFDoubleSegment.m-e

rm -rf ClusterPrePermissions
git clone https://github.com/clusterinc/ClusterPrePermissions
rm -rf ClusterPrePermissions/.git

#Fix Bullshit ClusterPrePermissions file
sed -i -e 's/typedef NS_ENUM/@import Foundation;@import UIKit;typedef NS_ENUM/g' ClusterPrePermissions/ClusterPrePermissions/ClusterPrePermissions/ClusterPrePermissions.m

rm ClusterPrePermissions/ClusterPrePermissions/ClusterPrePermissions/ClusterPrePermissions.m-e


echo Removing CocoaPods stuff

find . -iname "Pod*" -exec rm -rf "{}" \;

echo Done!