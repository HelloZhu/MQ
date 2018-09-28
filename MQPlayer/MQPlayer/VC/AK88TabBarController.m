//
//  TabBarController.m
//  MQPlayer
//
//  Created by ap2 on 2018/9/18.
//  Copyright © 2018年 ap2. All rights reserved.
//

#import "AK88TabBarController.h"
#import "AK88MovieViewController.h"
#import "AK88MyVideoTableViewController.h"
#import "OSTransmitDataViewController.h"

@interface AK88TabBarController ()


@end

@implementation AK88TabBarController

- (instancetype)init
{
    if(self = [super init])
    {
        self.viewControllers = [self createTabbarViewControllers];
    }
    return self;
}
/*
 // Override to support conditional editing of the table view.
 - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the specified item to be editable.
 return YES;
 }
 */

/*
 // Override to support editing the table view.
 - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
 if (editingStyle == UITableViewCellEditingStyleDelete) {
 // Delete the row from the data source
 [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
 } else if (editingStyle == UITableViewCellEditingStyleInsert) {
 // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
 }
 }
 */

/*
 // Override to support rearranging the table view.
 - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
 }
 */

/*
 // Override to support conditional rearranging of the table view.
 - (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the item to be re-orderable.
 return YES;
 }
 */

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */
- (void)codeddd
{
    NSFileManager *filem = [NSFileManager defaultManager];
    NSString *documents = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSArray *allfile = [[NSFileManager defaultManager] subpathsAtPath:documents];
    NSMutableArray *lsit = [NSMutableArray array];
    [allfile enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSMutableDictionary *dic = [NSMutableDictionary dictionary];
        NSString *fileName = obj;
        if ([fileName.pathExtension compare:@"mp4" options:NSCaseInsensitiveSearch]
            || [fileName.pathExtension compare:@"avi" options:NSCaseInsensitiveSearch]
            ||[fileName.pathExtension compare:@"mkv" options:NSCaseInsensitiveSearch]
            ||[fileName.pathExtension compare:@"mov" options:NSCaseInsensitiveSearch]
            ||[fileName.pathExtension compare:@"3gp" options:NSCaseInsensitiveSearch]
            ||[fileName.pathExtension compare:@"rmvb" options:NSCaseInsensitiveSearch])
        {
            NSString *path = [documents stringByAppendingFormat:@"/%@",fileName];
            NSDictionary *atr = [filem attributesOfItemAtPath:path error:nil];
            
            NSNumber *size = atr[NSFileSize];
            double s = size.longLongValue/(1024*1024.0);
            
            [dic setObject:[NSString stringWithFormat:@"%.1fM",s] forKey:@"size"];
        }
        [dic setObject:fileName forKey:@"name"];
        [lsit addObject:dic];
    }];
    
    NSLog(@"%@",allfile.description);
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
    
    AK88MovieViewController *mainVC = [[AK88MovieViewController alloc] init];
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
    
    AK88MyVideoTableViewController *helpVC = [[AK88MyVideoTableViewController alloc] initWithStyle:UITableViewStylePlain];
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
    
//    ToolsViewController *accountVC = [[ToolsViewController alloc] initWithStyle:UITableViewStyleGrouped];
//    accountVC.title = @"下载工具";
//    accountVC.tabBarItem.image = tabbar_help;
//    accountVC.tabBarItem.selectedImage = tabbar_help_selected;
//    [accountVC.tabBarItem setTitleTextAttributes:attribute forState:UIControlStateNormal];
//    [accountVC.tabBarItem setTitleTextAttributes:attribute_selected forState:UIControlStateSelected];
//    [accountVC.tabBarItem setTitleTextAttributes:attribute_selected forState:UIControlStateHighlighted];
    

    return @[[self nav:mainVC], [self nav:helpVC], [self nav:commentVC]];
}

- (UINavigationController *)nav:(UIViewController *)vc
{
    return [[UINavigationController alloc] initWithRootViewController:vc];
}

@end
