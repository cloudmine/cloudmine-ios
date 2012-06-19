//
//  CMWebService.m
//  cloudmine-ios
//
//  Copyright (c) 2012 CloudMine, LLC. All rights reserved.
//  See LICENSE file included with SDK for details.
//

#import <YAJLiOS/YAJL.h>

#import "SPLowVerbosity.h"
#import "NSData+Base64.h"

#import "CMWebService.h"
#import "CMAPICredentials.h"
#import "CMUser.h"
#import "CMServerFunction.h"
#import "CMPagingDescriptor.h"
#import "CMSortDescriptor.h"
#import "CMActiveUser.h"
#import "NSURL+QueryParameterAdditions.h"

#import "CMObjectEncoder.h"
#import "CMObjectDecoder.h"
#import "CMObjectSerialization.h"

#define CM_APIKEY_HEADER @"X-CloudMine-ApiKey"
#define CM_SESSIONTOKEN_HEADER @"X-CloudMine-SessionToken"

static __strong NSSet *_validHTTPVerbs = nil;

typedef CMUserAccountResult (^_CMWebServiceAccountResponseCodeMapper)(NSUInteger httpResponseCode);

@interface CMWebService ()

@property (nonatomic, strong) NSString *apiUrl;

- (NSURL *)constructTextUrlAtUserLevel:(BOOL)atUserLevel withKeys:(NSArray *)keys query:(NSString *)searchString pagingOptions:(CMPagingDescriptor *)paging sortingOptions:(CMSortDescriptor *)sorting withServerSideFunction:(CMServerFunction *)function extraParameters:(NSDictionary *)params;
- (NSURL *)constructBinaryUrlAtUserLevel:(BOOL)atUserLevel withKey:(NSString *)key withServerSideFunction:(CMServerFunction *)function extraParameters:(NSDictionary *)params;
- (NSURL *)constructDataUrlAtUserLevel:(BOOL)atUserLevel withKeys:(NSArray *)keys withServerSideFunction:(CMServerFunction *)function extraParameters:(NSDictionary *)params;
- (NSMutableURLRequest *)constructHTTPRequestWithVerb:(NSString *)verb URL:(NSURL *)url appSecret:(NSString *)appSecret binaryData:(BOOL)isForBinaryData user:(CMUser *)user;
- (void)executeUserAccountRequest:(NSURLRequest *)request codeMapper:(_CMWebServiceAccountResponseCodeMapper)codeMapper callback:(CMWebServiceUserAccountOperationCallback)callback;
- (void)executeRequest:(NSURLRequest *)request successHandler:(CMWebServiceObjectFetchSuccessCallback)successHandler errorHandler:(CMWebServiceFetchFailureCallback)errorHandler;
- (void)executeBinaryDataFetchRequest:(NSURLRequest *)request successHandler:(CMWebServiceFileFetchSuccessCallback)successHandler  errorHandler:(CMWebServiceFetchFailureCallback)errorHandler;
- (void)executeBinaryDataUploadRequest:(NSURLRequest *)request successHandler:(CMWebServiceFileUploadSuccessCallback)successHandler errorHandler:(CMWebServiceFetchFailureCallback)errorHandler;
- (NSURL *)appendKeys:(NSArray *)keys query:(NSString *)queryString serverSideFunction:(CMServerFunction *)function pagingOptions:(CMPagingDescriptor *)paging sortingOptions:(CMSortDescriptor *)sorting toURL:(NSURL *)theUrl extraParameters:(NSDictionary *)params;
@end

@implementation CMWebService
@synthesize networkQueue;
@synthesize apiUrl;

#pragma mark - Service initialization

- (id)init {
    CMAPICredentials *credentials = [CMAPICredentials sharedInstance];
    NSAssert([credentials appSecret] && [credentials appIdentifier],
             @"You must configure CMAPICredentials before using this method. If you don't want to use CMAPICredentials, you must call [CMWebService initWithAppSecret:appIdentifier:] instead of this method.");
    return [self initWithAppSecret:[credentials appSecret] appIdentifier:[credentials appIdentifier]];
}

