//
//  main.m
//  AltDeploy
//
//  Created by PixelOmer on 4.01.2020.
//  Copyright © 2020 PixelOmer. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ViewController.h"
#import <minizip/unzip.h>
#import <spawn.h>

int main(int argc, const char * argv[]) {
	if ((argc >= 2) && !strcmp(argv[1], "-i")) {
		setuid(0);
		seteuid(0);
		NSURL *pluginPath = [NSURL fileURLWithPath:[ViewController altPluginPath]];
		NSLog(@"%@", pluginPath);
		NSURL *mailBundlesURL = [NSURL fileURLWithPath:ViewController.mailBundlesPath];
		NSURL *destinationURL = [mailBundlesURL URLByAppendingPathComponent:pluginPath.lastPathComponent];
		BOOL wasInstalled = [ViewController isPluginInstalled];
		NSLog(@"%d", wasInstalled);
		[NSFileManager.defaultManager removeItemAtURL:destinationURL error:nil]; // Uninstall
		if (!wasInstalled) {
			// Install
			[NSFileManager.defaultManager
				createDirectoryAtURL:mailBundlesURL
				withIntermediateDirectories:YES
				attributes:nil
				error:nil
			];
			[NSFileManager.defaultManager
				copyItemAtURL:pluginPath
				toURL:destinationURL
				error:nil
			];
			for (NSString *file in [NSFileManager.defaultManager subpathsOfDirectoryAtPath:mailBundlesURL.path error:nil]) {
				chown([mailBundlesURL URLByAppendingPathComponent:file].path.UTF8String, 0, 0);
			}
			pid_t pid;
			const char *proc_argv[] = {
				"defaults",
				"write",
				"/Library/Preferences/com.apple.mail",
				"EnableBundles",
				"1",
				NULL
			};
			int success = !posix_spawnp(
				&pid,
				"defaults",
				NULL,
				NULL,
				(char**)&proc_argv[0],
				(char**)&proc_argv[(sizeof(proc_argv)/sizeof(*proc_argv))-1] // Last element of proc_argv, which is always NULL
			);
			if (success) waitpid(pid, NULL, 0);
		}
		return 0;
	}
	return NSApplicationMain(argc, argv);
}
