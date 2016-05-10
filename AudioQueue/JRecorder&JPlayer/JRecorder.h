//
//  JRecorder.h
//  
//
//  Created by jimmygao on 4/25/16.
//
//
//
#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#define kBufferDurationSeconds 0.5
#define kNumberRecordBuffers	3

@interface JRecorder : NSObject
{
    @public
    AudioQueueRef mQueue;
    AudioQueueBufferRef mBuffers[kNumberRecordBuffers];
    AudioStreamBasicDescription mRecordFormat;
    AudioFileID mRecordFile;
    SInt64 mRecordPacket;

    @private
    CFStringRef mFileName;
}

@property (assign, nonatomic, readonly) BOOL isRunning;

-(void)StartRecord;
-(void)StopRecord;
@end
