//
//  TDTAudioWaveView.m
//  Speech Wave
//
//  Created by Amit Chowdhary on 09/07/13.
//  Copyright (c) 2013 Amit Chowdhary. All rights reserved.
//

#import "TDTAudioWaveView.h"

@interface TDTAudioWaveView()

@property (nonatomic) float x;

@end

@implementation TDTAudioWaveView

- (void)drawRect:(CGRect)rect
{
    const CGFloat strokeColour1[4] = {1.0,.75,1.0,1.0};
    if (self.maxWaveHeight < 15 && self.maxWaveHeight > 4) {
        self.maxWaveHeight = 4;
    }
    float tempY = self.maxWaveHeight;
    float w = 0;
    float y = rect.size.height;
    float width = rect.size.width;
    int cycles = 6 + arc4random_uniform(5);
    if (cycles%2==0) cycles++;
    self.x = width/cycles;
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGMutablePathRef path = CGPathCreateMutable();
    CGContextSetLineWidth(context, .35);
    CGContextSetStrokeColor(context,strokeColour1);
    int count = 0;
    int cyclesByTwo = cycles/2;
    while (w <= width) {
        float n = cycles - abs(cyclesByTwo - count);
        self.maxWaveHeight = n*n*n*tempY/(cycles*cycles*cycles);
        CGPathMoveToPoint(path, NULL, w,y/2);
        CGPathAddQuadCurveToPoint(path, NULL, w+self.x/4, y/2 - self.maxWaveHeight, w+self.x/2, y/2);
        CGPathAddQuadCurveToPoint(path, NULL, w+3*self.x/4, y/2 + self.maxWaveHeight, w+self.x, y/2);
        w+=self.x;
        count++;
    }
    CGContextAddPath(context, path);
    CGContextDrawPath(context, kCGPathStroke);
}

@end
