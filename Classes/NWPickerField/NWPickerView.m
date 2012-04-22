//
//  NWPickerView.m
//  NWFieldPicker
//
//  Created by Scott Andrew on 9/28/09.
//  Copyright 2009 New Wave Digital Media. All rights reserved.
//
//  This source code is provided under BSD license, the conditions of which are listed below. 
//
//  Redistribution and use in source and binary forms, with or without modification, are permitted 
//  provided that the following conditions are met:
//
//  • Redistributions of source code must retain the above copyright notice, this list of 
//   conditions and the following disclaimer.
//  • Redistributions in binary form must reproduce the above copyright notice, this list of conditions
//   and the following disclaimer in the documentation and/or other materials provided with the distribution.
//  • Neither the name of Positive Spin Media nor the names of its contributors may be used to endorse or 
//   promote products derived from this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED 
//  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A 
//  PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY 
//  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, 
//  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE 
//  OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH 
//  DAMAGE.

#import "NWPickerView.h"
#import "NWPickerField.h"
#import "NSNotificationCenter+MainThread.h"

@interface NWPickerField(PickerViewExtension)
// call in our picker field to now if control was hidden or not. Used
// to toggle indicator in the field.
-(void) pickerViewHidden:(BOOL)wasHidden;

@end

@implementation NWPickerView

@synthesize hiddenFrame;
@synthesize visibleFrame;
@synthesize field;

-(void) dealloc {
    field = nil;
}


-(BOOL)resignFirstResponder {
	// when we resign the first responder we want to hide our selves.
    if (!self.hidden)
		[self toggle];
	
    // do what ever the control needs to do normally.
	return [super resignFirstResponder];
}

-(BOOL) canBecomeFirstResponder {
	// we need to allow this control to become the first responder
    // this allows us to hide what ever keyboards are up and allows us
    // to get a resign when we lose focus.
    return YES;
}

-(void) sendNotification:(NSString*) notificationName {
	NSDictionary* userInfo = [NSDictionary dictionaryWithObject:[NSValue valueWithCGRect:self.bounds] forKey:UIPickerViewBoundsUserInfoKey];
	[NSNotificationCenter postNotificationToMainThreadWithName:notificationName object:self.field userInfo:userInfo];
}

-(void) toggle {
	if (self.hidden) {
		self.hidden = NO;
		
        // this will toggle the indicator.
        [field pickerViewHidden:NO];
        
        // send the notification that we are about to show.
		[self sendNotification:UIPickerViewWillShownNotification];
		
		// Make sure this is the top view so it covers everything
		[self.superview bringSubviewToFront:self];
		
        // set up our animation
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:.25];
		[self setFrame:visibleFrame];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(slideInAnimationDidStop:finished:context:)];
		[UIView commitAnimations];
		
        // become the first responder.
		[self becomeFirstResponder];
	}
	else {
         // this will toggle the indicator.
        [field pickerViewHidden:YES];
        
        // send our notification that we are about to hide.
		[self sendNotification:UIPickerViewWillHideNotification];
		
        // setup our animation
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:.25];
		[self setFrame:hiddenFrame];	
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(slideOutAnimationDidStop:finished:context:)];
		[UIView commitAnimations];

	}
	
}

- (void)slideOutAnimationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
	self.hidden = YES;
    [self sendNotification:UIPickerViewDidHideNotification];
}

- (void)slideInAnimationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
	[self sendNotification:UIPickerViewDidShowNotification];
}


@end
