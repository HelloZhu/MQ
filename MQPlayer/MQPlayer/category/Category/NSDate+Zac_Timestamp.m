//
//  NSObject+Zac_Timestamp.m
//  ESD
//
//  Created by ap2 on 2017/7/14.
//  Copyright © 2017年 zac. All rights reserved.
//

#import "NSDate+Zac_Timestamp.h"

@implementation NSDate (Zac_Timestamp)

/**
 *
 *  @brief  毫秒时间戳 例如 1443066826371
 *
 *  @return 毫秒时间戳
 */
+ (NSString *)zac_MillisecondTimestamp
{
    return  [[NSNumber numberWithLongLong:[[NSDate date] timeIntervalSince1970]*1000] stringValue];
}
@end