- (id)initWithAppSecret:(NSString *)appSecret appIdentifier:(NSString *)appIdentifier {
    NSParameterAssert(appSecret);
    NSParameterAssert(appIdentifier);

    if (!_validHTTPVerbs) {
        _validHTTPVerbs = $set(@"GET", @"POST", @"PUT", @"DELETE");
    }

    if (self = [super init]) {
        self.networkQueue = [[NSOperationQueue alloc] init];
        self.apiUrl = CM_BASE_URL;

        _appSecret = appSecret;
        _appIdentifier = appIdentifier;
    }
    return self;
}

#pragma mark - GET requests for non-binary data

- (void)getValuesForKeys:(NSArray *)keys
      serverSideFunction:(CMServerFunction *)function
           pagingOptions:(CMPagingDescriptor *)paging
          sortingOptions:(CMSortDescriptor *)sorting
                    user:(CMUser *)user
         extraParameters:(NSDictionary *)params
          successHandler:(CMWebServiceObjectFetchSuccessCallback)successHandler
            errorHandler:(CMWebServiceFetchFailureCallback)errorHandler {
    NSURLRequest *request = [self constructHTTPRequestWithVerb:@"GET"
                                                             URL:[self constructTextUrlAtUserLevel:(user != nil)
                                                                                          withKeys:keys
                                                                                             query:nil
                                                                                     pagingOptions:paging
                                                                                    sortingOptions:sorting
                                                                            withServerSideFunction:function
                                                                                   extraParameters:params]
                                                          appSecret:_appSecret
                                                      binaryData:NO
                                                            user:user];
    [self executeRequest:request successHandler:successHandler errorHandler:errorHandler];
}

#pragma mark - Search requests (non-binary data only)

- (void)searchValuesFor:(NSString *)searchQuery
     serverSideFunction:(CMServerFunction *)function
          pagingOptions:(CMPagingDescriptor *)paging
         sortingOptions:(CMSortDescriptor *)sorting
                   user:(CMUser *)user
        extraParameters:(NSDictionary *)params
         successHandler:(CMWebServiceObjectFetchSuccessCallback)successHandler
           errorHandler:(CMWebServiceFetchFailureCallback)errorHandler {
    NSURLRequest *request = [self constructHTTPRequestWithVerb:@"GET"
                                                             URL:[self constructTextUrlAtUserLevel:(user != nil)
                                                                                          withKeys:nil
                                                                                             query:searchQuery
                                                                                     pagingOptions:paging
                                                                                    sortingOptions:sorting
                                                                            withServerSideFunction:function
                                                                                   extraParameters:params]
                                                          appSecret:_appSecret
                                                      binaryData:NO
                                                            user:user];
    [self executeRequest:request successHandler:successHandler errorHandler:errorHandler];
}

#pragma mark - GET requests for binary data

- (void)getBinaryDataNamed:(NSString *)key
        serverSideFunction:(CMServerFunction *)function 
                      user:(CMUser *)user
           extraParameters:(NSDictionary *)params
            successHandler:(CMWebServiceFileFetchSuccessCallback)successHandler
              errorHandler:(CMWebServiceFetchFailureCallback)errorHandler {
    NSURLRequest *request = [self constructHTTPRequestWithVerb:@"GET"
                                                             URL:[self constructBinaryUrlAtUserLevel:(user != nil)
                                                                                             withKey:key
                                                                              withServerSideFunction:function
                                                                                     extraParameters:params]
                                                          appSecret:_appSecret
                                                      binaryData:NO
                                                            user:user];
    [self executeBinaryDataFetchRequest:request successHandler:successHandler errorHandler:errorHandler];
}

#pragma mark - POST (update) requests for non-binary data

