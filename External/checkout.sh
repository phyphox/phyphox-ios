echo Refreshing GitHub Sources

. checkoutLatestCommit.sh JanX2/JXLS JXLS

. checkoutLatestRelease.sh JonasGessner/JGProgressHUD JGProgressHUD

. checkoutLatestTag.sh pixelglow/ZipZap ZipZap

. checkoutLatestRelease.sh Boris-Em/BEMCheckBox BEMCheckBox

. checkoutLatestRelease.sh swisspol/GCDWebServer GCDWebServer

#echo Removing CocoaPods stuff
#find . -iname "Pod*" -prune -exec rm -rf "{}" \

echo Done!
