//
//  ExperimentAudioOutput.m
//  phyphox
//
//  Created by Jonas Gessner on 16.03.16.
//  Copyright © 2016 RWTH Aachen. All rights reserved.
//

#import "ExperimentAudioOutput.h"
#import "phyphox-swift.h"
#import <EZAudioiOS/EZAudioiOS.h>

@interface ExperimentAudioOutput () <EZOutputDataSource> {
    EZOutput *_output;
}

@end

@implementation ExperimentAudioOutput

- (instancetype)initWithSampleRate:(NSUInteger)sampleRate loop:(BOOL)loop dataSource:(DataBuffer *)dataBuffer {
    self = [super init];
    
    if (self) {
        AudioStreamBasicDescription inputFormat = [EZAudioUtilities monoFloatFormatWithSampleRate:sampleRate];
        _output = [EZOutput outputWithDataSource:self inputFormat:inputFormat];
        _dataSource = dataBuffer;
        _sampleRate = sampleRate;
        _loop = loop;
        
        [self play];
    }
    
    return self;
}

- (OSStatus)output:(EZOutput *)output shouldFillAudioBufferList:(AudioBufferList *)audioBufferList withNumberOfFrames:(UInt32)frames timestamp:(const AudioTimeStamp *)timestamp {
    Float32 *buffer = (Float32 *)audioBufferList->mBuffers[0].mData;
    
    NSUInteger index = 0;
    
    if (_dataSource.count == 0) {
        return noErr;
    }
    
    for (UInt32 frame = 0; frame < frames; frame++) {
        if (index >= _dataSource.count) {
            break;
        }
        
        buffer[frame] = [_dataSource objectAtIndexedSubscript:index];
        
        index++;
    }
    
    return noErr;
}

- (void)play {
    [_output startPlayback];
}

- (void)pause {
    [_output stopPlayback];
}

@end
