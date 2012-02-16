//
//  ChatMessage.h
//  iSub
//
//  Created by bbaron on 8/16/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "TBXML.h"

@interface ChatMessage : NSObject <NSCopying> 

@property NSInteger timestamp;
@property (copy) NSString *user;
@property (copy) NSString *message;

- (id)initWithTBXMLElement:(TBXMLElement *)element;
-(id) copyWithZone: (NSZone *) zone;

@end
