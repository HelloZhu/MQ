//
//  NSDate+Interval.m
//  ESD
//
//  Created by ap2 on 16/7/6.
//  Copyright © 2016年 zac. All rights reserved.
//

#import "NSDate+Interval.h"

@implementation NSDate (Interval)

/**
 *  获取两个时间的间隔（秒）
 *
 *  @param fromdate 旧的时间
 *  @param toDate   新的时间
 *
 *  @return 间隔（秒）
 */
+ (long long)zac_intervalFromDate:(NSDate *)fromdate toDate:(NSDate *)toDate
{
    NSCalendar *cal = [NSCalendar currentCalendar];
    // 适配iOS8，参数废弃 modify by hhx 2017.07.12
//    unsigned int unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
    unsigned int unitFlags = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
    NSDateComponents *d = [cal components:unitFlags fromDate:fromdate toDate:toDate options:0];
    long long sec = [d hour]*3600+[d minute]*60+[d second];
    NSLog(@"second = %lld",sec);
    return sec;
}

/**
 *  国际时间转换成当地时区时间
 *
 *  @return 当地时区时间
 */
+ (NSDate *)localeDate
{
    NSDate *date = [NSDate date];
    NSTimeZone *zone = [NSTimeZone systemTimeZone];
    NSInteger interval = [zone secondsFromGMTForDate: date];
    NSDate *localeDate = [date  dateByAddingTimeInterval: interval];
    return localeDate;
}

@end
