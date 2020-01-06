//
//  ViewController.m
//  AltDeploy
//
//  Created by PixelOmer on 4.01.2020.
//  Copyright © 2020 PixelOmer. All rights reserved.
//

#import "ViewController.h"
#import <libimobiledevice/libimobiledevice.h>
#import <libimobiledevice/lockdown.h>
#import <SAMKeychain/SAMKeychain.h>
#import <AltServer/ALTDeviceManager.h>
#import <AltDeploy-Swift.h>
@class ALTDeviceManager;
@protocol Installation;

@implementation ViewController

static NSString *defaultKeyEquivalent;

static void handle_idevice_event(const idevice_event_t *event, void *user_data) {
	ViewController *vc = (__bridge id)user_data;
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

- (void)didClickSaveButton:(NSButton *)sender {
	NSSecureTextField *passwordField = objc_getAssociatedObject(sender, @selector(passwordField));
	NSTextField *usernameField = objc_getAssociatedObject(sender, @selector(usernameField));
	[self.class setAppleIDUsername:usernameField.stringValue password:passwordField.stringValue];
	objc_setAssociatedObject(sender, @selector(passwordField), nil, OBJC_ASSOCIATION_RETAIN);
	objc_setAssociatedObject(sender, @selector(usernameField), nil, OBJC_ASSOCIATION_RETAIN);
	[sender.window close];
}

- (void)askForAppleID {
	NSViewController *vc = [[NSStoryboard storyboardWithName:@"Main" bundle:NSBundle.mainBundle] instantiateControllerWithIdentifier:@"appleid"];
	NSSecureTextField *passwordField = nil;
	NSTextField *usernameField = nil;
	NSButton *button = nil;
	for (__kindof NSView *view in vc.view.subviews) {
		NSLog(@"view: %@", view);
		if (view.tag == 300) button = view;
		else if (view.tag == 200) passwordField = view;
		else if (view.tag == 100) usernameField = view;
	}
	objc_setAssociatedObject(button, @selector(passwordField), passwordField, OBJC_ASSOCIATION_RETAIN);
	objc_setAssociatedObject(button, @selector(usernameField), usernameField, OBJC_ASSOCIATION_RETAIN);
	NSString *username;
	if ([self.class getAppleIDUsername:&username password:nil]) {
		usernameField.stringValue = username;
	}
	button.action = @selector(didClickSaveButton:);
	button.target = self;
	[self presentViewControllerAsModalWindow:vc];
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

- (void)didClickInstallPlugin:(id)sender {
	[self beginMailPluginInstallation];
}

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
	NSMutableArray * __block newOptions = [NSMutableArray new];
	for (NSInteger i=0; i<devices.count; i++) {
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
		if (i == (devices.count-1)) {
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
		newOptions = nil;
	}];
}

- (void)setProgressVisible:(BOOL)visible {
	[self.class dispatchIfNecessary:^{
		self->_progressContainerView.hidden = !visible;
		self->_deviceButton.hidden = visible;
		self->_actionButton.hidden = visible;
		self->_startButton.hidden = visible;
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
	NSString *username, *password;
	if (![self.class getAppleIDUsername:&username password:&password]) {
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
	self.progressVisible = YES;
	ALTDevice *device = [[ALTDevice alloc] initWithName:@"targetDevice" identifier:devices[_deviceButton.indexOfSelectedItem]];
	NSProgress * __block progress = nil;
	progress = [ALTDeviceManager.sharedManager
		installApplicationTo:device
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
					self.progressVisible = NO;
				});
			}
			else {
				dispatch_async(dispatch_get_main_queue(), ^{
					self.progressVisible = NO;
				});
			}
		}
	];
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

+ (BOOL)getAppleIDUsername:(NSString **)usernamePt password:(NSString **)passwordPt {
	NSDictionary *account = [SAMKeychain accountsForService:NSBundle.mainBundle.bundleIdentifier].firstObject;
	if (!account) return NO;
	NSString *password = [SAMKeychain passwordForService:NSBundle.mainBundle.bundleIdentifier account:account[kSAMKeychainAccountKey]];
	if (!password) return NO;
	if (passwordPt) *passwordPt = [password copy];
	if (usernamePt) *usernamePt = [account[kSAMKeychainAccountKey] copy];
	return YES;
}

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

+ (BOOL)setAppleIDUsername:(NSString *)username password:(NSString *)password {
	for (NSDictionary *account in [SAMKeychain accountsForService:NSBundle.mainBundle.bundleIdentifier]) {
		[SAMKeychain deletePasswordForService:NSBundle.mainBundle.bundleIdentifier account:account[kSAMKeychainAccountKey]];
	}
	return [SAMKeychain setPassword:password forService:NSBundle.mainBundle.bundleIdentifier account:username error:nil];
}

- (void)fetchUtilities {
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSArray<NSMenuItem *> * __block menuItems = nil;
		NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"https://api.pixelomer.com/ALTImpactor/v0/utilities"]];
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

- (void)didClickAppleID:(id)sender {
	[self askForAppleID];
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
				selectedUtilityURL = utilityURLs[index-3];
			}
			break;
	}
	_startButton.enabled = (_deviceButton.menu.itemArray.count && _startButton.enabled);
}

- (void)reloadMainMenu {
	pluginMenuItem.title = [
		([self.class isPluginInstalled] ? @"Remove" : @"Install")
		stringByAppendingString:@" Mail Plugin"
	];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	NSMenuItem *item = NSApp.mainMenu.itemArray[0].submenu.itemArray[2];
	item.action = @selector(didClickAppleID:);
	item.target = self;
	pluginMenuItem = NSApp.mainMenu.itemArray[0].submenu.itemArray[3];
	pluginMenuItem.action = @selector(didClickInstallPlugin:);
	pluginMenuItem.target = self;
	[self reloadMainMenu];
	_startButton.target = self;
	_startButton.action = @selector(didClickStart:);
	_actionButton.action = @selector(didChooseAction:);
	_actionButton.target = self;
	defaultKeyEquivalent = [_actionButton itemAtIndex:0].keyEquivalent.copy;
	devices = @[];
	[self didChooseAction:self->_actionButton];
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


@end
