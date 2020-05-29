//
//  AWMemoryCache.h
//  AWCache
//
//  Created by liangaiwu on 2020/5/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AWMemoryCache<KeyType, ObjectType> : NSCache <KeyType, ObjectType>

@property (nonatomic, class, readonly, nonnull) AWMemoryCache *sharedMemoryCache;

@property (assign, nonatomic) BOOL shouldRemoveAllObjectsOnMemoryWarning;

@property (assign, nonatomic) BOOL shouldRemoveAllObjectsWhenEnteringBackground;

@end

NS_ASSUME_NONNULL_END
