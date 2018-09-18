//
//  UIImage+OriginalMode.m
//  ESD
//
//  Created by ap2 on 2017/8/1.
//  Copyright © 2017年 zac. All rights reserved.
//

#import "UIImage+OriginalMode.h"

@implementation UIImage (OriginalMode)

+(instancetype)zac_imageWithOriginalModeName:(NSString *)imageName
{
    UIImage *image = [UIImage imageNamed:imageName];
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

@end
