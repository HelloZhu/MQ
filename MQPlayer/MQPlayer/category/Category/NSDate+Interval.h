//
//  NSDate+Interval.h
//  ESD
//
//  Created by ap2 on 16/7/6.
//  Copyright © 2016年 zac. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDate (Interval)


/**
 *  获取两个时间的间隔（秒）
 *
 *  @param fromdate 旧的时间
 *  @param toDate   新的时间
 *
 *  @return 间隔（秒）
 */
+ (long long)zac_intervalFromDate:(NSDate *)fromdate toDate:(NSDate *)toDate;

/**
 *  国际时间转换成当地时区时间
 *
 *  @return 当地时区时间
 */
+ (NSDate *)localeDate;

@end
