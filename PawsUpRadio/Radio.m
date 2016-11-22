//
//  Radio.m
//  PawsUpRadio
//
//  Created by Fox on 2014-09-28.
//  Copyright (c) 2014 Fox Council. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Radio.h"

@implementation Radio

#pragma mark - Sexy Defines

#define DEBUG_LOG 0
#define VERBOSE_LOG 0
#define VERBOSE_BUF 0

#define kPacketSize 8000
#define kAudioBufferSize 8000
#define kNumberBuffers 6
#define kMaxOutOfBuffers 36

#pragma mark - Init Methods

- (id)init
{
    self = [super init];
    
    if (self != nil)
    {
        // Basic Setup
        currentPacket   = [[NSMutableData alloc] init];
        metaDataBuffer  = [[NSMutableData alloc] init];
        currentAudio    = [[NSMutableData alloc] init];
        
        self.metaData = [NSMutableDictionary dictionary];
        
        self.isPlaying = NO;
        self.userAgent = @"PawsUpRadio-iOS-2.5";
    
        // iOS Hardware/Software Audio Events
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleInterruption:) name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleRouteChange:) name:AVAudioSessionRouteChangeNotification object:[AVAudioSession sharedInstance]];
    }
    
    return self;
}

#pragma mark - Playback Control Method

- (void)togglePlayStop
{
    if (self.isPlaying)
    {
        [self stop];
    }
    else
    {
        [self start];
    }
}

#pragma mark - Private Methods

- (void)start
{
    if (self.isPlaying)
    {
        // NSLog(@"Start while started!");
        [self stop];
    }
    
    if (DEBUG_LOG)
    {
        NSLog(@"Start Called");
    }
    
    [currentPacket setLength:0];
    [metaDataBuffer setLength:0];
    [currentAudio setLength:0];
    
    streamCount = 0;
    icyInterval = 0;
    packetQueue = [[Queue alloc] init];
    
    audioTotalBytes = 0;
    audioCurrentGain = 1.0;
    
    AudioFileStreamOpen((__bridge void *)(self),  &PropertyListener, &PacketsProc, kAudioFileMP3Type, &audioStreamID);
    
    NSError *audio_error;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:0 error:&audio_error];
    
    if (conn)
    {
        [conn cancel];
    }
    
    if (DEBUG_LOG)
    {
        NSLog(@"connecting to url %@", self.url);
    }
    
    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:self.url];
    
    [req setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    [req setValue:@"1" forHTTPHeaderField:@"icy-metadata"];
    [req setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];
    [req setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];
    [req setTimeoutInterval:10];
    
    conn = [NSURLConnection connectionWithRequest:req delegate:self];
    
    self.isBuffering = YES;
    self.isPlaying = NO;
    self.isError = NO;
    self.isInterrupted = NO;
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(playingStateChange)])
    {
        [self.delegate playingStateChange];
    }
}

- (void)stop
{
    if (DEBUG_LOG)
    {
        NSLog(@"Stop Called");
    }
    
    self.isPlaying = NO;
    self.isBuffering = NO;
    self.isInterrupted = NO;
    
    Queue *queue = packetQueue;
    
    @synchronized (queue)
    {
        [conn cancel];
        conn = nil;
        
        AudioFileStreamClose(audioStreamID);
        
        AudioQueueStop(audioQueue, YES);
        AudioQueueReset(audioQueue);
            
        for (int i = 0; i < kNumberBuffers; ++i)
        {
            if (audioBuffers[i])
            {
                AudioQueueFreeBuffer(audioQueue, audioBuffers[i]);
            }
        }
            
        AudioQueueDispose(audioQueue, YES);
        
        Packet *packet = [queue returnAndRemoveOldest];
        
        while (packet)
        {
            packet = [queue returnAndRemoveOldest];
        }
        
        for (int i = 0; i < kNumberBuffers; i++)
        {
            audioFreeBuffers[i] = nil;
        }
        
        NSError* audio_error;
        
        [[AVAudioSession sharedInstance] setActive:NO error:&audio_error];
        
        audioStarted = NO;
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(playingStateChange)])
    {
        [self.delegate playingStateChange];
    }
    
    self.totalBytes = 0;
}

