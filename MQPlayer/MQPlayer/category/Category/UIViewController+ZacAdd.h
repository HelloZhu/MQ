//
//  UIViewController+ZacAdd.h
//  ZAC_CategoryUtils
//
//  Created by ap2 on 2018/8/7.
//  Copyright © 2018年 gonglx. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIViewController (ZacAdd)

@property (assign) BOOL shouldHideNavigationBar;

+ (instancetype)zac_initFromXIB;

@end
