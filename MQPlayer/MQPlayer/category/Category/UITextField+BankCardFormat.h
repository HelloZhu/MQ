//
//  UITextField+BankCardFormat.h
//  GYBankCardFormat
//
//  Created by ap2 on 16/1/6.
//  Copyright © 2016年 蒲晓涛. All rights reserved.
//

/** 在代理方法给这两个变量赋值
 
 - (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range
 replacementString:(NSString *)string
{
    previousTextFieldContent = textField.text;
    previousSelection = textField.selectedTextRange;
 
 return YES;
}
 *
 */



#import <UIKit/UIKit.h>

@interface UITextField (BankCardFormat)

@property (nonatomic, copy) NSString *previousTextFieldContent;
@property (nonatomic, strong) UITextRange *previousSelection;

//UIControlEventEditingChanged 在监听的这个通知里的方法调用该方法
- (void)reformatAsCardNumber;

@end