- (void)processMetaData:(NSString *)data
{
    for (NSString *pairString in [data componentsSeparatedByString:@";"])
    {
        NSArray *pair = [pairString componentsSeparatedByString:@"="];
        
        if ([pair count] != 2)
        {
            continue;
        }
        
        NSString *parsedString = [[pair objectAtIndex:1] substringFromIndex:1];
        
        [self.metaData setObject:[parsedString substringToIndex:[parsedString length] - 1] forKey:[pair objectAtIndex:0]];
        
        if ([[pair objectAtIndex:0] isEqualToString:@"StreamName"] && self.delegate && [self.delegate respondsToSelector:@selector(updateStreamName:)])
        {
            [self.delegate updateStreamName:[parsedString substringToIndex:[parsedString length] - 1]];
        }
        else if ([[pair objectAtIndex:0] isEqualToString:@"StreamTitle"] && self.delegate && [self.delegate respondsToSelector:@selector(updateStreamTitle:)])
        {
            [self.delegate updateStreamTitle:[parsedString substringToIndex:[parsedString length] - 1]];
        }
    }
}

#pragma mark - NSURLConnection Handlers

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse *u = (NSHTTPURLResponse *)response;
    
    if (DEBUG_LOG)
    {
        NSLog(@"HTTP response =  %d", (int)[u statusCode]);
    }
    
    streamHeaders = [u allHeaderFields];
    
    if (DEBUG_LOG)
    {
        NSLog(@"HTTP response Headers = %@", streamHeaders);
    }
    
    NSString* stationName = [streamHeaders objectForKey:@"icy-name"];
    
    if (stationName != nil)
    {
        [self processMetaData:[NSString stringWithFormat:@"StreamName='%@';", stationName]];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (VERBOSE_LOG)
    {
        NSLog(@"didReceiveData %d bytes", (int)[data length]);
    }
    
    NSInteger length = [data length];
    
    self.totalBytes += length;
    
    const char *bytes = (const char *)[data bytes];
    
    if (!icyInterval)
    {
        icyInterval = [[streamHeaders objectForKey:@"Icy-Metaint"] intValue];
        
        if (DEBUG_LOG)
        {
            NSLog(@"Icy interval = %u", icyInterval);
        }
    }
    
    [self fillcurrentPacket:bytes withLength:length];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if (DEBUG_LOG)
    {
        NSLog(@"didFailWithError %@", error);
    }
    
    if (self.isPlaying)
    {
        // Auto-Retry?
        // [self start];
    }
    else
    {
        if (DEBUG_LOG)
        {
            NSLog(@"didFailWithError: Already Stopped!");
        }
    }
    
    self.isError = YES;
    self.isBuffering = NO;
    self.isPlaying = NO;
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(playingStateChange)])
    {
        [self.delegate playingStateChange];
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(updateStreamTitle:)])
    {
        [self.delegate updateStreamTitle:[error localizedDescription]];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (DEBUG_LOG)
    {
        NSLog(@"connectionDidFinishLoading");
    }
    
    if (self.isPlaying)
    {
        self.isError = YES;
        self.isBuffering = NO;
        self.isPlaying = NO;
        
        [self stop];
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(playingStateChange)])
        {
            [self.delegate playingStateChange];
        }
    }
}

#pragma mark - core audio processing

static void audioQueueCallBack(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer)
{
    @autoreleasepool
    {
        Radio *streamer = (__bridge Radio *)inUserData;
        
        [streamer handleAudioQueueCallBack:inAQ withBuffer:inBuffer];
    }
}

