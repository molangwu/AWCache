//  
//  AWDiskCache.h
//  AWCache
//
//  Created by liangaiwu on 2020/5/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, AWDiskCacheExpireType) {
    AWDiskCacheExpireTypeModificationDate,
    AWDiskCacheExpireTypeAccessDate,
    AWDiskCacheExpireTypeCreationDate
};

@interface AWDiskCache : NSObject

@property (nonatomic, class, readonly, nonnull) AWDiskCache *sharedDiskCache;

@property (nonatomic, assign) NSDataReadingOptions diskCacheReadingOptions;
@property (nonatomic, assign) NSDataWritingOptions diskCacheWritingOptions;

@property (assign, nonatomic) AWDiskCacheExpireType diskCacheExpireType;

@property (nonatomic, assign) NSTimeInterval maxDiskAge;
@property (nonatomic, assign) NSUInteger maxDiskSize;

- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithCacheName:(NSString *)name;
- (nullable instancetype)initWithCachePath:(NSString *)cachePath;

- (NSUInteger)totalSize;
- (void)totalSizeWithBlock:(void(^)(NSUInteger))block;

- (NSUInteger)totalCount;
- (void)totalCountWithBlock:(void(^)(NSUInteger))block;

- (nullable NSData *)dataForKey:(NSString *)key;
- (void)dataForKey:(NSString *)key withBlock:(void(^)(NSString *key, NSData * _Nullable data))block;

- (void)setData:(NSData *)data forKey:(NSString *)key;
- (void)setData:(NSData *)data forKey:(NSString *)key withBlock:(nullable void(^)(NSString *key))block;

- (void)removeDataForKey:(NSString *)key;
- (void)removeDataForKey:(NSString *)key withBlock:(nullable void(^)(NSString *key))block;

- (void)removeAllData;
- (void)removeAllDataWithBlock:(nullable void(^)(void))block;

- (void)removeExpiredData;
- (void)removeExpiredDataWithBlock:(nullable void(^)(void))block;

@end

NS_ASSUME_NONNULL_END