- (void)updateValuesFromDictionary:(NSDictionary *)data
                serverSideFunction:(CMServerFunction *)function
                              user:(CMUser *)user
                   extraParameters:(NSDictionary *)params
                    successHandler:(CMWebServiceObjectFetchSuccessCallback)successHandler
                      errorHandler:(CMWebServiceFetchFailureCallback)errorHandler {
    NSMutableURLRequest *request = [self constructHTTPRequestWithVerb:@"POST"
                                                             URL:[self constructTextUrlAtUserLevel:(user != nil)
                                                                                          withKeys:nil
                                                                                             query:nil
                                                                                     pagingOptions:nil
                                                                                    sortingOptions:nil
                                                                            withServerSideFunction:function
                                                                                   extraParameters:params]
                                                          appSecret:_appSecret
                                                      binaryData:NO
                                                            user:user];
    [request setHTTPBody:[[data yajl_JSONString] dataUsingEncoding:NSUTF8StringEncoding]];
    [self executeRequest:request successHandler:successHandler errorHandler:errorHandler];
}

#pragma mark - POST requests for binary data

- (void)uploadBinaryData:(NSData *)data
      serverSideFunction:(CMServerFunction *)function
                   named:(NSString *)key
              ofMimeType:(NSString *)mimeType
                    user:(CMUser *)user
         extraParameters:(NSDictionary *)params
          successHandler:(CMWebServiceFileUploadSuccessCallback)successHandler
            errorHandler:(CMWebServiceFetchFailureCallback)errorHandler {
    NSMutableURLRequest *request = [self constructHTTPRequestWithVerb:@"PUT"
                                                             URL:[self constructBinaryUrlAtUserLevel:(user != nil)
                                                                                             withKey:key
                                                                              withServerSideFunction:function
                                                                                     extraParameters:params]
                                                          appSecret:_appSecret
                                                      binaryData:YES
                                                            user:user];
    if (mimeType.length > 0) {
        [request setValue:mimeType forHTTPHeaderField:@"Content-Type"];
    }
    [request setHTTPBody:[data mutableCopy]];
    [self executeBinaryDataUploadRequest:request successHandler:successHandler errorHandler:errorHandler];
}

- (void)uploadFileAtPath:(NSString *)path
      serverSideFunction:(CMServerFunction *)function
                   named:(NSString *)key
              ofMimeType:(NSString *)mimeType
                    user:(CMUser *)user
         extraParameters:(NSDictionary *)params
          successHandler:(CMWebServiceFileUploadSuccessCallback)successHandler
            errorHandler:(CMWebServiceFetchFailureCallback)errorHandler {
    NSMutableURLRequest *request = [self constructHTTPRequestWithVerb:@"PUT"
                                                             URL:[self constructBinaryUrlAtUserLevel:(user != nil)
                                                                                             withKey:key
                                                                              withServerSideFunction:function
                                                                                     extraParameters:params]
                                                       appSecret:_appSecret
                                                      binaryData:YES
                                                            user:user];
    if (mimeType.length > 0) {
        [request setValue:mimeType forKey:@"Content-Type"];
    }
    [request setHTTPBodyStream:[NSInputStream inputStreamWithFileAtPath:path]];
    [self executeBinaryDataUploadRequest:request successHandler:successHandler errorHandler:errorHandler];
}

#pragma mark - PUT (replace) requests for non-binary data

- (void)setValuesFromDictionary:(NSDictionary *)data
             serverSideFunction:(CMServerFunction *)function
                           user:(CMUser *)user
                extraParameters:(NSDictionary *)params
                 successHandler:(CMWebServiceObjectFetchSuccessCallback)successHandler
                   errorHandler:(CMWebServiceFetchFailureCallback)errorHandler {
    NSMutableURLRequest *request = [self constructHTTPRequestWithVerb:@"PUT"
                                                             URL:[self constructTextUrlAtUserLevel:(user != nil)
                                                                                          withKeys:nil
                                                                                             query:nil
                                                                                     pagingOptions:nil
                                                                                    sortingOptions:nil
                                                                            withServerSideFunction:function
                                                                                   extraParameters:params]
                                                          appSecret:_appSecret
                                                      binaryData:NO
                                                            user:user];
    [request setHTTPBody:[[data yajl_JSONString] dataUsingEncoding:NSUTF8StringEncoding]];
    [self executeRequest:request successHandler:successHandler errorHandler:errorHandler];
}

