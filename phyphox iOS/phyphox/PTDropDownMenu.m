//
//  PTDropDownMenu.m
//  ProTube 2
//
//  Created by Jonas Gessner on 30.08.14.
//  Copyright (c) 2014 Jonas Gessner. All rights reserved.
//

/**
 This code is taken from the ProTube for YouTube iOS app (https://itunes.apple.com/app/id931201696). © 2014-2016 Jonas Gessner
 */

#define kButtonHeight 40.0
#define kBorderWidth (1.0/[UIScreen mainScreen].scale)

#import "PTDropDownMenu.h"
#import "UIColor+Expanded.h"
#import "Constants.h"

#define kTitleColor [UIColor whiteColor]
#define kBorderColor [UIColor whiteColor]

@implementation PTDropDownMenu {
    NSArray <UIButton *>*_buttons;
}

- (UIButton *)makeButtonWithTitle:(NSString *)title {
    UIButton *b = [[UIButton alloc] init];
    [b addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    b.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    
    [b setTitleColor:[kTitleColor colorWithAlphaComponent:0.8f] forState:UIControlStateNormal];
    [b setBackgroundImage:UIImageCreateColorImage([UIColor colorWithWhite:0.0f alpha:0.1f], (CGSize){1.0f, 1.0f}, NO) forState:UIControlStateHighlighted];
    b.layer.borderWidth = kBorderWidth;
    b.layer.borderColor = [kBorderColor colorWithAlphaComponent:0.8f].CGColor;
    [b setTitle:title forState:UIControlStateNormal];
    
    return b;
}

- (void)buttonTapped:(UIButton *)button {
    if (self.buttonTappedBlock) {
        NSUInteger index = (NSUInteger)button.tag;
        
        self.buttonTappedBlock(index);
    }
}

- (instancetype)initWithItems:(NSArray <NSString *>*)items {
    self = [super init];
    if (self) {
        self.clipsToBounds = YES;
        
        NSMutableArray <UIButton *>*buttons = [NSMutableArray array];
        NSUInteger index = 0;
        for (NSString *title in items) {
            UIButton *b = [self makeButtonWithTitle:title];
            b.tag = (NSInteger)index;
            
            [self addSubview:b];
            
            [buttons addObject:b];
            
            index++;
        }
        
        _buttons = buttons.copy;
    }
    
    return self;
}

- (CGSize)sizeThatFits:(CGSize)size {
    return (CGSize){size.width, _buttons.count*(kButtonHeight-kBorderWidth)};
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat currentY = 0.0f;
    
    for (UIButton *b in _buttons) {
        CGRect r = CGRectZero;
        r.origin.y = currentY-kBorderWidth;
        r.size.height = kButtonHeight;
        r.origin.x = -kBorderWidth;
        r.size.width = self.bounds.size.width+2.0f*kBorderWidth;
        
        b.frame = r;
        
        currentY += r.size.height-kBorderWidth;
    }
}

@end
