//
//  TDTWaveView.m
//  Speech Wave
//
//  Created by Amit Chowdhary on 08/07/13.
//  Copyright (c) 2013 Amit Chowdhary. All rights reserved.
//
#define RAND_FROM_TO(min,max) (min + arc4random_uniform(max + 1))

#import "TDTWaveView.h"
#import <QuartzCore/QuartzCore.h>
#import "CAStreamBasicDescription.h"

@interface TDTWaveView()

@property (nonatomic,strong) NSTimer* updateTimer;
@property (nonatomic) float x;
@property (nonatomic) float yc;

@end

@implementation TDTWaveView

- (id)initWithFrame:(CGRect)frame {
	if (self = [super initWithFrame:frame]) {
		_refreshHz = 1. / 30.;
		_channelNumbers = [[NSArray alloc] initWithObjects:[NSNumber numberWithInt:0], nil];
        _chan_lvls = (AudioQueueLevelMeterState*)malloc(sizeof(AudioQueueLevelMeterState) * [_channelNumbers count]);
        _meterTable = new MeterTable(kMinDBvalue);
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)coder {
	if (self = [super initWithCoder:coder]) {
        _refreshHz = 1. / 50.;
		_channelNumbers = [[NSArray alloc] initWithObjects:[NSNumber numberWithInt:0], nil];
        _chan_lvls = (AudioQueueLevelMeterState*)malloc(sizeof(AudioQueueLevelMeterState) * [_channelNumbers count]);
        _meterTable = new MeterTable(kMinDBvalue);
    }
    return self;
}

- (void)setRefreshHz:(CGFloat)v
{
	_refreshHz = v;
	if (_updateTimer)
	{
		[_updateTimer invalidate];
		_updateTimer = [NSTimer
						scheduledTimerWithTimeInterval:_refreshHz
						target:self
						selector:@selector(_refresh)
						userInfo:nil
						repeats:YES
						];
	}
}

- (void)setAq:(AudioQueueRef)v
{
	if ((_aq == NULL) && (v != NULL))
	{
		if (_updateTimer) [_updateTimer invalidate];
		
		_updateTimer = [NSTimer
						scheduledTimerWithTimeInterval:_refreshHz
						target:self
						selector:@selector(_refresh)
						userInfo:nil
						repeats:YES
						];
	} else if ((_aq != NULL) && (v == NULL)) {
		_peakFalloffLastFire = CFAbsoluteTimeGetCurrent();
	}
	
	_aq = v;
	
	if (_aq)
	{
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
                
				[self setChannelNumbers:chan_array];
				//[chan_array release];
				
				_chan_lvls = (AudioQueueLevelMeterState*)realloc(_chan_lvls, queueFormat.NumberChannels() * sizeof(AudioQueueLevelMeterState));
			}
		}
		catch (CAXException e) {
			char buf[256];
			fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
		}
	} 
}

- (void)_refresh
{
	BOOL success = NO;
    
	// if we have no queue, but still have levels, gradually bring them down
	if (_aq == NULL)
	{
		CGFloat maxLvl = -1.;
		CFAbsoluteTime thisFire = CFAbsoluteTimeGetCurrent();
		// calculate how much time passed since the last draw
		CFAbsoluteTime timePassed = thisFire - _peakFalloffLastFire;
		CGFloat newLevel = self.yc - timePassed * kLevelFalloffPerSec;
        if (newLevel < 0.) newLevel = 0.;
        self.yc = newLevel * 10;
        NSLog(@"----%f",self.yc);
        [self setNeedsDisplay];
		// stop the timer when the last level has hit 0
		if (maxLvl <= 0.)
		{
			[_updateTimer invalidate];
			_updateTimer = nil;
		}
        [self setNeedsDisplay];
		_peakFalloffLastFire = thisFire;
		success = YES;
	} else {
		
		UInt32 data_sz = sizeof(AudioQueueLevelMeterState) * [_channelNumbers count];
		OSErr status = AudioQueueGetProperty(_aq, kAudioQueueProperty_CurrentLevelMeterDB, _chan_lvls, &data_sz);
		if (status != noErr) goto bail;
        
		for (int i=0; i<[_channelNumbers count]; i++)
		{
			NSInteger channelIdx = [(NSNumber *)[_channelNumbers objectAtIndex:i] intValue];
			
			if (channelIdx >= [_channelNumbers count]) goto bail;
			if (channelIdx > 127) goto bail;
		
        if (_chan_lvls)
        {
           self.yc = ceil(_meterTable->ValueAt((float)(_chan_lvls[channelIdx].mAveragePower)) * 300);
            self.yc < 25 ? self.yc = 10 : self.yc++;
           // NSLog(@"%f",self.yc);
           [self setNeedsDisplay];
           success = YES;
        }
            
        }
	}
	
bail:
	if (!success)
	{
        [self setNeedsDisplay];
		//printf("ERROR: metering failed\n");
	}
}


- (void)drawRect:(CGRect)rect
{
//    static BOOL flag = NO;
//    if (!flag) {
//        self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:.02 target:self selector:@selector(setNeedsDisplay) userInfo:nil repeats:YES];
//        flag = YES;
//    }
    //self.yc = RAND_FROM_TO(0, 120);
    
    float w = 0;
    float y = rect.size.height;
    float width = rect.size.width;
    self.x = width/arc4random_uniform(8);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, w,y/2);
    CGPathAddLineToPoint(path, NULL, width, y/2);
    while (w <= width) {
        CGPathMoveToPoint(path, NULL, w,y/2);
        CGPathAddQuadCurveToPoint(path, NULL, w+self.x/4, y/2 - self.yc, w+self.x/2, y/2);
        CGPathAddQuadCurveToPoint(path, NULL, w+3*self.x/4, y/2 + self.yc, w+self.x, y/2);
        CGContextAddPath(context, path);
        CGContextDrawPath(context, kCGPathStroke);
        w+=self.x;
    }
}

@end
