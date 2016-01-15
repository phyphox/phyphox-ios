//
//  Constants.h
//  phyphox
//
//  Created by Jonas Gessner on 15.01.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_INLINE UIImage *UIImageCreateColorImage(UIColor *color, CGSize size, BOOL opaque) {
    UIGraphicsBeginImageContextWithOptions(size, opaque,  0.0f);
    
    [color setFill];
    
    [[UIBezierPath bezierPathWithRect:(CGRect){CGPointZero, size}] fill];
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return img;
}

OBJC_EXTERN BOOL ptHelperFunctionIsIOS9(void);

#define iOS9 ptHelperFunctionIsIOS9()
