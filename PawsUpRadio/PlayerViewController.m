//
//  ViewController.m
//  PawsUpRadio
//
//  Created by Fox on 2014-09-19.
//  Copyright (c) 2014 Fox Council. All rights reserved.
//

#import <MediaPlayer/MediaPlayer.h>
#import <MediaPlayer/MPNowPlayingInfoCenter.h>

#import "PlayerViewController.h"
#import "Reachability.h"

#import "secret.h"

@interface PlayerViewController ()

@property (nonatomic, weak) IBOutlet UILabel* stationNameLabel;
@property (nonatomic, weak) IBOutlet UILabel* songInfoLabel;

@property (nonatomic, weak) IBOutlet UIButton* playPauseButton;

@property (nonatomic, weak) IBOutlet NSLayoutConstraint* songTitleLeftContraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint* songTitleRightContraint;

@property (nonatomic, retain) MPMediaItemArtwork* albumArt;

@property (nonatomic) Reachability *purReachability;

@end

@implementation PlayerViewController

#pragma mark - UIViewContoller Handlers

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.albumArt = [[MPMediaItemArtwork alloc] initWithImage: [UIImage imageNamed:@"iTunesArtwork"]];
    
    [self setNowPlayingData:@"Paws Up Radio" forKey:MPMediaItemPropertyTitle];
    
    /*
     Observe the kNetworkReachabilityChangedNotification. When that notification is posted, the method reachabilityChanged will be called.
     */
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
    
    self.purReachability = [Reachability reachabilityWithHostName:kPurRadioUrlConstant];
    [self.purReachability startNotifier];
    [self updatePurReachability:self.purReachability];
    
    // Do Background Image Stuff
    [self initBackground];
    [self doBackground];
    
    self.radio = [[Radio alloc] init]; // Set User-Agent
    self.radio.delegate = self;
    self.radio.url = [NSURL URLWithString:kPurRadioPlayerUrl];
    
    self.adView = [[MPAdView alloc] initWithAdUnitId:kPurMainAdUnitId size:MOPUB_BANNER_SIZE];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self showBannerAds];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self hideBannerAds];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

#pragma mark - MoPub Ad Controllers

- (void)showBannerAds
{
    self.adView.delegate = self;
    [self.view addSubview:self.adView];
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
    
    CGFloat centeredX = (self.view.bounds.size.width - size.width) / 2;
    CGFloat bottomAlignedY = self.view.bounds.size.height - 49 - size.height;
    
    view.frame = CGRectMake(centeredX, bottomAlignedY, size.width, size.height);
}

#pragma mark - System Event Handlers

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Reachability Methods

/*!
 * Called by Reachability whenever status changes.
 */
- (void) reachabilityChanged:(NSNotification *)note
{
    Reachability* curReach = [note object];
    NSParameterAssert([curReach isKindOfClass:[Reachability class]]);
    [self updatePurReachability:curReach];
}

- (void)updatePurReachability:(Reachability *)reachability
{
    NetworkStatus netStatus = [reachability currentReachabilityStatus];

    switch (netStatus)
    {
        case NotReachable:
        {
            [self setStationName:@"NO NETWORK DETECTED"];
            
            if ([self.radio isPlaying])
            {
                [self.radio togglePlayStop];
            }
        }
        break;
        
        case ReachableViaWWAN:
        case ReachableViaWiFi:
        {
            // NSLog(@"reconnectOnWiFi = %@", [[NSUserDefaults standardUserDefaults] objectForKey:@"ReconnectOnWiFi"]);
            
            BOOL reconnectOnWiFi = [[NSUserDefaults standardUserDefaults] boolForKey:@"ReconnectOnWiFi"];
            
            if (self.radio.isPlaying && netStatus == ReachableViaWiFi && reconnectOnWiFi)
            {
                [self.radio togglePlayStop];
                [self.radio togglePlayStop];
            }
            
            [self setStationName:@""];
        }
        break;
    }
}

