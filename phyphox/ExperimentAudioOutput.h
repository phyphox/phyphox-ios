//
//  ExperimentAudioOutput.h
//  phyphox
//
//  Created by Jonas Gessner on 16.03.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DataBuffer;

@interface ExperimentAudioOutput : NSObject

- (instancetype)initWithSampleRate:(NSUInteger)sampleRate loop:(BOOL)loop dataSource:(DataBuffer *)dataBuffer;

@property (nonatomic, assign, readonly) BOOL loop;
@property (nonatomic, strong, readonly) DataBuffer *dataSource;
@property (nonatomic, assign, readonly) NSUInteger sampleRate;

- (void)play;
- (void)pause;

@end