#pragma mark - DELETE requests for data

- (void)deleteValuesForKeys:(NSArray *)keys
         serverSideFunction:(CMServerFunction *)function
                       user:(CMUser *)user
            extraParameters:(NSDictionary *)params
             successHandler:(CMWebServiceObjectFetchSuccessCallback)successHandler
               errorHandler:(CMWebServiceFetchFailureCallback)errorHandler {
    NSURLRequest *request = [self constructHTTPRequestWithVerb:@"DELETE" URL:[[self constructDataUrlAtUserLevel:(user != nil)
                                                                                                        withKeys:keys
                                                                                           withServerSideFunction:function
                                                                                                  extraParameters:params]
                                                                                URLByAppendingQueryString:@"all=true"]
                                                          appSecret:_appSecret
                                                      binaryData:NO
                                                            user:user];
    [self executeRequest:request successHandler:successHandler errorHandler:errorHandler];
}

#pragma mark - User account management

- (void)loginUser:(CMUser *)user callback:(CMWebServiceUserAccountOperationCallback)callback {
    NSParameterAssert(user);

    NSURL *url = [NSURL URLWithString:[self.apiUrl stringByAppendingFormat:@"/app/%@/account/login", _appIdentifier]];
    NSMutableURLRequest *request = [self constructHTTPRequestWithVerb:@"POST" URL:url appSecret:_appSecret binaryData:NO user:nil];
    
    // Add Basic Auth header manually
    NSData *credentialData = [[NSString stringWithFormat:@"%@:%@", user.userId, user.password] dataUsingEncoding:NSASCIIStringEncoding];
    NSString *basicAuthValue = [NSString stringWithFormat:@"Basic %@", [credentialData base64EncodedString]];
    [request setValue:basicAuthValue forHTTPHeaderField:@"Authorization"];

    [self executeUserAccountRequest:request codeMapper:^CMUserAccountResult(NSUInteger httpResponseCode) {
        switch (httpResponseCode) {
            case 200:
                return CMUserAccountLoginSucceeded;
            case 401:
                return CMUserAccountLoginFailedIncorrectCredentials;
            case 404:
                return CMUserAccountOperationFailedUnknownAccount;
            default:
                return CMUserAccountUnknownResult;
        }
    }
                           callback:callback];
}

- (void)logoutUser:(CMUser *)user callback:(CMWebServiceUserAccountOperationCallback)callback {
    NSParameterAssert(user);
    NSAssert(user.isLoggedIn, @"Cannot logout a user that hasn't been logged in.");

    NSURL *url = [NSURL URLWithString:[self.apiUrl stringByAppendingFormat:@"/app/%@/account/login", _appIdentifier]];
    NSMutableURLRequest *request = [self constructHTTPRequestWithVerb:@"POST" URL:url appSecret:_appSecret binaryData:NO user:nil];
    [request setValue:user.token forHTTPHeaderField:CM_SESSIONTOKEN_HEADER];

    [self executeUserAccountRequest:request codeMapper:^CMUserAccountResult(NSUInteger httpResponseCode) {
        switch (httpResponseCode) {
            case 200:
                return CMUserAccountLogoutSucceeded;
            case 404:
                return CMUserAccountOperationFailedUnknownAccount;
            default:
                return CMUserAccountUnknownResult;
        }
    }
                           callback:callback];
}

