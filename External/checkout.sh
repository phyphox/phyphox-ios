echo Refreshing GitHub Sources

#No need for fancy CocoaPods or Carthage...

echo Not checking out XMLDictionary, because the local version contains changes.

sleep 5s

#rm -rf XMLDictionary
#git clone https://github.com/nicklockwood/XMLDictionary
#rm -rf XMLDictionary/.git

rm -rf OrderedDictionary
git clone -b development https://github.com/JonasGessner/OrderedDictionary
rm -rf OrderedDictionary/.git

rm -rf pop
git clone https://github.com/facebook/pop
rm -rf pop/.git

rm -rf VBFPopFlatButton
git clone https://github.com/victorBaro/VBFPopFlatButton
rm -rf VBFPopFlatButton/.git

rm -rf ClusterPrePermissions
git clone https://github.com/clusterinc/ClusterPrePermissions
rm -rf ClusterPrePermissions/.git

echo Done!