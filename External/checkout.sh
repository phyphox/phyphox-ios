echo Refreshing GitHub Sources

#No need for fancy CocoaPods or Carthage...

rm -rf XMLDictionary
git clone https://github.com/nicklockwood/XMLDictionary
rm -rf XMLDictionary/.git

rm -rf OrderedDictionary
git clone -b development https://github.com/JonasGessner/OrderedDictionary
rm -rf OrderedDictionary/.git

echo Done!