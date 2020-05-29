//
//  AWMemoryCache.m
//  AWCache
//
//  Created by liangaiwu on 2020/5/29.
//


#import "AWMemoryCache.h"
#import <UIKit/UIKit.h>

#ifndef AW_LOCK
#define AW_LOCK(lock) dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
#endif

#ifndef AW_UNLOCK
#define AW_UNLOCK(lock) dispatch_semaphore_signal(lock);
#endif

@interface AWMemoryCache <KeyType, ObjectType> ()


@property (nonatomic, strong, nonnull) NSMapTable<KeyType, ObjectType> *weakCache;
@property (nonatomic, strong, nonnull) dispatch_semaphore_t weakCacheLock;

@end

@implementation AWMemoryCache


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (AWMemoryCache *)sharedMemoryCache {
    static dispatch_once_t onceToken;
    static id instance;
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    
    self.weakCache = [[NSMapTable alloc]initWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory capacity:0];
    self.weakCacheLock = dispatch_semaphore_create(1);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidReceiveMemoryWarningNotification) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackgroundNotification) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

#pragma mark - public
- (void)setObject:(id)obj forKey:(id)key cost:(NSUInteger)g {
    
    [super setObject:obj forKey:key cost:g];
    if(key && obj) {
        AW_LOCK(self.weakCacheLock);
        [self.weakCache setObject:obj forKey:key];
        AW_UNLOCK(self.weakCacheLock);
    }
}

- (id)objectForKey:(id)key {
    
    if(!key) return nil;
    id obj = [super objectForKey: key];
    if(!obj) {
        AW_LOCK(self.weakCacheLock);
        obj = [self.weakCache objectForKey:key];
        AW_UNLOCK(self.weakCacheLock);
        if(obj) {
            [super setObject:obj forKey:key cost:0];
        }
    }
    return obj;
}

- (void)removeObjectForKey:(id)key {
    
    if(!key) return;
    [super removeObjectForKey:key];
    AW_LOCK(self.weakCacheLock);
    [self.weakCache removeObjectForKey:key];
    AW_UNLOCK(self.weakCacheLock);
}

- (void)removeAllObjects {
    
    [super removeAllObjects];
    AW_LOCK(self.weakCacheLock);
    [self.weakCache removeAllObjects];
    AW_UNLOCK(self.weakCacheLock);
}

#pragma mark - Notification
- (void)appDidReceiveMemoryWarningNotification {
    
    if (self.shouldRemoveAllObjectsOnMemoryWarning) {
        [super removeAllObjects];
    }
}

- (void)appDidEnterBackgroundNotification {
    
    if (self.shouldRemoveAllObjectsWhenEnteringBackground) {
        [super removeAllObjects];
    }
}


@end
