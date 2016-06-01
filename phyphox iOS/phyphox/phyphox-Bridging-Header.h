//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "XMLDictionary.h"
#import "Constants.h"
#import "VBFPopFlatButton.h"
#import <TheAmazingAudioEngine/TheAmazingAudioEngine.h>
#import "UIAlertController+PTExtensions.h"
#import "BEMCheckbox.h"
#import <ZipZap/ZipZap.h>
#import <JXLS/JXLS.h>
#import "PTButton.h"
#import "UIColor+Expanded.h"
#import <ifaddrs.h>
@import JGProgressHUD;

BOOL AEFloatConverterToFloat(AEFloatConverter* converter, AudioBufferList *sourceBuffer, float * const * targetBuffers, UInt32 frames);