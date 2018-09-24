//
//  TabBarController.m
//  MQPlayer
//
//  Created by ap2 on 2018/9/18.
//  Copyright © 2018年 ap2. All rights reserved.
//

#import "TabBarController.h"
#import "HotMovieViewController.h"
#import "MyVideoTableViewController.h"
#import "TransViewController.h"
#import "ToolsViewController.h"
#import "OSTransmitDataViewController.h"

@interface TabBarController ()


@end

@implementation TabBarController

- (instancetype)init
{
    if(self = [super init])
    {
        self.viewControllers = [self createTabbarViewControllers];
    }
    return self;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (NSArray *)createTabbarViewControllers
{
    UIImage *tabbar_comment_selected = [UIImage zac_imageWithOriginalModeName:@"tabbar_comment_selected"];
    UIImage *tabbar_comment = [UIImage zac_imageWithOriginalModeName:@"tabbar_comment"];
    
    UIImage *tabbar_Main_selected = [UIImage zac_imageWithOriginalModeName:@"tabbar_home_selected"];
    UIImage *tabbar_Main = [UIImage zac_imageWithOriginalModeName:@"tabbar_home"];
    
    UIImage *tabbar_help_selected = [UIImage zac_imageWithOriginalModeName:@"tabbar_help_selected"];
    UIImage *tabbar_help = [UIImage zac_imageWithOriginalModeName:@"tabbar_help"];
    
    UIImage *tabbar_Me_selected = [UIImage zac_imageWithOriginalModeName:@"tabbar_Me_selected"];
    UIImage *tabbar_Me = [UIImage zac_imageWithOriginalModeName:@"tabbar_Me"];
    
    HotMovieViewController *mainVC = [[HotMovieViewController alloc] init];
    mainVC.title = @"店长推荐";
    mainVC.tabBarItem.image = tabbar_Main;
    mainVC.tabBarItem.selectedImage = tabbar_Main_selected;
    
    UIColor *fontColor_Selected = UIColorFromRGB(218, 34, 25);
    UIColor *fontColor_Normal = UIColorFromRGB(153, 153, 153);
    
    UIFont *font = [UIFont systemFontOfSize:12];
    NSDictionary *attribute = @{NSForegroundColorAttributeName:fontColor_Normal,
                                NSFontAttributeName:font};
    
    NSDictionary *attribute_selected = @{NSForegroundColorAttributeName:fontColor_Selected,
                                         NSFontAttributeName:font};
    
    [mainVC.tabBarItem setTitleTextAttributes:attribute forState:UIControlStateNormal];
    [mainVC.tabBarItem setTitleTextAttributes:attribute_selected forState:UIControlStateSelected];
    [mainVC.tabBarItem setTitleTextAttributes:attribute_selected forState:UIControlStateHighlighted];
    
    MyVideoTableViewController *helpVC = [[MyVideoTableViewController alloc] initWithStyle:UITableViewStylePlain];
    helpVC.title = @"我的视频";
    helpVC.tabBarItem.image = tabbar_Me ;
    helpVC.tabBarItem.selectedImage = tabbar_Me_selected ;
    [helpVC.tabBarItem setTitleTextAttributes:attribute forState:UIControlStateNormal];
    [helpVC.tabBarItem setTitleTextAttributes:attribute_selected forState:UIControlStateSelected];
    [helpVC.tabBarItem setTitleTextAttributes:attribute_selected forState:UIControlStateHighlighted];
    
    
    OSTransmitDataViewController *commentVC = [OSTransmitDataViewController zac_initFromXIB];
    commentVC.title = @"电脑互传";
    commentVC.tabBarItem.image = tabbar_comment;
    commentVC.tabBarItem.selectedImage = tabbar_comment_selected;
    [commentVC.tabBarItem setTitleTextAttributes:attribute forState:UIControlStateNormal];
    [commentVC.tabBarItem setTitleTextAttributes:attribute_selected forState:UIControlStateSelected];
    [commentVC.tabBarItem setTitleTextAttributes:attribute_selected forState:UIControlStateHighlighted];
    
    ToolsViewController *accountVC = [[ToolsViewController alloc] initWithStyle:UITableViewStyleGrouped];
    accountVC.title = @"下载工具";
    accountVC.tabBarItem.image = tabbar_help;
    accountVC.tabBarItem.selectedImage = tabbar_help_selected;
    [accountVC.tabBarItem setTitleTextAttributes:attribute forState:UIControlStateNormal];
    [accountVC.tabBarItem setTitleTextAttributes:attribute_selected forState:UIControlStateSelected];
    [accountVC.tabBarItem setTitleTextAttributes:attribute_selected forState:UIControlStateHighlighted];
    

    return @[[self nav:mainVC], [self nav:helpVC], [self nav:commentVC]];
}

- (UINavigationController *)nav:(UIViewController *)vc
{
    return [[UINavigationController alloc] initWithRootViewController:vc];
}

@end
