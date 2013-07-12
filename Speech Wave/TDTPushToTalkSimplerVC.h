//
//  TDTPushToTalkSimplerVC.h
//  Speech Wave
//
//  Created by Amit Chowdhary on 11/07/13.
//  Copyright (c) 2013 Amit Chowdhary. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface TDTPushToTalkSimplerVC : UIViewController <UIGestureRecognizerDelegate, AVAudioPlayerDelegate>

@property (nonatomic, weak) IBOutlet UISegmentedControl *waveTypePicker;

- (IBAction)playButtonPressed:(id)sender;

@end
