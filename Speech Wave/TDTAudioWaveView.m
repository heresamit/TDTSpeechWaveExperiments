//
//  TDTAudioWaveView.m
//  Speech Wave
//
//  Created by Amit Chowdhary on 09/07/13.
//  Copyright (c) 2013 Amit Chowdhary. All rights reserved.
//

#import "TDTAudioWaveView.h"

@implementation TDTAudioWaveView

- (id)initWithFrame:(CGRect)frame type:(int)type
{
    self = [super initWithFrame:frame];
    if (self) {
        self.typeOfView = type;
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    const CGFloat strokeColour1[4] = {1.0,.75,1.0,1.0};
    float tempY = self.maxWaveHeight;
    float w = 0;
    float y = rect.size.height;
    float width = rect.size.width;
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGMutablePathRef path = CGPathCreateMutable();
    int count = 0;
    switch (self.typeOfView) {
        case 0:
        case 1:
        case 3:
        {
            //    if (self.maxWaveHeight < 15 && self.maxWaveHeight > 4) {
            //        self.maxWaveHeight = 4;
            //    }
            if (self.typeOfView == 3) CGContextSetLineWidth(context, 2);
            CGContextSetStrokeColor(context,strokeColour1);
            int cycles;
            if (!self.typeOfView) cycles = 6 + arc4random_uniform(5);
            else cycles = 4 + arc4random_uniform(5);;
            if (cycles % 2 == 0) cycles++;
            float x = width/cycles;
            int cyclesByTwo = cycles/2;
            CGContextSetStrokeColor(context,strokeColour1);
            float n;
            while (w <= width) {
                n = cycles - abs(cyclesByTwo - count);
                self.maxWaveHeight = n*n*n*tempY/(cycles*cycles*cycles);
                CGPathMoveToPoint(path, NULL, w,y/2);
                CGPathAddQuadCurveToPoint(path, NULL, w + x/4, y/2 - self.maxWaveHeight, w + x/2, y/2);
                CGPathAddQuadCurveToPoint(path, NULL, w + 3*x/4, y/2 + self.maxWaveHeight, w + x, y/2);
                w+=x;
                count++;
            }
            CGContextAddPath(context, path);
            break;
        }
        case 2:
        {
            int cycles = 4 + arc4random_uniform(5);
            if (cycles % 2 == 0) cycles++;
            float x = width/cycles;
            CGContextSetStrokeColor(context,strokeColour1);
            while (w <= width) {
                CGPathMoveToPoint(path, NULL, w,y/2);
                CGPathAddQuadCurveToPoint(path, NULL, w + x/4, y/2 - self.maxWaveHeight, w + x/2, y/2);
                CGPathAddQuadCurveToPoint(path, NULL, w + 3*x/4, y/2 + self.maxWaveHeight, w + x, y/2);
                w+=x;
            }
            CGContextAddPath(context, path);
            break;
        }
        default:
            break;
    }
    CGContextDrawPath(context, kCGPathStroke);
}

@end
