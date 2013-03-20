//
//  ARColumnManager.h
//  iActiveRecord
//
//  Created by Alex Denisov on 01.05.12.
//  Copyright (c) 2012 CoreInvader. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ARSchemaManager : NSObject

@property (nonatomic, retain) NSMutableDictionary *schemes;
@property (nonatomic, retain) NSMutableDictionary *indexSchemes;

+ (id)sharedInstance;

- (void)registerSchemeForRecord:(Class)aRecordClass;
- (NSArray *)columnsForRecord:(Class)aRecordClass;
- (NSArray *)indexesForRecord:(Class)aRecordClass;

@end
