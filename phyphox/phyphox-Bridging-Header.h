//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "XMLDictionary.h"
#import "OrderedDictionary.h"
#import "Constants.h"
#import "PTDropDownMenu.h"
#import "VBFPopFlatButton.h"
#import "PTNavigationBarTitleView.h"
#import <TheAmazingAudioEngine/TheAmazingAudioEngine.h>

BOOL AEFloatConverterToFloat(AEFloatConverter* converter, AudioBufferList *sourceBuffer, float * const * targetBuffers, UInt32 frames);
BOOL AEFloatConverterFromFloat(AEFloatConverter* converter, float * const * sourceBuffers, AudioBufferList *targetBuffer, UInt32 frames);
