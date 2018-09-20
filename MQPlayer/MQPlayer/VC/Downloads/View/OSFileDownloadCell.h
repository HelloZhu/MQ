//
//  OSFileDownloadCell.h
//  DownloaderManager
//
//  Created by xiaoyuan on 2017/6/5.
//  Copyright © 2017年 alpface. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UITableViewCell+XYConfigure.h"

@class OSRemoteResourceItem;

@interface OSFileDownloadCell : UITableViewCell

@property (nonatomic, strong) OSRemoteResourceItem *fileItem;
@property (nonatomic, copy) void (^optionButtonClick)(UIButton *btn, OSFileDownloadCell *cell);

- (void)setLongPressGestureRecognizer:(void (^)(UILongPressGestureRecognizer *longPres))block;
- (void)cycleViewClick:(id)cycleView;

@end
