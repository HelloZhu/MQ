//
//  UITextField+LimitLength.h
//  ZAC_CategoryUtils
//
//  Created by ap2 on 2018/8/9.
//  Copyright © 2018年 gonglx. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UITextField (LimitLength)
@property (assign,nonatomic) NSUInteger maxLength;

@property (copy,nonatomic) void(^valueChangedBlock)(NSString *content);

@end
