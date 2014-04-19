//
//  CMObjectEncoderSpec.m
//  cloudmine-iosTests
//
//  Copyright (c) 2012 CloudMine, LLC. All rights reserved.
//  See LICENSE file included with SDK for details.
//

#import "Kiwi.h"

#import "CMObjectEncoder.h"
#import "CMSerializable.h"
#import "NSString+UUID.h"
#import "CMGenericSerializableObject.h"
#import "CMCrossPlatformGenericSerializableObject.h"
#import "CMObjectSerialization.h"
#import "CMGeoPoint.h"
#import "CMDate.h"
#import "CMTestEncoder.h"

SPEC_BEGIN(CMObjectEncoderSpec)

describe(@"CMObjectEncoder", ^{
    it(@"should encode a single object correctly", ^{
        NSString *uuid = [NSString stringWithUUID];
        CMGenericSerializableObject *object = [[CMGenericSerializableObject alloc] initWithObjectId:uuid];
        [object fillPropertiesWithDefaults];
        [object.dictionary setValue:[NSNull null] forKey:@"testNull"];

        // Add a geo field.
        CMGeoPoint *geoPoint = [[CMGeoPoint alloc] initWithLatitude:14.1247 andLongitude:-74.199887];
        object.nestedObject = geoPoint;

        // Run the serialization.
        NSDictionary *dictionaryOfData = [CMObjectEncoder encodeObjects:[NSSet setWithObject:object]];

        // Check the integrity data.
        [dictionaryOfData shouldNotBeNil];
        [[[dictionaryOfData should] have:1] items];

        [[dictionaryOfData should] haveValueForKey:uuid];
        NSDictionary *theOnlyObject = [dictionaryOfData objectForKey:uuid];
        [[[theOnlyObject objectForKey:CMInternalObjectIdKey] should] equal:uuid];
        [[[theOnlyObject objectForKey:CMInternalClassStorageKey] should] equal:@"CMGenericSerializableObject"];
        [[[theOnlyObject objectForKey:@"string1"] should] equal:@"Hello World"];
        [[[theOnlyObject objectForKey:@"string2"] should] equal:@"Apple Macintosh"];
        [[[theOnlyObject objectForKey:@"simpleInt"] should] equal:theValue(42)];
        [[theOnlyObject objectForKey:@"arrayOfBooleans"] shouldNotBeNil];
        [[[[theOnlyObject objectForKey:@"arrayOfBooleans"] should] have:5] items];
        [[[theOnlyObject objectForKey:@"nestedObject"] should] beKindOfClass:[NSDictionary class]];
        [[[theOnlyObject objectForKey:@"date"] should] beKindOfClass:[NSDictionary class]];
        [[[theOnlyObject objectForKey:@"dictionary"] should] beKindOfClass:[NSDictionary class]];
        [[[[theOnlyObject objectForKey:@"dictionary"] valueForKey:@"testNull"] should] beKindOfClass:[NSNull class]];


        //TODO: Uncomment when server-side support for object relationships is done.

//        [[theOnestednlyObject objectForKey:@"nestedObject"] shouldNotBeNil];

//        NSDictionary *nestedObject = [theOnlyObject objectForKey:@"nestedObject"];
//        [[[nestedObject objectForKey:CMInternalObjectIdKey] should] equal:object.nestedObject.objectId];
//        [[[nestedObject objectForKey:CMInternalClassStorageKey] should] equal:@"CMGenericSerializableObject"];
//        [[[nestedObject objectForKey:@"string1"] should] equal:@"Nested 1"];
//        [[[nestedObject objectForKey:@"string2"] should] equal:@"Nested 2"];
//        [[[nestedObject objectForKey:@"simpleInt"] should] equal:theValue(999)];
//        [[[nestedObject objectForKey:@"arrayOfBooleans"] should] equal:[NSNull null]];
//        [[[nestedObject objectForKey:@"nestedObject"] should] equal:[NSNull null]];
    });

    it(@"should encode an object with a custom class name correctly", ^{
        NSString *uuid = [NSString stringWithUUID];
        CMCrossPlatformGenericSerializableObject *object = [[CMCrossPlatformGenericSerializableObject alloc] initWithObjectId:uuid];
        [object fillPropertiesWithDefaults];

        // Run the serialization.
        NSDictionary *dictionaryOfData = [CMObjectEncoder encodeObjects:[NSSet setWithObject:object]];

        // Check the integrity data.
        [dictionaryOfData shouldNotBeNil];
        [[[dictionaryOfData should] have:1] items];

        [[dictionaryOfData should] haveValueForKey:uuid];
        NSDictionary *theOnlyObject = [dictionaryOfData objectForKey:uuid];
        [[[theOnlyObject objectForKey:CMInternalClassStorageKey] should] equal:@"genericObject"];
    });
    
    it(@"should encode an Integer properly", ^{
        NSString *uuid = [NSString stringWithUUID];
        CMTestEncoderInt *test = [[CMTestEncoderInt alloc] initWithObjectId:uuid];
        test.anInt = 10;
        
        // Run the serialization.
        NSDictionary *result = [CMObjectEncoder encodeObjects:@[test]];
        [[result shouldNot] beNil];
        [[[result should] have:1] items];
        [[result should] haveValueForKey:uuid];
        NSDictionary *object = result[uuid];
        [[object[@"anInt"] should] equal:@10];
    });
    
    it(@"should encode a float properly", ^{
        NSString *uuid = [NSString stringWithUUID];
        CMTestEncoderFloat *test = [[CMTestEncoderFloat alloc] initWithObjectId:uuid];
        test.aFloat = 10.5;
        
        // Run the serialization.
        NSDictionary *result = [CMObjectEncoder encodeObjects:@[test]];
        [[result shouldNot] beNil];
        [[[result should] have:1] items];
        [[result should] haveValueForKey:uuid];
        NSDictionary *object = result[uuid];
        [[object[@"aFloat"] should] equal:@10.5];
    });
    
    it(@"should encode an object that adheres to NSCoding properly", ^{
        NSString *uuid = [NSString stringWithUUID];
        CMTestEncoderNSCodingParent *test = [[CMTestEncoderNSCodingParent alloc] initWithObjectId:uuid];
        
        // Run the serialization.
        NSDictionary *result = [CMObjectEncoder encodeObjects:@[test]];
        [[result shouldNot] beNil];
        [[[result should] have:1] items];
        [[result should] haveValueForKey:uuid];
        NSDictionary *object = result[uuid];
        [[object[@"something"] should] beMemberOfClass:[NSDictionary class]];
        NSDictionary *something = object[@"something"];
        [[something[@"aString"] should] equal:@"Test!"];
        [[something[@"anInt"] should] equal:@11];
    });
    
    
});

SPEC_END
