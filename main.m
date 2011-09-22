//
//  main.m
//  iSubTESTING
//
//  Created by Ben Baron on 2/27/10.
//  Copyright __MyCompanyName__ 2010. All rights reserved.
//

//#import <UIKit/UIKit.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER

int main(int argc, char *argv[]) {
    
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    int retVal = UIApplicationMain(argc, argv, @"UAApplication", nil);
    [pool release];
    return retVal;
}
