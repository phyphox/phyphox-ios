//
//  PTButton.h
//  ProTube 2
//
//  Created by Jonas Gessner on 31.08.14.
//  Copyright (c) 2014 Jonas Gessner. All rights reserved.
//

/**
 This code is taken from the ProTube for YouTube iOS app (https://itunes.apple.com/app/id931201696). © 2014-2016 Jonas Gessner
 */

#import <UIKit/UIKit.h>

@interface PTButton : UIButton

- (void)setTintColor:(UIColor *)tintColor forState:(UIControlState)state;
- (UIColor *)tintColorForState:(UIControlState)state;

@end