- (void)handleAudioQueueCallBack:(AudioQueueRef)inAQ withBuffer:(AudioQueueBufferRef)inBuffer
{
    if (!self.isPlaying)
    {
        if (DEBUG_LOG)
        {
            NSLog(@"audioQueueCallBack returning, not playing!");
        }
        
        return;
    }
    
    Queue *queue = packetQueue;
    int numDescriptions = 0;
    inBuffer->mAudioDataByteSize = 0;
    
    @synchronized (packetQueue)
    {
        if (VERBOSE_BUF)
        {
            NSLog(@"queue.size == %ld packets", (long)queue.size);
        }
        
        if (queue.size == 0)
        {
            audioOutOfBuffers++;
        }
        
        while ([queue peak])
        {
            Packet *packet = [queue peak];
            
            NSData *data = [packet audioData];
            
            if ([data length]+inBuffer->mAudioDataByteSize < kAudioBufferSize)
            {
                packet = [queue returnAndRemoveOldest];
                
                memcpy((char*)inBuffer->mAudioData+inBuffer->mAudioDataByteSize, (const char*)[data bytes], [data length]);
                
                audioDescriptions[numDescriptions] = [packet audioDescription];
                audioDescriptions[numDescriptions].mStartOffset = inBuffer->mAudioDataByteSize;
                
                inBuffer->mAudioDataByteSize += [data length];
                
                numDescriptions++;
            }
            else
            {
                if (VERBOSE_LOG)
                {
                    NSLog(@"audioQueueCallBack %d bytes, %d bytes", (int)[data length], (int)inBuffer->mAudioDataByteSize);
                }
                
                break;
            }
        }
        
        if (inBuffer->mAudioDataByteSize > 0)
        {
            if (VERBOSE_BUF)
            {
                NSLog(@"inBuffer->mAudioDataByteSize == %d bytes", (int)inBuffer->mAudioDataByteSize);
            }
            
            if (VERBOSE_LOG)
            {
                NSLog(@"AudioQueueEnqueueBuffer %d bytes, %d descriptions", (int)inBuffer->mAudioDataByteSize, numDescriptions);
            }
            
            AudioQueueEnqueueBuffer(inAQ, inBuffer, numDescriptions, audioDescriptions);
            
            self.isBuffering = NO;
            
            if (audioOutOfBuffers > 0)
            {
                audioOutOfBuffers--;
            }
        }
        else if (inBuffer->mAudioDataByteSize == 0)
        {
            if (VERBOSE_BUF)
            {
                NSLog(@"inBuffer->mAudioDataByteSize == 0");
            }
            
            for (int i = 0; i < kNumberBuffers; i++)
            {
                if (!audioFreeBuffers[i])
                {
                    audioFreeBuffers[i] = inBuffer;
                    break;
                }
            }
            
            audioOutOfBuffers++;
            
            if (DEBUG_LOG)
            {
                NSLog(@"out of Buffers: %d", audioOutOfBuffers);
            }
        }
    }
}

static void PropertyListener(void *inClientData, AudioFileStreamID inAudioFileStream, AudioFileStreamPropertyID inPropertyID, UInt32 *ioFlags)
{
    Radio *streamer = (__bridge Radio *)inClientData;
    
    [streamer handlePropertlyListener:inAudioFileStream fileStreamPropertyID:inPropertyID ioFlags:ioFlags];
}

