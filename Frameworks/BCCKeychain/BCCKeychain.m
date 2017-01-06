//
//  BCCKeychain.m
//
//  Created by Buzz Andersen on 10/20/08.
//  Based partly on code by Jonathan Wight, Jon Crosby, and Mike Malone.
//  Copyright 2013 Brooklyn Computer Club. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//


#import "BCCKeychain.h"
#import <Security/Security.h>


#define USE_MAC_KEYCHAIN_API !TARGET_OS_IPHONE || (TARGET_IPHONE_SIMULATOR && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_0)

static NSString *BCCKeychainErrorDomain = @"BCCKeychainErrorDomain";


#if USE_MAC_KEYCHAIN_API

@interface BCCKeychain ()

+ (SecKeychainItemRef)getKeychainItemReferenceForUsername:(NSString *)username andServiceName:(NSString *)serviceName error:(NSError **)error;

@end

#endif


@implementation BCCKeychain

#pragma mark - Mac Keychain Implementation

#if USE_MAC_KEYCHAIN_API

+ (NSString *)getPasswordStringForUsername:(NSString *)username andServiceName:(NSString *)serviceName error:(NSError **)error
{
    NSData *passwordData = [BCCKeychain getPasswordDataForUsername:username andServiceName:serviceName error:error];
    return [[NSString alloc] initWithData:passwordData encoding:NSUTF8StringEncoding];
}

+ (NSData *)getPasswordDataForUsername:(NSString *)username andServiceName:(NSString *)serviceName error:(NSError **)error
{
	if (!username || !serviceName) {
        if (error) {
            *error = [NSError errorWithDomain:BCCKeychainErrorDomain code:-2000 userInfo:nil];
        }
		
        return nil;
	}
	
	SecKeychainItemRef item = [BCCKeychain getKeychainItemReferenceForUsername:username andServiceName:serviceName error:error];
	if ((error && *error) || !item) {
		return nil;
	}
	
	// from Advanced Mac OS X Programming, ch. 16
    UInt32 passwordByteLength;
    void *passwordBytes;
    SecKeychainAttribute attributes[8];
    SecKeychainAttributeList list;
	
    attributes[0].tag = kSecAccountItemAttr;
    attributes[1].tag = kSecDescriptionItemAttr;
    attributes[2].tag = kSecLabelItemAttr;
    attributes[3].tag = kSecModDateItemAttr;
    
    list.count = 4;
    list.attr = attributes;
    
    OSStatus status = SecKeychainItemCopyContent(item, NULL, &list, &passwordByteLength, &passwordBytes);
	
	if (status != noErr) {
		if (error) {
            *error = [NSError errorWithDomain:BCCKeychainErrorDomain code:status userInfo:nil];
        }
        
		return nil;
    }
    
	NSData *passwordData = [NSData dataWithBytes:passwordBytes length:passwordByteLength];
	
	SecKeychainItemFreeContent(&list, passwordBytes);
    
    CFRelease(item);
    
    return passwordData;
}

+ (BOOL)storeUsername:(NSString *)username andPasswordString:(NSString *)passwordString forServiceName:(NSString *)serviceName updateExisting:(BOOL)updateExisting error:(NSError **)error
{
    return [BCCKeychain storeUsername:username andPasswordData:[passwordString dataUsingEncoding:NSUTF8StringEncoding] forServiceName:serviceName updateExisting:updateExisting error:error];
}

