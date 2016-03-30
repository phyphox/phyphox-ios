//
//  PTNavigationBarTitleView.h
//  ProTube 2
//
//  Created by Jonas Gessner on 27.08.14.
//  Copyright (c) 2014 Jonas Gessner. All rights reserved.
//

/**
 This code is taken from the ProTube for YouTube iOS app (https://itunes.apple.com/app/id931201696). © 2014-2016 Jonas Gessner
 */

@import UIKit;

@interface PTNavigationBarTitleView : UIControl

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *prompt;

@property (nonatomic, copy) void (^promptAction)(void);

@property (nonatomic, assign) BOOL promptButtonExtended;

@property (nonatomic, assign) BOOL blockFrame;

@property (nonatomic, assign) BOOL hiddenForSearch;

@end
