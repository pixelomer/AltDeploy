//
//  ALTPreferencesViewController.h
//  AltDeploy
//
//  Created by PixelOmer on 10.01.2020.
//  Copyright © 2020 PixelOmer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface ALTPreferencesViewController : NSViewController<NSTableViewDelegate, NSTableViewDataSource> {
	NSArray<NSDictionary<NSString *, id> *> *accounts;
	NSArray<NSArray<NSTextFieldCell *> *> *cells;
	NSDateFormatter *dateFormatter;
}
@property (weak) IBOutlet NSButton *modifyButton;
@property (weak) IBOutlet NSButton *removeButton;
@property (weak) IBOutlet NSButton *setAsDefaultButton;
@property (weak) IBOutlet NSTableView *tableView;
@property (weak) IBOutlet NSScrollView *scrollView;
@end

NS_ASSUME_NONNULL_END
