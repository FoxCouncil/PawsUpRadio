//
//  Queue.m
//  PawsUpRadio
//
//  Created by Fox on 2014-09-28.
//  Copyright (c) 2014 Fox Council. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Queue.h"

@implementation Queue

- (id) init {
    self = [super init];
    if (self) {
        array = [NSMutableArray arrayWithCapacity:0];
    }
    
    return self;
}

- (id)returnAndRemoveOldest {
    id object = [array lastObject];
    if (object) {
        [array removeLastObject];
    }
    return object;
}

- (id)peak {
    return [array lastObject];
}

- (void)addItem:(id)item {
    [array insertObject:item atIndex:0];
}

- (NSInteger)size
{
    return [array count];
}

- (void)empty {
    [array removeAllObjects];
}

- (void) dealloc {
    [array removeAllObjects];
}

@end