#pragma mark - Visual Methods

- (void)initBackground
{
    // Set vertical effect
    UIInterpolatingMotionEffect *verticalMotionEffect = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.y" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
    verticalMotionEffect.minimumRelativeValue = @(-10);
    verticalMotionEffect.maximumRelativeValue = @(10);
    
    // Set horizontal effect
    UIInterpolatingMotionEffect *horizontalMotionEffect = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.x" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
    horizontalMotionEffect.minimumRelativeValue = @(-10);
    horizontalMotionEffect.maximumRelativeValue = @(10);
    
    // Create group to combine both
    UIMotionEffectGroup *group = [UIMotionEffectGroup new];
    group.motionEffects = @[horizontalMotionEffect, verticalMotionEffect];
    
    [self.backgroundImageView addMotionEffect:group];
}

- (void)doBackground
{
    NSString* customBackgroundPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"background.png"];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:customBackgroundPath])
    {
        self.backgroundImageView.image = [UIImage imageWithContentsOfFile:customBackgroundPath];
    }
    else
    {
        self.backgroundImageView.image = [UIImage imageNamed:@"bg1"];
    }
}

- (void)setStationName:(NSString*)stationTitle
{
    if ([self.stationNameLabel.text isEqual:stationTitle] && self.stationNameLabel.alpha != 0.0f)
    {
        return;
    }
    else if ([stationTitle isEqual:@""])
    {
        [UIView animateWithDuration:0.2f animations:^{
            self.stationNameLabel.alpha = 0.0f;
        }];
    }
    else if ([self.stationNameLabel.text isEqual:@""])
    {
        self.stationNameLabel.alpha = 0.0f;
        self.stationNameLabel.text = stationTitle;
        
        [UIView animateWithDuration:0.2f animations:^{
            self.stationNameLabel.alpha = 1.0f;
        }];
    }
    else
    {
        [UIView animateWithDuration:0.2f animations:^{
            self.stationNameLabel.alpha = 0.0f;
        } completion:^(BOOL finished) {
            self.stationNameLabel.text = stationTitle;
            
            [UIView animateWithDuration:0.2f animations:^{
                self.stationNameLabel.alpha = 1.0f;
            }];
        }];
    }
}

- (void)setSongTitle:(NSString*)songTitle
{
    if ([self.songInfoLabel.text isEqual:songTitle])
    {
        // Not
        return;
    }
    
    if ([self.songInfoLabel.text isEqual:@""] || [self.songInfoLabel.text isEqual:@"Connecting..."])
    {
        [UIView animateWithDuration:0.2f animations:^{
            self.songInfoLabel.alpha = 0.0f;
        } completion:^(BOOL finished) {
            
            self.songTitleRightContraint.constant = -610;
            self.songTitleLeftContraint.constant = -600;
            
            [self.view layoutIfNeeded];
            
            self.songInfoLabel.alpha = 1.0f;
            
            self.songInfoLabel.text = songTitle;
            
            [UIView animateWithDuration:0.2f animations:^{
                self.songTitleLeftContraint.constant = -10;
                self.songTitleRightContraint.constant = 10;
                
                [self.view layoutIfNeeded];
            }];
        }];
    }
    else
    {
        [self.view layoutIfNeeded];
        
        [UIView animateWithDuration:0.2f animations:^{
            
            self.songTitleLeftContraint.constant = 610;
            self.songTitleRightContraint.constant = 610;
            
            [self.view layoutIfNeeded];
            
        } completion:^(BOOL finished) {
            
            self.songTitleRightContraint.constant = -610;
            self.songTitleLeftContraint.constant = -600;
            
            [self.view layoutIfNeeded];
            
            self.songInfoLabel.text = songTitle;
            
            [UIView animateWithDuration:0.2f animations:^{
                self.songTitleLeftContraint.constant = -10;
                self.songTitleRightContraint.constant = 10;
                
                [self.view layoutIfNeeded];
            }];
        }];
    }
}

