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

@interface TDTWaveView()

@property (nonatomic,strong) NSTimer* timer;
@property (nonatomic) float x;
@property (nonatomic) float yc;

@end

@implementation TDTWaveView

- (void)drawRect:(CGRect)rect
{
    static BOOL flag = NO;
    if (!flag) {
        self.timer = [NSTimer scheduledTimerWithTimeInterval:.02 target:self selector:@selector(setNeedsDisplay) userInfo:nil repeats:YES];
        flag = YES;
    }
    self.yc = RAND_FROM_TO(0, 120);
    float w = 0;
    float y = rect.size.height;
    float width = rect.size.width;
    self.x = width/arc4random_uniform(6);
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
