//
//  NSDecimalNumber+sqlRepresentation.m
//  iActiveRecord
//
//  Created by Alex Denisov on 18.01.12.
//  Copyright (c) 2012 CoreInvader. All rights reserved.
//

#import "NSDecimalNumber+sqlRepresentation.h"

@implementation NSDecimalNumber (sqlRepresentation)

- (NSString *)toSql {
    return [self stringValue];
}

+ (const char *)sqlType {
    return "real";
}

+ (id)fromSql:(NSString *)sqlData {
    return [NSDecimalNumber decimalNumberWithString:sqlData];
}

@end
