//
//  AssetsViewController.m
//  DeGiro
//
//  Created by Taras Kalapun on 9/3/15.
//  Copyright (c) 2015 Taras Kalapun. All rights reserved.
//

#import "AssetsViewController.h"
#import "DeGiro.h"
#import <SVProgressHUD.h>
#import <SSKeychain.h>

@interface AssetsViewController ()
@property (nonatomic, strong) NSMutableArray *assets;

@property (nonatomic, weak) IBOutlet UILabel *totalLabel;
@property (nonatomic, weak) IBOutlet UILabel *totalDayLabel;
@property (nonatomic, weak) IBOutlet UILabel *roiLabel;
@property (nonatomic, weak) IBOutlet UILabel *inLabel;

@end

@implementation AssetsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;

    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
    
    //[self login:nil];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if ([DeGiro shared].sessionId) {
        [self refresh:nil];
    } else {
        if (![self tryLogin]) {
            [self showLoginScreen];
        }
    }
    
    
}

- (IBAction)login:(id)sender {
    [self showLoginScreen];
}

- (IBAction)showLoginScreen {
    
    NSString *service = @"degiro.com";
    NSArray *accounts = [SSKeychain accountsForService:service];
    
    NSString *oldLogin = nil;
    NSString *oldPassword = nil;
    
    if (accounts.count > 0) {
        oldLogin = accounts[0][kSSKeychainAccountKey];
        oldPassword = [SSKeychain passwordForService:service account:oldLogin];
    }
    
    for (NSString *account in accounts) {
        [SSKeychain deletePasswordForService:service account:account];
    }
    
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Login to DeGiro" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"Login";
        textField.keyboardType = UIKeyboardTypeASCIICapable;
        textField.text = oldLogin;
    }];
    [ac addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"Password";
        textField.keyboardType = UIKeyboardTypeASCIICapable;
        textField.secureTextEntry = YES;
        textField.text = oldPassword;
    }];
    [ac addAction:[UIAlertAction actionWithTitle:@"Login" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *loginField = ac.textFields[0];
        UITextField *passwordField = ac.textFields[1];
        
        [SSKeychain setPassword:passwordField.text forService:service account:loginField.text];
        if (![self tryLogin]) {
            [self showLoginScreen];
        }
        
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
    }]];
    
    [self presentViewController:ac animated:YES completion:nil];
}

