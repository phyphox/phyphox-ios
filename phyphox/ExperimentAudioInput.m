//
//  ExperimentAudioInput.m
//  phyphox
//
//  Created by Jonas Gessner on 23.03.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

#import "ExperimentAudioInput.h"
#import "phyphox-swift.h"

@implementation ExperimentAudioInput {
    EZMicrophone *_microphone;
    BOOL _recording;
}

- (instancetype)initWithSampleRate:(NSUInteger)sampleRate outBuffers:(NSArray <DataBuffer *>*)outBuffers {
    self = [super init];
    
    if (self) {
        _sampleRate = sampleRate;
        _outBuffers = [outBuffers copy];
    }
    
    return self;
}

- (void)startRecording {
    if (_recording) {
        return;
    }
    
    _recording = YES;
    
    if (_microphone == nil) {
        _microphone = [[EZMicrophone alloc] initWithMicrophoneDelegate:self withAudioStreamBasicDescription:[EZAudioUtilities monoFloatFormatWithSampleRate:_sampleRate]];
    }
    
    [_microphone startFetchingAudio];
}

- (void)stopRecording {
    if (!_recording) {
        return;
    }
    
    [_microphone stopFetchingAudio];
    
    
    _recording = NO;
}

- (void)microphone:(EZMicrophone *)microphone hasAudioReceived:(float **)buffer withBufferSize:(UInt32)bufferSize withNumberOfChannels:(UInt32)numberOfChannels {
    float *values = buffer[0];
    
    NSMutableArray <NSNumber *>* final = [NSMutableArray arrayWithCapacity:bufferSize];
    
    for (int i = 0; i < bufferSize; i++) {
        float value = values[i];
        [final addObject:@(value)];
    }
    
    for (DataBuffer *outBuffer in _outBuffers) {
        [outBuffer appendFromArray:final notify:YES];
    }
}

@end