- (void)createAccountWithUser:(CMUser *)user callback:(CMWebServiceUserAccountOperationCallback)callback {
    NSParameterAssert(user);
    NSAssert(user.userId != nil && user.password != nil, @"Cannot create an account from a user that doesn't have an ID or password set.");

    NSURL *url = [NSURL URLWithString:[self.apiUrl stringByAppendingFormat:@"/app/%@/account/create", _appIdentifier]];
    NSMutableURLRequest *request = [self constructHTTPRequestWithVerb:@"POST" URL:url appSecret:_appSecret binaryData:NO user:nil];

    // The username and password of this account are supplied in the request body.
    NSMutableDictionary *payload = $mdict(@"credentials", $dict(@"email", user.userId, @"password", user.password));
    
    // Extract other profile fields from the user by serializing it to JSON and removing the "token" and "tokenExpiration" fields (which don't
    // need to be sent over the wire).
    NSMutableDictionary *serializedUser = [[[(NSDictionary *)[CMObjectEncoder encodeObjects:$array(user)] allValues] objectAtIndex:0] mutableCopy];
    [serializedUser removeObjectsForKeys:[$array(@"token", @"tokenExpiration") arrayByAddingObjectsFromArray:[CMInternalKeys allObjects]]];
    if ([serializedUser count] > 0) {
        [payload setObject:serializedUser forKey:@"profile"];
    }
    
    [request setHTTPBody:[[payload yajl_JSONString] dataUsingEncoding:NSUTF8StringEncoding]];

    [self executeUserAccountRequest:request codeMapper:^CMUserAccountResult(NSUInteger httpResponseCode) {
        switch (httpResponseCode) {
            case 201:
                return CMUserAccountCreateSucceeded;
            case 400:
                return CMUserAccountCreateFailedInvalidRequest;
            case 409:
                return CMUserAccountCreateFailedDuplicateAccount;
            default:
                return CMUserAccountUnknownResult;
        }
    }
                           callback:callback];
}

- (void)changePasswordForUser:(CMUser *)user oldPassword:(NSString *)oldPassword newPassword:(NSString *)newPassword callback:(CMWebServiceUserAccountOperationCallback)callback {

    NSParameterAssert(user);
    NSParameterAssert(oldPassword);
    NSParameterAssert(newPassword);
    NSAssert(user.userId, @"Cannot change the password of a user that doesn't have a user id set.");

    NSURL *url = [NSURL URLWithString:[self.apiUrl stringByAppendingFormat:@"/app/%@/account/password/change", _appIdentifier]];
    NSMutableURLRequest *request = [self constructHTTPRequestWithVerb:@"POST" URL:url appSecret:_appSecret binaryData:NO user:nil];

    // This API endpoint doesn't use a session token for security purposes. The user must supply their old password
    // explicitly in addition to their new password.
    NSData *credentialData = [[NSString stringWithFormat:@"%@:%@", user.userId, user.password] dataUsingEncoding:NSASCIIStringEncoding];
    NSString *basicAuthValue = [NSString stringWithFormat:@"Basic %@", [credentialData base64EncodedString]];
    [request setValue:basicAuthValue forHTTPHeaderField:@"Authorization"];
    
    NSDictionary *payload = $dict(@"password", newPassword);
    [request setHTTPBody:[[payload yajl_JSONString] dataUsingEncoding:NSUTF8StringEncoding]];

    [self executeUserAccountRequest:request codeMapper:^CMUserAccountResult(NSUInteger httpResponseCode) {
        switch (httpResponseCode) {
            case 200:
                return CMUserAccountPasswordChangeSucceeded;
            case 401:
                return CMUserAccountPasswordChangeFailedInvalidCredentials;
            case 404:
                return CMUserAccountOperationFailedUnknownAccount;
            default:
                return CMUserAccountUnknownResult;
        }
    }
                           callback:callback];
}

