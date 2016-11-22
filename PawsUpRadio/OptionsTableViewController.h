//
//  OptionsTableViewController.h
//  PawsUpRadio
//
//  Created by Fox on 2014-09-23.
//  Copyright (c) 2014 Fox Council. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MPAdView.h"
#import "PlayerViewController.h"

@interface OptionsTableViewController : UITableViewController <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIAlertViewDelegate, MPAdViewDelegate>
{
    NSTimer* timer;
    PlayerViewController* playerViewContoller;
    NSUserDefaults* userDefaults;
}

@property (nonatomic, weak) IBOutlet UILabel* backgroundButtonLabel;
@property (nonatomic, weak) IBOutlet UIView* adViewFrame;

@property (nonatomic, retain) MPAdView* adView;

@end


