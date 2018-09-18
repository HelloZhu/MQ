//
//  UITextField+LimitLength.m
//  ZAC_CategoryUtils
//
//  Created by ap2 on 2018/8/9.
//  Copyright © 2018年 gonglx. All rights reserved.
//

#import "UITextField+LimitLength.h"
#import "UITextField+trimWhiteSpace.h"
#import <objc/runtime.h>

static const char max_length = '\0';
static const char value_changed_block = '\0';
static const char kObsever = '\0';
static const char kDisableEmoji = '\0';


@interface UITextField ()

@property (assign,nonatomic,getter=isObsevered) BOOL obsever;
@end

@implementation UITextField (LimitLength)

-(void)setDisableEmoji:(BOOL)disableEmoji{
    
    objc_setAssociatedObject(self, &kDisableEmoji, [NSNumber numberWithBool:disableEmoji], OBJC_ASSOCIATION_RETAIN);
}

-(BOOL)isDisableEmoji{
    
    return [objc_getAssociatedObject(self, &kDisableEmoji) boolValue];
}

-(BOOL)isObsevered{
    
    return [objc_getAssociatedObject(self, &kObsever) boolValue];
}

-(void)setObsever:(BOOL)obsever{
    
    objc_setAssociatedObject(self, &kObsever, [NSNumber numberWithBool:obsever], OBJC_ASSOCIATION_RETAIN);
}

-(NSUInteger)maxLength{
    
    return [objc_getAssociatedObject(self, &max_length) integerValue];
}

-(void)setMaxLength:(NSUInteger)maxLength{
    objc_setAssociatedObject(self, &max_length, @(maxLength), OBJC_ASSOCIATION_RETAIN);
    
    if (!self.isObsevered) {
        [self addTarget:self action:@selector(mq_textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        self.obsever = YES;
    }
}


-(void)setValueChangedBlock:(void (^)(NSString *))valueChangedBlock{
    
    objc_setAssociatedObject(self, &value_changed_block, valueChangedBlock, OBJC_ASSOCIATION_COPY);
    if (!self.isObsevered) {
        [self addTarget:self action:@selector(mq_textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        self.obsever = YES;
    }
}


-(void(^)(NSString *))valueChangedBlock{
    
    return objc_getAssociatedObject(self, &value_changed_block);
}


- (void)mq_textFieldDidChange:(UITextField *)textField
{
    NSUInteger kMaxLength = [objc_getAssociatedObject(self, &max_length) integerValue];
    
    if (kMaxLength == 0) {
        
        kMaxLength = NSIntegerMax;
    }
    
    [textField trimWhiteSpace];
    textField.text = [self disable_emoji:textField.text];
    
    NSString *toBeString = textField.text;
    
    //获取高亮部分
    UITextRange *selectedRange = [textField markedTextRange];
    UITextPosition *position = [textField positionFromPosition:selectedRange.start offset:0];
    
    // 没有高亮选择的字，则对已输入的文字进行字数统计和限制
    if (!position)
    {
        
        if (toBeString.length > kMaxLength)
        {
            NSRange rangeIndex = [toBeString rangeOfComposedCharacterSequenceAtIndex:kMaxLength];
            if (rangeIndex.length == 1)
            {
                textField.text = [toBeString substringToIndex:kMaxLength];
            }
            else
            {
                NSRange rangeRange = [toBeString rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, kMaxLength)];
                
                NSInteger tmpLength;
                if (rangeRange.length > kMaxLength) {
                    tmpLength = rangeRange.length - rangeIndex.length;
                }else{
                    
                    tmpLength = rangeRange.length;
                }
                textField.text = [toBeString substringWithRange:NSMakeRange(0, tmpLength)];
            }
        }
        
    }
    if (self.valueChangedBlock) {
        
        self.valueChangedBlock(self.text);
    }
}


- (NSString *)disable_emoji:(NSString *)text{
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[^\\u0020-\\u007E\\u00A0-\\u00BE\\u2E80-\\uA4CF\\uF900-\\uFAFF\\uFE30-\\uFE4F\\uFF00-\\uFFEF\\u0080-\\u009F\\u2000-\\u201f\r\n]"options:NSRegularExpressionCaseInsensitive error:nil];
    NSString *modifiedString = [regex stringByReplacingMatchesInString:text
                                                               options:0
                                                                 range:NSMakeRange(0, [text length])
                                                          withTemplate:@""];
    return modifiedString;
}
@end
