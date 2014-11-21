//
//  ARDatabaseManager.m
//  iActiveRecord
//
//  Created by Alex Denisov on 10.01.12.
//  Copyright (c) 2012 CoreInvader. All rights reserved.
//

#import "ARDatabaseManager.h"
#import "ActiveRecord.h"
#import "class_getSubclasses.h"
#import "NSString+quotedString.h"
#include <sys/xattr.h>
#import "sqlite3_unicode.h"
#import "ARColumn.h"
#import "ActiveRecord_Private.h"

#define DEFAULT_DBNAME @"database"

#if 0
    #define SQLLog(fmt, ...) NSLog(fmt, ##__VA_ARGS__)
#else
    #define SQLLog(fmt, ...) //NSLog(fmt, ##__VA_ARGS__)
#endif

@implementation ARDatabaseManager

static BOOL useCacheDirectory = YES;
static NSString *databaseName = DEFAULT_DBNAME;

static BOOL migrationsEnabled = YES;

+ (void)registerDatabase:(NSString *)aDatabaseName cachesDirectory:(BOOL)isCache {
    databaseName = [aDatabaseName copy];
    useCacheDirectory = isCache;
}

+ (id)sharedInstance {
    static ARDatabaseManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ARDatabaseManager alloc] init];
    });
    return instance;
}

+ (dispatch_queue_t)sqliteQueue {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.iActiveRecord.sqlite", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

- (id)init {
    self = [super init];
    if(nil != self){
#ifdef UNIT_TEST
        dbName = [[NSString alloc] initWithFormat:@"%@-test.sqlite", databaseName];
#else
        dbName = [[NSString alloc] initWithFormat:@"%@.sqlite", databaseName];
#endif
        NSString *storageDirectory = useCacheDirectory ? [self cachesDirectory] : [self documentsDirectory];
        dbPath = [[NSString alloc] initWithFormat:@"%@/%@", storageDirectory, dbName];
        NSLog(@"%@", dbPath);
        [self createDatabase];
    }
    return self;
}

- (void)dealloc{
    [self closeConnection];
    [dbName release];
    [dbPath release];
    [super dealloc];
}

- (void)createDatabase {
    if(![[NSFileManager defaultManager] fileExistsAtPath:dbPath]){
        [[NSFileManager defaultManager] createFileAtPath:dbPath contents:nil attributes:nil];
        if(!useCacheDirectory){
            [self skipBackupAttributeToFile:[NSURL fileURLWithPath:dbPath]];
        }
        [self openConnection];
        [self createTables];
        return;
    }
    [self openConnection];
    [self appendMigrations];
}

- (void)clearDatabase {
    NSArray *entities = class_getSubclasses([ActiveRecord class]);
    for(Class Record in entities){
        [Record performSelector:@selector(dropAllRecords)];
    }
}

- (void)createTables {
    NSArray *entities = class_getSubclasses([ActiveRecord class]);
    for(Class Record in entities){
        [self createTable:Record];
    }
}

- (void)createTable:(id)aRecord {
    const char *sqlQuery = (const char *)[aRecord performSelector:@selector(sqlOnCreate)];
    [self executeSqlQuery:sqlQuery];
}

- (void)appendMigrations {
    if(!migrationsEnabled){
        return;
    }
    NSArray *existedTables = [self tables];
    NSArray *describedTables = [self describedTables];
    for(NSString *table in describedTables){
        if(![existedTables containsObject:table]){
            [self createTable:NSClassFromString(table)];
        }else{
            Class Record = NSClassFromString(table);
            NSArray *existedColumns = [self columnsForTable:table];
            
            NSArray *describedProperties = [Record performSelector:@selector(columns)];
            NSMutableArray *describedColumns = [NSMutableArray array];
            for(ARColumn *column in describedProperties){
                [describedColumns addObject:column.columnName];
            }
            for(NSString *column in describedColumns){
                if(![existedColumns containsObject:column]){
                    const char *sql = (const char *)[Record performSelector:@selector(sqlOnAddColumn:) 
                                                                 withObject:column];
                    [self executeSqlQuery:sql];
                }
            }
        }
    }
}

- (void)addColumn:(NSString *)aColumn onTable:(NSString *)aTable {
    
}

- (NSArray *)describedTables {
    NSArray *entities = class_getSubclasses([ActiveRecord class]);
    NSMutableArray *tables = [NSMutableArray arrayWithCapacity:entities.count];
    for(Class record in entities){
        [tables addObject:NSStringFromClass(record)];
    }
    return tables;
}

- (NSArray *)columnsForTable:(NSString *)aTableName {
    NSString *sql = [NSString stringWithFormat:@"PRAGMA table_info(%@)", [aTableName quotedString]];
    __block NSMutableArray *resultArray = nil;
    dispatch_sync([ARDatabaseManager sqliteQueue], ^{
        char **results;
        int nRows;
        int nColumns;
        const char *pszSql = [sql UTF8String];
        if(SQLITE_OK == sqlite3_get_table(database,
                                          pszSql,
                                          &results,
                                          &nRows,
                                          &nColumns,
                                          NULL))
        {
            resultArray = [NSMutableArray arrayWithCapacity:nRows++];
            for(int i=0;i<nRows-1;i++){
                int index = (i + 1)*nColumns + 1;
                const char *pszValue = results[index];
                if(pszValue){
                    [resultArray addObject:[NSString stringWithUTF8String:pszValue]];
                }
            }
            sqlite3_free_table(results);
        }else
        {
            NSLog(@"Couldn't retrieve data from database: %s", sqlite3_errmsg(database));
        }
    });
    return resultArray;
}

//  select tbl_name from sqlite_master where type='table' and name not like 'sqlite_%'
- (NSArray *)tables {
    __block NSMutableArray *resultArray = nil;
    dispatch_sync([ARDatabaseManager sqliteQueue], ^{
        char **results;
        int nRows;
        int nColumns;
        const char *pszSql = [@"select tbl_name from sqlite_master where type='table' and name not like 'sqlite_%'" UTF8String];
        if(SQLITE_OK == sqlite3_get_table(database,
                                          pszSql,
                                          &results,
                                          &nRows,
                                          &nColumns,
                                          NULL))
        {
            resultArray = [NSMutableArray arrayWithCapacity:nRows++];
            for(int i=0;i<nRows-1;i++){
                for(int j=0;j<nColumns;j++){
                    int index = (i+1)*nColumns + j;
                    [resultArray addObject:[NSString stringWithUTF8String:results[index]]];
                }
            }
            sqlite3_free_table(results);
        }else
        {
            NSLog(@"Couldn't retrieve data from database: %s", sqlite3_errmsg(database));
        }
    });
    return resultArray;
}

- (void)openConnection {
    dispatch_sync([ARDatabaseManager sqliteQueue], ^{
        sqlite3_unicode_load();
        if(SQLITE_OK != sqlite3_open([dbPath UTF8String], &database)){
            NSLog(@"Couldn't open database connection: %s", sqlite3_errmsg(database));
        }
    });
}

- (NSString *)tableName:(NSString *)modelName {
    return [[NSString stringWithFormat:@"%@", modelName] quotedString];
}

- (void)closeConnection {
    dispatch_sync([ARDatabaseManager sqliteQueue], ^{
        sqlite3_close(database);
        sqlite3_unicode_free();
    });
}

- (NSNumber *)insertRecord:(NSString *)aRecordName withSqlQuery:(const char *)anSqlQuery {
    [self executeSqlQuery:anSqlQuery];
    return [self getLastId:aRecordName];
}

- (void)executeSqlQuery:(const char *)anSqlQuery {
    SQLLog(@"execute: %s", anSqlQuery);
    dispatch_sync([ARDatabaseManager sqliteQueue], ^{
        if(SQLITE_OK != sqlite3_exec(database, anSqlQuery, NULL, NULL, NULL)){
            NSLog(@"Couldn't execute query %s : %s", anSqlQuery, sqlite3_errmsg(database));
        }
    });
}
 
- (NSString *)documentsDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
}

