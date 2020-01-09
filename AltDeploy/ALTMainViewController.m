//
//  ALTMainViewController.m
//  AltDeploy
//
//  Created by PixelOmer on 4.01.2020.
//  Copyright © 2020 PixelOmer. All rights reserved.
//

#import "ALTMainViewController.h"
#import "ALTAddAppleIDViewController.h"
#import "ALTAppleIDManager.h"
#import "ALTDragDropView.h"
#import <SAMKeychain/SAMKeychain.h>
#import <libimobiledevice/libimobiledevice.h>
#import <libimobiledevice/lockdown.h>
#import <AltServer/ALTDeviceManager.h>
#import <AltDeploy-Swift.h>
@class ALTDeviceManager;
@protocol Installation;

@interface ALTMainViewController () <ALTAddAppleIDDelegate, ALTDragDropViewDelegate>

@property (weak) IBOutlet NSTextField *descriptionLabel;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSView *progressContainerView;
@property (weak) IBOutlet NSPopUpButton *accountButton;
@property (weak) IBOutlet NSPopUpButton *deviceButton;
@property (weak) IBOutlet NSPopUpButton *actionButton;
@property (weak) IBOutlet NSButton *startButton;

@end

@implementation ALTMainViewController {
    NSArray <NSDictionary *> *accounts;
    NSArray <NSString *> *devices;
    NSProgress *currentProgress;
    NSArray <NSURL *> *utilityURLs;
    NSURL *selectedFileURL;
    NSURL *selectedUtilityURL;
    NSMenuItem *registerDeviceMenuItem;
    NSMenuItem *mailPluginMenuItem;
}

static NSString *defaultKeyEquivalent;

static void handle_idevice_event(const idevice_event_t *event, void *user_data) {
    ALTMainViewController *vc = (__bridge id)user_data;
    [vc refreshDevices];
}

+ (void)dispatchIfNecessary:(void(^)(void))block {
    if ([NSThread isMainThread]) block();
    else dispatch_async(dispatch_get_main_queue(), block);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(NSProgress *)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    [self.class dispatchIfNecessary:^{
        self->_descriptionLabel.stringValue = object.localizedDescription;
        self->_progressIndicator.doubleValue = object.fractionCompleted;
    }];
}

#pragma mark - Life Cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        @"RegisterDeviceAutomatically": @(YES)
    }];
    
    NSMenuItem *item0 = NSApp.mainMenu.itemArray[0].submenu.itemArray[2];
    item0.action = @selector(didClickAddAppleID:);
    item0.target = self;
    
    NSMenuItem *item1 = NSApp.mainMenu.itemArray[0].submenu.itemArray[3];
    item1.action = @selector(didClickKeychainAccess:);
    item1.target = self;
    
    registerDeviceMenuItem = NSApp.mainMenu.itemArray[0].submenu.itemArray[4];
    registerDeviceMenuItem.action = @selector(didClickRegisterDeviceAutomatically:);
    registerDeviceMenuItem.target = self;
    registerDeviceMenuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"RegisterDeviceAutomatically"] ? NSControlStateValueOn : NSControlStateValueOff;
    
    NSMenuItem *itemHelp = NSApp.mainMenu.itemArray[4].submenu.itemArray[0];
    itemHelp.action = @selector(showHelp:);
    itemHelp.target = self;
    
    mailPluginMenuItem = NSApp.mainMenu.itemArray[0].submenu.itemArray[6];
    mailPluginMenuItem.action = @selector(didClickInstallPlugin:);
    mailPluginMenuItem.target = self;
    
    [self reloadMainMenu];
    
    _startButton.action = @selector(didClickStart:);
    _startButton.target = self;
    
    _actionButton.action = @selector(didChooseAction:);
    _actionButton.target = self;
    
    ((ALTDragDropView *)self.view).dropDelegate = self;
    
    defaultKeyEquivalent = [_actionButton itemAtIndex:0].keyEquivalent.copy;
    
    accounts = @[];
    devices = @[];
    
    [self didChooseAction:self->_actionButton];
    [self refreshAppleIDs];
    [self fetchUtilities];
    
    idevice_error_t error;
    if ((error = idevice_event_subscribe(&handle_idevice_event, (__bridge void *)self)) != IDEVICE_E_SUCCESS) {
        [NSException raise:NSInternalInconsistencyException format:@"Failed to subscribe to the iDevice events (%d)", error];
    }
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    // Update the view, if already loaded.
}

