//
//  TDTPushToTalkSimplerVC.m
//  Speech Wave
//
//  Created by Amit Chowdhary on 11/07/13.
//  Copyright (c) 2013 Amit Chowdhary. All rights reserved.
//

#import "TDTPushToTalkSimplerVC.h"
#import "TDTAudioWaveView.h"
#include <math.h>
#import "TDTWaveView.h"

@interface TDTPushToTalkSimplerVC ()

@property (nonatomic, strong) TDTAudioWaveView *audioWaveView;
@property (nonatomic, strong) UILabel* titleLabel;
@property (nonatomic, strong) UIImageView* pressToSpeakButton;
@property (nonatomic, strong) UIView* containerView;
@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic, strong) AVAudioSession *session;
@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, strong) NSTimer* updateTimer;
@property (nonatomic, strong) NSMutableArray* meterTable;
@property (nonatomic, strong) TDTWaveView* otherWaveView;
@property (nonatomic) float mScaleFactor;

@end

@implementation TDTPushToTalkSimplerVC

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setUpAudioObjects];
    [self setUpViews];
	// Do any additional setup after loading the view
}

- (void)setUpMeterTable
{
    float inMinDecibels = -80.;
    float inRoot = 2.;
    double minAmp = pow(10., 0.05 * inMinDecibels);
	double ampRange = 1. - minAmp;
	double invAmpRange = 1. / ampRange;
	double rroot = 1. / inRoot;
    self.meterTable = [[NSMutableArray alloc] initWithCapacity:400];
    float mDecibelResolution = inMinDecibels/399;
    self.mScaleFactor = 1./mDecibelResolution;
    
    for (size_t i = 0; i < 400; ++i) {
		double decibels = i * mDecibelResolution;
		double amp = pow(10., 0.05 * decibels);
		double adjAmp = (amp - minAmp) * invAmpRange;
		[self.meterTable setObject:[NSNumber numberWithDouble:pow(adjAmp, rroot)] atIndexedSubscript:i];
	}
}

- (void)setUpAudioObjects
{
    [self setUpMeterTable];
    
    self.session = [AVAudioSession sharedInstance];
    [self.session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    AudioChannelLayout channelLayout;
    memset(&channelLayout, 0, sizeof(AudioChannelLayout));
    channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
    self.recorder = [[AVAudioRecorder alloc] initWithURL:[NSURL URLWithString:[NSTemporaryDirectory() stringByAppendingPathComponent:@"temp.m4a"]]
                                                settings:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                 [NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                                                                                 [NSNumber numberWithFloat:11025.0], AVSampleRateKey,
                                                                                 [NSNumber numberWithInt:1], AVNumberOfChannelsKey,
                                                                                 [NSNumber numberWithInt:24000], AVEncoderBitRateKey,
                                                                                 [NSData dataWithBytes:&channelLayout length:sizeof(AudioChannelLayout)], AVChannelLayoutKey,
                                                                                 nil]
                                                   error:nil];
    self.recorder.meteringEnabled = YES;
    [self.recorder prepareToRecord];
}

- (void)viewChoiceChanged
{
    if (self.waveTypePicker.selectedSegmentIndex != 0)
    {
        [self.audioWaveView removeFromSuperview];
        self.otherWaveView = [[TDTWaveView alloc] initWaveWithType:1 Frame:CGRectMake(0, 30, 250, 150) MaxValue:0 MinValue:-160];
        self.otherWaveView.backgroundColor = [UIColor clearColor];
        [self.otherWaveView setZeroPointValue:-55];
        [self.containerView addSubview:self.otherWaveView];
    }
    else
    {
        [self.otherWaveView removeFromSuperview];
        self.audioWaveView = [[TDTAudioWaveView alloc] initWithFrame:CGRectMake(-250, 30, 500, 150) type:0];
        self.audioWaveView.backgroundColor = [UIColor clearColor];
        self.audioWaveView.maxWaveHeight = 4;
        [self.containerView addSubview:self.audioWaveView];
        [self animateWave];
    }
}

- (void)setUpViews
{
    [self.waveTypePicker addTarget:self action:@selector(viewChoiceChanged) forControlEvents:UIControlEventValueChanged];
    
    self.containerView = [[UIView alloc] initWithFrame:CGRectMake(35, 100, 250, 230)];
    self.containerView.clipsToBounds = YES;
    self.containerView.userInteractionEnabled = YES;
    [self.view addSubview:self.containerView];
    
    self.audioWaveView = [[TDTAudioWaveView alloc] initWithFrame:CGRectMake(-250, 30, 500, 150) type:0];
    self.audioWaveView.backgroundColor = [UIColor clearColor];
    self.audioWaveView.maxWaveHeight = 4;
    [self.containerView addSubview:self.audioWaveView];
    
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 250, 30)];
    self.titleLabel.text = @"Press and Hold Bubble.";
    self.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:15.0f];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.backgroundColor = [UIColor colorWithRed:170./255. green:252./255. blue:201./255. alpha:1];
    [self.containerView addSubview:self.titleLabel];
    
    self.pressToSpeakButton = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"press-to-speak-button-highlighted.png"]];
    self.pressToSpeakButton.frame = CGRectMake(100, 180, 50, 50);
    UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(userDidLongPressSpeakButton:)];
    lpgr.minimumPressDuration = 0.5;
    lpgr.delegate = self;
    [self.pressToSpeakButton addGestureRecognizer:lpgr];
    self.pressToSpeakButton.userInteractionEnabled = YES;
    [self.containerView addSubview:self.pressToSpeakButton];
    
    [self.view addSubview:self.containerView];
    if (self.updateTimer) [_updateTimer invalidate];
    self.updateTimer = [NSTimer
                    scheduledTimerWithTimeInterval:1./30.
                    target:self
                    selector:@selector(refreshaudioWaveView)
                    userInfo:nil
                    repeats:YES
                    ];
    
    [self animateWave];
}

