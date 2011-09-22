//
//  This class was created by Nonnus,
//  who graciously decided to share it with the CocoaHTTPServer community.
//

//#import <Foundation/Foundation.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER
#import "HTTPConnection.h"


@interface MyHTTPConnection : HTTPConnection
{
	int dataStartIndex;
	NSMutableArray* multipartData;
	BOOL postHeaderOK;
}

- (BOOL)isBrowseable:(NSString *)path;
- (NSString *)createBrowseableIndex:(NSString *)path;

- (BOOL)supportsPOST:(NSString *)path withSize:(UInt64)contentLength;

@end