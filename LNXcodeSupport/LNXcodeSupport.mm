//
//  LNXcodeSupport.m
//  LNProvider
//
//  Created by John Holdsworth on 31/03/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

#import "LNXcodeSupport.h"
#import "LNXcodeSupport-Swift.h"
#import "LNExtensionClientDO.h"
#import "LNHighlightGutter.h"

#import "XcodePrivate.h"
#import <objc/runtime.h>

#define REFRESH_INTERVAL 60.
#define REVERT_DELAY 1.5

static LNXcodeSupport *lineNumberPlugin;

@interface LNXcodeSupport () <LNRegistration, LNConnectionDelegate>

@property NSMutableArray<LNExtensionClient *> *extensions;

@property Class sourceDocClass, scrollerClass;
@property NSTextView *popover;

@property NSButton *undoButton;
@property LNConfig undoConfig;
@property NSString *undoText;
@property NSRange undoRange;

@property NSMutableDictionary<NSString *, void (^)()> *onupdate;

@end

@implementation LNXcodeSupport

+ (void)pluginDidLoad:(NSBundle *)pluginBundle {
    NSString *currentApplicationName = [NSBundle mainBundle].infoDictionary[@"CFBundleName"];
    static dispatch_once_t onceToken;

    if ([currentApplicationName isEqualToString:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            LNXcodeSupport *plugin = lineNumberPlugin = [[self alloc] init];
            plugin.extensions = [NSMutableArray new];
            plugin.onupdate = [NSMutableDictionary new];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
            [self swizzleClass:[NSDocument class]
                      exchange:@selector(_finishSavingToURL:ofType:forSaveOperation:changeCount:)
                          with:@selector(ln_finishSavingToURL:ofType:forSaveOperation:changeCount:)];

            Class aClass = NSClassFromString(@"IDEEditorDocument");
            [self swizzleClass:aClass
                      exchange:@selector(closeToRevert)
                          with:@selector(ln_closeToRevert)];

            aClass = NSClassFromString(@"DVTMarkedScroller");
            [self swizzleClass:aClass
                      exchange:@selector(drawKnobSlotInRect:highlight:)
                          with:@selector(ln_drawKnobSlotInRect:highlight:)];
#pragma clang diagnostic pop

            dispatch_async(dispatch_get_main_queue(), ^{
                plugin.sourceDocClass = NSClassFromString(@"IDEEditorDocument"); //IDESourceCodeDocument");
                plugin.scrollerClass = NSClassFromString(@"SourceEditorScrollView");

                plugin.popover = [[NSTextView alloc] initWithFrame:NSZeroRect];
                NSMutableParagraphStyle *myStyle = [NSMutableParagraphStyle new];
                [myStyle setLineSpacing:5.0];
                [plugin.popover setDefaultParagraphStyle:myStyle];

                plugin.undoButton = [[NSButton alloc] initWithFrame:NSZeroRect];
                plugin.undoButton.bordered = FALSE;

                NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"undo" ofType:@"png"];
                plugin.undoButton.image = [[NSImage alloc] initWithContentsOfFile:path];
                plugin.undoButton.imageScaling = NSImageScaleProportionallyDown;

                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                    NSConnection *registrationDO = [[NSConnection alloc] init];
                    [registrationDO setRootObject:plugin];
                    [registrationDO registerName:XCODE_LINE_NUMBER_REGISTRATION];

                    NSURL *appURL = [[NSBundle bundleForClass:self] URLForResource:@"LNProvider" withExtension:@"app"];
                    [[NSWorkspace sharedWorkspace] openURL:appURL];

                    [[NSRunLoop currentRunLoop] run];
                });
            });
        });
    }
}

+ (void)swizzleClass:(Class)aClass exchange:(SEL)origMethod with:(SEL)altMethod {
    method_exchangeImplementations(class_getInstanceMethod(aClass, origMethod),
                                   class_getInstanceMethod(aClass, altMethod));
}

- (oneway void)registerLineNumberService:(NSString *)serviceName {
    [self deregisterService:serviceName];
    NSLog(@"Registering %@ ...", serviceName);
    [self.extensions addObject:[[LNExtensionClientDO alloc] initServiceName:serviceName delegate:self]];
}

- (oneway void)ping {
}

- (oneway void)deregisterService:(NSString *_Nonnull)serviceName {
    for (LNExtensionClient *extension in self.extensions) {
        if ([extension.serviceName isEqualToString:serviceName]) {
            [self.extensions removeObject:extension];
            break;
        }
    }
}

