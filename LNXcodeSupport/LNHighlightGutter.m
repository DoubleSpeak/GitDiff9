//
//  LNHighlightGutter.m
//  LNXcodeSupport
//
//  Created by User on 08/06/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

#import "LNHighlightGutter.h"
#import "LNXcodeSupport.h"

@implementation LNHighlightFleck {
    NSTrackingArea *trackingArea;
}

static NSMutableArray *queue;

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
    if (![object isKindOfClass:[self class]]) NSLog( @"%@ %@", self, object );
    return [object isKindOfClass:[self class]] && self.yoffset == object.yoffset &&
    self.frame.origin.y == object.frame.origin.y && self.element == object.element;
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

- (void)updateTrackingAreas {
    if (trackingArea != nil) {
        [self removeTrackingArea:trackingArea];
    }

    int opts = (NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways);
    trackingArea = [[NSTrackingArea alloc] initWithRect:[self bounds]
                                                options:opts
                                                  owner:self
                                               userInfo:nil];
    [self addTrackingArea:trackingArea];
}

- (void)mouseEntered:(NSEvent *)theEvent {
    NSLog(@"Mouse entered");
    if (self.element.text)
        [lineNumberPlugin mouseEntered:self];
}

- (void)mouseExited:(NSEvent *)theEvent {
    NSLog(@"Mouse exited");
    [lineNumberPlugin mouseExited:self];
}

@end

@implementation LNHighlightGutter

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    // Drawing code here.
//    [[NSColor redColor] setFill];
//    CGFloat height = dirtyRect.size.height;
//    dirtyRect.size.height = 20.;
//    for ( CGFloat y = 0; y< height; y += 40 ) {
//        dirtyRect.origin.y = y;
//        NSRectFill(dirtyRect);
//    }
}

@end
