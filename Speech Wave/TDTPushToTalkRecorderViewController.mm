//
//  TDTPushToTalkRecorderViewController.m
//  Speech Wave
//
//  Created by Amit Chowdhary on 09/07/13.
//  Copyright (c) 2013 Amit Chowdhary. All rights reserved.
//
#import "TDTAudioWaveView.h"
#import "TDTPushToTalkRecorderViewController.h"
#import "AQRecorder.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "MeterTable.h"
#import <CoreMedia/CMTime.h>

const float _refreshHz = 1./30.;

@interface TDTPushToTalkRecorderViewController ()

{
    AQRecorder*	recorder;
    CFStringRef	recordFilePath;
    AudioQueueLevelMeterState *_chan_lvls;
    NSArray	*_channelNumbers;
    MeterTable *_meterTable;
}

@property (nonatomic, copy) NSArray *channelNumbers;
@property (nonatomic, strong) TDTAudioWaveView* audioWaveView;
@property (nonatomic, strong) UILabel* titleLabel;
@property (nonatomic, strong) UIImageView* pressToSpeakButton;
@property (nonatomic) AudioQueueRef  aq;
@property (nonatomic, strong) NSTimer* updateTimer;
@property (nonatomic, strong) UIView* containerView;
@property(nonatomic, strong) AVAudioPlayer *meinPlayer;
@property(nonatomic, strong) NSDate *start;

@end

@implementation TDTPushToTalkRecorderViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

- (void)setAq:(AudioQueueRef)v
{
	if ((_aq == NULL) && (v != NULL))
	{
		if (_updateTimer) [_updateTimer invalidate];
		_updateTimer = [NSTimer
						scheduledTimerWithTimeInterval:_refreshHz
						target:self
						selector:@selector(refreshAudioWaveView)
						userInfo:nil
						repeats:YES
						];
	}
	_aq = v;
	if (_aq) {
		try {
			UInt32 val = 1;
			XThrowIfError(AudioQueueSetProperty(_aq, kAudioQueueProperty_EnableLevelMetering, &val, sizeof(UInt32)), "couldn't enable metering");
			// now check the number of channels in the new queue, we will need to reallocate if this has changed
			CAStreamBasicDescription queueFormat;
			UInt32 data_sz = sizeof(queueFormat);
			XThrowIfError(AudioQueueGetProperty(_aq, kAudioQueueProperty_StreamDescription, &queueFormat, &data_sz), "couldn't get stream description");
            
			if (queueFormat.NumberChannels() != [_channelNumbers count])
			{
				NSArray *chan_array;
				if (queueFormat.NumberChannels() < 2)
					chan_array = [[NSArray alloc] initWithObjects:[NSNumber numberWithInt:0], nil];
				else
					chan_array = [[NSArray alloc] initWithObjects:[NSNumber numberWithInt:0], [NSNumber numberWithInt:1], nil];
				self.channelNumbers = chan_array;
				_chan_lvls = (AudioQueueLevelMeterState*)realloc(_chan_lvls, queueFormat.NumberChannels() * sizeof(AudioQueueLevelMeterState));
			}
		}
		catch (CAXException e) {
			char buf[256];
			fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
		}
	}
    else if (v == NULL){
        if (_updateTimer) [_updateTimer invalidate];
        self.audioWaveView.maxWaveHeight = 2;
        [self.audioWaveView setNeedsDisplay];
    }
}

- (void)refreshAudioWaveView
{
    BOOL success = NO;
    UInt32 data_sz = sizeof(AudioQueueLevelMeterState) * [_channelNumbers count];
    OSErr status = AudioQueueGetProperty(_aq, kAudioQueueProperty_CurrentLevelMeterDB, _chan_lvls, &data_sz);
    if (status != noErr) {
        NSLog(@"Metering Failed");
        return;
    }
    int i = 0;
    NSInteger channelIdx = [(NSNumber *)[_channelNumbers objectAtIndex:i] intValue];
    
    if (channelIdx >= [_channelNumbers count]) {
        NSLog(@"Metering Failed");
        return;
    }
    if (channelIdx > 127) {
        NSLog(@"Metering Failed");
        return;
    }
    if (_chan_lvls)
    {
        self.audioWaveView.maxWaveHeight = ceil(_meterTable->ValueAt((float)(_chan_lvls[channelIdx].mAveragePower)) * 200);;
        //NSLog(@"Audio Level: %f",self.audioWaveView.maxWaveHeight);
        [self.audioWaveView setNeedsDisplay];
        success = YES;
    }
}

