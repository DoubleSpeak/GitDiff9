//
//  LNHighlightGutter.m
//  LNXcodeSupport
//
//  Created by User on 08/06/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

#import "LNHighlightGutter.h"

@implementation LNHighlightGutter

//- (void)drawRect:(NSRect)dirtyRect {
//    [super drawRect:dirtyRect];
//
//    // Drawing code here.
//    [[NSColor redColor] setFill];
//    CGFloat height = dirtyRect.size.height;
//    dirtyRect.size.height = 20.;
//    for ( CGFloat y = 0; y< height; y += 40 ) {
//        dirtyRect.origin.y = y;
//        NSRectFill(dirtyRect);
//    }
//}

@end

@implementation LNHighlightFleck {
    NSTrackingArea *trackingArea;
}

static NSMutableArray<LNHighlightFleck *> *queue;

+ (LNHighlightFleck *)fleck {
    if (!queue)
        queue = [NSMutableArray new];
    LNHighlightFleck *fleck = queue.lastObject;
    [queue removeLastObject];
    return fleck ?: [[LNHighlightFleck alloc] initWithFrame:NSZeroRect];
}

+ (void)recycle:(NSArray<LNHighlightFleck *> *)used {
    [queue addObjectsFromArray:used];
}

- (BOOL)isEqual:(LNHighlightFleck *)object {
//    if (![object isKindOfClass:[self class]]) NSLog( @"%@ %@", self, object );
    return ![object isKindOfClass:[self class]] ? [super isEqual:object] :
        self.element == object.element && NSEqualRects(self.frame, object.frame);
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    // Drawing code here.
    dirtyRect.origin.x += 4.;
    dirtyRect.size.width -= 4.;
    [self.element.color setFill];
    NSRectFill(dirtyRect);
}

- (NSTextView *)sourceTextView {
    return self.superview.superview.superview.subviews[0].subviews[0];
}

// https://stackoverflow.com/questions/11188034/mouseentered-and-mouseexited-not-called-in-nsimageview-subclass

- (void)updateTrackingAreas {
    if (trackingArea != nil)
        [self removeTrackingArea:trackingArea];

    int opts = (NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways);
    trackingArea = [[NSTrackingArea alloc] initWithRect:[self bounds]
                                                options:opts
                                                  owner:self
                                               userInfo:nil];
    [self addTrackingArea:trackingArea];
}

// mouseEntered: & mouseExited: implemented in category in LNXcodeSupport.mm

@end
