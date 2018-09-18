//
//  NSObject+Zac_Timestamp.h
//  ESD
//
//  Created by ap2 on 2017/7/14.
//  Copyright © 2017年 zac. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDate (Zac_Timestamp)

/**
 *
 *  @brief  毫秒时间戳 例如 1443066826371
 *
 *  @return 毫秒时间戳
 */
+ (NSString *)zac_MillisecondTimestamp;

@end
