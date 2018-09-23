//
//  XYDBUtil.m
//
//
//  Created by mofeini on 17/2/10.
//  Copyright © 2017年 com.test.demo. All rights reserved.
//

#import "XYDBUtil.h"
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"
#import "NSObject+XYProperties.h"

#ifdef DEBUG
#define debugLog(...)    NSLog(__VA_ARGS__)
#define debugMethod()    NSLog(@"%s", __func__)
#define debugError()     NSLog(@"Error at %s Line:%d", __func__, __LINE__)
#else
#define debugLog(...)
#define debugMethod()
#define debugError()
#endif

#define PATH_OF_CACHES    [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0]

@implementation XYDBUtilItem

- (NSString *)description {
    return [NSString stringWithFormat:@"id=%@, value=%@, timeStamp=%@", self.xy_itemId, self.xy_itemObject, self.xy_createdTime];
}

@end

@interface XYDBUtil()

@property (strong, nonatomic) FMDatabaseQueue * dbQueue;
@property (nonatomic, copy) NSString *dbPath;

@end

@implementation XYDBUtil

static NSString *const DEFAULT_DB_NAME = @"database.sqlite";

static NSString *const CREATE_TABLE_SQL =
@"CREATE TABLE IF NOT EXISTS %@ ( \
id TEXT NOT NULL, \
json TEXT NOT NULL, \
createdTime TEXT NOT NULL, \
PRIMARY KEY(id)) \
";

static NSString *const UPDATE_ITEM_SQL = @"REPLACE INTO %@ (id, json, createdTime) values (?, ?, ?)";

static NSString *const QUERY_ITEM_SQL = @"SELECT json, createdTime from %@ where id = ? Limit 1";

static NSString *const SELECT_ALL_SQL = @"SELECT * from %@";

static NSString *const CLEAR_ALL_SQL = @"DELETE from %@";

static NSString *const DELETE_ITEM_SQL = @"DELETE from %@ where id = ?";

static NSString *const DELETE_ITEMS_SQL = @"DELETE from %@ where id in ( %@ )";

static NSString *const DELETE_ITEMS_WITH_PREFIX_SQL = @"DELETE from %@ where id like ? ";

+ (BOOL)xy_checkTableName:(NSString *)tableName {
    if (tableName == nil || tableName.length == 0 || [tableName rangeOfString:@" "].location != NSNotFound) {
        debugLog(@"ERROR, table name: %@ format error.", tableName);
        return NO;
    }
    return YES;
}

- (id)init {
    return [self initDBWithName:DEFAULT_DB_NAME];
}

- (id)initDBWithName:(NSString *)dbName {
    self = [super init];
    if (self) {
        NSString * dbPath = [PATH_OF_CACHES stringByAppendingPathComponent:dbName];
        _dbPath = dbPath;
        if (_dbQueue) {
            [self xy_close];
        }
        _dbQueue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
    }
    return self;
}

- (id)initWithDBWithPath:(NSString *)dbPath {
    self = [super init];
    if (self) {
        _dbPath = dbPath;
        if (_dbQueue) {
            [self xy_close];
        }
        _dbQueue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
    }
    return self;
}

- (void)xy_createTableWithName:(NSString *)tableName {
    if ([XYDBUtil xy_checkTableName:tableName] == NO) {
        return;
    }
    NSString * sql = [NSString stringWithFormat:CREATE_TABLE_SQL, tableName];
    __block BOOL result;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql];
    }];
    if (!result) {
        debugLog(@"ERROR, failed to create table: %@", tableName);
    }
}

- (void)xy_clearTable:(NSString *)tableName {
    if ([XYDBUtil xy_checkTableName:tableName] == NO) {
        return;
    }
    NSString * sql = [NSString stringWithFormat:CLEAR_ALL_SQL, tableName];
    __block BOOL result;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql];
    }];
    if (!result) {
        debugLog(@"ERROR, failed to clear table: %@", tableName);
    }
}

- (void)xy_putObject:(id)object withId:(NSString *)objectId intoTable:(NSString *)tableName {
    if ([XYDBUtil xy_checkTableName:tableName] == NO) {
        return;
    }
    
    NSError * error;
    id obj = nil;
    NSBundle *mainB = [NSBundle bundleForClass:[object class]];
    if (mainB == [NSBundle mainBundle]) {
        obj = [object xy_allProperties];
        
    }else
    {
        obj = object;
    }
    
    NSData * data = [NSJSONSerialization dataWithJSONObject:obj options:0 error:&error];
    if (error) {
        debugLog(@"ERROR, faild to get json data");
        return;
    }
    NSString * jsonString = [[NSString alloc] initWithData:data encoding:(NSUTF8StringEncoding)];
    NSDate * createdTime = [NSDate date];
    NSString * sql = [NSString stringWithFormat:UPDATE_ITEM_SQL, tableName];
    __block BOOL result;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql, objectId, jsonString, createdTime];
    }];
    if (!result) {
        debugLog(@"ERROR, failed to insert/replace into table: %@", tableName);
    }
}

