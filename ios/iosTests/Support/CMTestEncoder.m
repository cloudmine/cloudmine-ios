//
//  CMTestEncoder.m
//  cloudmine-ios
//
//  Created by Ethan Mick on 4/19/14.
//  Copyright (c) 2014 CloudMine, LLC. All rights reserved.
//

#import "CMTestEncoder.h"

@implementation CMTestEncoderInt

- (id)initWithCoder:(NSCoder *)aDecoder;
{
    if ( self = ([super initWithCoder:aDecoder]) ) {
        self.anInt = [aDecoder decodeIntegerForKey:@"anInt"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder;
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeInteger:self.anInt forKey:@"anInt"];
}

@end

@implementation CMTestEncoderFloat

- (id)initWithCoder:(NSCoder *)aDecoder;
{
    if ( self = ([super initWithCoder:aDecoder]) ) {
        self.aFloat = [aDecoder decodeFloatForKey:@"aFloat"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder;
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeFloat:self.aFloat forKey:@"aFloat"];
}

@end

@implementation CMTestEncoderNSCoding

- (id)initWithCoder:(NSCoder *)aDecoder;
{
    if ( self = ([super init]) ) {
        self.aString = [aDecoder decodeObjectForKey:@"aString"];
        self.anInt = [aDecoder decodeIntegerForKey:@"anInt"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder;
{
    [aCoder encodeObject:self.aString forKey:@"aString"];
    [aCoder encodeInteger:self.anInt forKey:@"anInt"];
}

@end

@implementation CMTestEncoderNSCodingParent

- (id)initWithCoder:(NSCoder *)aDecoder;
{
    if ( self = ([super initWithCoder:aDecoder]) ) {
        self.something = [aDecoder decodeObjectForKey:@"something"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder;
{
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:self.something forKey:@"something"];
}

- (id)initWithObjectId:(NSString *)theObjectId;
{
    if ( (self = [super initWithObjectId:theObjectId]) ) {
        self.something = [[CMTestEncoderNSCoding alloc] init];
        self.something.aString = @"Test!";
        self.something.anInt = 11;
    }
    return self;
}

@end