#pragma mark - ALTDragDropViewDelegate

- (void)dragDropView:(ALTDragDropView *)view droppedWithFilenames:(NSArray <NSString *> *)filenames {
    if (filenames.count == 1) {
        self.actionButton.enabled = YES;
        self->selectedFileURL = [NSURL fileURLWithPath:filenames.firstObject];
        [self didChooseAction:self.actionButton];
    }
}

#pragma mark - Menu Actions

- (void)didClickAddAppleID:(NSMenuItem *)sender {
    [self askForAppleID];
}

- (void)didClickKeychainAccess:(NSMenuItem *)sender {
    NSURL *appURL = [NSURL fileURLWithPath:@"/System/Applications/Utilities/Keychain Access.app" isDirectory:YES];
    [[NSWorkspace sharedWorkspace] openURL:appURL];
}

- (void)didClickRegisterDeviceAutomatically:(NSMenuItem *)sender {
    [registerDeviceMenuItem setState:registerDeviceMenuItem.state == NSControlStateValueOn ? NSControlStateValueOff : NSControlStateValueOn];
    [[NSUserDefaults standardUserDefaults] setBool:(registerDeviceMenuItem.state == NSControlStateValueOn) forKey:@"RegisterDeviceAutomatically"];
}

- (void)showHelp:(NSMenuItem *)sender {
    NSURL *helpFile = [NSURL URLWithString:@"https://github.com/pixelomer/AltDeploy"];
    [[NSWorkspace sharedWorkspace] openURL:helpFile];
}

- (void)reloadMainMenu {
    mailPluginMenuItem.title = [
                            ([self.class isPluginInstalled] ? @"Remove" : @"Install")
                            stringByAppendingString:@" Mail Plugin"
                            ];
}

#pragma mark - Mail Plugin

+ (NSString *)altPluginPath {
    return [NSBundle.mainBundle pathForResource:@"AltPlugin" ofType:@"mailbundle"];
}

+ (NSString *)mailBundlesPath {
    return @"/Library/Mail/Bundles";
}

+ (BOOL)isPluginInstalled {
    BOOL isDir;
    return ([NSFileManager.defaultManager fileExistsAtPath:[[self mailBundlesPath] stringByAppendingPathComponent:[self altPluginPath].lastPathComponent] isDirectory:&isDir] && isDir);
}

- (void)beginMailPluginInstallation {
    BOOL isInstalling = ![self.class isPluginInstalled];
    NSString *script = [NSString stringWithFormat:
                        @"do shell script \"%@ -i\" with administrator privileges",
                        NSBundle.mainBundle.executablePath
                        ];
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:script];
    NSAlert *alert = [NSAlert new];
    [alert addButtonWithTitle:@"OK"];
    NSDictionary *error;
    if ([appleScript executeAndReturnError:&error]) {
        alert.messageText = @"Success";
        if (isInstalling) {
            alert.informativeText = @"The mail plugin is now installed. To enable this plugin:\n1) Restart the mail app\n2) In mail preferences, press \"Manage Plug-ins...\"\n3) Enable \"AltPlugin.mailbundle\"\n4) Press \"Apply and Restart Mail\"\nThis application relies on this plugin so this plugin must be enabled. It is also necessary to keep the Mail application open while AltDeploy is running.";
        }
        else {
            alert.informativeText = @"The mail plugin was uninstalled successfully.";
        }
    }
    else {
        alert.messageText = @"Failure";
        alert.informativeText = error.description;
    }
    [alert runModal];
    [self reloadMainMenu];
}

#pragma mark - Apple ID

- (void)askForAppleID {
    ALTAddAppleIDViewController *vc = (ALTAddAppleIDViewController *)[[NSStoryboard storyboardWithName:@"Main" bundle:NSBundle.mainBundle] instantiateControllerWithIdentifier:@"appleid"];
    vc.delegate = self;
    [self presentViewControllerAsModalWindow:vc];
}

- (void)didAddAppleID {
    [self refreshAppleIDs];
}

- (void)refreshAppleIDs {
    accounts = [[ALTAppleIDManager sharedManager] getAllAppleIDs];
    NSMutableArray <NSString *> *newOptions = [NSMutableArray array];
    for (NSDictionary *account in accounts) {
        [newOptions addObject:account[kSAMKeychainAccountKey]];
    }
    [self.class dispatchIfNecessary:^{
        [self.accountButton removeAllItems];
        for (NSString *title in newOptions) {
            [self.accountButton.menu
             addItemWithTitle:title
             action:nil
             keyEquivalent:defaultKeyEquivalent
             ];
        }
        [self didChooseAction:self.actionButton];
    }];
}

