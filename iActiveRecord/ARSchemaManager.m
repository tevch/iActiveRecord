//
//  ARColumnManager.m
//  iActiveRecord
//
//  Created by Alex Denisov on 01.05.12.
//  Copyright (c) 2012 CoreInvader. All rights reserved.
//

#import "ARSchemaManager.h"
#import "ARColumn_Private.h"
#import "NSMutableDictionary+valueToArray.h"
#import "ActiveRecord_Private.h"

@implementation ARSchemaManager {
    NSMutableDictionary *_columnLookup;
}

@synthesize schemes;
@synthesize indexSchemes;

static ARSchemaManager *_instance = nil;

+ (id)sharedInstance {
    @synchronized(self){
        if(_instance == nil){
            _instance = [ARSchemaManager new];
        }
        return _instance;
    }
}

- (id)init {
    self = [super init];
    self.schemes = [NSMutableDictionary new];
    self.indexSchemes = [NSMutableDictionary new];
    _columnLookup = [NSMutableDictionary new];
    return self;
}

- (void)dealloc {
    self.schemes = nil;
    self.indexSchemes = nil;
    [super dealloc];
}

- (void)registerSchemeForRecord:(Class)aRecordClass {
    Class ActiveRecordClass = NSClassFromString(@"NSObject");
    NSArray *ignoredFields = [aRecordClass performSelector:@selector(ignoredFields)];
    NSArray *indexedFields = [aRecordClass performSelector:@selector(indexedFields)];
    id CurrentClass = aRecordClass;
    while(nil != CurrentClass && CurrentClass != ActiveRecordClass){
        unsigned int outCount, i;
        objc_property_t *properties = class_copyPropertyList(CurrentClass, &outCount);
        for (i = 0; i < outCount; i++) {
            ARColumn *column = [[ARColumn alloc] initWithProperty:properties[i]];
            NSString *recordName = [aRecordClass
                                    performSelector:@selector(recordName)];
            if(![ignoredFields containsObject:column.columnName]){
                [self.schemes addValue:column toArrayNamed:recordName];
                NSMutableDictionary *columns = [_columnLookup objectForKey:recordName];
                if (!columns) {
                    columns = [NSMutableDictionary dictionary];
                    [_columnLookup setObject:columns forKey:recordName];
                }
                [columns setObject:column forKey:column.columnName];
            }
            if([indexedFields containsObject:column.columnName]){
                [self.indexSchemes addValue:column
                               toArrayNamed:recordName];
            }
            [column release];
        }
        free(properties);
        CurrentClass = class_getSuperclass(CurrentClass);
    }
}

- (NSArray *)columnsForRecord:(Class)aRecordClass {
    return [[self.schemes valueForKey:[aRecordClass performSelector:@selector(recordName)]] allObjects];
}

- (ARColumn *)columnNamed:(NSString *)aColumnName forRecord:(Class)aRecordClass {
    return [[_columnLookup objectForKey:[aRecordClass performSelector:@selector(recordName)]] objectForKey:aColumnName];
}


- (NSArray *)indexesForRecord:(Class)aRecordClass {
    return [[self.indexSchemes valueForKey:[aRecordClass performSelector:@selector(recordName)]] allObjects];
}

@end