- (void)updateHighlights:(NSData *)json error:(NSError *)error forFile:(NSString *)filepath {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error)
            [[NSAlert alertWithError:error] runModal];
        else if (auto update = self.onupdate[filepath])
            update();
    });
}

- (void)updateLinenumberHighlightsForFile:(NSString *)filepath {
    for (LNExtensionClient *extension in self.extensions)
        [extension requestHighlightsForFile:filepath];
}

- (void)updateConfig:(LNConfig)config forService:(NSString *_Nonnull)serviceName {
    NSLog(@"%@ updateConfig: %@", serviceName, config);
}

- (void)initialOrOccaisionalLineNumberUpdate:(NSString *)filepath {
    // update if not already in memory or 60 seconds has passed
    for (LNExtensionClient *extension in lineNumberPlugin.extensions) {
        if (extension[filepath].updated < [NSDate timeIntervalSinceReferenceDate] - REFRESH_INTERVAL) {
            if (!extension[filepath])
                extension.highightsByFile[filepath] = [[LNFileHighlights alloc] initWithData:nil
                                                                                     service:extension.serviceName];
            [extension requestHighlightsForFile:filepath];
        }
    }
}

@end

@implementation NSDocument (IDESourceCodeDocument)

- (void)forceLineNumberUpdate {
    if ([self isKindOfClass:lineNumberPlugin.sourceDocClass])
        [lineNumberPlugin updateLinenumberHighlightsForFile:[[self fileURL] path]];
}

// source file is being saved
- (void)ln_finishSavingToURL:(id)a0 ofType:(id)a1 forSaveOperation:(NSUInteger)a2 changeCount:(id)a3 {
    [self ln_finishSavingToURL:a0 ofType:a1 forSaveOperation:a2 changeCount:a3];
    [self forceLineNumberUpdate];
}

// revert on change on disk
- (void)ln_closeToRevert {
    [self ln_closeToRevert];
    [self forceLineNumberUpdate];
}

@end

@implementation NSString (LineNumber)

// https://stackoverflow.com/questions/1085524/how-to-count-the-number-of-lines-in-an-objective-c-string-nsstring

- (NSUInteger)numberOfLines {
    NSUInteger numberOfLines, index, stringLength = [self length];

    for (index = 0, numberOfLines = 0; index < stringLength; numberOfLines++)
        index = NSMaxRange([self lineRangeForRange:NSMakeRange(index, 0)]);

    return numberOfLines;
}

- (NSUInteger)indexForLine:(NSUInteger)lineNumber {
    NSUInteger numberOfLines, index, stringLength = [self length];

    for (index = 0, numberOfLines = 0; index < stringLength && numberOfLines < lineNumber; numberOfLines++)
        index = NSMaxRange([self lineRangeForRange:NSMakeRange(index, 0)]);

    return index;
}

@end

@implementation NSScroller (LineNumber)

- (NSString *)editedDocPath {
    return [[[[(SourceCodeEditorContainerView *)self.superview.superview.superview.superview
               editor] document] fileURL] path];
}

// scroll bar overview
- (void)ln_drawKnobSlotInRect:(CGRect)rect highlight:(BOOL)highlight {
    [self ln_drawKnobSlotInRect:rect highlight:highlight];
    if (![self.superview isKindOfClass:lineNumberPlugin.scrollerClass])
        return;

    NSString *filepath = [self editedDocPath];
    [lineNumberPlugin initialOrOccaisionalLineNumberUpdate:filepath];

    __weak NSScroller *weakSelf = self;
    (lineNumberPlugin.onupdate[filepath] = ^{
        NSLog(@"%@ %@", self, filepath);
        [weakSelf updateLineNumberFlecksFor:filepath];
        [weakSelf updateScrollbarMarkersFor:filepath in:rect];
    })();
}