- (void)didClickInstallPlugin:(id)sender {
    [self beginMailPluginInstallation];
}

#pragma mark - iOS Devices

- (void)refreshDevices {
    char **udids;
    int udid_count = 0;
    idevice_error_t error = idevice_get_device_list(&udids, &udid_count);
    switch (error) {
        case IDEVICE_E_NO_DEVICE:
            devices = @[];
            break;
        case IDEVICE_E_SUCCESS: {
            NSMutableArray *newArray = [NSMutableArray new];
            for (int i=0; i<udid_count; i++) {
                [newArray addObject:[NSString stringWithCString:udids[i] encoding:NSASCIIStringEncoding]];
            }
            devices = [newArray copy];
            break;
        }
        default:
            [NSException raise:NSInternalInconsistencyException format:@"Failed to get device UDIDs (%d)", error];
    }
    NSMutableArray <NSString *> *newOptions = [NSMutableArray array];
    for (NSInteger i = 0; i < devices.count; i++) {
        NSString *newOption = [NSString stringWithFormat:@"Unknown [%s]", udids[i]];
        idevice_t device;
        if (idevice_new(&device, udids[i]) == IDEVICE_E_SUCCESS) {
            lockdownd_client_t client;
            if (lockdownd_client_new(device, &client, "altimpactor") == LOCKDOWN_E_SUCCESS) {
                char *device_name;
                if (lockdownd_get_device_name(client, &device_name) == LOCKDOWN_E_SUCCESS) {
                    newOption = [NSString stringWithFormat:@"%s [%s]", device_name, udids[i]];
                    free(device_name);
                }
                lockdownd_client_free(client);
            }
            idevice_free(device);
        }
        [newOptions addObject:newOption];
        if (i == (devices.count - 1)) {
            idevice_device_list_free(udids);
        }
    }
    [self.class dispatchIfNecessary:^{
        [self.deviceButton removeAllItems];
        for (NSString *title in newOptions) {
            [self.deviceButton.menu
             addItemWithTitle:title
             action:nil
             keyEquivalent:defaultKeyEquivalent
             ];
        }
        [self didChooseAction:self.actionButton];
    }];
}

#pragma mark - File Actions

- (void)chooseIPA {
    [_actionButton.menu performActionForItemAtIndex:0];
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowedFileTypes = @[@"ipa"];
    panel.allowsMultipleSelection = NO;
    panel.canChooseDirectories = NO;
    panel.canChooseFiles = YES;
    panel.resolvesAliases = YES;
    _actionButton.enabled = NO;
    _startButton.enabled = NO;
    [panel beginWithCompletionHandler:^(NSModalResponse result) {
        [self.class dispatchIfNecessary:^{
            self->_actionButton.enabled = YES;
            if (result == NSModalResponseOK) {
                self->selectedFileURL = panel.URLs.firstObject;
            }
            [self didChooseAction:self->_actionButton];
        }];
    }];
}

- (void)fetchUtilities {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray<NSMenuItem *> * __block menuItems = nil;
        NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"https://api.pixelomer.com/ALTImpactor/v1/utilities"]];
        if (data) {
            NSError *error;
            NSArray *array = [NSJSONSerialization
                              JSONObjectWithData:data
                              options:0
                              error:&error
                              ];
            if ([array isKindOfClass:[NSArray class]] && !error) {
                NSMutableArray *mutableMenuItems = nil;
                NSMutableArray *URLs = nil;
                for (NSDictionary *dict in array) {
                    if (![dict isKindOfClass:[NSDictionary class]]) continue;
                    if (![dict[@"name"] isKindOfClass:[NSString class]]) continue;
                    if (![dict[@"url"] isKindOfClass:[NSString class]]) continue;
                    if (!mutableMenuItems) mutableMenuItems = [NSMutableArray new];
                    if (!URLs) URLs = [NSMutableArray new];
                    NSMenuItem *item = [[NSMenuItem alloc]
                                        initWithTitle:dict[@"name"]
                                        action:nil
                                        keyEquivalent:defaultKeyEquivalent
                                        ];
                    item.enabled = YES;
                    [mutableMenuItems addObject:item];
                    [URLs addObject:[NSURL URLWithString:dict[@"url"]]];
                }
                self->utilityURLs = [URLs copy];
                menuItems = [mutableMenuItems copy];
            }
        }
        if (!menuItems) {
            menuItems = @[
                [[NSMenuItem alloc]
                 initWithTitle:@"Failed to load utlities."
                 action:nil
                 keyEquivalent:defaultKeyEquivalent
                 ]
            ];
            menuItems.firstObject.enabled = NO;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_actionButton.menu removeItemAtIndex:3];
            for (NSMenuItem *item in menuItems) {
                [self->_actionButton.menu addItem:item];
            }
        });
    });
}

