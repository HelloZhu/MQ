//
//  UIViewController+ZacAdd.m
//  ZAC_CategoryUtils
//
//  Created by ap2 on 2018/8/7.
//  Copyright © 2018年 gonglx. All rights reserved.
//

#import "UIViewController+ZacAdd.h"
#include <objc/runtime.h>

const void * HideNavigationBarKey = @"HideNavigationBarKey";

@implementation UIViewController (ZacAdd)

+ (void)load {
    
    Method fromMethod_viewWillAppear = class_getInstanceMethod([self class], @selector(viewWillAppear:));
    Method toMethod_viewWillAppear = class_getInstanceMethod([self class], @selector(zac_swizzlingViewWillAppear:));
    
    if (!class_addMethod([self class], @selector(zac_swizzlingViewWillAppear:), method_getImplementation(toMethod_viewWillAppear), method_getTypeEncoding(toMethod_viewWillAppear))) {
        method_exchangeImplementations(fromMethod_viewWillAppear, toMethod_viewWillAppear);
    }
    
    
    Method fromMethod_viewWillDisappear = class_getInstanceMethod([self class], @selector(viewWillDisappear:));
    Method toMethod_viewWillDisappear = class_getInstanceMethod([self class], @selector(zac_swizzlingViewWillDisappear:));
    
    if (!class_addMethod([self class], @selector(zac_swizzlingViewWillDisappear:), method_getImplementation(toMethod_viewWillDisappear), method_getTypeEncoding(toMethod_viewWillDisappear))) {
        method_exchangeImplementations(fromMethod_viewWillDisappear, toMethod_viewWillDisappear);
    }
    
    Method fromMethod_viewDidLoad = class_getInstanceMethod([self class], @selector(viewDidLoad));
    Method toMethod_viewDidLoad = class_getInstanceMethod([self class], @selector(zac_swizzlingviewDidLoad));
    
    if (!class_addMethod([self class], @selector(zac_swizzlingviewDidLoad), method_getImplementation(toMethod_viewDidLoad), method_getTypeEncoding(toMethod_viewDidLoad))) {
        method_exchangeImplementations(fromMethod_viewDidLoad, toMethod_viewDidLoad);
    }
}

- (void)zac_swizzlingviewDidLoad
{
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage zac_imageWithOriginalModeName:@"back"] landscapeImagePhone:nil style:UIBarButtonItemStylePlain target:self action:@selector(goback)];
    [self zac_swizzlingviewDidLoad];
}

- (void)goback
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)zac_swizzlingViewWillAppear:(BOOL)animated {
    
    [self.navigationController.navigationBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
    //去掉透明后导航栏下边的黑边
    [self.navigationController.navigationBar setShadowImage:nil];
    
    [self zac_swizzlingViewWillAppear:animated];
}

- (void)zac_swizzlingViewWillDisappear:(BOOL)animated
{
    
    [self zac_swizzlingViewWillDisappear:animated];
}

#pragma mark - setter and getter
- (void)setShouldHideNavigationBar:(BOOL)shouldHideNavigationBar
{
    objc_setAssociatedObject(self, HideNavigationBarKey, @(shouldHideNavigationBar), OBJC_ASSOCIATION_RETAIN);
}

- (BOOL)shouldHideNavigationBar
{
    id value = objc_getAssociatedObject(self, HideNavigationBarKey);
    return [value boolValue];
}

#pragma mark - init use xib
+ (instancetype)zac_initFromXIB
{
   return [[[self class] alloc] initWithNibName:NSStringFromClass([self class]) bundle:[NSBundle mainBundle]];
}

@end