- (void)resetForgottenPasswordForUser:(CMUser *)user callback:(CMWebServiceUserAccountOperationCallback)callback {
    NSParameterAssert(user);
    NSAssert(user.userId, @"Cannot reset the password of a user that doesn't have a user id set.");

    NSURL *url = [NSURL URLWithString:[self.apiUrl stringByAppendingFormat:@"/app/%@/account/password/reset", _appIdentifier]];
    NSMutableURLRequest *request = [self constructHTTPRequestWithVerb:@"POST" URL:url appSecret:_appSecret binaryData:NO user:nil];

    NSDictionary *payload = $dict(@"email", user.userId);
    [request setHTTPBody:[[payload yajl_JSONString] dataUsingEncoding:NSUTF8StringEncoding]];

    [self executeUserAccountRequest:request codeMapper:^CMUserAccountResult(NSUInteger httpResponseCode) {
        switch (httpResponseCode) {
            case 200:
                return CMUserAccountPasswordResetEmailSent;
            case 404:
                return CMUserAccountOperationFailedUnknownAccount;
            default:
                return CMUserAccountUnknownResult;
        }
    }
                           callback:callback];
}

#pragma - Request queueing and execution

- (void)executeUserAccountRequest:(NSMutableURLRequest *)request
                       codeMapper:(_CMWebServiceAccountResponseCodeMapper)codeMapper
                         callback:(CMWebServiceUserAccountOperationCallback)callback {

    // TODO: Let this switch between MsgPack and GZIP'd JSON.
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-type"];

    __unsafe_unretained NSURLRequest *blockRequest = request;
    void (^responseBlock)() = ^{
        CMUserAccountResult resultCode = codeMapper(blockRequest.responseStatusCode);

        if (resultCode == CMUserAccountUnknownResult) {
            NSLog(@"Unexpected response received from server during user account creation. Code %d, body: %@.", blockRequest.responseStatusCode, blockRequest.responseString);
        }

        NSDictionary *responseBody = [NSDictionary dictionary];
        if (blockRequest.responseString != nil) {
            NSError *parseErr = nil;
            NSDictionary *parsedResponseBody = [blockRequest.responseString yajl_JSON:&parseErr];
            if (!parseErr && parsedResponseBody) {
                responseBody = parsedResponseBody;
            }
        }

        if (callback != nil) {
            callback(resultCode, responseBody);
        }
    };

    [request setCompletionBlock:responseBlock];
    [request setFailedBlock:responseBlock];

    [self.networkQueue addOperation:request];
    [self.networkQueue go];
}

- (void)executeRequest:(NSURLRequest *)request
        successHandler:(CMWebServiceObjectFetchSuccessCallback)successHandler
          errorHandler:(CMWebServiceFetchFailureCallback)errorHandler {

    __unsafe_unretained NSURLRequest *blockRequest = request; // Stop the retain cycle.

    [request setCompletionBlock:^{
        NSDictionary *results = [blockRequest.responseString yajl_JSON];

        if (blockRequest.responseStatusCode == 400 || blockRequest.responseStatusCode == 500) {
            NSString *message = [results objectForKey:@"error"];
            NSError *err = $makeErr(@"CloudMine", 500, message);

            if (errorHandler != nil) {
                errorHandler(err);
            }
        } else {
            NSDictionary *successes = nil;
            NSDictionary *errors = nil;
            NSDictionary *meta = nil;
            NSNumber *count = nil;
            
            id snippetResult = nil;
            if (results) {
                successes = [results objectForKey:@"success"];
                if (!successes) {
                    successes = [NSDictionary dictionary];
                }

                errors = [results objectForKey:@"errors"];
                if (!errors) {
                    errors = [NSDictionary dictionary];
                }
                
                snippetResult = [results objectForKey:@"result"];
                if(!snippetResult) {
                    snippetResult = [NSDictionary dictionary];
                }
                
                meta = [results objectForKey:@"meta"];
                if(!meta) {
                    meta = [NSDictionary dictionary];
                }
                
                count = [results objectForKey:@"count"];
            }
            if (successHandler != nil) {
                successHandler(successes, errors, meta, snippetResult, count, blockRequest.responseHeaders);
            }
        }
    }];

    [request setFailedBlock:^{
        if (errorHandler != nil) {
            errorHandler(blockRequest.error);
        }
    }];

    [self.networkQueue addOperation:request];
    [self.networkQueue go];
}

