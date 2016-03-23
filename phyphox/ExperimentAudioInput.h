//
//  ExperimentAudioInput.h
//  phyphox
//
//  Created by Jonas Gessner on 23.03.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <EZAudioiOS/EZAudioiOS.h>

@class DataBuffer;

@interface ExperimentAudioInput : NSObject <EZMicrophoneDelegate>

- (instancetype)initWithSampleRate:(NSUInteger)sampleRate outBuffers:(NSArray <DataBuffer *>*)outBuffers;

@property (nonatomic, assign, readonly) NSUInteger sampleRate;
@property (nonatomic, strong, readonly) NSArray <DataBuffer *>* outBuffers;

- (void)startRecording;
- (void)stopRecording;

@end
