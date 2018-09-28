//
//  HotModel.h
//  MQPlayer
//
//  Created by zhu2 on 2018/9/23.
//  Copyright © 2018年 ap2. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AK88HotModel : NSObject

@property (nonatomic, strong) NSArray *subjects;
@property (nonatomic, assign) NSInteger count;
@property (nonatomic, assign) NSInteger total;
@property (nonatomic, assign) NSInteger start;

@end

@interface AK88directors : NSObject

@property (nonatomic, copy)   NSString *name;

@end

@interface actors : NSObject

@property (nonatomic, copy)   NSString *name;

@end

@interface pic : NSObject

@property (nonatomic, copy)   NSString *large;
@property (nonatomic, copy)   NSString *normal;

@end

@interface rating : NSObject

@property (nonatomic, strong) NSNumber *value;
@property (nonatomic, assign) NSInteger star_count;
@property (nonatomic, assign) NSInteger count;
@property (nonatomic, assign) NSInteger max;

@end

@interface subjects : NSObject

@property (nonatomic, copy)   NSString *subtype;
@property (nonatomic, copy)   NSString *title;
@property (nonatomic, copy)   NSString *url;
@property (nonatomic, strong) NSArray *directors;
@property (nonatomic, copy)   NSString *null_rating_reason;
@property (nonatomic, strong) NSString *interest;
@property (nonatomic, assign) NSInteger collect_count;
@property (nonatomic, assign) NSInteger wish_count;
@property (nonatomic, copy)   NSString *lineticket_url;
@property (nonatomic, copy)   NSString *year;
@property (nonatomic, copy)   NSString *uri;
@property (nonatomic, strong) NSArray *pubdate;
@property (nonatomic, strong) NSArray *actors;
@property (nonatomic, copy)   NSString *type;
@property (nonatomic, copy)   NSString *uid;
@property (nonatomic, copy)   NSString *sharing_url;
@property (nonatomic, strong) pic *pic;
@property (nonatomic, copy)   NSString *release_date;
@property (nonatomic, strong) NSArray *genres;
@property (nonatomic, strong) NSString *text_link_info;
@property (nonatomic, assign) NSInteger is_released;
@property (nonatomic, strong) rating *rating;
@property (nonatomic, assign) NSInteger has_linewatch;

@end