- (void)executeBinaryDataFetchRequest:(NSURLRequest *)request
        successHandler:(CMWebServiceFileFetchSuccessCallback)successHandler
          errorHandler:(CMWebServiceFetchFailureCallback)errorHandler {

    __unsafe_unretained NSURLRequest *blockRequest = request; // Stop the retain cycle.

    [request setCompletionBlock:^{
        if (blockRequest.responseStatusCode == 200) {
            if (successHandler != nil) {
                successHandler(blockRequest.responseData, [blockRequest.responseHeaders objectForKey:@"Content-Type"], blockRequest.responseHeaders);
            }
        } else {
            if (errorHandler != nil) {
                NSError *err = $makeErr(@"CloudMine", blockRequest.responseStatusCode, blockRequest.responseStatusMessage);
                errorHandler(err);
            }
        }
    }];

    [request setFailedBlock:^{
        if (errorHandler != nil) {
            errorHandler(blockRequest.error);
        }
    }];

    [self.networkQueue addOperation:request];
    [self.networkQueue go];
}

- (void)executeBinaryDataUploadRequest:(NSURLRequest *)request
                       successHandler:(CMWebServiceFileUploadSuccessCallback)successHandler
                         errorHandler:(CMWebServiceFetchFailureCallback)errorHandler {

    __unsafe_unretained NSURLRequest *blockRequest = request; // Stop the retain cycle.

    [request setCompletionBlock:^{
        NSDictionary *results = [blockRequest.responseString yajl_JSON];
        
        id snippetResult = nil;
        NSString *key = [results objectForKey:@"key"];

        if(results) {
            snippetResult = [results objectForKey:@"result"];
            
            if(!snippetResult) {
                snippetResult = [NSDictionary dictionary];
            }
        }
        if (successHandler != nil) {
            successHandler(blockRequest.responseStatusCode == 201 ? CMFileCreated : CMFileUpdated, key, snippetResult, blockRequest.responseHeaders);
        }
    }];

    [request setFailedBlock:^{
        if (errorHandler != nil) {
            errorHandler(blockRequest.error);
        }
    }];

    [self.networkQueue addOperation:request];
    [self.networkQueue go];
}

#pragma - Request construction

- (NSURLRequest *)constructHTTPRequestWithVerb:(NSString *)verb
                                             URL:(NSURL *)url
                                          appSecret:(NSString *)appSecret
                                      binaryData:(BOOL)isForBinaryData
                                            user:(CMUser *)user {
    NSAssert([_validHTTPVerbs containsObject:verb], @"You must pass in a valid HTTP verb. Possible choices are: GET, POST, PUT, and DELETE");

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:verb];
    if (user) {
        if (user.token == nil) {
            [[NSException exceptionWithName:@"CMInternalInconsistencyException" reason:@"You cannot construct a user-level CloudMine request when the user isn't logged in." userInfo:nil] raise];
            __builtin_unreachable();
        }
        [request setValue:user.token forHTTPHeaderField:CM_SESSIONTOKEN_HEADER];
    }
    [request setValue:appSecret forHTTPHeaderField:CM_APIKEY_HEADER];

    // TODO: This should be customizable to change between JSON, GZIP'd JSON, and MsgPack.

    // Don't do this for binary data since that requires further intervention by the developer.
    if (!isForBinaryData) {
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-type"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    }
    
    // Add user agent and user tracking headers
    [request setValue:[NSString stringWithFormat:@"CM-iOS/%@", CM_VERSION] forHTTPHeaderField:@"X-CloudMine-Agent"];
    [request setValue:[[CMActiveUser currentActiveUser] identifier] forHTTPHeaderField:@"X-CloudMine-UT"];

    #ifdef DEBUG
        NSLog(@"Constructed CloudMine URL: %@\nHeaders:%@", request.url, request.allHTTPHeaderFields);
    #endif

    return [request copy];
}

#pragma mark - General URL construction

