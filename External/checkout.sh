echo Refreshing GitHub Sources

#Manual 💪 CocoaPods 👎

echo Not checking out XMLDictionary, because the local version contains changes.

sleep 3s

#rm -rf XMLDictionary
#git clone https://github.com/nicklockwood/XMLDictionary
#rm -rf XMLDictionary/.git

rm -rf TheAmazingAudioEngine
git clone https://github.com/TheAmazingAudioEngine/TheAmazingAudioEngine
rm -rf TheAmazingAudioEngine/.git

rm -rf JXLS
git clone --recursive https://github.com/JanX2/JXLS
rm -rf JXLS/.git
rm -rf JXLS/External/xlslib/.git

rm -rf JGProgressHUD
git clone https://github.com/JonasGessner/JGProgressHUD
rm -rf JGProgressHUD/.git

rm -rf ZipZap
git clone https://github.com/pixelglow/ZipZap
rm -rf ZipZap/.git

rm -rf BEMCheckBox
git clone https://github.com/Boris-Em/BEMCheckBox
rm -rf BEMCheckBox/.git

rm -rf pop
git clone https://github.com/facebook/pop
rm -rf pop/.git

rm -rf VBFPopFlatButton
git clone https://github.com/victorBaro/VBFPopFlatButton
rm -rf VBFPopFlatButton/.git

rm -rf GCDWebServer
git clone https://github.com/swisspol/GCDWebServer
rm -rf GCDWebServer/.git


#Fix pop import
sed -i -e 's/\"POP.h\"/<POP\/POP.h>/g' VBFPopFlatButton/VBFPopFlatButton/VBFPopFlatButtonClasses/VBFDoubleSegment.m

rm VBFPopFlatButton/VBFPopFlatButton/VBFPopFlatButtonClasses/VBFDoubleSegment.m-e

echo Removing CocoaPods stuff

find . -iname "Pod*" -exec rm -rf "{}" \;

echo Done!
