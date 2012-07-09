//
//  BassEncryptedStream.h
//  Anghami
//
//  Created by Benjamin Baron on 6/30/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "BassStream.h"

@interface BassEncryptedStream : BassStream

@property (strong) EX2FileDecryptor *decryptor;

@end