- (NSURL *)constructTextUrlAtUserLevel:(BOOL)atUserLevel
                              withKeys:(NSArray *)keys
                                 query:(NSString *)searchString
                         pagingOptions:(CMPagingDescriptor *)paging
                        sortingOptions:(CMSortDescriptor *)sorting
                withServerSideFunction:(CMServerFunction *)function 
                       extraParameters:params{

    NSAssert(keys == nil || searchString == nil, @"When constructing CM URLs, 'keys' and 'searchString' are mutually exclusive");

    NSString *endpoint = nil;
    if (searchString != nil) {
        endpoint = @"search";
    } else {
        endpoint = @"text";
    }

    NSURL *url;
    if (atUserLevel) {
        url = [NSURL URLWithString:[self.apiUrl stringByAppendingFormat:@"/app/%@/user/%@", _appIdentifier, endpoint]];
    } else {
        url = [NSURL URLWithString:[self.apiUrl stringByAppendingFormat:@"/app/%@/%@", _appIdentifier, endpoint]];
    }

    return [self appendKeys:keys query:searchString serverSideFunction:function pagingOptions:paging sortingOptions:sorting toURL:url extraParameters:params];
}

- (NSURL *)constructBinaryUrlAtUserLevel:(BOOL)atUserLevel
                                 withKey:(NSString *)key
                  withServerSideFunction:(CMServerFunction *)function
                         extraParameters:(NSDictionary *)params {
    NSURL *url;
    if (atUserLevel) {
        url = [NSURL URLWithString:[self.apiUrl stringByAppendingFormat:@"/app/%@/user/binary", _appIdentifier]];
    } else {
        url = [NSURL URLWithString:[self.apiUrl stringByAppendingFormat:@"/app/%@/binary", _appIdentifier]];
    }
    
    if (key) {
        url = [url URLByAppendingPathComponent:key];
    }

    return [self appendKeys:nil query:nil serverSideFunction:function pagingOptions:nil sortingOptions:nil toURL:url extraParameters:params];
}

- (NSURL *)constructDataUrlAtUserLevel:(BOOL)atUserLevel
                              withKeys:(NSArray *)keys
                withServerSideFunction:(CMServerFunction *)function
                       extraParameters:(NSDictionary *)params {
    NSURL *url;
    if (atUserLevel) {
        url = [NSURL URLWithString:[self.apiUrl stringByAppendingFormat:@"/app/%@/user/data", _appIdentifier]];
    } else {
        url = [NSURL URLWithString:[self.apiUrl stringByAppendingFormat:@"/app/%@/data", _appIdentifier]];
    }

    return [self appendKeys:keys query:nil serverSideFunction:function pagingOptions:nil sortingOptions:nil toURL:url extraParameters:params];
}

- (NSURL *)appendKeys:(NSArray *)keys
                query:(NSString *)searchString
   serverSideFunction:(CMServerFunction *)function
        pagingOptions:(CMPagingDescriptor *)paging
       sortingOptions:(CMSortDescriptor *)sorting
                toURL:(NSURL *)theUrl
      extraParameters:(NSDictionary *)params {

    NSAssert(keys == nil || searchString == nil, @"When constructing CM URLs, 'keys' and 'searchString' are mutually exclusive");

    NSMutableArray *queryComponents = [NSMutableArray arrayWithCapacity:2];
    if (keys && [keys count] > 0) {
        [queryComponents addObject:[NSString stringWithFormat:@"keys=%@", [keys componentsJoinedByString:@","]]];
    }
    if (function) {
        [queryComponents addObject:[function stringRepresentation]];
    }
    if (searchString) {
        [queryComponents addObject:[NSString stringWithFormat:@"q=%@", searchString]];
    }
    if (paging) {
        [queryComponents addObject:[paging stringRepresentation]];
    }
    if (sorting) {
        [queryComponents addObject:[sorting stringRepresentation]];
    }
    if (params) {
        for(id key in params) {
            [queryComponents addObject:[NSString stringWithFormat:@"%@=%@", key, [params objectForKey:key]]];
        }
    }
    return [theUrl URLByAppendingQueryString:[queryComponents componentsJoinedByString:@"&"]];
}

@end
