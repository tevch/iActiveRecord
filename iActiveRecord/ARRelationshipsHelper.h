//
//  ARRelationships.m
//  iActiveRecord
//
//  Created by Alex Denisov on 10.01.12.
//  Copyright (c) 2012 CoreInvader. All rights reserved.
//

#import "NSString+lowercaseFirst.h"

#import <objc/runtime.h>

#define belongs_to_imp(class, getter, dependency) \
+ (ARDependency)_ar_registerBelongsTo##class {\
return dependency;\
}\
- (id)getter{\
NSString *class_name = @""#class"";\
return [self performSelector:@selector(belongsTo:) withObject:class_name];\
}\
- (void)set##class:(ActiveRecord *)aRecord {\
NSString *aClassName = @""#class"";\
void (*action)(id, SEL, ActiveRecord*, NSString*) = (void (*)(id, SEL, ActiveRecord*, NSString*)) objc_msgSend;\
action(self, sel_getUid("setRecord:belongsTo:"), aRecord, aClassName);\
}

#define belongs_to_dec(class, getter, dependency) \
- (id)getter;\
- (void)set##class:(ActiveRecord *)aRecord;


#define has_many_dec(relative_class, accessor, dependency)\
- (ARLazyFetcher *)accessor;\
- (void)add##relative_class:(ActiveRecord *)aRecord;\
- (void)remove##relative_class:(ActiveRecord *)aRecord;

#define has_many_imp(relative_class, accessor, dependency) \
+ (ARDependency)_ar_registerHasMany##relative_class{\
return dependency;\
}\
- (ARLazyFetcher *)accessor{\
NSString *class_name = @""#relative_class"";\
ARLazyFetcher* (*action)(id, SEL, NSString*) = (ARLazyFetcher* (*)(id, SEL, NSString*)) objc_msgSend;\
return action(self, sel_getUid("hasManyRecords:"), class_name);\
}\
- (void)add##relative_class:(ActiveRecord *)aRecord {\
void (*action)(id, SEL, ActiveRecord*) = (void (*)(id, SEL, ActiveRecord*)) objc_msgSend;\
action(self, sel_getUid("addRecord:"), aRecord);\
}\
- (void)remove##relative_class:(ActiveRecord *)aRecord {\
void (*action)(id, SEL, ActiveRecord*) = (void (*)(id, SEL, ActiveRecord*)) objc_msgSend;\
action(self, sel_getUid("removeRecord:"), aRecord);\
}

#define has_many_through_dec(relative_class, relationship, accessor, dependency) \
- (ARLazyFetcher *)accessor;\
- (void)add##relative_class:(ActiveRecord *)aRecord;\
- (void)remove##relative_class:(ActiveRecord *)aRecord;

#define has_many_through_imp(relative_class, relationship, accessor, dependency) \
+ (ARDependency)_ar_registerHasManyThrough##relative_class##_ar_##relationship{\
return dependency;\
}\
- (ARLazyFetcher *)accessor\
{\
NSString *className = @""#relative_class"";\
NSString *relativeClassName = @""#relationship"";\
ARLazyFetcher* (*action)(id, SEL, NSString*, NSString*) = (ARLazyFetcher* (*)(id, SEL, NSString*, NSString*)) objc_msgSend;\
return action(self, sel_getUid("hasMany:through:"), className, relativeClassName);\
}\
- (void)add##relative_class:(ActiveRecord *)aRecord {\
NSString *className = @""#relative_class"";\
NSString *relativeClassName = @""#relationship"";\
void (*action)(id, SEL, ActiveRecord*, NSString*, NSString*) = (void (*)(id, SEL, ActiveRecord*, NSString*, NSString*)) objc_msgSend;\
action(self, sel_getUid("addRecord:ofClass:through:"), aRecord, className, relativeClassName);\
}\
- (void)remove##relative_class:(ActiveRecord *)aRecord {\
NSString *className = @""#relationship"";\
void (*action)(id, SEL, ActiveRecord*, NSString*) = (void (*)(id, SEL, ActiveRecord*, NSString*)) objc_msgSend;\
action(self, sel_getUid("removeRecord:through:"), aRecord, className);\
}