- (NSString *)cachesDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
}

- (NSArray *)allRecordsWithName:(NSString *)aName withSql:(NSString *)aSqlRequest{
    SQLLog(@"read: %@", aSqlRequest);
    __block NSMutableArray *resultArray = nil;
    dispatch_sync([ARDatabaseManager sqliteQueue], ^{
        NSString *propertyName;
        id aValue;
        Class Record;
        char **results;
        int nRows;
        int nColumns;
        const char *pszSql = [aSqlRequest UTF8String];
        if(SQLITE_OK == sqlite3_get_table(database,
                                          pszSql,
                                          &results,
                                          &nRows,
                                          &nColumns,
                                          NULL))
        {
            resultArray = [NSMutableArray arrayWithCapacity:nRows++];
            Record = NSClassFromString(aName);
            BOOL hasColumns = NO;
            Class *columnClasses = malloc(sizeof(Class) * nColumns);
            for(int i=0;i<nRows-1;i++){
                id record = [Record new];
                for(int j=0;j<nColumns;j++){
                    propertyName = [NSString stringWithUTF8String:results[j]];

                    if (!hasColumns) {
                        ARColumn *column = [Record performSelector:@selector(columnNamed:)
                                                        withObject:propertyName];
                        columnClasses[j] = column.columnClass;
                    }

                    int index = (i+1)*nColumns + j;
                    const char *pszValue = results[index];
                    
                    if(pszValue){
                        NSString *sqlData = [NSString stringWithUTF8String:pszValue];
                        aValue = [columnClasses[j] performSelector:@selector(fromSql:)
                                                     withObject:sqlData];
                        [record setValue:aValue forKey:propertyName];
                    }
                }
                hasColumns = YES;
                [resultArray addObject:record];
                [record release];
            }
            free(columnClasses);
            sqlite3_free_table(results);
        }else
        {
            NSLog(@"%@", aSqlRequest);
            NSLog(@"Couldn't retrieve data from database: %s", sqlite3_errmsg(database));
        }
    });
    return resultArray;
}

