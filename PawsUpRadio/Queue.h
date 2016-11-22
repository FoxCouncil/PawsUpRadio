//
//  Queue.h
//  PawsUpRadio
//
//  Created by Fox on 2014-09-28.
//  Copyright (c) 2014 Fox Council. All rights reserved.
//

#ifndef PawsUpRadio_Queue_h
#define PawsUpRadio_Queue_h

#import <UIKit/UIKit.h>

@interface Queue : NSObject {
    NSMutableArray *array;
}

- (id)returnAndRemoveOldest;
- (void)addItem:(id)item;
- (NSInteger)size;
- (void)empty;
- (id)peak;

@end

#endif
