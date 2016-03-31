//
//  PTNavigationBarTitleView.m
//  ProTube 2
//
//  Created by Jonas Gessner on 27.08.14.
//  Copyright (c) 2014 Jonas Gessner. All rights reserved.
//

/**
 This code is taken from the ProTube for YouTube iOS app (https://itunes.apple.com/app/id931201696). © 2014-2016 Jonas Gessner
 */

#import "PTNavigationBarTitleView.h"
#import "VBFPopFlatButton.h"
#import "UIColor+Expanded.h"
#import "Constants.h"

@interface PTNavigationBarTitleView ()

@end

@implementation PTNavigationBarTitleView {
    UILabel *_titleLabel;
    UILabel *_promptLabel;
    
    VBFPopFlatButton *_promptButton;
}

@dynamic title, prompt;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.textColor = kHighlightColor;
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.userInteractionEnabled = NO;
        _titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        
        _promptLabel = [[UILabel alloc] init];
        _promptLabel.backgroundColor = [UIColor clearColor];
        _promptLabel.textColor = kHighlightColor;
        _promptLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
        _promptLabel.userInteractionEnabled = NO;
        
        [self addSubview:_titleLabel];
        [self addSubview:_promptLabel];
        
        [self addTarget:self action:@selector(promptActionPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)setHiddenForSearch:(BOOL)hiddenForSearch {
    if (_hiddenForSearch == hiddenForSearch) {
        return;
    }
    
    _hiddenForSearch = hiddenForSearch;
    
    if (_hiddenForSearch) {
        super.alpha = 0.0f;
    }
    else {
        super.alpha = 1.0f;
    }
}

- (void)setAlpha:(CGFloat)alpha {
    if (self.hiddenForSearch) {
        alpha = MIN(0.0f, alpha);
    }
    
    super.alpha = alpha;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    
    if (highlighted) {
        _promptLabel.textColor = [kHighlightColor colorByInterpolatingToColor:[UIColor whiteColor] byFraction:0.5f];
    }
    else {
        _promptLabel.textColor = kHighlightColor;
    }
    
    _promptButton.highlighted = highlighted;
}

- (void)setTitle:(NSString *)title {
    _titleLabel.text = title;
    [self setNeedsLayout];
}

- (void)setPrompt:(NSString *)prompt {
    if (prompt.length > 0) {
        _titleLabel.textColor = [UIColor blackColor];
    }
    else {
        _titleLabel.textColor = kHighlightColor;
    }
    
    _promptLabel.text = prompt;
    [self setNeedsLayout];
}

- (void)setPromptButtonExtended:(BOOL)promptButtonExtended {
    if (self.promptButtonExtended == promptButtonExtended) {
        return;
    }
    
    _promptButtonExtended = promptButtonExtended;
    
    [_promptButton animateToType:(promptButtonExtended ? buttonUpBasicType : buttonDownBasicType)];
}

- (NSString *)title {
    return _titleLabel.text;
}

- (NSString *)prompt {
    return _promptLabel.text;
}

- (void)setPromptAction:(void (^)(void))promptAction {
    _promptAction = promptAction;
    
    if (_promptAction) {
        self.userInteractionEnabled = YES;
        
        if (!_promptButton) {
            _promptButton = [[VBFPopFlatButton alloc] initWithFrame:(CGRect){CGPointZero, {14.0f, 14.0f}} buttonType:buttonDownBasicType buttonStyle:buttonPlainStyle animateToInitialState:NO];
            _promptButton.lineRadius = 0.5f;
            _promptButton.lineThickness = 1.0f;
            [_promptButton setTintColor:kHighlightColor forState:UIControlStateNormal];
            [_promptButton setTintColor:[kHighlightColor colorByInterpolatingToColor:[UIColor whiteColor] byFraction:0.5f] forState:UIControlStateHighlighted];
            _promptButton.userInteractionEnabled = UIAccessibilityIsVoiceOverRunning();
            
            [_promptButton addTarget:self action:@selector(promptActionPressed) forControlEvents:UIControlEventTouchUpInside];
            
            [self addSubview:_promptButton];
        }
    }
    else {
        self.userInteractionEnabled = NO;
        
        [_promptButton removeFromSuperview];
        _promptButton = nil;
    }
}

- (void)promptActionPressed {
    if (_promptAction) {
        _promptAction();
    }
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGSize s = CGSizeZero;
    s.height = 44.0f;
    
    s.width = MAX([_titleLabel sizeThatFits:size].width, [_promptLabel sizeThatFits:size].width+_promptButton.frame.size.width+3.0f);
    
    return s;
}

- (void)setFrame:(CGRect)frame {
    if (self.blockFrame) {
        return;
    }
    
    [super setFrame:frame];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat xOrigin = 0.0f;
    
    CGRect t = (CGRect){{xOrigin, 0.0f}, [_titleLabel sizeThatFits:self.bounds.size]};
    t.size.width = self.bounds.size.width-xOrigin;
    
    t.origin.y = CGRectGetMidY(self.bounds)-CGRectGetMidY(t)+1.0f;
    
    if (self.prompt.length) {
        CGRect p = (CGRect){CGPointZero, [_promptLabel sizeThatFits:self.bounds.size]};
        p.size.width = MIN(self.bounds.size.width, p.size.width);
        p.origin.x = (self.bounds.size.width-p.size.width)/2.0f+xOrigin/2.0f;
        t.origin.y -= 8.0f;
        
        if (_titleLabel.text.length) {
            p.origin.y = CGRectGetMaxY(t);//+3.0f;
        }
        else {
            if (iOS9) {
                p.origin.y = CGRectGetMidY(self.bounds)-p.size.height/2.0f+4.0f;
            }
            else {
                p.origin.y = CGRectGetMidY(self.bounds)-p.size.height/2.0f-1.0f;
            }
        }
        
        _promptLabel.frame = p;
    }
    
    if (_promptButton) {
        CGAffineTransform _t = _promptButton.transform;
        _promptButton.transform = CGAffineTransformIdentity;
        CGRect r = _promptButton.frame;
        r.origin.x = CGRectGetMaxX(_promptLabel.frame)+3.0f;
        r.origin.y = CGRectGetMinY(_promptLabel.frame)+(_promptLabel.frame.size.height-_promptButton.frame.size.height)/2.0f;
        _promptButton.frame = r;
        _promptButton.transform = _t;
    }
    
    _titleLabel.frame = t;
}


@end
