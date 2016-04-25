//
//  Constants.h
//  phyphox
//
//  Created by Jonas Gessner on 15.01.16.
//  Copyright © 2016 Jonas Gessner. All rights reserved.
//  By Order of RWTH Aachen.
//

#import <UIKit/UIKit.h>
@import JGProgressHUD;

#define kHighlightColor [UIColor colorWithRed:(226.0/255.0) green:(67.0/255.0) blue:(48.0/255.0) alpha: 1.0]

NS_INLINE UIImage *UIImageCreateColorImage(UIColor *color, CGSize size, BOOL opaque) {
    UIGraphicsBeginImageContextWithOptions(size, opaque,  0.0f);
    
    [color setFill];
    
    [[UIBezierPath bezierPathWithRect:(CGRect){CGPointZero, size}] fill];
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return img;
}

NS_INLINE JGProgressHUD *showErrorHUDWithDescription(NSString *errorDescription) {
    JGProgressHUD *HUD = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
    HUD.interactionType = JGProgressHUDInteractionTypeBlockTouchesOnHUDView;
    HUD.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    HUD.textLabel.text = errorDescription;
    
    HUD.indicatorView = [[JGProgressHUDErrorIndicatorView alloc] init];
    
    [HUD showInView:[UIApplication sharedApplication].keyWindow.rootViewController.view animated:YES];
    
    [HUD dismissAfterDelay:3.0];
    
    return HUD;
}

OBJC_EXTERN BOOL ptHelperFunctionIsIOS9(void);

#define iOS9 ptHelperFunctionIsIOS9()