+ (BOOL)storeUsername:(NSString *)username andPasswordData:(NSData *)passwordData forServiceName:(NSString *)serviceName updateExisting:(BOOL)updateExisting error:(NSError **)error
{
	if (!username || !passwordData || !serviceName) {
        if (error) {
            *error = [NSError errorWithDomain:BCCKeychainErrorDomain code:-2000 userInfo:nil];
        }
		return NO;
	}
	
	if (error) {
		*error = nil;
	}

	OSStatus status = noErr;
	
	SecKeychainItemRef item = [BCCKeychain getKeychainItemReferenceForUsername:username andServiceName:serviceName error:error];
	
	if (item) {
		status = SecKeychainItemModifyAttributesAndData(item,
                                                        NULL,
                                                        (UInt32)[passwordData length],
                                                        [passwordData bytes]);
		
		CFRelease(item);
	} else {
		status = SecKeychainAddGenericPassword(NULL,
                                               (UInt32)[serviceName lengthOfBytesUsingEncoding:NSUTF8StringEncoding], 
                                               [serviceName UTF8String],
                                               (UInt32)[username lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
                                               [username UTF8String],
                                               (UInt32)[passwordData length],
                                               [passwordData bytes],
                                               NULL);
	}
	
	if (status != noErr) {
		if (error) {
            *error = [NSError errorWithDomain:BCCKeychainErrorDomain code:status userInfo:nil];
        }
        return NO;
	}
    
    return YES;
}

+ (BOOL)deleteItemForUsername:(NSString *)username andServiceName:(NSString *)serviceName error:(NSError **)error
{
	if (!username || !serviceName) {
        if (error) {
            *error = [NSError errorWithDomain:BCCKeychainErrorDomain code:2000 userInfo:nil];
        }
		return NO;
	}
	
	if (error) {
		*error = nil;
	}
	
	SecKeychainItemRef item = [BCCKeychain getKeychainItemReferenceForUsername:username andServiceName:serviceName error:error];
	if ((error && *error) || !item) {
        return NO;
	}
	
	OSStatus status = SecKeychainItemDelete(item);
		
    CFRelease(item);
	
	if (status != noErr) {
        if (error) {
            *error = [NSError errorWithDomain:BCCKeychainErrorDomain code:status userInfo:nil];
        }
        return NO;
	}
    
    return YES;
}

// NOTE: Item reference passed back by reference must be released!
+ (SecKeychainItemRef)getKeychainItemReferenceForUsername:(NSString *)username andServiceName:(NSString *)serviceName error:(NSError **)error
{
	if (!username || !serviceName) {
		*error = [NSError errorWithDomain:BCCKeychainErrorDomain code:-2000 userInfo:nil];
		return nil;
	}
	
	if (error) {
		*error = nil;
	}
    
	SecKeychainItemRef item;
	
	OSStatus status = SecKeychainFindGenericPassword(NULL,
                                                     (UInt32)[serviceName lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
                                                     [serviceName UTF8String],
                                                     (UInt32)[username lengthOfBytesUsingEncoding:NSUTF8StringEncoding],
                                                     [username UTF8String],
                                                     NULL,
                                                     NULL,
                                                     &item);
	
	if (status != noErr) {
		if (status != errSecItemNotFound && error) {
			*error = [NSError errorWithDomain:BCCKeychainErrorDomain code:status userInfo:nil];
		}
		
		return nil;		
	}
	
	return item;
}

#else

#pragma mark - iOS Keychain Implementation

+ (NSString *)getPasswordStringForUsername:(NSString *)username andServiceName:(NSString *)serviceName error:(NSError **)error
{
    NSData *passwordData = [BCCKeychain getPasswordDataForUsername:username andServiceName:serviceName error:error];
    return [[NSString alloc] initWithData:passwordData encoding:NSUTF8StringEncoding];
}

+ (NSData *)getPasswordDataForUsername:(NSString *)username andServiceName:(NSString *)serviceName error:(NSError **)error
{
	if (!username || !serviceName) {
		if (error) {
			*error = [NSError errorWithDomain:BCCKeychainErrorDomain code:-2000 userInfo:nil];
		}
		return nil;
	}
	
	/*if (error != nil) {
		*error = nil;
	}*/
    
	// Set up a query dictionary with the base query attributes: item type (generic), username, and service
	
	NSArray *keys = [[NSArray alloc] initWithObjects:(__bridge NSString *)kSecClass, kSecAttrAccount, kSecAttrService, nil];
	NSArray *objects = [[NSArray alloc] initWithObjects:(__bridge NSString *)kSecClassGenericPassword, username, serviceName, nil];
	
	NSMutableDictionary *query = [[NSMutableDictionary alloc] initWithObjects:objects forKeys:keys];
	
	// First do a query for attributes, in case we already have a Keychain item with no password data set.
	// One likely way such an incorrect item could have come about is due to the previous (incorrect)
	// version of this code (which set the password as a generic attribute instead of password data).
	
	CFDataRef attributeResult = nil;
	NSMutableDictionary *attributeQuery = [query mutableCopy];
	[attributeQuery setObject:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnAttributes];
	OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)attributeQuery, (CFTypeRef *)&attributeResult);
	
	if (status != noErr) {
		// No existing item found--simply return nil for the password
		if (status != errSecItemNotFound && error) {
			//Only return an error if a real exception happened--not simply for "not found."
			*error = [NSError errorWithDomain:BCCKeychainErrorDomain code:status userInfo:nil];
		}
		
		return nil;
	}
	
	// We have an existing item, now query for the password data associated with it.
	
	CFDataRef resultData = nil;
	NSMutableDictionary *passwordQuery = [query mutableCopy];
	[passwordQuery setObject:(id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    
	status = SecItemCopyMatching((__bridge CFDictionaryRef)passwordQuery, (CFTypeRef *)&resultData);
	
	if (status != noErr) {
		if (status == errSecItemNotFound) {
			// We found attributes for the item previously, but no password now, so return a special error.
			// Users of this API will probably want to detect this error and prompt the user to
			// re-enter their credentials.  When you attempt to store the re-entered credentials
			// using storeUsername:andPassword:forServiceName:updateExisting:error
			// the old, incorrect entry will be deleted and a new one with a properly encrypted
			// password will be added.
			if (error) {
				*error = [NSError errorWithDomain:BCCKeychainErrorDomain code:-1999 userInfo:nil];
			}
		} else if (error) {
			// Something else went wrong. Simply return the normal Keychain API error code.
            *error = [NSError errorWithDomain:BCCKeychainErrorDomain code:status userInfo:nil];
		}
		
		return nil;
	}
    
	NSData *passwordData = nil;
    
	if (resultData) {
		passwordData = (__bridge NSData *)(resultData);
	}
	else if (error) {
		// There is an existing item, but we weren't able to get password data for it for some reason,
		// Possibly as a result of an item being incorrectly entered by the previous code.
		// Set the -1999 error so the code above us can prompt the user again.
        *error = [NSError errorWithDomain:BCCKeychainErrorDomain code:-1999 userInfo:nil];
	}
    
	return passwordData;
}

+ (BOOL)storeUsername:(NSString *)username andPasswordString:(NSString *)passwordString forServiceName:(NSString *)serviceName updateExisting:(BOOL)updateExisting error:(NSError **)error
{
    return [BCCKeychain storeUsername:username andPasswordData:[passwordString dataUsingEncoding:NSUTF8StringEncoding] forServiceName:serviceName updateExisting:updateExisting error:error];
}

+ (BOOL)storeUsername:(NSString *)username andPasswordData:(NSData *)passwordData forServiceName:(NSString *)serviceName updateExisting:(BOOL)updateExisting error:(NSError **)error
{		
	if (!username || !passwordData || !serviceName) {
		if (error) {
			*error = [NSError errorWithDomain:BCCKeychainErrorDomain code:-2000 userInfo:nil];
		}
		
        return NO;
	}
	
	// See if we already have a password entered for these credentials.
	NSError *getError = nil;
	NSData *existingPassword = [BCCKeychain getPasswordDataForUsername:username andServiceName:serviceName error:&getError];
    
	if ([getError code] == -1999) {
		// There is an existing entry without a password properly stored (possibly as a result of the previous incorrect version of this code.
		// Delete the existing item before moving on entering a correct one.
        
		getError = nil;
		
		[self deleteItemForUsername:username andServiceName:serviceName error:&getError];
        
		if ([getError code] != noErr) {
			if (error) {
				*error = getError;
			}
			return NO;
		}
	} else if ([getError code] != noErr) {
		if (error) {
			*error = getError;
		}
		return NO;
	}
	
	/*if (error != nil) {
		*error = nil;
	}*/
	
	OSStatus status = noErr;
    
	if (existingPassword) {
		// We have an existing, properly entered item with a password.
		// Update the existing item.
		
		if (updateExisting) {
			//Only update if we're allowed to update existing.  If not, simply do nothing.
			
			NSArray *keys = [[NSArray alloc] initWithObjects:(__bridge NSString *)kSecClass,
                              kSecAttrService, 
                              kSecAttrLabel, 
                              kSecAttrAccount, 
                              nil];
			
			NSArray *objects = [[NSArray alloc] initWithObjects:(__bridge NSString *)kSecClassGenericPassword,
                                 serviceName,
                                 serviceName,
                                 username,
                                 nil];
			
			NSDictionary *query = [[NSDictionary alloc] initWithObjects:objects forKeys:keys];
			
			status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)[NSDictionary dictionaryWithObject:passwordData forKey:(__bridge NSString *)kSecValueData]);
		}
	}
	else {
		// No existing entry (or an existing, improperly entered, and therefore now
		// deleted, entry).  Create a new entry.
		
		NSArray *keys = [[NSArray alloc] initWithObjects:(__bridge NSString *)kSecClass,
                          kSecAttrService,
                          kSecAttrLabel, 
                          kSecAttrAccount, 
                          kSecValueData, 
                          nil];
		
		NSArray *objects = [[NSArray alloc] initWithObjects:(__bridge NSString *)kSecClassGenericPassword,
                             serviceName,
                             serviceName,
                             username,
                             passwordData,
                             nil];
		
		NSDictionary *query = [[NSDictionary alloc] initWithObjects:objects forKeys:keys];
        
		status = SecItemAdd((__bridge CFDictionaryRef) query, NULL);
	}
	
	if (status != noErr) {
		// Something went wrong with adding the new item. Return the Keychain error code.
		if (error) {
			*error = [NSError errorWithDomain:BCCKeychainErrorDomain code:status userInfo:nil];
		}
        	return NO;
	}
    
    return YES;
}

+ (BOOL)deleteItemForUsername:(NSString *)username andServiceName:(NSString *)serviceName error:(NSError **)error 
{
	if (!username || !serviceName) {
		if (error) {
			*error = [NSError errorWithDomain:BCCKeychainErrorDomain code:-2000 userInfo:nil];
		}
		return NO;
	}
	
	/*if (error != nil) {
		*error = nil;
	}*/
    
	NSArray *keys = [[NSArray alloc] initWithObjects:(__bridge NSString *)kSecClass, kSecAttrAccount, kSecAttrService, kSecReturnAttributes, nil];
	NSArray *objects = [[NSArray alloc] initWithObjects:(__bridge NSString *)kSecClassGenericPassword, username, serviceName, kCFBooleanTrue, nil];
	
	NSDictionary *query = [[NSDictionary alloc] initWithObjects:objects forKeys:keys];
	
	OSStatus status = SecItemDelete((__bridge CFDictionaryRef) query);
	
	if (status != noErr) {
		if (error) {
			*error = [NSError errorWithDomain:BCCKeychainErrorDomain code:status userInfo:nil];
		}
        
        return NO;
	}
    
    return YES;
}

#endif

@end