- (BOOL)tryLogin {
    NSString *service = @"degiro.com";
    NSArray *accounts = [SSKeychain accountsForService:service];
    if (accounts.count == 0) {
        return NO;
    }
    NSString *account = accounts[0][kSSKeychainAccountKey];
    NSString *password = [SSKeychain passwordForService:service account:account];
    if (password.length == 0) {
        return NO;
    }
    
    [SVProgressHUD show];
    
    [[DeGiro shared] loadAccountWithUsername:account password:password completion:^(NSString *accountId, NSError *error) {
        [SVProgressHUD dismiss];
        if (error) {
            [[[UIAlertView alloc] initWithTitle:@"Error logging in" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
        } else {
            [self refresh:nil];
        }
    }];
    
    return YES;
}

- (IBAction)refresh:(id)sender {
    
    if ([DeGiro shared].needsReLogin) {
        [self login:nil];
        return;
    }
    
    [self.refreshControl beginRefreshing];
    
    [[DeGiro shared] loadPortfolioWithCompletion:^(NSDictionary *data, NSError *error) {
        
        [self.refreshControl endRefreshing];
        
        if (error) {
            [[[UIAlertView alloc] initWithTitle:@"Error logging in" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
        } else {
            //NSLog(@"data: %@", data);
            if (data[@"totalPortfolio"]) [self fillTotals:data[@"totalPortfolio"]];
            if (data[@"portfolio"]) [self fillPortfolio:data[@"portfolio"]];
        }
    }];
}

- (void)fillTotals:(NSDictionary *)totals {
    float totalInvested = 0.0;
    float totalEarnings = 0.0;
    float dayEarnings = 0.0;
    
    for (NSDictionary *data in totals[@"value"]) {
        if ([data[@"name"] isEqualToString:@"pl"]) {
            NSString *val = data[@"value"];
            totalEarnings = val.floatValue;
        }
        if ([data[@"name"] isEqualToString:@"plToday"]) {
            NSString *val = data[@"value"];
            dayEarnings = val.floatValue;
        }
        if ([data[@"name"] isEqualToString:@"total"]) {
            NSString *val = data[@"value"];
            totalInvested = val.floatValue;
        }
    }
    
    self.inLabel.text = [NSString stringWithFormat:@"%.2f", totalInvested];
    
    float roi = totalEarnings / totalInvested;
    
    self.totalLabel.text = [NSString stringWithFormat:@"%.2f", totalEarnings];
    //self.totalLabel.textColor = (totalEarnings > 0) ? [UIColor greenColor] : [UIColor redColor];
    
    self.totalDayLabel.text = [NSString stringWithFormat:@"%.2f", dayEarnings];
    //self.totalDayLabel.textColor = (dayEarnings > 0) ? [UIColor greenColor] : [UIColor redColor];
    
    self.roiLabel.text = [NSString stringWithFormat:@"%.2f %%", (roi*100)];
    //self.roiLabel.textColor = (roi > 0) ? [UIColor greenColor] : [UIColor redColor];
    
}

- (void)fillPortfolio:(NSDictionary *)portfolio {
    
    NSString *baseCurrency = [DeGiro shared].baseCurrency;
    
    self.assets = [NSMutableArray array];
    
    
    for (NSDictionary *dataType in portfolio[@"value"]) {
        NSString *title = [dataType[@"title"] componentsSeparatedByString:@"."][1];
        
        
        NSMutableArray *items = [NSMutableArray array];
        
        for (NSDictionary *data in dataType[@"value"]) {
            if ([data[@"name"] isEqualToString:@"positionrow"]) {
                NSMutableDictionary *row = [NSMutableDictionary dictionary];
                
                for (NSDictionary *column in data[@"value"]) {
                    if ([column[@"name"] isEqualToString:@"product"]) {
                        row[@"name"] = column[@"value"];
                    }
                    if ([column[@"name"] isEqualToString:@"size"]) {
                        row[@"amount"] = column[@"value"];
                    }
                    
                    //currency
                    if ([column[@"name"] isEqualToString:@"currency"]) {
                        row[@"currency"] = column[@"value"];
                    }
                    
                    // price per stock
                    if ([column[@"name"] isEqualToString:@"price"]) {
                        row[@"price"] = column[@"value"];
                    }
                    
                    // price total
                    if ([column[@"name"] isEqualToString:@"value"]) {
                        row[@"value"] = column[@"value"];
                    }
                    
                    //
                    if ([column[@"name"] isEqualToString:@"plBase"]) {
                        row[@"plBase"] = column[@"value"][baseCurrency];
                    }
                    
                    if ([column[@"name"] isEqualToString:@"todayPlBase"]) {
                        row[@"todayPlBase"] = column[@"value"][baseCurrency];
                    }
                }
                
                float rate = 1;
                
                if (![row[@"currency"] isEqualToString:baseCurrency]) {
                    NSString *curr = [baseCurrency stringByAppendingString:row[@"currency"]];
                    rate = [[DeGiro shared].currencyRates[curr] floatValue];
                }
                
                row[@"gain"] = @([row[@"plBase"] floatValue] + [row[@"value"] floatValue] / rate);
                
                [items addObject:row];
            }
        }
        
        
        [self.assets addObject:@{
                                 @"title": title,
                                 @"items": items
                                 }];
    }
    
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.assets.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *items = self.assets[section][@"items"];
    return items.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.assets[section][@"title"];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AssetCell" forIndexPath:indexPath];
    
    if (!cell.accessoryView) {
        UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 90, 30)];
        l.textAlignment = NSTextAlignmentRight;
        cell.accessoryView = l;
    }
    
    UILabel *gainLabel = (id)cell.accessoryView;
    
    // Configure the cell...
    NSDictionary *item = self.assets[indexPath.section][@"items"][indexPath.row];
    
    cell.textLabel.text = item[@"name"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%i @ %.2f", (int)[item[@"amount"] integerValue], [item[@"price"] floatValue]];
    
    float gain = [item[@"gain"] floatValue];
    gainLabel.text = [NSString stringWithFormat:@"%.2f", gain];
    gainLabel.textColor = (gain > 0) ? [UIColor greenColor] : [UIColor redColor];
    
    
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