- (id)xy_getObjectById:(NSString *)objectId fromTable:(NSString *)tableName {
    XYDBUtilItem * item = [self xy_getDBItemById:objectId fromTable:tableName];
    if (item) {
        return item.xy_itemObject;
    } else {
        return nil;
    }
}


- (XYDBUtilItem *)xy_getDBItemById:(NSString *)objectId fromTable:(NSString *)tableName {
    if ([XYDBUtil xy_checkTableName:tableName] == NO) {
        return nil;
    }
    NSString * sql = [NSString stringWithFormat:QUERY_ITEM_SQL, tableName];
    __block NSString * json = nil;
    __block NSDate * createdTime = nil;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet * rs = [db executeQuery:sql, objectId];
        if ([rs next]) {
            json = [rs stringForColumn:@"json"];
            createdTime = [rs dateForColumn:@"createdTime"];
        }
        [rs close];
    }];
    if (json) {
        NSError * error;
        id result = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:(NSJSONReadingAllowFragments) error:&error];
        if (error) {
            debugLog(@"ERROR, faild to prase to json");
            return nil;
        }
        XYDBUtilItem * item = [[XYDBUtilItem alloc] init];
        item.xy_itemId = objectId;
        item.xy_itemObject = result;
        item.xy_createdTime = createdTime;
        return item;
    } else {
        return nil;
    }
}

- (void)xy_putString:(NSString *)string withId:(NSString *)stringId intoTable:(NSString *)tableName {
    if (string == nil) {
        debugLog(@"error, string is nil");
        return;
    }
    [self xy_putObject:@[string] withId:stringId intoTable:tableName];
}

- (NSString *)xy_getStringById:(NSString *)stringId fromTable:(NSString *)tableName {
    NSArray * array = [self xy_getObjectById:stringId fromTable:tableName];
    if (array && [array isKindOfClass:[NSArray class]]) {
        return array[0];
    }
    return nil;
}

- (void)xy_putNumber:(NSNumber *)number withId:(NSString *)numberId intoTable:(NSString *)tableName {
    if (number == nil) {
        debugLog(@"error, number is nil");
        return;
    }
    [self xy_putObject:@[number] withId:numberId intoTable:tableName];
}

- (NSNumber *)xy_getNumberById:(NSString *)numberId fromTable:(NSString *)tableName {
    NSArray * array = [self xy_getObjectById:numberId fromTable:tableName];
    if (array && [array isKindOfClass:[NSArray class]]) {
        return array[0];
    }
    return nil;
}

- (NSArray *)xy_getAllItemsFromTable:(NSString *)tableName {
    if ([XYDBUtil xy_checkTableName:tableName] == NO) {
        return nil;
    }
    NSString * sql = [NSString stringWithFormat:SELECT_ALL_SQL, tableName];
    __block NSMutableArray * result = [NSMutableArray array];
    [_dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet * rs = [db executeQuery:sql];
        while ([rs next]) {
            XYDBUtilItem * item = [[XYDBUtilItem alloc] init];
            item.xy_itemId = [rs stringForColumn:@"id"];
            item.xy_itemObject = [rs stringForColumn:@"json"];
            item.xy_createdTime = [rs dateForColumn:@"createdTime"];
            [result addObject:item];
        }
        [rs close];
    }];
    // parse json string to object
    NSError * error;
    for (XYDBUtilItem * item in result) {
        error = nil;
        id object = [NSJSONSerialization JSONObjectWithData:[item.xy_itemObject dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:(NSJSONReadingAllowFragments) error:&error];
        if (error) {
            debugLog(@"ERROR, faild to prase to json.");
        } else {
            item.xy_itemObject = object;
        }
    }
    return result;
}

- (void)xy_deleteObjectById:(NSString *)objectId fromTable:(NSString *)tableName {
    if ([XYDBUtil xy_checkTableName:tableName] == NO) {
        return;
    }
    NSString * sql = [NSString stringWithFormat:DELETE_ITEM_SQL, tableName];
    __block BOOL result;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql, objectId];
    }];
    if (!result) {
        debugLog(@"ERROR, failed to delete item from table: %@", tableName);
    }
}

