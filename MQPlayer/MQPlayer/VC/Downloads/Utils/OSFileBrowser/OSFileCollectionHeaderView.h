//
//  OSFileCollectionHeaderView.h
//  FileDownloader
//
//  Created by Swae on 2017/11/19.
//  Copyright © 2017年 alpface. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OSFileCollectionViewFlowLayout.h"
#import "OSFileBrowserAppearanceConfigs.h"

FOUNDATION_EXPORT NSString * const OSFileCollectionHeaderViewDefaultIdentifier;

@class OSFileCollectionHeaderView, OSFileCollectionViewFlowLayout;

@protocol OSFileCollectionHeaderViewDelegate <NSObject>

@optional
- (void)fileCollectionHeaderView:(OSFileCollectionHeaderView *)headerView
                   reLayoutStyle:(OSFileCollectionLayoutStyle)style;
- (void)fileCollectionHeaderView:(OSFileCollectionHeaderView *)headerView
             clickedSearchButton:(UIButton *)searchButton;
- (void)fileCollectionHeaderView:(OSFileCollectionHeaderView *)headerView
          didSelectedSortChanged:(UISegmentedControl *)sortControl currentSortType:(OSFileBrowserSortType)sortType;

@end

@interface OSFileCollectionHeaderView : UICollectionReusableView

@property (nonatomic, weak) id<OSFileCollectionHeaderViewDelegate> delegate;


@end
