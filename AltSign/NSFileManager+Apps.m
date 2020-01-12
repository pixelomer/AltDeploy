//
//  NSFileManager+Apps.m
//  AltSign
//
//  Created by Riley Testut on 5/28/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import "NSFileManager+Apps.h"
#import <spawn.h>
#import "NSError+ALTErrors.h"

#define READ_BUFFER_SIZE 8192
#define MAX_FILENAME 512

@implementation NSFileManager (Apps)

- (nullable NSURL *)unzipAppBundleAtURL:(NSURL *)ipaURL toDirectory:(NSURL *)directoryURL error:(NSError **)error
{
	// I tried other options. This is the only one that worked flawlessly. Feel free to make a pull request with a better option.
	pid_t pid;
	directoryURL = [directoryURL URLByAppendingPathExtension:@"app"];
	[NSFileManager.defaultManager removeItemAtURL:directoryURL error:nil];
	NSURL *extractedURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString]];
	const char *__argv[] = {
		"/usr/bin/unzip",
		ipaURL.path.UTF8String,
		"-d",
		extractedURL.path.UTF8String,
		NULL
	};
	const char *__envp[] = {
		"PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
		NULL
	};
	int status = posix_spawn(&pid, "/usr/bin/unzip", nil, nil, (char * const *)__argv, (char * const *)__envp);
	if (status == 0) {
		status = 0;
		waitpid(pid, &status, 0);
		int returnValue = WEXITSTATUS(status);
		if (returnValue != 0) {
			if (error) *error = [NSError errorWithDomain:@"com.pixelomer.altdeploy.UnzipError" code:returnValue userInfo:@{
				NSLocalizedDescriptionKey : @"unzip command returned a non-zero exit code."
			}];
			return nil;
		}
		BOOL isDir;
		if (![NSFileManager.defaultManager fileExistsAtPath:[extractedURL.path stringByAppendingPathComponent:@"Payload"] isDirectory:&isDir] || !isDir) {
			if (error) *error = [NSError errorWithDomain:@"com.pixelomer.altdeploy.UnzipError" code:-2 userInfo:@{
				NSLocalizedDescriptionKey : @"IPA does not contain a Payload directory."
			}];
			return nil;
		}
		NSURL *appURL = nil;
		for (NSURL *url in [NSFileManager.defaultManager contentsOfDirectoryAtURL:[extractedURL URLByAppendingPathComponent:@"Payload"] includingPropertiesForKeys:nil options:0 error:nil]) {
			if ([url.lastPathComponent hasSuffix:@".app"] && [NSFileManager.defaultManager fileExistsAtPath:url.path isDirectory:&isDir] && isDir) {
				if (appURL) {
					if (error) *error = [NSError errorWithDomain:@"com.pixelomer.altdeploy.UnzipError" code:-3 userInfo:@{
						NSLocalizedDescriptionKey : @"Payload contains multiple applications."
					}];
					return nil;
				}
				appURL = url;
				[NSFileManager.defaultManager moveItemAtURL:url toURL:directoryURL error:nil];
			}
		}
		[NSFileManager.defaultManager removeItemAtURL:[directoryURL URLByAppendingPathComponent:@"_CodeSignature"] error:nil];
		return directoryURL;
	}
	else {
		if (error) *error = [NSError errorWithDomain:@"com.pixelomer.altdeploy.UnzipError" code:status userInfo:@{
			NSLocalizedDescriptionKey : @"Failed to execute the unzip command."
		}];
	}
	return nil;
}

- (NSURL *)zipAppBundleAtURL:(NSURL *)appBundleURL error:(NSError **)error
{
	NSURL *ipaURL = [NSURL fileURLWithPath:[[NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString] stringByAppendingPathExtension:@"ipa"]];
	pid_t pid;
	int errorCode = -1;
	const char *__argv[] = {
		"/usr/bin/zip",
		"-r",
		ipaURL.path.UTF8String,
		appBundleURL.path.UTF8String,
		NULL
	};
	const char *__envp[] = {
		"PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
		NULL
	};
	int status = posix_spawn(&pid, "/usr/bin/zip", nil, nil, (char * const *)__argv, (char * const *)__envp);
	if (status == 0) {
		status = 0;
		waitpid(pid, &status, 0);
		errorCode = WEXITSTATUS(status);
		if (errorCode == 0) return ipaURL;
	}
	if (error) *error = [NSError errorWithDomain:@"com.pixelomer.altdeploy.UnzipError" code:status userInfo:@{
		NSLocalizedDescriptionKey : @"Failed to execute the zip command."
	}];
	return nil;
}

@end
