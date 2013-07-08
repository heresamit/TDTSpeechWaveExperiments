//
//  TDTWaveView.h
//  Speech Wave
//
//  Created by Amit Chowdhary on 08/07/13.
//  Copyright (c) 2013 Amit Chowdhary. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioQueue.h>
#import "CAXException.h"
#import "MeterTable.h"

@interface TDTWaveView : UIView {
    CFAbsoluteTime				_peakFalloffLastFire;
    AudioQueueLevelMeterState	*_chan_lvls;
    MeterTable					*_meterTable;
}

@property (nonatomic) AudioQueueRef aq; // The AudioQueue object
@property (nonatomic) CGFloat refreshHz; // How many times per second to redraw
@property (nonatomic) NSArray *channelNumbers; // Array of NSNumber objects: The indices of the channels to display in this meter

@end
