//
//  ViewController.h
//  PawsUpRadio
//
//  Created by Fox on 2014-09-19.
//  Copyright (c) 2014 Fox Council. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MPAdView.h"
#import "Radio.h"

@interface PlayerViewController : UIViewController <RadioDelegate, MPAdViewDelegate>

@property (atomic, strong) Radio* radio;

@property (nonatomic, retain) MPAdView* adView;

@property (nonatomic, weak) IBOutlet UIImageView* backgroundImageView;

FOUNDATION_EXPORT NSString *const kPurRadioUrlConstant;

- (void)doBackground;

@end



