//
//  Radio.h
//  PawsUpRadio
//
//  Created by Fox on 2014-09-28.
//  Copyright (c) 2014 Fox Council. All rights reserved.
//

#ifndef PawsUpRadio_Radio_h
#define PawsUpRadio_Radio_h
#endif

#import <UIKit/UIKit.h>
#include <AudioToolbox/AudioToolbox.h>
#include <AudioToolbox/AudioFileStream.h>
#include <AudioToolbox/AudioServices.h>
#include "Queue.h"
#include "Packet.h"
#import <AVFoundation/AVFoundation.h>


@protocol RadioDelegate

@optional

- (void)playingStateChange;

- (void)interruptRadio;
- (void)resumeInterruptedRadio;
- (void)networkChanged;
- (void)connectProblem;
- (void)audioUnplugged;

- (void)updateStreamName:(NSString *)name;
- (void)updateStreamTitle:(NSString *)title;


@end

@interface Radio : NSObject {
    
    AudioFileStreamID             audioStreamID;
    AudioStreamBasicDescription   audioDataFormat;
    AudioQueueRef                 audioQueue;
    NSMutableData*                currentAudio;
    AudioQueueBufferRef           audioBuffers[6];
    BOOL						  audioStarted;
    Queue*                        packetQueue;
    int							  audioTotalBytes;
    AudioStreamPacketDescription  audioDescriptions[512];
    AudioQueueBufferRef			  audioFreeBuffers[6];
    float						  audioCurrentGain;
    int							  audioOutOfBuffers;
    
    NSURLConnection* conn;
    NSMutableData* currentPacket;
    NSMutableData* metaDataBuffer;    
    NSDictionary* streamHeaders;
    
    int icyInterval;
    int metaLength;
    int streamCount;
}

#pragma mark - Public Properties

@property (nonatomic, weak) NSObject<RadioDelegate>* delegate;

@property (nonatomic, strong) NSURL* url;
@property (nonatomic, strong) NSString* userAgent;
@property (nonatomic, strong) NSMutableDictionary* metaData;

@property (atomic) NSInteger totalBytes;

@property (atomic) BOOL isPlaying;
@property (atomic) BOOL isBuffering;
@property (atomic) BOOL isError;
@property (atomic) BOOL isInterrupted;

#pragma mark - Init Method

- (id)init;

#pragma mark - Playback Control Method

- (void)togglePlayStop;

#pragma mark - Blearg

- (void)networkChanged;

- (void)audioUnplugged;

@end