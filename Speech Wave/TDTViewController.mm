//
//  TDTViewController.m
//  Speech Wave
//
//  Created by Amit Chowdhary on 08/07/13.
//  Copyright (c) 2013 Amit Chowdhary. All rights reserved.
//

#import "TDTViewController.h"
#import "TDTWaveView.h"
#import <AudioToolbox/AudioToolbox.h>
#import <QuartzCore/QuartzCore.h>

@interface TDTViewController ()

@property (nonatomic, strong) TDTWaveView* self_view;

@end


@implementation TDTViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor darkGrayColor];
    _self_view = [[TDTWaveView alloc] initWithFrame:CGRectMake(-320, 174, 640, 200)];
    [self.view addSubview:_self_view];
    _self_view.backgroundColor = [UIColor clearColor];
    recorder = new AQRecorder();
	player = new AQPlayer();
    OSStatus error = AudioSessionInitialize(NULL, NULL, interruptionListener, (__bridge void*)self);
	if (error) printf("ERROR INITIALIZING AUDIO SESSION! %d\n", (int)error);
	else
	{
		UInt32 category = kAudioSessionCategory_PlayAndRecord;
		error = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
		if (error) printf("couldn't set audio category!");
        
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
	if (recorder->IsRunning()) // If we are currently recording, stop and save the file.
	{
		[self stopRecord];
	}
	else // If we're not recording, start.
	{
        // Start the recorder
		recorder->StartRecord(CFSTR("recordedFile.caf"));
		
		[self setFileDescriptionForFormat:recorder->DataFormat() withName:@"Recorded File"];
		
		// Hook the level meter up to the Audio Queue for the recorder
		[_self_view setAq:recorder->Queue()];
	}
    [self animateWave];

}

- (void)animateWave {
    [UIView animateWithDuration:.5 delay:0.0 options:UIViewAnimationOptionRepeat|UIViewAnimationOptionCurveLinear animations:^{
        _self_view.transform = CGAffineTransformMakeTranslation(+_self_view.frame.size.width/2, 0);
    } completion:^(BOOL finished) {
//        [UIView animateWithDuration:2.0 animations:^{
//            _self_view.transform = CGAffineTransformMakeTranslation(0, 0);
//        } completion:^(BOOL finished) {
//            [self animateWave];
//        }];
        _self_view.transform = CGAffineTransformMakeTranslation(0, 0);
        //[self animateWave];
    }];
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

-(void)setFileDescriptionForFormat: (CAStreamBasicDescription)format withName:(NSString*)name
{
	//char buf[5];
	//const char *dataFormat = OSTypeToStr(buf, format.mFormatID);
	//NSString* description = [[NSString alloc] initWithFormat:@"(%ld ch. %s @ %g Hz)", format.NumberChannels(), dataFormat, format.mSampleRate, nil];
	//fileDescription.text = description;
	//[description release];
}

#pragma mark Playback routines

-(void)stopPlayQueue
{
	player->StopQueue();
	[_self_view setAq: nil];
	//btn_record.enabled = YES;
}

-(void)pausePlayQueue
{
	player->PauseQueue();
	//playbackWasPaused = YES;
}

- (void)stopRecord
{
	// Disconnect our level meter from the audio queue
	[_self_view setAq: nil];
	
	recorder->StopRecord();
	
	// dispose the previous playback queue
	player->DisposeQueue(true);
    
	// now create a new queue for the recorded file
	recordFilePath = (__bridge CFStringRef)[NSTemporaryDirectory() stringByAppendingPathComponent: @"recordedFile.caf"];
	player->CreateQueueForFile(recordFilePath);
    
	// Set the button's state back to "record"
	//btn_record.title = @"Record";
	//btn_play.enabled = YES;
}


#pragma mark AudioSession listeners
void interruptionListener(	void *	inClientData,
                          UInt32	inInterruptionState)
{
	TDTViewController *THIS = (__bridge TDTViewController*)inClientData;
	if (inInterruptionState == kAudioSessionBeginInterruption)
	{
		if (THIS->recorder->IsRunning()) {
			[THIS stopRecord];
		}
		else if (THIS->player->IsRunning()) {
			//the queue will stop itself on an interruption, we just need to update the UI
			[[NSNotificationCenter defaultCenter] postNotificationName:@"playbackQueueStopped" object:THIS];
			THIS->playbackWasInterrupted = YES;
		}
	}
	else if ((inInterruptionState == kAudioSessionEndInterruption) && THIS->playbackWasInterrupted)
	{
		// we were playing back when we were interrupted, so reset and resume now
		THIS->player->StartQueue(true);
		[[NSNotificationCenter defaultCenter] postNotificationName:@"playbackQueueResumed" object:THIS];
		THIS->playbackWasInterrupted = NO;
	}
}

void propListener(	void *                  inClientData,
                  AudioSessionPropertyID	inID,
                  UInt32                  inDataSize,
                  const void *            inData)
{
	TDTViewController *THIS = (__bridge TDTViewController*)inClientData;
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
            
			if (reasonVal == kAudioSessionRouteChangeReason_OldDeviceUnavailable)
			{
				if (THIS->player->IsRunning()) {
					[THIS pausePlayQueue];
					[[NSNotificationCenter defaultCenter] postNotificationName:@"playbackQueueStopped" object:THIS];
				}
			}
            
			// stop the queue if we had a non-policy route change
			if (THIS->recorder->IsRunning()) {
				[THIS stopRecord];
			}
		}
	}
	else if (inID == kAudioSessionProperty_AudioInputAvailable)
	{
//		if (inDataSize == sizeof(UInt32)) {
//			//UInt32 isAvailable = *(UInt32*)inData;
//			// disable recording if input is not available
//			//THIS->btn_record.enabled = (isAvailable > 0) ? YES : NO;
//		}
	}
}

#pragma mark Initialization routines
- (void)awakeFromNib
{
	// Allocate our singleton instance for the recorder & player object
	recorder = new AQRecorder();
	player = new AQPlayer();
    
	OSStatus error = AudioSessionInitialize(NULL, NULL, interruptionListener, (__bridge void*) self);
	if (error) printf("ERROR INITIALIZING AUDIO SESSION! %d\n", (int)error);
	else
	{
		UInt32 category = kAudioSessionCategory_PlayAndRecord;
		error = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
		if (error) printf("couldn't set audio category!");
        
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
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackQueueStopped:) name:@"playbackQueueStopped" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackQueueResumed:) name:@"playbackQueueResumed" object:nil];
    
    [self registerForBackgroundNotifications];
}

# pragma mark Notification routines
- (void)playbackQueueStopped:(NSNotification *)note
{
//	btn_play.title = @"Play";
//	[lvlMeter_in setAq: nil];
//	btn_record.enabled = YES;
}

- (void)playbackQueueResumed:(NSNotification *)note
{
//	btn_play.title = @"Stop";
//	btn_record.enabled = NO;
//	[lvlMeter_in setAq: player->Queue()];
}

#pragma mark background notifications
- (void)registerForBackgroundNotifications
{
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(resignActive)
												 name:UIApplicationWillResignActiveNotification
											   object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(enterForeground)
												 name:UIApplicationWillEnterForegroundNotification
											   object:nil];
}

- (void)resignActive
{
    if (recorder->IsRunning()) [self stopRecord];
    if (player->IsRunning()) [self stopPlayQueue];
    _inBackground = true;
}

- (void)enterForeground
{
    OSStatus error = AudioSessionSetActive(true);
    if (error) printf("AudioSessionSetActive (true) failed");
	_inBackground = false;
}


@end
