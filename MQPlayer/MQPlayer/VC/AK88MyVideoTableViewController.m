//
//  MyVideoTableViewController.m
//  MQPlayer
//
//  Created by ap2 on 2018/9/18.
//  Copyright © 2018年 ap2. All rights reserved.
//

#import "AK88MyVideoTableViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "AK88FullScreenViewController.h"
#import "MyVideoTableViewCell.h"

@interface AK88MyVideoTableViewController ()
@property (nonatomic, strong) NSMutableArray *dataArr;
@end

@implementation AK88MyVideoTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadData) name:kTransStateChangeNotification object:nil];
    self.tableView.rowHeight = 100;
    self.tableView.tableFooterView = [UIView new];
    [self.tableView registerNib:[UINib nibWithNibName:@"MyVideoTableViewCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:@"cell"];
    
    NSString *documents = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/example.mp4"];
    NSString *ext = [[NSBundle mainBundle] pathForResource:@"KNSemiModalDemo" ofType:@"mov"];
    [[NSData dataWithContentsOfFile:ext] writeToFile:documents atomically:YES];
    [self reloadData];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataArr.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *dict = [self.dataArr objectAtIndex:indexPath.row];
    MyVideoTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.logoImageView.image = dict[@"img"];
    cell.nanel.text = dict[@"name"];
    cell.sizelabel.text = dict[@"size"];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *dict = [self.dataArr objectAtIndex:indexPath.row];
    NSString *path = [NSHomeDirectory() stringByAppendingFormat:@"/Documents/%@",dict[@"name"]];
    
    AK88FullScreenViewController *vc = [[AK88FullScreenViewController alloc] init];
    vc.url = [NSURL fileURLWithPath:path];
    [self.navigationController pushViewController:vc animated:NO];
}

-(UIImage *)getThumbnailImage:(NSString *)videoURL

{
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:videoURL] options:nil];
//    //NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
//
//    BOOL hasVideoTrack = [tracks count] > 0;
//    if (!hasVideoTrack) {
//        return nil;
//    }
    AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    
    gen.appliesPreferredTrackTransform = YES;
    
    CMTime time = CMTimeMakeWithSeconds(0.0, 600);
    
    NSError *error = nil;
    
    CMTime actualTime;
    
    CGImageRef image = [gen copyCGImageAtTime:time actualTime:&actualTime error:&error];
    
    UIImage *thumb = [[UIImage alloc] initWithCGImage:image];
    
    CGImageRelease(image);
    
    return thumb;
}


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

// 定义编辑样式
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleDelete;
}

// 进入编辑模式，按下出现的编辑按钮后,进行删除操作
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSDictionary *dict = [self.dataArr objectAtIndex:indexPath.row];
        NSString *path = [NSHomeDirectory() stringByAppendingFormat:@"/Documents/%@",dict[@"name"]];
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        [self.dataArr removeObject:dict];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

// 修改编辑按钮文字
- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return @"删除";
}

- (void)reloadData
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
            UIImage *image = [self getThumbnailImage:path];
            NSDictionary *atr = [filem attributesOfItemAtPath:path error:nil];
            [dic setObject:image forKey:@"img"];
            
            NSNumber *size = atr[NSFileSize];
            double s = size.longLongValue/(1024*1024.0);
            
            [dic setObject:[NSString stringWithFormat:@"%.1fM",s] forKey:@"size"];
        }
        [dic setObject:fileName forKey:@"name"];
        [lsit addObject:dic];
    }];
    
    NSLog(@"%@",allfile.description);
    self.dataArr = [lsit mutableCopy];
    [self.tableView reloadData];
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

@end
