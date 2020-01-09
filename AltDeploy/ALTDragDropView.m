//
//  ALTDragDropView.m
//  AltDeploy
//
//  Created by Darwin on 1/9/20.
//  Copyright © 2020 PixelOmer. All rights reserved.
//

#import "ALTDragDropView.h"

@interface ALTDragDropView () <NSDraggingDestination>

@end

@implementation ALTDragDropView

- (void)awakeFromNib {
    [super awakeFromNib];
    [self registerForDraggedTypes:@[ NSFilenamesPboardType ]];
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    NSPasteboard *pboard;
    NSDragOperation sourceDragMask;
    
    sourceDragMask = [sender draggingSourceOperationMask];
    pboard = [sender draggingPasteboard];
    
    if ([[pboard types] containsObject:NSFilenamesPboardType]) {
        NSArray <NSString *> *files = [pboard propertyListForType:NSFilenamesPboardType];
        if (files.count == 1) {
            if ([[files.firstObject pathExtension] isEqualToString:@"ipa"]) {
                return NSDragOperationCopy;
            }
        }
    }
    
    return NSDragOperationNone;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    NSPasteboard *pboard;
    NSDragOperation sourceDragMask;
    
    sourceDragMask = [sender draggingSourceOperationMask];
    pboard = [sender draggingPasteboard];
    
    if ([[pboard types] containsObject:NSFilenamesPboardType]) {
        NSArray <NSString *> *files = [pboard propertyListForType:NSFilenamesPboardType];
        [self.dropDelegate dragDropView:self droppedWithFilenames:files];
    }
    
    return YES;
}

@end
