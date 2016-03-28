echo Refreshing GitHub Sources

#No need for fancy CocoaPods or Carthage...

echo Not checking out XMLDictionary, because the local version contains changes.

sleep 3s

#rm -rf XMLDictionary
#git clone https://github.com/nicklockwood/XMLDictionary
#rm -rf XMLDictionary/.git

rm -rf TheAmazingAudioEngine
git clone https://github.com/TheAmazingAudioEngine/TheAmazingAudioEngine
rm -rf TheAmazingAudioEngine/.git

rm -rf pop
git clone https://github.com/facebook/pop
rm -rf pop/.git

rm -rf VBFPopFlatButton
git clone https://github.com/victorBaro/VBFPopFlatButton
rm -rf VBFPopFlatButton/.git

#Fix pop import
sed -i -e 's/\"POP.h\"/<POP\/POP.h>/g' VBFPopFlatButton/VBFPopFlatButton/VBFPopFlatButtonClasses/VBFDoubleSegment.m

rm VBFPopFlatButton/VBFPopFlatButton/VBFPopFlatButtonClasses/VBFDoubleSegment.m-e

echo Removing CocoaPods stuff

find . -iname "Pod*" -exec rm -rf "{}" \;

echo Done!