- (void)refreshaudioWaveView
{
    if (self.waveTypePicker.selectedSegmentIndex == 0) {
        if (self.recorder.isRecording) {
            [self.recorder updateMeters];
            float v = [self.recorder averagePowerForChannel:0];
            self.audioWaveView.maxWaveHeight = (float)[self.meterTable[(int)(v * self.mScaleFactor)] doubleValue] * 200;
        }
        else if (self.player.isPlaying) {
            [self.player updateMeters];
            float v = [self.player averagePowerForChannel:0];
            self.audioWaveView.maxWaveHeight = (float)[self.meterTable[(int)(v * self.mScaleFactor/2)] doubleValue] * 200;
        }
        else {
            self.audioWaveView.maxWaveHeight = 5;
        }
        [self.audioWaveView setNeedsDisplay];
    }
    else if (self.waveTypePicker.selectedSegmentIndex == 1) {
        if (self.recorder.isRecording) {
            [self.recorder updateMeters];
            [self.otherWaveView startWavingWithValue:[self.recorder averagePowerForChannel:0]];
        }
        else if (self.player.isPlaying) {
            [self.player updateMeters];
            [self.otherWaveView startWavingWithValue:[self.player averagePowerForChannel:0]];
        }
    }
}

- (void)userDidLongPressSpeakButton:(UILongPressGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        self.pressToSpeakButton.image = [UIImage imageNamed:@"press-to-speak-button.png"];
        [self startRecording];
    }
    else if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        self.pressToSpeakButton.image = [UIImage imageNamed:@"press-to-speak-button-highlighted.png"];
        [self stopRecording];
    }
}

- (void)animateWave
{
    [UIView animateWithDuration:.5 delay:0.0 options:UIViewAnimationOptionRepeat|UIViewAnimationOptionCurveLinear animations:^{
        self.audioWaveView.transform = CGAffineTransformMakeTranslation(self.audioWaveView.frame.size.width/2, 0);
    } completion:^(BOOL finished) {
        self.audioWaveView.transform = CGAffineTransformMakeTranslation(0, 0);
    }];
}

- (void)startRecording
{
    if (self.player.isPlaying) {
        [self.player stop];
        self.player = nil;
    }
    NSLog(@"Started");
    [self.session setActive:YES error:nil];
    if (self.waveTypePicker.selectedSegmentIndex == 1) [self refreshOtherWaveView];
    [self.recorder record];
}

- (void)stopRecording
{
    NSLog(@"Stopped");
    [self.session setActive:NO error:nil];
    [self.recorder stop];
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL URLWithString:[NSTemporaryDirectory() stringByAppendingPathComponent:@"temp.m4a"]] error:nil];
    self.player.delegate = self;
    self.player.meteringEnabled = YES;
}

- (IBAction)playButtonPressed:(id)sender {
    if (!self.player.isPlaying && !self.recorder.isRecording) {
        [self.session setActive:YES error:nil];
        [self.player prepareToPlay];
        if (self.waveTypePicker.selectedSegmentIndex == 1) {
            [self refreshOtherWaveView];
        }
        [self.player setVolume:1.0f];
        [self.player play];
    }
}

- (void)refreshOtherWaveView
{
    [self.otherWaveView removeFromSuperview];
    self.otherWaveView = [[TDTWaveView alloc] initWaveWithType:1 Frame:CGRectMake(0, 30, 250, 150) MaxValue:0 MinValue:-160];
    self.otherWaveView.backgroundColor = [UIColor clearColor];
    [self.otherWaveView setZeroPointValue:-55];
    [self.containerView addSubview:self.otherWaveView];
}
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    //NSLog(@"%d",flag);
}
@end
