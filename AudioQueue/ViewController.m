//
//  ViewController.m
//  AudioQueue
//
//  Created by jimmygao on 4/22/16.
//  Copyright (c) 2016 jimmygao. All rights reserved.
//

#import "ViewController.h"
#import "JRecorder.h"


@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *btnRecord;
@property (weak, nonatomic) IBOutlet UIButton *btnPlay;

@end

@implementation ViewController
{
    JRecorder *recorder;

}

- (void)viewDidLoad {
    [super viewDidLoad];
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [session setActive:YES error:nil];

    recorder = [[JRecorder alloc]init];

}

- (IBAction)onpressedBtnRecord:(id)sender {
    if (recorder.isRunning) {
        [recorder StopRecord];
    }
    else
    {
        [recorder StartRecord];
    }
//    if(recorder.isRunning)
//    {
//        [recorder StopRecord];
//        
//    }
//    else
//        [recorder StartRecord];
}

- (IBAction)onpressedBtnPlay:(id)sender {

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



@end