- (void)setUpAudioSession
{
    OSStatus error = AudioSessionInitialize(NULL, NULL, interruptionListener, (__bridge void*)self);
	if (error) printf("ERROR INITIALIZING AUDIO SESSION! %d\n", (int)error);
	else
	{
		UInt32 category = kAudioSessionCategory_PlayAndRecord;
		error = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
		if (error) printf("couldn't set audio category!");
        
//        Float64 preferredSampleRate = 11025.0;
//        AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareSampleRate, sizeof(preferredSampleRate), &preferredSampleRate);

		error = AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, propListener, (__bridge void*) self);
		if (error) printf("ERROR ADDING AUDIO SESSION PROP LISTENER! %d\n", (int)error);
		UInt32 inputAvailable = 0;
		UInt32 size = sizeof(inputAvailable);
		
		// we do not want to allow recording if input is not available
		error = AudioSessionGetProperty(kAudioSessionProperty_AudioInputAvailable, &size, &inputAvailable);
        //		if (error) printf("ERROR GETTING INPUT AVAILABILITY! %d\n", (int)error);
        //		btn_record.enabled = (inputAvailable) ? YES : NO;
        //
		// we also need to listen to see if input availability changes
		error = AudioSessionAddPropertyListener(kAudioSessionProperty_AudioInputAvailable, propListener,  (__bridge void*)self);
		if (error) printf("ERROR ADDING AUDIO SESSION PROP LISTENER! %d\n", (int)error);
        
		error = AudioSessionSetActive(true);
		if (error) printf("AudioSessionSetActive (true) failed");
	}
	[self initializeAudioObjects];
}

- (void)initializeAudioObjects
{
    _channelNumbers = [[NSArray alloc] initWithObjects:[NSNumber numberWithInt:0], nil];
    _chan_lvls = (AudioQueueLevelMeterState*)malloc(sizeof(AudioQueueLevelMeterState) * [_channelNumbers count]);
    recorder = new AQRecorder();
    _meterTable = new MeterTable(kMinDBvalue);
}

- (void)startRecording
{
    AudioSessionSetActive(true);
    self.titleLabel.text = @"Recording...";
    if (recorder->IsRunning()) 
	{
		[self stopRecording];
	}
	else
	{
		recorder->StartRecord(CFSTR("recordedFile.caf"));
		[self setFileDescriptionForFormat:recorder->DataFormat() withName:@"Recorded File"];
		[self setAq:recorder->Queue()];
	}
}

- (void)setUpViews {
    self.containerView = [[UIView alloc] initWithFrame:CGRectMake(35, 100, 250, 230)];
    self.containerView.clipsToBounds = YES;
    self.containerView.userInteractionEnabled = YES;
    [self.view addSubview:self.containerView];
    
    self.audioWaveView = [[TDTAudioWaveView alloc] initWithFrame:CGRectMake(-250, 30, 500, 150)];
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
}

- (void)userDidLongPressSpeakButton:(UILongPressGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        self.pressToSpeakButton.image = [UIImage imageNamed:@"press-to-speak-button.png"];
        [self startRecording];
        NSLog(@"Started");
    }
    else if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        self.pressToSpeakButton.image = [UIImage imageNamed:@"press-to-speak-button-highlighted.png"];
        [self stopRecording];
        NSLog(@"Stopped");
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setUpAudioSession];
    [self setUpViews];
    [self animateWave];
}

- (void)animateWave {
    [UIView animateWithDuration:.5 delay:0.0 options:UIViewAnimationOptionRepeat|UIViewAnimationOptionCurveLinear animations:^{
        self.audioWaveView.transform = CGAffineTransformMakeTranslation(self.audioWaveView.frame.size.width/2, 0);
    } completion:^(BOOL finished) {
        self.audioWaveView.transform = CGAffineTransformMakeTranslation(0, 0);
    }];
}

