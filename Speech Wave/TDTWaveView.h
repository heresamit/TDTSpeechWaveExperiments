//
//  WaveView.h
//  Speech Wave
//
//  Created by Amit Chowdhary on 08/07/13.
//  Copyright (c) 2013 Amit Chowdhary. All rights reserved.
//


#import <UIKit/UIKit.h>

typedef enum {
    
    kWaveTypeDefault = 0,
    kWaveTypeMirror = 1
    
} WaveType ;

@interface TDTWaveView : UIView

- (TDTWaveView *)initWaveWithType:(WaveType)type frame:(CGRect)frame maxValue:(CGFloat)max minValue:(CGFloat)min;
- (TDTWaveView *)setWaveType:(WaveType)type maxValue:(CGFloat)max minValue:(CGFloat)min;

/*fill the changing value*/
- (void)startWavingWithValue:(CGFloat)value;

/*settings*/
//wave range in y axis，default is established view's height in WaveTypeDefault and height/2 in WaveTypeMirror
- (void)setWaveRange:(CGFloat)range;
//interval in x axis, default is 1.0
- (void)setXInterval:(CGFloat)interval;
//wave line width, default is 1.0, only available in WaveTypeDefault
- (void)setWaveLineWidth:(CGFloat)width;
//wave line color, default is red, only available in WaveTypeDefault
- (void)setWaveLineColor:(CGColorRef)color;
//banchmark, increases in values from bottom to top, default is view's height/2, only available in WaveTypeDefault
- (void)setBanchmarkHeight:(CGFloat)height;
//a boolean value that determines whether the wave is filling, default is NO, only available in WaveTypeDefault
- (void)setFilling:(BOOL)filling;
//filling color, default is blue
- (void)setFillingColor:(CGColorRef)color;
//only available in WaveTypeMirror, the update value under this value will be ignored, to filter noise
- (void)setZeroPointValue:(CGFloat)value;
- (void)setZeroPointLineWidth:(CGFloat)width;

@end