- (void)updateLineNumberFlecksFor:(NSString *)filepath {
    NSView *floatingContainer = self.superview.subviews[1];
    NSArray *floating = floatingContainer.subviews;
    LNHighlightGutter *highlightGutter = floating.lastObject;
    SourceEditorGutterMarginContentView *lineNumberGutter;

    if (![highlightGutter isKindOfClass:[LNHighlightGutter class]]) {
        lineNumberGutter = floating.lastObject;
        NSRect rect = lineNumberGutter.frame;
        rect.origin.y = 0.;
        rect.origin.x += rect.size.width - 3.;
        rect.size.width = 8.;
        rect.size.height += 5000.;
        highlightGutter = [[LNHighlightGutter alloc] initWithFrame:rect];
        [floatingContainer addSubview:highlightGutter];
    } else
        lineNumberGutter = [floating objectAtIndex:floating.count - 2];

    NSLog(@">>>>>>>>>>> %@ %@ %@", highlightGutter, NSStringFromRect(highlightGutter.frame), lineNumberGutter);
    if (![lineNumberGutter respondsToSelector:@selector(lineNumberLayers)])
        return;

    NSDictionary *lineNumberLayers = [lineNumberGutter lineNumberLayers];
    NSMutableArray<LNHighlightFleck *> *next = [NSMutableArray new];

    for (NSNumber *line in lineNumberLayers) {
        SourceEditorFontSmoothingTextLayer *layer = lineNumberLayers[line];
        NSRect rect = layer.frame;
        rect.origin.x = NSWidth(highlightGutter.frame) - 4.;
        rect.origin.y = NSHeight(highlightGutter.frame) - lineNumberGutter.frame.origin.y - rect.origin.y - 13.;
        rect.size.width = 6.;
        rect.size.height += 5.;
        for (LNExtensionClient *extension in lineNumberPlugin.extensions.reverseObjectEnumerator) {
            if (LNFileHighlights *diffs = extension[filepath]) {
                if (LNHighlightElement *element = diffs[line.integerValue + 1]) {
                    rect.origin.x -= 2.;
                    LNHighlightFleck *fleck = [LNHighlightFleck fleck];
                    fleck.frame = rect;
                    fleck.element = element;
                    fleck.extension = extension;
                    fleck.yoffset = [lineNumberLayers[@(element.start - 1)] frame].origin.y;
                    [next addObject:fleck];
                }
            }
        }
    }

    if (![[highlightGutter subviews] isEqualToArray:next]) {
        [[[highlightGutter subviews] copy] makeObjectsPerformSelector:@selector(removeFromSuperview)];
        for (LNHighlightFleck *fleck in next)
            [highlightGutter addSubview:fleck];
        NSLog(@"REFRESH");
    } else
        [LNHighlightFleck recycle:next];
}

- (void)updateScrollbarMarkersFor:(NSString *)filepath in:(NSRect)rect {
    static Class markerListClass;
    if (!markerListClass) {
        markerListClass = objc_allocateClassPair(NSClassFromString(@"_DVTMarkerList"), "ln_DVTMarkerList", 0);
        class_addMethod(markerListClass, @selector(_recomputeMarkRects), imp_implementationWithBlock(^{}), "v16@0:8");
        objc_registerClassPair(markerListClass);
    }

    _DVTMarkerList *markers = [[markerListClass alloc] initWithSlotRect:rect];
    NSMutableArray *marks = [NSMutableArray new], *markRects = [NSMutableArray new];
    [markers setValue:marks forKey:@"_marks"];
    [markers setValue:markRects forKey:@"_markRects"];

    static NSMutableDictionary<NSString *, NSNumber *> *lineCountCache;
    if (!lineCountCache)
        lineCountCache = [NSMutableDictionary new];

    SourceEditorContentView *editor = self.superview.subviews[0].subviews[0];
    NSInteger lines = lineCountCache[filepath].intValue;
    if (!lines)
        lineCountCache[filepath] = @(lines = [editor.accessibilityValue numberOfLines] ?: 1);

    CGFloat lineHeight = [editor defaultLineHeight];
    CGFloat scale = lines * lineHeight < NSHeight(self.frame) ? lineHeight : NSHeight(self.frame) / lines;

    for (LNExtensionClient *extension in lineNumberPlugin.extensions) {
        if (LNFileHighlights *diffs = extension[filepath]) {
            [diffs foreachHighlightRange:^(NSRange range, LNHighlightElement *element) {
                NSRect rect = NSMakeRect(5., (range.location - 1) * scale, 2., MAX(range.length * scale, 2.));
                [marks addObject:@((range.location - 1.) / lines)];
                [markRects addObject:[NSValue valueWithBytes:&rect objCType:@encode(NSRect)]];
            }];
        }
    }

    [self setValue:markers forKey:@"_diffMarks"];
}

@end

@implementation LNHighlightFleck (LNXcodeSupport)