#pragma mark AudioSession listeners
void interruptionListener(void *inClientData,UInt32 inInterruptionState)
{
	TDTPushToTalkRecorderViewController *THIS = (__bridge TDTPushToTalkRecorderViewController*)inClientData;
	if (inInterruptionState == kAudioSessionBeginInterruption)
	{
		if (THIS->recorder->IsRunning()) {
			[THIS stopRecording];
		}
	}
}

void propListener(void *inClientData, AudioSessionPropertyID inID, UInt32 inDataSize,const void* inData)
{
	TDTPushToTalkRecorderViewController *THIS = (__bridge TDTPushToTalkRecorderViewController*)inClientData;
	if (inID == kAudioSessionProperty_AudioRouteChange)
	{
		CFDictionaryRef routeDictionary = (CFDictionaryRef)inData;
		//CFShow(routeDictionary);
		CFNumberRef reason = (CFNumberRef)CFDictionaryGetValue(routeDictionary, CFSTR(kAudioSession_AudioRouteChangeKey_Reason));
		SInt32 reasonVal;
		CFNumberGetValue(reason, kCFNumberSInt32Type, &reasonVal);
		if (reasonVal != kAudioSessionRouteChangeReason_CategoryChange)
		{
			/*CFStringRef oldRoute = (CFStringRef)CFDictionaryGetValue(routeDictionary, CFSTR(kAudioSession_AudioRouteChangeKey_OldRoute));
             if (oldRoute)
             {
             printf("old route:\n");
             CFShow(oldRoute);
             }
             else
             printf("ERROR GETTING OLD AUDIO ROUTE!\n");
             
             CFStringRef newRoute;
             UInt32 size; size = sizeof(CFStringRef);
             OSStatus error = AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &size, &newRoute);
             if (error) printf("ERROR GETTING NEW AUDIO ROUTE! %d\n", error);
             else
             {
             printf("new route:\n");
             CFShow(newRoute);
             }*/
			// stop the queue if we had a non-policy route change
			if (THIS->recorder->IsRunning()) {
				[THIS stopRecording];
			}
		}
	}
	else if (inID == kAudioSessionProperty_AudioInputAvailable)
	{
		if (inDataSize == sizeof(UInt32)) {
			UInt32 isAvailable = *(UInt32*)inData;
			// disable recording if input is not available
			THIS->_pressToSpeakButton.userInteractionEnabled = (isAvailable > 0) ? YES : NO;
		}
	}
}

-(void)setFileDescriptionForFormat:(CAStreamBasicDescription)format withName:(NSString*)name
{
	//char buf[5];
	//const char *dataFormat = OSTypeToStr(buf, format.mFormatID);
	//NSString* description = [[NSString alloc] initWithFormat:@"(%ld ch. %s @ %g Hz)", format.NumberChannels(), dataFormat, format.mSampleRate, nil];
	//NSLog(@"%@",description);
}

char *OSTypeToStr(char *buf, OSType t)
{
	char *p = buf;
	char str[4] = {0};
    char *q = str;
	*(UInt32 *)str = CFSwapInt32(t);
	for (int i = 0; i < 4; ++i) {
		if (isprint(*q) && *q != '\\')
			*p++ = *q++;
		else {
			sprintf(p, "\\x%02x", *q++);
			p += 4;
		}
	}
	*p = '\0';
	return buf;
}

- (void)stopRecording
{
    self.titleLabel.text = @"Press and Hold Bubble.";
	recorder->StopRecord();
    NSLog(@"%@",[_start timeIntervalSinceNow]);
    [self setAq:nil];
	recordFilePath = (__bridge CFStringRef)[NSTemporaryDirectory() stringByAppendingPathComponent: @"recordedFile.caf"];
	self.pressToSpeakButton.userInteractionEnabled = YES;
    //[self sendAudioDataToDelegate];
    //[self compressAudioToM4A];
    AudioSessionSetActive(false);
}

- (void)sendAudioDataToDelegate
{
    NSData *audioData = [NSData dataWithContentsOfFile:(__bridge NSString*)recordFilePath];
    NSLog(@"%lu",(unsigned long)audioData.length);
}

