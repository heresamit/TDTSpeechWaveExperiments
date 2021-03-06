//
//  TDTAudioWaveView.h
//  Speech Wave
//
//  Created by Amit Chowdhary on 09/07/13.
//  Copyright (c) 2013 Amit Chowdhary. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TDTAudioWaveView : UIView

@property (nonatomic) float maxWaveHeight;
@property (nonatomic) int typeOfView;

- (id)initWithFrame:(CGRect)frame type:(int)type;

@end
