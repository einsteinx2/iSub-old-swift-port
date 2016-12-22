//
//  ISMSLoader_Subclassing.h
//  libSub
//
//  Created by Benjamin Baron on 2/2/16.
//  Copyright © 2016 Einstein Times Two Software. All rights reserved.
//

@interface ISMSLoader (Subclassing)

@property (nullable, nonatomic, strong) NSURLConnection *connection;
@property (nullable, nonatomic, strong) NSURLRequest *request;
@property (nullable, nonatomic, strong) NSURLResponse *response;
@property (nullable, nonatomic, strong) NSMutableData *receivedData;

// Override this to run setup during init
- (void)setup;

// Override this to create the request
- (nullable NSURLRequest *)createRequest;

// Override this to process the response
- (void)processResponse;

@end