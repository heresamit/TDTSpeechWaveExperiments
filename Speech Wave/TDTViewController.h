//
//  TDTViewController.h
//  Speech Wave
//
//  Created by Amit Chowdhary on 08/07/13.
//  Copyright (c) 2013 Amit Chowdhary. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AQPlayer.h"
#import "AQRecorder.h"
#import <Foundation/Foundation.h>

@interface TDTViewController : UIViewController {
    AQRecorder*					recorder;
    AQPlayer*					player;
    CFStringRef					recordFilePath;
    BOOL						playbackWasInterrupted;
	BOOL						playbackWasPaused;
	
}
@property (nonatomic, assign)	BOOL                inBackground;
@end
