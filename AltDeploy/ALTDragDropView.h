//
//  ALTDragDropView.h
//  AltDeploy
//
//  Created by Darwin on 1/9/20.
//  Copyright © 2020 PixelOmer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class ALTDragDropView;

@protocol ALTDragDropViewDelegate <NSObject>
- (void)dragDropView:(ALTDragDropView *)view droppedWithFilenames:(NSArray <NSString *> *)filenames;
@end

@interface ALTDragDropView : NSView
@property (nonatomic, weak) id <ALTDragDropViewDelegate> dropDelegate;
@end

NS_ASSUME_NONNULL_END
