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
    NSUInteger _lastIndex;
    BOOL _stopPlayback;
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
    }
    
    return self;
}

- (OSStatus)output:(EZOutput *)output shouldFillAudioBufferList:(AudioBufferList *)audioBufferList withNumberOfFrames:(UInt32)frames timestamp:(const AudioTimeStamp *)timestamp {
    if (_stopPlayback) {
        _stopPlayback = NO;
        [self pause];
        return -1;
    }
    
    if (_dataSource.count == 0) {
        return noErr;
    }
    
    Float32 *buffer = (Float32 *)audioBufferList->mBuffers[0].mData;
    
    for (UInt32 frame = 0; frame < frames; frame++) {
        if (!_loop) {
            if (frame < _dataSource.count) {
                buffer[frame] = [_dataSource objectAtIndexedSubscript:frame];
            }
            else {
                _stopPlayback = YES;
                break;
            }
        }
        else {
            NSUInteger index = (_lastIndex+frame) % _dataSource.count;
            
            buffer[frame] = [_dataSource objectAtIndexedSubscript:index];
        }
    }
    
    _lastIndex = (_lastIndex+frames-1) % _dataSource.count;
    
    return noErr;
}

- (void)play {
    _stopPlayback = NO;
    [_output startPlayback];
}

- (void)pause {
    _lastIndex = 0;
    [_output stopPlayback];
}

@end
