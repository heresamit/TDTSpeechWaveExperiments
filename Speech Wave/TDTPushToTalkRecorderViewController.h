//
//  TDTPushToTalkRecorderViewController.h
//  Speech Wave
//
//  Created by Amit Chowdhary on 09/07/13.
//  Copyright (c) 2013 Amit Chowdhary. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface TDTPushToTalkRecorderViewController : UIViewController <UIGestureRecognizerDelegate, AVAudioPlayerDelegate>

@end

@protocol TDTAudioRecorderUserProtocol <NSObject>

- (void)audioDidFinishRecordingWithData:(NSData *)audioData;

@end