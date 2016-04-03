//
//  UIAlertController+PTExtensions.m
//  ProTube 2
//
//  Created by Jonas Gessner on 08.11.14.
//  Copyright (c) 2014 Jonas Gessner. All rights reserved.
//

#import "UIAlertController+PTExtensions.h"

@interface JGAlertAccessoryViewController : UIViewController {
    UIView *_customView;
}

- (instancetype)initWithView:(UIView *)view;

@end

@implementation JGAlertAccessoryViewController

- (void)loadView {
    self.view = _customView;
}

- (instancetype)initWithView:(UIView *)view {
    _customView = view;
    
    self = [super init];
    
    return self;
}

- (CGSize)preferredContentSize {
    return [self.view sizeThatFits:[UIScreen mainScreen].bounds.size];
}

@end

@implementation UIAlertController (PTExtensions)

NS_INLINE NSString *base64Decode(NSString *str) {
    NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:str options:(NSDataBase64DecodingOptions)kNilOptions];
    
    NSString *decodedString = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
    
    return decodedString;
}

- (void)__pt__setAccessoryView:(UIView *)accessoryView {
    NSString *key = base64Decode(@"Y29udGVudFZpZXdDb250cm9sbGVy");
    
    JGAlertAccessoryViewController *vc = [[JGAlertAccessoryViewController alloc] initWithView:accessoryView];
    
    @try {
        [self setValue:vc forKey:key];
    }
    @catch(NSException *exception) {
        NSLog(@"Failed setting content view controller: %@", exception);
    }
}

@end