- (NSArray *)joinedRecordsWithSql:(NSString *)aSqlRequest {
    SQLLog(@"joined SQL: %@", aSqlRequest);
    __block NSMutableArray *resultArray = nil;
    __block NSMutableArray *columnTypesArray = nil;
    dispatch_sync([ARDatabaseManager sqliteQueue], ^{
        NSString *propertyName;
        NSString *header;
        id aValue;
        char **results;
        int nRows;
        int nColumns;
        const char *pszSql = [aSqlRequest UTF8String];
        if(SQLITE_OK == sqlite3_get_table(database,
                                          pszSql,
                                          &results,
                                          &nRows,
                                          &nColumns,
                                          NULL))
        {
            resultArray = [NSMutableArray arrayWithCapacity:nRows++];
            columnTypesArray = [NSMutableArray array];
            for(int i=0;i<nRows-1;i++){
                NSMutableDictionary *dictionary = [NSMutableDictionary new];
                NSString *recordName = nil;
                for(int j=0;j<nColumns;j++){
                    header = [NSString stringWithUTF8String:results[j]];
                    
                    recordName = [[header componentsSeparatedByString:@"#"] objectAtIndex:0];
                    propertyName = [[header componentsSeparatedByString:@"#"] objectAtIndex:1];
                    
                    Class Record = NSClassFromString(recordName);
                    
                    id currentRecord = [dictionary valueForKey:recordName];
                    if(currentRecord == nil){
                        currentRecord = [Record new];
                        [dictionary setValue:currentRecord
                                      forKey:recordName];
                    }
                    
                    int index = (i+1)*nColumns + j;
                    const char *pszValue = results[index];

                    // Cache column class types as we iterate over many records
                    Class columnClass;
                    if (columnTypesArray.count == j){
                        ARColumn *column = [Record
                                            performSelector:@selector(columnNamed:)
                                            withObject:propertyName];
                        columnClass = column.columnClass;
                        [columnTypesArray addObject:columnClass];
                    } else {
                        columnClass = columnTypesArray[j];
                    }
                    
                    if(pszValue){
                        NSString *sqlData = [NSString stringWithUTF8String:pszValue];
                        aValue = [columnClass performSelector:@selector(fromSql:) 
                                                     withObject:sqlData];
                        [currentRecord setValue:aValue
                                         forKey:propertyName];
                    }
                }
                [resultArray addObject:dictionary];
                [dictionary release];
            }
            sqlite3_free_table(results);
        }else
        {
            NSLog(@"%@", aSqlRequest);
            NSLog(@"Couldn't retrieve data from database: %s", sqlite3_errmsg(database));
        }
    });
    return resultArray;
}

- (NSInteger)countOfRecordsWithName:(NSString *)aName {
    NSString *aSqlRequest = [NSString stringWithFormat:
                             @"SELECT count(id) FROM %@", 
                             [self tableName:aName]];
    return [self functionResult:aSqlRequest];
}

- (NSNumber *)getLastId:(NSString *)aRecordName {
    NSString *aSqlRequest = [NSString stringWithFormat:@"select MAX(id) from %@", 
                             [aRecordName quotedString]];
    NSInteger res = [self functionResult:aSqlRequest];
    return [NSNumber numberWithLong:res];
}

- (NSInteger)functionResult:(NSString *)anSql {
    __block NSInteger resId = 0;
    dispatch_sync([ARDatabaseManager sqliteQueue], ^{
        char **results;
        int nRows;
        int nColumns;
        const char *pszSql = [anSql UTF8String];
        if(SQLITE_OK == sqlite3_get_table(database,
                                          pszSql,
                                          &results,
                                          &nRows,
                                          &nColumns,
                                          NULL))
        {
            if(nRows == 0 || nColumns == 0){
                resId = -1;
            }else{
                resId = [[NSString stringWithUTF8String:results[1]] integerValue];
            }

            sqlite3_free_table(results);
        }else
        {
            NSLog(@"%@", anSql);
            NSLog(@"Couldn't retrieve data from database: %s", sqlite3_errmsg(database));
        }
    });
    return resId;
}

- (void)skipBackupAttributeToFile:(NSURL *)url {
    u_int8_t b = 1;
    setxattr([[url path] fileSystemRepresentation], "com.apple.MobileBackup", &b, 1, 0, 0);
}

+ (void)disableMigrations {
    migrationsEnabled = NO;
}

@end
