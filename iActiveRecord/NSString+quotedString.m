//
//  NSString+quotedString.m
//  iActiveRecord
//
//  Created by Alex Denisov on 26.03.12.
//  Copyright (c) 2012 CoreInvader. All rights reserved.
//

#import "NSString+quotedString.h"

@implementation NSString (quotedString)

- (NSString *)quotedString {
    return [NSString stringWithFormat:@"\"%@\"", self];
}

- (NSString *)literalQuotedString {
    return [NSString stringWithFormat:@"\'%@\'", self];
}

# warning quotedString fails to correctly escape literal strings - for instance, if you have a friend with the first name "Email", then iActiveRecord will set his first name to be equal to his email address. Literal strings need to be escaped with single quotes. The function stringWithEscapedQuote also needs to be updated to reflect this change.

@end
