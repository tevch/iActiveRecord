//
//  class_getSubclasses.h
//  iActiveRecord
//
//  Created by Alex Denisov on 21.03.12.
//  Copyright (c) 2012 okolodev.org. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSArray *class_getSubclasses(Class parentClass) {
    /*
    int numClasses = objc_getClassList(NULL, 0);
    Class classes[sizeof(Class) * numClasses];
    numClasses = objc_getClassList(classes, numClasses);
    NSMutableArray *result = [NSMutableArray array];
    for (NSInteger i = 0; i < numClasses; i++) {
        Class superClass = classes[i];
        do{
            superClass = class_getSuperclass(superClass);
        } while(superClass && superClass != parentClass);
        
        if (superClass == nil) {
            continue;
        }
        [result addObject:classes[i]];
    }
    return result;
     */
     

    
    
     int numClasses = objc_getClassList(NULL, 0);
     Class *classes = NULL;
    
     classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
     numClasses = objc_getClassList(classes, numClasses);
    
     NSMutableArray *result = [NSMutableArray array];
     for (NSInteger i = 0; i < numClasses; i++)
     {
     Class superClass = classes[i];
     do
     {
     superClass = class_getSuperclass(superClass);
     } while(superClass && superClass != parentClass);
     
     if (superClass == nil)
     {
     continue;
     }
     
     [result addObject:classes[i]];
     }
     
     free(classes);
     
     return result;
}