- (void)compressAudioToM4A {
    NSLog(@"Compressing");
    
    NSString *exportPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"out.m4a"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:exportPath]) {
        NSLog(@"%@",exportPath);
        [fileManager removeItemAtPath:exportPath error:NULL];
        //[fileManager createFileAtPath:exportPath contents:nil attributes:nil];
    }
    NSURL *exportURL = [NSURL fileURLWithPath:exportPath];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:(__bridge NSString*)recordFilePath] options:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                                        [ NSNumber numberWithInt: kAudioFormatLinearPCM], AVFormatIDKey,
                                                                                                                        [ NSNumber numberWithInt: 2 ], AVNumberOfChannelsKey,
                                                                                                                        [ NSNumber numberWithFloat: 11025.0 ], AVSampleRateKey,
                                                                                                                        [ NSNumber numberWithInt:16], AVLinearPCMBitDepthKey,
                                                                                                                        nil]];
    CMTime audioDuration = asset.duration;
    NSLog(@"seconds = %f", CMTimeGetSeconds(audioDuration));
    // reader
    NSError *readerError = nil;
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset
                                                           error:&readerError];
    AVAssetTrack *track = [[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
    AVAssetReaderTrackOutput *readerOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:track outputSettings:nil];
    [reader addOutput:readerOutput];
    // writer
    NSError *writerError = nil;
    AVAssetWriter *writer = [[AVAssetWriter alloc] initWithURL:exportURL fileType:AVFileTypeAppleM4A error:&writerError];
    AudioChannelLayout channelLayout;
    memset(&channelLayout, 0, sizeof(AudioChannelLayout));
    channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
    // use different values to affect the downsampling/compression
    NSDictionary *outputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                                    [NSNumber numberWithFloat:11025.0], AVSampleRateKey,
                                    [NSNumber numberWithInt:2], AVNumberOfChannelsKey,
                                    [NSNumber numberWithInt:64000], AVEncoderBitRateKey,
                                    [NSData dataWithBytes:&channelLayout length:sizeof(AudioChannelLayout)], AVChannelLayoutKey,
                                    nil];
    AVAssetWriterInput *writerInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:outputSettings];
    [writerInput setExpectsMediaDataInRealTime:NO];
    [writer addInput:writerInput];
    
    [writer startWriting];
    [writer startSessionAtSourceTime:kCMTimeZero];
    
    [reader startReading];
    dispatch_queue_t mediaInputQueue = dispatch_queue_create("mediaInputQueue", NULL);
    [writerInput requestMediaDataWhenReadyOnQueue:mediaInputQueue usingBlock:^{
        
       // NSLog(@"Asset Writer ready : %d", writerInput.readyForMoreMediaData);
        while (writerInput.readyForMoreMediaData) {
            CMSampleBufferRef nextBuffer;
            if ([reader status] == AVAssetReaderStatusReading && (nextBuffer = [readerOutput copyNextSampleBuffer])) {
                if (nextBuffer) {
                    [writerInput appendSampleBuffer:nextBuffer];
                }
            } else {
                [writerInput markAsFinished];
                
                switch ([reader status]) {
                    case AVAssetReaderStatusReading:
                        break;
                    case AVAssetReaderStatusFailed:
                        [writer cancelWriting];
                        break;
                    case AVAssetReaderStatusCompleted:
                        NSLog(@"Writer completed");
                        [writer endSessionAtSourceTime:asset.duration];
                        [writer finishWriting];
                        NSData *data = [NSData dataWithContentsOfFile:exportPath];
                        NSLog(@"%lu",(unsigned long)data.length);
                         NSError *error = nil;
                        self.titleLabel.text = @"Playing";
                        _meinPlayer = [[AVAudioPlayer alloc]
                                       initWithContentsOfURL:[NSURL fileURLWithPath:exportPath]
                                       error:&error];
                        _meinPlayer.delegate = self;
                        [_meinPlayer prepareToPlay];
                        AVAudioSession *session = [AVAudioSession sharedInstance];
                        [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
                        [session setActive:YES error:nil];
                        [_meinPlayer play];
                        break;
                }
                break;
            }
        }
    }];
    self.titleLabel.text = @"Processing";
    NSLog(@"OUTSIDE");
   
    
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    if (!flag)
        NSLog(@"Failed");
    else
        NSLog(@"Success");
    
    self.titleLabel.text = @"Press and Hold Button";
}

@end
