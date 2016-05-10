//
//  JRecorder.m
//  
//
//  Created by jimmygao on 4/25/16.
//
//

#import "JRecorder.h"
static void MyInputBufferHandler(	void *								inUserData,
                                 AudioQueueRef						inAQ,
                                 AudioQueueBufferRef					inBuffer,
                                 const AudioTimeStamp *				inStartTime,
                                 UInt32								inNumPackets,
                                 const AudioStreamPacketDescription*	inPacketDesc)
{
    JRecorder *record = (__bridge JRecorder *)inUserData;
    
    if (inNumPackets > 0) {
        // write packets to file
        AudioFileWritePackets(record->mRecordFile, FALSE, inBuffer->mAudioDataByteSize,inPacketDesc, record->mRecordPacket, &inNumPackets, inBuffer->mAudioData);
        record->mRecordPacket += inNumPackets;
    }
    
    // if we're not stopping, re-enqueue the buffe so that it gets filled again
    if (record.isRunning){
        AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
    }
    
    static int count = 0;
    count ++;
    NSLog(@"record buffer count: %d，mRecordPacket = %lld,now packet = %d",count,record->mRecordPacket,inNumPackets);
}




@implementation JRecorder

-(instancetype)init{
    if (self = [super init]) {
        _isRunning = NO;
        mRecordPacket = 0;
    }
    return self;
}

-(void)StartRecord
{
    OSStatus status;
    int i, bufferByteSize;
    UInt32 size;
    CFURLRef url;
    
    [self SetupAudioFormat:kAudioFormatMPEG4AAC];
    
    AudioQueueNewInput(&mRecordFormat, MyInputBufferHandler, (__bridge void *)(self), NULL, NULL, 0, &mQueue);
    
    size = sizeof(mRecordFormat);
    AudioQueueGetProperty(mQueue, kAudioQueueProperty_StreamDescription,&mRecordFormat, &size);

    NSLog(@"mRecordFormat: mSampleRate = %f,formatFlag = %d, bytes per packet = %d, frame per packet = %d, bytes per frame = %d, channel per frame = %d, bits per channel = %d,reserved = %d",mRecordFormat.mSampleRate,mRecordFormat.mFormatFlags,mRecordFormat.mBytesPerPacket,mRecordFormat.mFramesPerPacket, mRecordFormat.mBytesPerFrame,mRecordFormat.mChannelsPerFrame,mRecordFormat.mBitsPerChannel,mRecordFormat.mReserved);

    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *recordFile = [documentPath stringByAppendingPathComponent:@"test.caf"];
    NSLog(@"recorderFile = %@",recordFile);
    url = CFURLCreateWithString(kCFAllocatorDefault, (CFStringRef)recordFile, NULL);
    AudioFileCreateWithURL(url, kAudioFileMPEG4Type, &mRecordFormat, kAudioFileFlags_EraseFile, &mRecordFile);
    CFRelease(url);
    
    [self CopyEncoderCookieToFile];
    
    bufferByteSize = [self ComputeRecordBufferSize:&mRecordFormat ForDuration:kBufferDurationSeconds];
    
    for (i = 0; i < kNumberRecordBuffers; i++) {
        AudioQueueAllocateBuffer(mQueue, bufferByteSize, &mBuffers[i]);
        AudioQueueEnqueueBuffer(mQueue, mBuffers[i], 0, NULL);
    }
    
    _isRunning = YES;
    status = AudioQueueStart(mQueue, NULL);
    NSLog(@"audio queue start status = %d",status);
}

-(void)StopRecord
{
    _isRunning = NO;
    AudioQueueStop(mQueue, true);
    
    [self CopyEncoderCookieToFile];
    if (mFileName)
    {
        CFRelease(mFileName);
        mFileName = NULL;
    }
    AudioQueueDispose(mQueue, true);
    AudioFileClose(mRecordFile);
}

-(void)SetupAudioFormat:(UInt32)inFormatID
{
    memset(&mRecordFormat, 0, sizeof(mRecordFormat));
    
    mRecordFormat.mSampleRate = 44100;
    mRecordFormat.mChannelsPerFrame = 1;
    mRecordFormat.mFormatID = inFormatID;
    
    if (inFormatID == kAudioFormatLinearPCM)
    {
        // if we want pcm, default to signed 16-bit little-endian
        mRecordFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        mRecordFormat.mBitsPerChannel = 16;
        mRecordFormat.mBytesPerPacket = mRecordFormat.mBytesPerFrame = (mRecordFormat.mBitsPerChannel / 8) * mRecordFormat.mChannelsPerFrame;
        mRecordFormat.mFramesPerPacket = 1;
    }
}

-(int)ComputeRecordBufferSize:(AudioStreamBasicDescription *)format ForDuration:(float)seconds
{
    int packets, frames, bytes = 0;
    
    frames = (int)ceil(seconds * format->mSampleRate);
    
    if (format->mBytesPerFrame > 0)
        bytes = frames * format->mBytesPerFrame;
    else {
        UInt32 maxPacketSize;
        if (format->mBytesPerPacket > 0)
            maxPacketSize = format->mBytesPerPacket;	// constant packet size
        else {
            UInt32 propertySize = sizeof(maxPacketSize);
            AudioQueueGetProperty(mQueue, kAudioQueueProperty_MaximumOutputPacketSize, &maxPacketSize,&propertySize);
        }
        if (format->mFramesPerPacket > 0)
            packets = frames / format->mFramesPerPacket;
        else
            packets = frames;	// worst-case scenario: 1 frame in a packet
        if (packets == 0)		// sanity check
            packets = 1;
        bytes = packets * maxPacketSize;
    }
    return bytes;
}

-(void)CopyEncoderCookieToFile
{
    UInt32 propertySize;
    // get the magic cookie, if any, from the converter
    OSStatus err = AudioQueueGetPropertySize(mQueue, kAudioQueueProperty_MagicCookie, &propertySize);
    
    // we can get a noErr result and also a propertySize == 0
    // -- if the file format does support magic cookies, but this file doesn't have one.
    if (err == noErr && propertySize > 0) {
        UInt8 *magicCookie = (UInt8*)malloc(propertySize);
        UInt32 magicCookieSize;
        AudioQueueGetProperty(mQueue, kAudioQueueProperty_MagicCookie, magicCookie, &propertySize);
        magicCookieSize = propertySize;	// the converter lies and tell us the wrong size
        
        // now set the magic cookie on the output file
        UInt32 willEatTheCookie = false;
        // the converter wants to give us one; will the file take it?
        err = AudioFileGetPropertyInfo(mRecordFile, kAudioFilePropertyMagicCookieData, NULL, &willEatTheCookie);
        if (err == noErr && willEatTheCookie) {
            err = AudioFileSetProperty(mRecordFile, kAudioFilePropertyMagicCookieData, magicCookieSize, magicCookie);
        }
        free(magicCookie);
    }
}

@end

