//
//  Logging.m
//  iSub
//
//  Created by Benjamin Baron on 1/10/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

#import "Logging.h"
#import "Imports.h"

@implementation Logging

+ (NSString *)latestLogFileName
{
    NSString *logsFolder = [[SavedSettings cachesPath] stringByAppendingPathComponent:@"Logs"];
    NSArray *logFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:logsFolder error:nil];
    
    NSTimeInterval modifiedTime = 0.;
    NSString *fileNameToUse;
    for (NSString *file in logFiles)
    {
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[logsFolder stringByAppendingPathComponent:file] error:nil];
        NSDate *modified = [attributes fileModificationDate];
        if (modified && [modified timeIntervalSince1970] >= modifiedTime)
        {
            // This file is newer
            fileNameToUse = file;
            modifiedTime = [modified timeIntervalSince1970];
        }
    }
    
    return fileNameToUse;
}

+ (NSString *)zipAllLogFiles
{
    NSString *zipFileName = @"iSub Logs.zip";
    NSString *zipFilePath = [[SavedSettings cachesPath] stringByAppendingPathComponent:zipFileName];
    NSString *logsFolder = [[SavedSettings cachesPath] stringByAppendingPathComponent:@"Logs"];
    
    // Delete the old zip if exists
    [[NSFileManager defaultManager] removeItemAtPath:zipFilePath error:nil];
    
    // Zip the logs
    ZKFileArchive *archive = [ZKFileArchive archiveWithArchivePath:zipFilePath];
    NSInteger result = [archive deflateDirectory:logsFolder relativeToPath:[SavedSettings cachesPath] usingResourceFork:NO];
    if (result == zkSucceeded)
    {
        return zipFilePath;
    }
    return nil;
}

+ (void)startRedirectingLogToFile
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndexSafe:0];
    NSString *logPath = [documentsDirectory stringByAppendingPathComponent:@"console.log"];
    freopen([logPath cStringUsingEncoding:NSASCIIStringEncoding],"a+",stderr);
}

+ (void)stopRedirectingLogToFile
{
    freopen("/dev/tty","w",stderr);
}

@end
