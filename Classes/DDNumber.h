//#import <Foundation/Foundation.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER


@interface NSNumber (DDNumber)

+ (BOOL)parseString:(NSString *)str intoSInt64:(SInt64 *)pNum;
+ (BOOL)parseString:(NSString *)str intoUInt64:(UInt64 *)pNum;

+ (BOOL)parseString:(NSString *)str intoNSInteger:(NSInteger *)pNum;
+ (BOOL)parseString:(NSString *)str intoNSUInteger:(NSUInteger *)pNum;

@end
