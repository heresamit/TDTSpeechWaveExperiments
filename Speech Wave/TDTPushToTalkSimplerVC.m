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
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIImageView *pressToSpeakButton;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic, strong) AVAudioSession *session;
@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, strong) NSTimer *updateTimer;
@property (nonatomic, strong) NSMutableArray *meterTable;
@property (nonatomic, strong) TDTWaveView *otherWaveView;
@property (nonatomic) float mScaleFactor;

@end

@implementation TDTPushToTalkSimplerVC

- (void)viewDidLoad
{
  [super viewDidLoad];
  [self setUpAudioObjects];
  [self setUpViews];
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
		[self.meterTable setObject:@(pow(adjAmp, rroot)) atIndexedSubscript:i];
	}
}

- (void)setUpAudioSession
{
  self.session = [AVAudioSession sharedInstance];
  [self.session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
  UInt32 doChangeDefaultRoute = 1;
  AudioSessionSetProperty (kAudioSessionProperty_OverrideCategoryDefaultToSpeaker,
                           sizeof(doChangeDefaultRoute), &doChangeDefaultRoute);
}

- (NSDictionary *)getRecordSettingsDictionary
{
  AudioChannelLayout channelLayout;
  memset(&channelLayout, 0, sizeof(AudioChannelLayout));
  channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
  return @{AVFormatIDKey: @(kAudioFormatMPEG4AAC),
           AVSampleRateKey: @11025.0f,
           AVNumberOfChannelsKey: @1,
           AVEncoderBitRateKey: @24000,
           AVChannelLayoutKey: [NSData dataWithBytes:&channelLayout
                                              length:sizeof(AudioChannelLayout)]};
}

- (void)setUpRecorder
{
  NSURL *fileURL = [NSURL URLWithString:[NSTemporaryDirectory() stringByAppendingPathComponent:@"temp.m4a"]];
  self.recorder = [[AVAudioRecorder alloc] initWithURL:fileURL
                                              settings:[self getRecordSettingsDictionary]
                                                 error:nil];
  self.recorder.meteringEnabled = YES;
  [self.recorder prepareToRecord];
  
}

- (void)setUpAudioObjects
{
  [self setUpMeterTable];
  [self setUpAudioSession];
  [self setUpRecorder];
}

- (void)viewChoiceChanged
{
  if (self.waveTypePicker.selectedSegmentIndex != 0)
  {
    [self.audioWaveView removeFromSuperview];
    self.otherWaveView = [[TDTWaveView alloc] initWaveWithType:1
                                                         frame:CGRectMake(0, 30, 250, 150)
                                                      maxValue:0
                                                      minValue:-160];
    self.otherWaveView.backgroundColor = [UIColor clearColor];
    [self.otherWaveView setZeroPointValue:-55];
    [self.containerView addSubview:self.otherWaveView];
  }
  else
  {
    [self.otherWaveView removeFromSuperview];
    self.audioWaveView = [[TDTAudioWaveView alloc] initWithFrame:CGRectMake(-250, 30, 500, 150)
                                                            type:0];
    self.audioWaveView.backgroundColor = [UIColor clearColor];
    self.audioWaveView.maxWaveHeight = 4;
    [self.containerView addSubview:self.audioWaveView];
    [self animateWave];
  }
}

- (void)setUpContainer
{
  self.containerView = [[UIView alloc] initWithFrame:CGRectMake(35, 100, 250, 230)];
  self.containerView.clipsToBounds = YES;
  self.containerView.userInteractionEnabled = YES;
  [self.view addSubview:self.containerView];
}

- (void)setUpAudioWaveView
{
  self.audioWaveView = [[TDTAudioWaveView alloc] initWithFrame:CGRectMake(-250, 30, 500, 150)
                                                          type:0];
  self.audioWaveView.backgroundColor = [UIColor clearColor];
  self.audioWaveView.maxWaveHeight = 4;
  [self.containerView addSubview:self.audioWaveView];
}

- (void)setUpTitleLabel
{
  self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 250, 30)];
  self.titleLabel.text = @"Press and Hold Bubble.";
  self.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:15.0f];
  self.titleLabel.textAlignment = NSTextAlignmentCenter;
  self.titleLabel.backgroundColor = [UIColor colorWithRed:170./255.
                                                    green:252./255.
                                                     blue:201./255.
                                                    alpha:1];
  [self.containerView addSubview:self.titleLabel];
}

- (void)setUpPressToSpeakButton
{
  self.pressToSpeakButton = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"press-to-speak-button-highlighted.png"]];
  self.pressToSpeakButton.frame = CGRectMake(100, 180, 50, 50);
  [self addLongPressGestureRecognizerTo:self.pressToSpeakButton];
  self.pressToSpeakButton.userInteractionEnabled = YES;
  [self.containerView addSubview:self.pressToSpeakButton];
}

- (void)addLongPressGestureRecognizerTo:(id)view
{
  UILongPressGestureRecognizer *gestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                                  action:@selector(userDidLongPressSpeakButton:)];
  gestureRecognizer.minimumPressDuration = 0.5;
  gestureRecognizer.delegate = self;
  [view addGestureRecognizer:gestureRecognizer];
}

- (void)setUpTimer
{
  if (self.updateTimer) [_updateTimer invalidate];
  self.updateTimer = [NSTimer
                      scheduledTimerWithTimeInterval:1./30.
                      target:self
                      selector:@selector(refreshaudioWaveView)
                      userInfo:nil
                      repeats:YES
                      ];
}

- (void)setUpViews
{
  [self.waveTypePicker addTarget:self
                          action:@selector(viewChoiceChanged)
                forControlEvents:UIControlEventValueChanged];
  [self setUpContainer];
  [self setUpAudioWaveView];
  [self setUpTitleLabel];
  [self setUpPressToSpeakButton];
  [self.view addSubview:self.containerView];
  [self setUpTimer];
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
  CGFloat dx = self.audioWaveView.frame.size.width/2;
  [UIView animateWithDuration:.5
                        delay:0.0
                      options:UIViewAnimationOptionRepeat|UIViewAnimationOptionCurveLinear
                   animations:^{
    self.audioWaveView.transform = CGAffineTransformMakeTranslation(dx, 0);
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
  [self.session setActive:YES error:nil];
  if (self.waveTypePicker.selectedSegmentIndex == 1) {
    [self refreshOtherWaveView];
  }
  [self.recorder record];
}

- (void)stopRecording
{
  [self.session setActive:NO error:nil];
  [self.recorder stop];
  NSURL *fileURL = [NSURL URLWithString:[NSTemporaryDirectory() stringByAppendingPathComponent:@"temp.m4a"]];
  self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:fileURL error:nil];
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
  self.otherWaveView = [[TDTWaveView alloc] initWaveWithType:1
                                                       frame:CGRectMake(0, 30, 250, 150)
                                                    maxValue:0
                                                    minValue:-160];
  self.otherWaveView.backgroundColor = [UIColor clearColor];
  [self.otherWaveView setZeroPointValue:-55];
  [self.containerView addSubview:self.otherWaveView];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
  //NSLog(@"%d",flag);
}
@end