- (void)xy_deleteObjectsByIdArray:(NSArray *)objectIdArray fromTable:(NSString *)tableName {
    if ([XYDBUtil xy_checkTableName:tableName] == NO) {
        return;
    }
    NSMutableString *stringBuilder = [NSMutableString string];
    for (id objectId in objectIdArray) {
        NSString *item = [NSString stringWithFormat:@" '%@' ", objectId];
        if (stringBuilder.length == 0) {
            [stringBuilder appendString:item];
        } else {
            [stringBuilder appendString:@","];
            [stringBuilder appendString:item];
        }
    }
    NSString *sql = [NSString stringWithFormat:DELETE_ITEMS_SQL, tableName, stringBuilder];
    __block BOOL result;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql];
    }];
    if (!result) {
        debugLog(@"ERROR, failed to delete items by ids from table: %@", tableName);
    }
}

- (void)xy_deleteObjectsByIdPrefix:(NSString *)objectIdPrefix fromTable:(NSString *)tableName {
    if ([XYDBUtil xy_checkTableName:tableName] == NO) {
        return;
    }
    NSString *sql = [NSString stringWithFormat:DELETE_ITEMS_WITH_PREFIX_SQL, tableName];
    NSString *prefixArgument = [NSString stringWithFormat:@"%@%%", objectIdPrefix];
    __block BOOL result;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql, prefixArgument];
    }];
    if (!result) {
        debugLog(@"ERROR, failed to delete items by id prefix from table: %@", tableName);
    }
}

- (void)xy_close {
    [_dbQueue close];
    _dbQueue = nil;
}

- (NSArray *)xy_getItemsFromTable:(NSString *)tableName withRange:(NSRange)range {
    
    if ([XYDBUtil xy_checkTableName:tableName] == NO) {
        return nil;
    }
    
    NSString * sql = [NSString stringWithFormat:@"SELECT * FROM %@ LIMIT %zd, %zd",tableName, range.location, range.length];
    __block NSMutableArray * result = [NSMutableArray array];
    [_dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet * rs = [db executeQuery:sql];
        while ([rs next]) {
            XYDBUtilItem * item = [[XYDBUtilItem alloc] init];
            item.xy_itemId = [rs stringForColumn:@"id"];
            item.xy_itemObject = [rs stringForColumn:@"json"];
            item.xy_createdTime = [rs dateForColumn:@"createdTime"];
            [result addObject:item];
        }
        [rs close];
    }];
    // parse json string to object
    NSError * error;
    for (XYDBUtilItem * item in result) {
        error = nil;
        id object = [NSJSONSerialization JSONObjectWithData:[item.xy_itemObject dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:(NSJSONReadingAllowFragments) error:&error];
        if (error) {
            debugLog(@"ERROR, faild to prase to json.");
        } else {
            item.xy_itemObject = object;
        }
    }
    return result;
    
    
}

- (BOOL)xy_isExistTableWithName:(NSString *)tableName
{
    __block BOOL result;
    
    [_dbQueue inDatabase:^(FMDatabase *db) {
        FMResultSet * rs = [db executeQuery:@"select count(*) as 'count' from sqlite_master where type ='table' and name = ?", tableName];
        while ([rs next])
        {
            // just print out what we've got in a number of formats.
            NSInteger count = [rs intForColumn:@"count"];
            if (0 == count)
            {
                result = NO;
            }
            else
            {
                result = YES;
            }
        }
        
    }];
    return result;
}

// 删除表
- (BOOL)xy_deleteTable:(NSString *)tableName
{
    __block BOOL result;
    [_dbQueue inDatabase:^(FMDatabase *db) {
        NSString *sqlstr = [NSString stringWithFormat:@"DROP TABLE %@", tableName];
        if (![db executeUpdate:sqlstr])
        {
            debugLog(@"Delete table error!");
            result = NO;
        }
        result = YES;
    }];
    return result;
}

// 删除数据库
- (void)xy_deleteDatabseWithDBName:(NSString *)DBName
{
    __block BOOL success;
    __block NSError *error;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // delete the old db.
    if ([fileManager fileExistsAtPath:DBName])
    {
        [_dbQueue inDatabase:^(FMDatabase *db) {
            [db close];
            success = [fileManager removeItemAtPath:DBName error:&error];
            if (!success) {
                NSAssert1(0, @"Failed to delete old database file with message '%@'.", [error localizedDescription]);
            }
        }];
    }
}

- (NSString *)xy_getDBPath {
    return _dbPath;
}
@end
