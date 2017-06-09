//
//  LNXcodeSupport.h
//  LNProvider
//
//  Created by John Holdsworth on 31/03/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "LNHighlightGutter.h"

@interface LNXcodeSupport : NSObject
@end

@interface LNXcodeSupport (MouseOver)
- (void)mouseEntered:(LNHighlightFleck *)fleck;
- (void)mouseExited:(LNHighlightFleck *)fleck;
@end

extern LNXcodeSupport *lineNumberPlugin;