- (void)handlePropertlyListener:(AudioFileStreamID)inAudioFileStream fileStreamPropertyID:(AudioFileStreamPropertyID)inPropertyID ioFlags:(UInt32 *)ioFlags
{
    OSStatus err = noErr;

    if (inPropertyID == kAudioFileStreamProperty_ReadyToProducePackets)
    {
        NSError *audio_error;
        
        [[AVAudioSession sharedInstance] setActive:YES error:&audio_error];
        
        AudioStreamBasicDescription asbd;
        UInt32 asbdSize = sizeof(asbd);
        AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataFormat, &asbdSize, &asbd);
        AudioQueueNewOutput(&asbd, audioQueueCallBack, (__bridge void *)(self), NULL, NULL, 0, &audioQueue);
        
        for (int i = 0; i < kNumberBuffers; ++i)
        {
            AudioQueueAllocateBuffer(audioQueue, kAudioBufferSize, &audioBuffers[i]);
        }
        
        // get magic cookie
        UInt32 cookieSize;
        Boolean writable;
        
        err = AudioFileStreamGetPropertyInfo(inAudioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, &writable);
        
        if (err)
        {
            return;
        }
        
        void *cookieData = calloc(1, cookieSize);
        
        AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, cookieData);
        AudioQueueSetProperty(audioQueue, kAudioQueueProperty_MagicCookie, cookieData, cookieSize);
    }
}

static void PacketsProc(void *inClientData, UInt32 inNumberBytes, UInt32 inNumberPackets, const void *inInputData, AudioStreamPacketDescription *inPacketDescriptions)
{
    Radio *streamer = (__bridge Radio *)inClientData;
    [streamer handlePacketsProc:inInputData numberBytes:inNumberBytes numberPackets:inNumberPackets packetDescriptions:inPacketDescriptions];
    
    if (VERBOSE_LOG)
    {
        NSLog(@"processing packets %d bytes", (int)inNumberBytes);
    }
}

- (void)handlePacketsProc:(const void *)inInputData numberBytes:(UInt32)inNumberBytes numberPackets:(UInt32)inNumberPackets packetDescriptions:(AudioStreamPacketDescription *)inPacketDescriptions
{
    for (int i = 0; i < inNumberPackets; ++i)
    {
        Packet *packet = [[Packet alloc] init];
        
        AudioStreamPacketDescription description = inPacketDescriptions[i];
        
        [packet setAudioDescription:description];
        [packet setAudioData: [[NSData alloc] initWithBytes:(const char*)inInputData+description.mStartOffset length:description.mDataByteSize]];
        
        @synchronized (packetQueue)
        {
            [packetQueue addItem:packet];
        }
        
        audioTotalBytes += description.mDataByteSize;
    }
    
    if (!audioStarted && audioTotalBytes >= kNumberBuffers* kAudioBufferSize)
    {
        for (int i = 0; i < kNumberBuffers; ++i)
        {
            [self handleAudioQueueCallBack:audioQueue withBuffer:audioBuffers[i]];
        }
        
        if (DEBUG_LOG)
        {
            NSLog(@"starting the queue");
        }
        
        AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, audioCurrentGain);
        AudioQueueStart(audioQueue, NULL);
        
        audioStarted = YES;
    }
    
    // check for free buffers
    @synchronized (packetQueue)
    {
        for (int i = 0; i < kNumberBuffers; i++)
        {
            if (audioFreeBuffers[i])
            {
                [self handleAudioQueueCallBack:audioQueue withBuffer:audioFreeBuffers[i]];
                audioFreeBuffers[i] = nil;
            
                break;
            }
        }
    }
}

- (void)processAudio:(const char*)buffer withLength:(NSInteger)length
{
    if (self.isPlaying)
    {
        if (VERBOSE_LOG)
        {
            NSLog(@"processAudio %d bytes", (int)length);
        }
        
        AudioFileStreamParseBytes(audioStreamID, (int)length, buffer, 0);
        
        @synchronized (packetQueue)
        {
            if (audioOutOfBuffers > kMaxOutOfBuffers)
            {
                if (VERBOSE_BUF)
                {
                    NSLog(@"Buffer has starved! (%d > %d)", audioOutOfBuffers, kMaxOutOfBuffers);
                }
                
                if (self.isPlaying)
                {
                    self.isError = YES;
                    self.isPlaying = NO;
                    
                    [self stop];
                    
                    if (self.delegate && [self.delegate respondsToSelector:@selector(updateStreamTitle:)])
                    {
                        [self.delegate updateStreamTitle:@"Timed out..."];
                    }
                    
                    audioOutOfBuffers = 0;
                }
                else
                {
                    if (DEBUG_LOG)
                    {
                        NSLog(@"out of buffers but stopped");
                    }
                }
            }
        }
    }
}

