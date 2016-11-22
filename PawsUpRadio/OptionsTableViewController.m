//
//  OptionsTableViewController.m
//  PawsUpRadio
//
//  Created by Fox on 2014-09-23.
//  Copyright (c) 2014 Fox Council. All rights reserved.
//

#import "OptionsTableViewController.h"
#import "secret.h"

@interface OptionsTableViewController ()

@property (nonatomic, weak) IBOutlet UISwitch* reconnectOnWiFiSwitch;
@property (nonatomic) UIImagePickerController* imagePicker;

@property (nonatomic, weak) IBOutlet UILabel* currentBytesLabel;
@property (nonatomic, weak) IBOutlet UILabel* lifetimeBytesLabel;

@end

@implementation OptionsTableViewController

#pragma mark - UIViewController Handlers

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        [[UITableViewCell appearance] setBackgroundColor:[UIColor clearColor]];
    }
    
    if (playerViewContoller == nil)
    {
        playerViewContoller = (PlayerViewController*)[[self.tabBarController viewControllers] objectAtIndex:0];
    }
    
    if (userDefaults == nil)
    {
        userDefaults = [NSUserDefaults standardUserDefaults];
    }
    
    self.imagePicker = [[UIImagePickerController alloc] init];
    self.imagePicker.delegate = self;
    self.imagePicker.allowsEditing = NO;
    self.imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    
    [self checkBackgroundLabelState];
    
    self.adView = [[MPAdView alloc] initWithAdUnitId:kPurSettingsAdUnitId size:MOPUB_BANNER_SIZE];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self timerTick:nil];
    
    if (timer == nil)
    {
        timer = [NSTimer scheduledTimerWithTimeInterval:0.5f target:self selector:@selector(timerTick:) userInfo:nil repeats:YES];
    }
    
    [self showBannerAds];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self hideBannerAds];
    
    if ([timer isValid])
    {
        [timer invalidate];
    }
    
    timer = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

#pragma mark - MoPub Ad Controllers

- (void)showBannerAds
{
    self.adView.delegate = self;
    [self.adViewFrame addSubview:self.adView];
    [self.adView loadAd];
}

- (void)hideBannerAds
{
    [self.adView removeFromSuperview];
    self.adView.delegate = nil;
}

#pragma mark - MPAdViewDelegate

- (UIViewController *)viewControllerForPresentingModalView
{
    return self;
}

- (void)adViewDidLoadAd:(MPAdView *)view
{
    CGSize size = [view adContentViewSize];
    
    CGFloat centeredX = (self.adViewFrame.bounds.size.width - size.width) / 2;
    
    view.frame = CGRectMake(centeredX, 0, size.width, size.height);
}

#pragma mark - UITableViewContoller Handlers

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0 && indexPath.row == 0)
    {
        return 50;
    }
    else if (indexPath.section == 1 && indexPath.row == 0)
    {
        return 79;
    }
    else
    {
        return 44;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 2 && indexPath.row == 0)
    {
        NSString* customBackgroundPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"background.png"];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:customBackgroundPath])
        {
            NSError *error;
            [[NSFileManager defaultManager] removeItemAtPath:customBackgroundPath error:&error];
            
            [playerViewContoller doBackground];
            
            [self checkBackgroundLabelState];
            
            [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
        }
        else
        {
            [self presentViewController:self.imagePicker animated:YES completion:NULL];
        }
    }
    else if (indexPath.section == 3 && indexPath.row == 2)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Warning" message:@"Are you sure you want to reset your transfer statistics?" delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
        
        [alert show];
        
        [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
    }
    else
    {
        NSLog(@"%ld, %ld", (long)indexPath.section, (long)indexPath.row);
    }
}

#pragma mark - UI Event Handlers

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex)
    {
        [userDefaults setInteger:0 forKey:@"TotalLifetimeBytes"];
        [userDefaults synchronize];
        playerViewContoller.radio.totalBytes = 0;
    }
}

- (IBAction)reconnectOnWiFiSwitchAction:(id)sender
{
    [userDefaults setBool:self.reconnectOnWiFiSwitch.on forKey:@"ReconnectOnWiFi"];
    [userDefaults synchronize];
}


// This method is called when an image has been chosen from the library or taken from the camera.
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    NSData* imageData = UIImagePNGRepresentation([info valueForKey:UIImagePickerControllerOriginalImage]);
    
    [imageData writeToFile:[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"background.png"] atomically:NO];
    
    [self checkBackgroundLabelState];
    
    [playerViewContoller doBackground];
    
    [self dismissViewControllerAnimated:YES completion:NULL];
    
    [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
    
    UITabBarController* parentView = (UITabBarController*)self.parentViewController;
    parentView.selectedIndex = 0;
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:NULL];
    
    [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
}

#pragma mark - NSTimer Tick Handler

- (void)timerTick:(NSTimer *)timer
{
    NSInteger sessionBytes = playerViewContoller.radio.totalBytes;
    NSInteger totalLifetimeBytes = [userDefaults integerForKey:@"TotalLifetimeBytes"] + sessionBytes;

    self.currentBytesLabel.text = [self transformBytesToHumanReadable:sessionBytes];
    self.lifetimeBytesLabel.text = [self transformBytesToHumanReadable:totalLifetimeBytes];
}

#pragma mark - Custom View Methods

- (void)checkBackgroundLabelState
{
    NSString* customBackgroundPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"background.png"];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:customBackgroundPath])
    {
        self.backgroundButtonLabel.text = @"Clear Background Image";
    }
    else
    {
        self.backgroundButtonLabel.text = @"Select Background Image";
    }
}

- (id)transformBytesToHumanReadable:(NSInteger)value;
{
    double convertedValue = (double)value;
    int multiplyFactor = 0;
    
    NSArray *tokens = [NSArray arrayWithObjects:@"B",@"KB",@"MB",@"GB",@"TB",nil];
    
    while (convertedValue > 1024) {
        convertedValue /= 1024;
        multiplyFactor++;
    }
    
    return [NSString stringWithFormat:@"%4.2f %@", convertedValue, [tokens objectAtIndex:multiplyFactor]];
}

@end
