//
//  HotMovieViewController.m
//  MQPlayer
//
//  Created by ap2 on 2018/9/18.
//  Copyright © 2018年 ap2. All rights reserved.
//

#import "HotMovieViewController.h"
#import "HotMovieCell.h"
#import "HotModel.h"

@interface HotMovieViewController ()
@property (nonatomic, strong)HotModel *hotModel;
@end

@implementation HotMovieViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    self.tableView.rowHeight = 150;
    self.tableView.tableFooterView = [UIView new];
    [self.tableView registerNib:[UINib nibWithNibName:@"HotMovieCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:@"cell"];
    [SVProgressHUD show];
    [[[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:@"https://raw.githubusercontent.com/HelloZhu/MQ/master/subjects.json"] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        id object =[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
            HotModel *model = [HotModel yy_modelWithJSON:object];
            self.hotModel = model;
            [self.tableView reloadData];
        });
        
    }]resume];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.hotModel.subjects.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    subjects *object = self.hotModel.subjects[indexPath.row];
    HotMovieCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    [cell.movieImage sd_setImageWithURL:[NSURL URLWithString:object.pic.normal]];
    cell.name.text = object.title;
    cell.score.text = [NSString stringWithFormat:@"%@分",object.rating.value.stringValue];
    
    cell.derector.text = [NSString stringWithFormat:@"导演：%@",object.directors[0][@"name"]];
    NSMutableString *desc = [[NSMutableString alloc] initWithString:@"主演："];
    [object.actors enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *dic = obj;
        [desc appendFormat:@".%@",dic[@"name"]];
    }];
    cell.desc.text = desc;
    // Configure the cell...
    
    return cell;
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

@end
