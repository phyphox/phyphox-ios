//
//  PTButton.m
//  ProTube 2
//
//  Created by Jonas Gessner on 31.08.14.
//  Copyright (c) 2014 Jonas Gessner. All rights reserved.
//

/**
 This code is taken from the ProTube for YouTube iOS app (https://itunes.apple.com/app/id931201696). © 2014-2016 Jonas Gessner
 */

#import "PTButton.h"

@implementation PTButton {
    NSMutableDictionary *_tintColors;
}

- (void)setTintColor:(UIColor *)tintColor forState:(UIControlState)state {
    if (!_tintColors) {
        _tintColors = [NSMutableDictionary dictionary];
    }
    
    if (!tintColor) {
        [_tintColors removeObjectForKey:@(state)];
    }
    else {
        _tintColors[@(state)] = tintColor;
    }
    
    [self updateState];
}

- (void)setSelected:(BOOL)selected {
    if (self.selected == selected) {
        return;
    }
    
    [super setSelected:selected];
    [self updateState];
}

- (void)setHighlighted:(BOOL)highlighted {
    if (self.highlighted == highlighted) {
        return;
    }
    
    [super setHighlighted:highlighted];
    [self updateState];
}

- (void)setEnabled:(BOOL)enabled {
    if (self.enabled == enabled) {
        return;
    }
    
    [super setEnabled:enabled];
    [self updateState];
}

- (void)updateState {
    self.tintColor = [self tintColorForState:self.state];
}

- (UIColor *)tintColorForState:(UIControlState)state {
    UIColor *tint = _tintColors[@(self.state)];
    
    if (!tint) {
        //Fall back to UIControlStateNormal
        tint = _tintColors[@(UIControlStateNormal)];
    }
    
    if (!tint) {
        //Use current tint color
        tint = self.tintColor;
    }
    
    if (!tint) {
        //Fall back to window color
        tint = self.window.tintColor;
    }
    
    if (!tint) {
        //Fall back to default color
        tint = [UIColor whiteColor];
    }
    
    return tint;
}

@end
