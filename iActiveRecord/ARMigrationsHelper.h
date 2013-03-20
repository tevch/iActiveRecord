//
//  ARMigrationsHelper.h
//  iActiveRecord
//
//  Created by Alex Denisov on 01.02.12.
//  Copyright (c) 2012 CoreInvader. All rights reserved.
//

#import <Foundation/Foundation.h>

#define ignore_field(aField)\
    [ActiveRecord performSelector:@selector(ignoreField:) withObject:(@""#aField"")];

#define migration_helper \
    static NSMutableSet *ignoredFields = nil;\

#define ignore_fields_do(igrnored_fileds) \
    migration_helper\
    + (void)initIgnoredFields {\
        if(nil == ignoredFields)\
            ignoredFields = [[NSMutableSet alloc] init];\
    igrnored_fileds\
}\


#define index_field(aField)\
    [ActiveRecord performSelector:@selector(indexField:) withObject:(@""#aField"")];

#define index_field_helper \
    static NSMutableSet *indexedFields = nil;\

#define index_fields_do(idnexed_feilds) \
    index_field_helper\
    + (void)initIndexedFields {\
        if(nil == indexedFields)\
            indexedFields = [[NSMutableSet alloc] init];\
    idnexed_feilds\
}\

