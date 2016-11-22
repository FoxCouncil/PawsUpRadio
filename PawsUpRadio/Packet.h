//
//  Packet.h
//  PawsUpRadio
//
//  Created by Fox on 2014-09-28.
//  Copyright (c) 2014 Fox Council. All rights reserved.
//

#ifndef PawsUpRadio_Packet_h
#define PawsUpRadio_Packet_h

#import <UIKit/UIKit.h>
#include <AudioToolbox/AudioToolbox.h>

@interface Packet : NSObject

@property (nonatomic, strong) NSData *audioData;
@property (nonatomic, assign) AudioStreamPacketDescription audioDescription;

@end

#endif
