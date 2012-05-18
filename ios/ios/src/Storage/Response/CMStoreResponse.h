//
//  CMStoreResponse.h
//  cloudmine-ios
//
//  Copyright (c) 2012 CloudMine, LLC. All rights reserved.
//  See LICENSE file included with SDK for details.
//

#import <Foundation/Foundation.h>
#import "CMSnippetResult.h"
#import "CMResponseMetadata.h"

@interface CMStoreResponse : NSObject

@property (strong, nonatomic) CMResponseMetadata *metadata;
@property (strong, nonatomic) CMSnippetResult *snippetResult;

- (id)initWithMetadata:(CMResponseMetadata *)metadata snippetResult:(CMSnippetResult *)snippetResult;

@end