- (void)fillcurrentPacket: (const char *)buffer withLength:(NSInteger)len
{
    for (unsigned i = 0; i < len; i++)
    {
        if (metaLength != 0)
        {
            if (buffer[i] != '\0')
            {
                [metaDataBuffer appendBytes:buffer+i length:1];
            }
            
            metaLength--;
            
            if (metaLength == 0)
            {
                NSString* streamMetaData = [[NSString alloc] initWithBytes:[metaDataBuffer bytes] length:[metaDataBuffer length] encoding:NSUTF8StringEncoding];
                
                if (DEBUG_LOG)
                {
                    NSLog(@"song meta info, %@", streamMetaData);
                }
                
                [self processMetaData:streamMetaData];
                
                [metaDataBuffer setLength:0];
            }
        }
        else
        {
            if (streamCount++ < icyInterval)
            {
                [currentPacket appendBytes:buffer+i length:1];
                
                if ([currentPacket length] == kPacketSize)
                {
                    if (self.isBuffering)
                    {
                        self.isPlaying = YES;
                        self.isBuffering = NO;
                        
                        if (self.delegate && [self.delegate respondsToSelector:@selector(playingStateChange)])
                        {
                            [self.delegate playingStateChange];
                        }
                    }
                    
                    [self processAudio:[currentPacket bytes] withLength:[currentPacket length]];
                    [currentPacket setLength:0];
                }
            }
            else
            {
                metaLength = 16*(unsigned char)buffer[i];
                streamCount = 0;
            }
        }
    }
}

#pragma mark - interruptions/route change

- (void)handleInterruption:(NSNotification *)notification
{
    int type = [notification.userInfo[AVAudioSessionInterruptionTypeKey] intValue];
    
    if (type == AVAudioSessionInterruptionTypeBegan && self.isPlaying)
    {
        if (self.delegate && [self.delegate respondsToSelector:@selector(interruptRadio)])
        {
            [self.delegate interruptRadio];
        }
        
        self.isInterrupted = YES;
    }
    else if (type == AVAudioSessionInterruptionTypeEnded && self.isInterrupted && self.isPlaying)
    {
        if (self.delegate && [self.delegate respondsToSelector:@selector(resumeInterruptedRadio)])
        {
            [self.delegate resumeInterruptedRadio];
        }
    }
}

- (void)handleRouteChange:(NSNotification *)notification
{
    int type = [notification.userInfo[AVAudioSessionRouteChangeReasonKey] intValue];
    
    if (type == AVAudioSessionRouteChangeReasonOldDeviceUnavailable)
    {
        [self audioUnplugged];
    }
}


#pragma mark - controls

- (void)updateGain: (float)value
{
    audioCurrentGain = value;
    
    if (audioStarted)
    {
        AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, audioCurrentGain);
    }
}

- (void)networkChanged
{
    if (DEBUG_LOG)
    {
        NSLog(@"networkChanged");
    }
    
    [self connectionDidFinishLoading:nil];
}

- (void)audioUnplugged
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(audioUnplugged)])
    {
        [self.delegate audioUnplugged];
    }
}

- (void)dealloc
{
    AudioFileStreamClose(audioStreamID);
    AudioQueueStop(audioQueue, YES);
    AudioQueueReset(audioQueue);
    
    for (int i = 0; i < kNumberBuffers; ++i)
    {
        AudioQueueFreeBuffer(audioQueue, audioBuffers[i]);
    }
    
    AudioQueueDispose(audioQueue, YES);
    
    packetQueue = nil;
    currentPacket = nil;
    metaDataBuffer = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
