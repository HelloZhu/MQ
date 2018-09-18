//
//  UIButton+Block.m
//  IOS-Categories
//
//  Created by Jakey on 14/12/30.
//  Copyright (c) 2014年 www.skyfox.org. All rights reserved.
//

#import "UIButton+Block.h"
#import <objc/runtime.h>
static const void *UIButtonBlockKey = &UIButtonBlockKey;
static const void *UIButtonfyBlockKey = &UIButtonfyBlockKey;

@implementation UIButton (Block)
-(void)addActionHandler:(TouchedBlock)touchHandler{
    objc_setAssociatedObject(self, UIButtonBlockKey, touchHandler, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self addTarget:self action:@selector(actionTouched:) forControlEvents:UIControlEventTouchUpInside];
}
-(void)actionTouched:(UIButton *)btn{
    TouchedBlock block = objc_getAssociatedObject(self, UIButtonBlockKey);
    ActionBlock block2 = objc_getAssociatedObject(self, UIButtonfyBlockKey);
    if (block) {
        block(btn.tag);
    }
    if (block2) {
        block2(btn);
    }
}

- (void)fy_addActionHandler:(ActionBlock)touchHandler
{
    objc_setAssociatedObject(self, UIButtonfyBlockKey, touchHandler, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self addTarget:self action:@selector(actionTouched:) forControlEvents:UIControlEventTouchUpInside];
}

@end