- (void)mouseEntered:(NSEvent *)theEvent {
    if (!self.element.text)
        return;
    NSLog(@"Mouse entered %@", self);
//    NSUInteger start = self.element.start;
    NSMutableAttributedString *attString = [[self.element attributedText] mutableCopy];
    NSString *undoText = [attString.string copy];

    // https://panupan.com/2012/06/04/trim-leading-and-trailing-whitespaces-from-nsmutableattributedstring/

    // Trim trailing whitespace and newlines.
    NSCharacterSet *charSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSRange range = [attString.string rangeOfCharacterFromSet:charSet
                                                      options:NSBackwardsSearch];
    while (range.length != 0 && NSMaxRange(range) == attString.length) {
        [attString replaceCharactersInRange:range
                                 withString:@""];
        range = [attString.string rangeOfCharacterFromSet:charSet
                                                  options:NSBackwardsSearch];
    }

    NSScrollView *editScroller = (NSScrollView *)self.superview.superview.superview;
    SourceEditorContentView *sourceTextView = editScroller.subviews[0].subviews[0];
    CGFloat lineHeight = [sourceTextView defaultLineHeight];

    NSMutableParagraphStyle *myStyle = [NSMutableParagraphStyle new];
    [myStyle setMinimumLineHeight:lineHeight];
    [attString setAttributes:@{NSParagraphStyleAttributeName: myStyle} range:NSMakeRange(0, attString.length)];

    [lineNumberPlugin.popover removeFromSuperview];
    NSTextView *popover = lineNumberPlugin.popover = [[NSTextView alloc] initWithFrame:NSZeroRect];

    [[popover textStorage] setAttributedString:attString];
    popover.font = [KeyPath objectFor:@"layoutManager.fontTheme.plainTextFont" from:sourceTextView];

    CGFloat width = NSWidth(sourceTextView.frame);
    CGFloat height = lineHeight * [popover.string numberOfLines];

    popover.frame = NSMakeRect(33., self.yoffset - 4., width, height);

    NSLog(@"%@ %f %f - %@ >%@< %@", NSStringFromRect(popover.frame),
          lineHeight, height, self.element.range, undoText, sourceTextView);
    NSString *popoverColor = self.extension.config[LNPopoverColorKey] ?: @"1 0.914 0.662 1";
    popover.backgroundColor = [NSColor colorWithString:popoverColor];
    [sourceTextView addSubview:popover];

    if (self.element.range &&
        sscanf(self.element.range.UTF8String, "%ld %ld", &range.location, &range.length) == 2) {

        lineNumberPlugin.undoConfig = self.extension.config;
        lineNumberPlugin.undoText = undoText;
        lineNumberPlugin.undoRange = range;

        [self performSelector:@selector(showUndoButton) withObject:nil afterDelay:REVERT_DELAY];
    }
}

- (void)mouseExited:(NSEvent *)theEvent {
    NSLog(@"Mouse exited %@", self);
    [lineNumberPlugin.popover removeFromSuperview];
    [lineNumberPlugin.undoButton removeFromSuperview];
}

- (void)showUndoButton {
    NSLog(@"showUndoButton: %@", lineNumberPlugin.popover.superview);
    if (lineNumberPlugin.popover.superview) {
        NSButton *undoButton = lineNumberPlugin.undoButton;
        undoButton.action = @selector(performUndo:);
        undoButton.target = self;

        CGFloat width = NSWidth(self.superview.frame);
        undoButton.frame = NSMakeRect(0, self.frame.origin.y + width, width, width);
        NSLog(@"showUndoButton: %@", NSStringFromRect(undoButton.frame));
        [self.superview addSubview:undoButton];
    }
}

- (void)performUndo:(NSButton *)sender {
    SourceEditorContentView *editor = sender.superview.superview.superview.subviews[0].subviews[0];
    NSString *buffer = editor.accessibilityValue;
    NSRange safeRange = NSMakeRange(lineNumberPlugin.undoRange.location - 1,
                                    MAX(lineNumberPlugin.undoRange.length, 1)), range;
    range.location = [buffer indexForLine:safeRange.location];
    range.length = [buffer indexForLine:safeRange.location + safeRange.length] - range.location;
    NSLog(@"performUndo: %@", [buffer substringWithRange:range]);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    LNConfig config = lineNumberPlugin.undoConfig;
    if ([[NSAlert alertWithMessageText:config[LNApplyTitleKey] ?: @"Line Number Plugin:"
                         defaultButton:config[LNApplyConfirmKey] ?: @"Modify"
                       alternateButton:@"Cancel"
                           otherButton:nil
             informativeTextWithFormat:config[LNApplyPromptKey] ?: @"Apply suggested changes at line %d-%d?",
          (int)safeRange.location + 1, (int)(safeRange.location + safeRange.length)]
         runModal] == NSAlertAlternateReturn)
        return;
#pragma clang diagnostic pop

    [editor setAccessibilitySelectedTextRange:range];
    [editor setAccessibilitySelectedText:lineNumberPlugin.undoText];
}

@end
