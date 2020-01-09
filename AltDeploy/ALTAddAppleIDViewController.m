//
//  ALTAddAppleIDViewController.m
//  AltDeploy
//
//  Created by Darwin on 1/9/20.
//  Copyright © 2020 PixelOmer. All rights reserved.
//

#import "ALTAddAppleIDViewController.h"
#import "ALTAppleIDManager.h"

@interface ALTAddAppleIDViewController ()
@property (weak) IBOutlet NSTextField *usernameField;
@property (weak) IBOutlet NSSecureTextField *passwordField;
@property (weak) IBOutlet NSButton *saveButton;
@end

@implementation ALTAddAppleIDViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *username = nil;
    if ([[ALTAppleIDManager sharedManager] getLastAppleID:&username]) {
        [self.usernameField setStringValue:username];
    }
}

- (IBAction)didClickButton:(NSButton *)sender {
    if (!self.passwordField.stringValue.length) {
        return;
    }
    [[ALTAppleIDManager sharedManager] addAppleID:self.usernameField.stringValue password:self.passwordField.stringValue];
    [self.view.window close];
    [self.delegate didAddAppleID];
}

@end