- (void)didChooseAction:(NSPopUpButton *)sender {
    if (sender != _actionButton) return;
    NSInteger index = _actionButton.indexOfSelectedItem;
    switch (index) {
        case 0:
            if (selectedFileURL) {
                [_actionButton itemAtIndex:0].title = selectedFileURL.lastPathComponent;
            }
            else {
                [_actionButton itemAtIndex:0].title = @"No file selected.";
            }
            _startButton.enabled = !!selectedFileURL;
            break;
        case 1: {
            // Browse
            [self chooseIPA];
            break;
        }
        case 2:
            // Separator
            _startButton.enabled = NO;
            break;
        default:
            // Utilities
            if (!(_startButton.enabled = !!utilityURLs)) {
                selectedUtilityURL = nil;
            }
            else {
                selectedUtilityURL = utilityURLs[index - 3];
            }
            break;
    }
    _startButton.enabled = (_deviceButton.menu.itemArray.count > 0 && _startButton.enabled);
}

#pragma mark - Main Progress

- (void)setProgressVisible:(BOOL)visible {
    [self.class dispatchIfNecessary:^{
        self.progressContainerView.hidden = !visible;
        self.accountButton.hidden = visible;
        self.deviceButton.hidden = visible;
        self.actionButton.hidden = visible;
        self.startButton.hidden = visible;
    }];
}

- (void)didClickStart:(id)sender {
    if (sender != _startButton) return;
    if (![self.class isPluginInstalled]) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = @"Missing Mail Plugin";
        alert.informativeText = @"The mail plugin is necessary for this app to function. Install it now?";
        [alert addButtonWithTitle:@"Install"];
        [alert addButtonWithTitle:@"Cancel"];
        NSModalResponse response = [alert runModal];
        if (response == NSAlertFirstButtonReturn) {
            [self beginMailPluginInstallation];
        }
        return;
    }
    if (_accountButton.indexOfSelectedItem < 0) {
        [self askForAppleID];
        return;
    }
    NSString *username = accounts[_accountButton.indexOfSelectedItem][kSAMKeychainAccountKey];
    NSString *password = [[ALTAppleIDManager sharedManager] passwordOfAppleID:username];
    if (!username || !password) {
        [self askForAppleID];
        return;
    }
    NSURL *fileURL = nil;
    if (_actionButton.indexOfSelectedItem == 0) {
        // Selecteed IPA
        fileURL = selectedFileURL;
    }
    else if (_actionButton.indexOfSelectedItem > 2) {
        // Utilitites
        fileURL = selectedUtilityURL;
    }
    if (!fileURL) {
        _startButton.enabled = NO;
        return;
    }
    [self setProgressVisible:YES];
    ALTDeviceManager.sharedManager.registerDeviceAutomatically = registerDeviceMenuItem.state == NSControlStateValueOn;
    ALTDevice *device = [[ALTDevice alloc] initWithName:@"targetDevice" identifier:devices[_deviceButton.indexOfSelectedItem]];
    NSProgress *progress = nil;
    progress = [ALTDeviceManager.sharedManager installApplicationTo:device
                                                            appleID:username
                                                           password:password
                                                     applicationURL:fileURL
                                                         completion:^(NSError * _Nullable error) {
        [progress removeObserver:self forKeyPath:@"localizedDescription"];
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *alert = [NSAlert alertWithError:error];
                [alert addButtonWithTitle:@"Dismiss"];
                [alert runModal];
                [self setProgressVisible:NO];
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setProgressVisible:NO];
            });
        }
    }];
    // FIXME: Race condition
    // If the completionHandler is called before the addObserver call,
    // the app will crash.
    [self observeValueForKeyPath:nil ofObject:progress change:nil context:nil];
    [progress
     addObserver:self
     forKeyPath:@"localizedDescription"
     options:0
     context:nil
     ];
}

@end
