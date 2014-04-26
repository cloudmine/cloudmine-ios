//
//  CMTestEncoder.h
//  cloudmine-ios
//
//  Created by Ethan Mick on 4/19/14.
//  Copyright (c) 2014 CloudMine, LLC. All rights reserved.
//

#import "CMObject.h"
#import "CMCoding.h"

@interface CMTestEncoderInt : CMObject

@property (nonatomic, assign) NSInteger anInt;

@end

@interface CMTestEncoderFloat : CMObject

@property (nonatomic, assign) CGFloat aFloat;

@end

@interface CMTestEncoderNSCoding : NSObject <CMCoding>

@property (nonatomic, copy) NSString *aString;
@property (nonatomic, assign) NSInteger anInt;

@end

@interface CMTestEncoderNSCodingParent : CMObject

@property (nonatomic, strong) CMTestEncoderNSCoding *something;

@end

@interface CMTestEncoderNSCodingDeeper : CMTestEncoderNSCoding <CMCoding>

@property (nonatomic, strong) CMTestEncoderFloat *nestedCMObject;

@end