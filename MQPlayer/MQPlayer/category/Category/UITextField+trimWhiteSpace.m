//
//  UITextField+trimWhiteSpace.m
//  TextFieldNoEmpty
//
//  Created by ap2 on 16/6/3.
//  Copyright © 2016年 ap2. All rights reserved.
//

#import "UITextField+trimWhiteSpace.h"

@implementation UITextField (trimWhiteSpace)
- (NSString *)trimWhiteSpace
{
    NSString *temp = [self.text stringByReplacingOccurrencesOfString:@" " withString:@""];
    temp = [temp stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    temp = [temp stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    self.text = temp;
    return temp;
}
@end