- (void)disablePlayPauseButton
{
    self.playPauseButton.enabled = NO;
    
    [UIView animateWithDuration:0.2 animations:^{
        self.playPauseButton.alpha = 0.3;
    }];
}

- (void)enablePlayPauseButton
{
    self.playPauseButton.enabled = YES;
    
    [UIView animateWithDuration:0.2 animations:^{
        self.playPauseButton.alpha = 0.9;
    }];
}

#pragma mark - Touch Event Handlers

- (IBAction)playPauseButtonTouched:(id)sender
{
    [self.radio togglePlayStop];
}

#pragma mark - Radio Delegate Handlers


- (void)interruptRadio {
    // NSLog(@"delegate radio interrupted");
}

- (void)resumeInterruptedRadio {
    // NSLog(@"delegate resume interrupted radio");
}

- (void)networkChanged {
    // NSLog(@"delegate network changed");
}

- (void)connectProblem {
    // NSLog(@"delegate connection problem");
}

- (void)audioUnplugged {
    // NSLog(@"delegate audio unplugged");
}

- (void)playingStateChange
{
    if ([self.radio isPlaying])
    {
        [self enablePlayPauseButton];
        [self.playPauseButton setImage:[UIImage imageNamed:@"StopBTN"] forState:UIControlStateNormal];
    }
    else if ([self.radio isBuffering])
    {
        [self disablePlayPauseButton];
        self.songInfoLabel.text = @"Connecting...";
        [self.playPauseButton setImage:[UIImage imageNamed:@"StopBTN"] forState:UIControlStateNormal];
    }
    else
    {
        if (![self.radio isError])
        {
            [self setStationName:@""];
            [self setSongTitle:@""];
        }
        
        [self setNowPlayingArray:@{
                                   MPMediaItemPropertyTitle: @"Paws Up Radio",
                                   MPMediaItemPropertyArtist: @"",
                                   MPMediaItemPropertyArtwork: self.albumArt
                                   }
         ];
        
        [self enablePlayPauseButton];
        [self.playPauseButton setImage:[UIImage imageNamed:@"PlayBTN"] forState:UIControlStateNormal];
    }

    [[NSUserDefaults standardUserDefaults] setInteger:[[NSUserDefaults standardUserDefaults] integerForKey:@"TotalLifetimeBytes"] + self.radio.totalBytes forKey:@"TotalLifetimeBytes"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)updateStreamName:(NSString *)name
{
    [self setStationName:name];
    [self setNowPlayingData:[NSString stringWithFormat:@"Paws Up Radio - %@", name] forKey:MPMediaItemPropertyTitle];
}

- (void)updateStreamTitle:(NSString *)title
{
    [self setSongTitle:title];
    [self setNowPlayingData:title forKey:MPMediaItemPropertyArtist];
}

#pragma mark - Now Playing Method

- (void)setNowPlayingData:(id)text forKey:(id)key
{
    Class playingInfoCenter = NSClassFromString(@"MPNowPlayingInfoCenter");
    
    if (playingInfoCenter)
    {
        NSMutableDictionary *songInfo = [[[MPNowPlayingInfoCenter defaultCenter] nowPlayingInfo] mutableCopy];
        
        if (songInfo == nil)
        {
            songInfo = [[NSMutableDictionary alloc] init];
        }
        
        if ([songInfo valueForKey:MPMediaItemPropertyArtwork] == nil)
        {
            [songInfo setObject:self.albumArt forKey:MPMediaItemPropertyArtwork];
        }
        
        [songInfo setObject:text forKey:key];
        
        [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:songInfo];
    }
}

- (void)setNowPlayingArray:(NSDictionary*)array
{
    Class playingInfoCenter = NSClassFromString(@"MPNowPlayingInfoCenter");
    
    if (playingInfoCenter)
    {
        [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:array];
    }
}


@end
