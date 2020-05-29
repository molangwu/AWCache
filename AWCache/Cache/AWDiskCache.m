//
//  AWDiskCache.m
//  AWCache
//
//  Created by liangaiwu on 2020/5/29.
//

#import "AWDiskCache.h"
#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonDigest.h>

static const NSInteger kDefaultCacheMaxDiskAge = 60 * 60 * 24 * 7; // 1 week

@interface AWDiskCache ()

@property (nonatomic, copy) NSString *diskCachePath;
@property (nonatomic, strong, nonnull) NSFileManager *fileManager;
@property (nonatomic, strong, nonnull) dispatch_queue_t ioQueue;

@end

@implementation AWDiskCache

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (AWDiskCache *)sharedDiskCache {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [[self alloc]initWithName:@"AWCache"];
    });
    return instance;
}

- (instancetype)init {
    NSAssert(NO, @"Use `initWithCacheName:` with the disk cache name");
    return nil;
}

- (instancetype)initWithCacheName:(NSString *)name {
    if (name.length == 0) return nil;
    NSString *cacheFolder = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *path = [cacheFolder stringByAppendingPathComponent:name];
    return [self initWithCachePath:path];
}

- (instancetype)initWithCachePath:(NSString *)cachePath {
    if (self = [super init]) {
        _diskCachePath = cachePath;
        [self commonInit];
        [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(applicationWillTerminate:)
            name:UIApplicationWillTerminateNotification
          object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    return self;
}

- (void)commonInit {
    self.fileManager = [NSFileManager new];
    self.diskCacheReadingOptions = 0;
    self.diskCacheWritingOptions = NSDataWritingAtomic;
    self.diskCacheExpireType = AWDiskCacheExpireTypeModificationDate;
    self.maxDiskSize = 0;
    self.maxDiskAge = kDefaultCacheMaxDiskAge;
    self.ioQueue = dispatch_queue_create("com.liangaiwu.cache.disk", DISPATCH_QUEUE_SERIAL);
}

- (BOOL)containsDataForKey:(NSString *)key {
    if(!key) return NO;
    NSString *filePath = [self cachePathForKey:key];
    BOOL exists = [self.fileManager fileExistsAtPath:filePath];
    if (!exists) {
        // checking the key with and without the extension
        exists = [self.fileManager fileExistsAtPath:filePath.stringByDeletingPathExtension];
    }
    return exists;
}

- (nullable NSData *)dataForKey:(NSString *)key {
    NSString *filePath = [self cachePathForKey:key];
    NSData *data = [NSData dataWithContentsOfFile:filePath options:self.diskCacheReadingOptions error:nil];
    if (data) return data;
    
    // checking the key with and without the extension
    data = [NSData dataWithContentsOfFile:filePath.stringByDeletingPathExtension options:self.diskCacheReadingOptions error:nil];
    if (data) return data;
    return nil;
}

- (void)dataForKey:(NSString *)key withBlock:(void (^)(NSString * _Nonnull, NSData * _Nullable))block {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.ioQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        NSData *data = [strongSelf dataForKey:key];
        if (block) block(key, data);
    });
}

- (void)setData:(NSData *)data forKey:(NSString *)key {
    if(!key || !data) return;
    if (![self.fileManager fileExistsAtPath:self.diskCachePath]) {
        [self.fileManager createDirectoryAtPath:self.diskCachePath withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    NSString *cachePathForKey = [self cachePathForKey:key];
    NSURL *fileURL = [NSURL fileURLWithPath:cachePathForKey];
    [data writeToURL:fileURL options:self.diskCacheWritingOptions error:nil];
}

- (void)setData:(NSData *)data forKey:(NSString *)key withBlock:(void (^)(NSString * _Nonnull))block {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.ioQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf setData:data forKey:key];
        if (block) block(key);
    });
}

- (void)removeDataForKey:(NSString *)key {
    if(!key) return;
    NSString *filePath = [self cachePathForKey:key];
    [self.fileManager removeItemAtPath:filePath error:nil];
}

- (void)removeDataForKey:(NSString *)key withBlock:(void (^)(NSString * _Nonnull))block {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.ioQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf removeDataForKey:key];
        if (block) block(key);
    });
}

- (void)removeAllData {
    [self.fileManager removeItemAtPath:self.diskCachePath error:nil];
    [self.fileManager createDirectoryAtPath:self.diskCachePath
            withIntermediateDirectories:YES
                             attributes:nil
                                  error:NULL];
}

- (void)removeAllDataWithBlock:(void (^)(void))block {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.ioQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf removeAllData];
        if (block) block();
    });
}

- (NSUInteger)totalSize {
    NSUInteger size = 0;
    NSDirectoryEnumerator *fileEnumerator = [self.fileManager enumeratorAtPath:self.diskCachePath];
    for (NSString *fileName in fileEnumerator) {
        NSString *filePath = [self.diskCachePath stringByAppendingPathComponent:fileName];
        NSDictionary<NSString *, id> *attrs = [self.fileManager attributesOfItemAtPath:filePath error:nil];
        size += [attrs fileSize];
    }
    return size;
}

- (void)totalSizeWithBlock:(void (^)(NSUInteger))block {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.ioQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        NSUInteger size = [strongSelf totalSize];
        if (block) block(size);
    });
}

- (NSUInteger)totalCount {
    NSUInteger count = 0;
    NSDirectoryEnumerator *fileEnumerator = [self.fileManager enumeratorAtPath:self.diskCachePath];
    count = fileEnumerator.allObjects.count;
    return count;
}

- (void)totalCountWithBlock:(void (^)(NSUInteger))block {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.ioQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        NSUInteger count = [strongSelf totalCount];
        if (block) block(count);
    });
}

- (void)removeExpiredData {
    NSURL *diskCacheURL = [NSURL fileURLWithPath:self.diskCachePath isDirectory:YES];
    
    NSURLResourceKey cacheContentDateKey = NSURLContentModificationDateKey;

    switch (self.diskCacheExpireType) {
        
        case AWDiskCacheExpireTypeModificationDate:
            cacheContentDateKey = NSURLContentModificationDateKey;
            break;
            
        case AWDiskCacheExpireTypeAccessDate:
            cacheContentDateKey = NSURLContentAccessDateKey;
            break;
        
        case AWDiskCacheExpireTypeCreationDate:
            cacheContentDateKey = NSURLCreationDateKey;
            break;
    }
    
    NSArray<NSString *> *resourceKeys = @[NSURLIsDirectoryKey, cacheContentDateKey, NSURLTotalFileAllocatedSizeKey];
    
    // This enumerator prefetches useful properties for our cache files.
    NSDirectoryEnumerator *fileEnumerator = [self.fileManager enumeratorAtURL:diskCacheURL
                                               includingPropertiesForKeys:resourceKeys
                                                                  options:NSDirectoryEnumerationSkipsHiddenFiles
                                                             errorHandler:NULL];
    
    NSDate *expirationDate = (self.maxDiskAge < 0) ? nil: [NSDate dateWithTimeIntervalSinceNow:-self.maxDiskAge];
    NSMutableDictionary<NSURL *, NSDictionary<NSString *, id> *> *cacheFiles = [NSMutableDictionary dictionary];
    NSUInteger currentCacheSize = 0;
    
    // Enumerate all of the files in the cache directory.  This loop has two purposes:
    //
    //  1. Removing files that are older than the expiration date.
    //  2. Storing file attributes for the size-based cleanup pass.
    NSMutableArray<NSURL *> *urlsToDelete = [[NSMutableArray alloc] init];
    for (NSURL *fileURL in fileEnumerator) {
        NSError *error;
        NSDictionary<NSString *, id> *resourceValues = [fileURL resourceValuesForKeys:resourceKeys error:&error];
        
        // Skip directories and errors.
        if (error || !resourceValues || [resourceValues[NSURLIsDirectoryKey] boolValue]) {
            continue;
        }
        
        // Remove files that are older than the expiration date;
        NSDate *modifiedDate = resourceValues[cacheContentDateKey];
        if (expirationDate && [[modifiedDate laterDate:expirationDate] isEqualToDate:expirationDate]) {
            [urlsToDelete addObject:fileURL];
            continue;
        }
        
        // Store a reference to this file and account for its total size.
        NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
        currentCacheSize += totalAllocatedSize.unsignedIntegerValue;
        cacheFiles[fileURL] = resourceValues;
    }
    
    for (NSURL *fileURL in urlsToDelete) {
        [self.fileManager removeItemAtURL:fileURL error:nil];
    }
    
    // If our remaining disk cache exceeds a configured maximum size, perform a second
    // size-based cleanup pass.  We delete the oldest files first.
    NSUInteger maxDiskSize = self.maxDiskSize;
    if (maxDiskSize > 0 && currentCacheSize > maxDiskSize) {
        // Target half of our maximum cache size for this cleanup pass.
        const NSUInteger desiredCacheSize = maxDiskSize / 2;
        
        // Sort the remaining cache files by their last modification time or last access time (oldest first).
        NSArray<NSURL *> *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent
                                                                 usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                                                     return [obj1[cacheContentDateKey] compare:obj2[cacheContentDateKey]];
                                                                 }];
        
        // Delete files until we fall below our desired cache size.
        for (NSURL *fileURL in sortedFiles) {
            if ([self.fileManager removeItemAtURL:fileURL error:nil]) {
                NSDictionary<NSString *, id> *resourceValues = cacheFiles[fileURL];
                NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                currentCacheSize -= totalAllocatedSize.unsignedIntegerValue;
                
                if (currentCacheSize < desiredCacheSize) {
                    break;
                }
            }
        }
    }
}

- (void)removeExpiredDataWithBlock:(void (^)(void))block {
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.ioQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf removeExpiredData];
        if (block) block();
    });
}

#pragma mark - Cache paths

- (nullable NSString *)cachePathForKey:(NSString *)key {
    if(!key) return nil;
    return [self.diskCachePath stringByAppendingPathComponent:key];
    return [self cachePathForKey:key inPath:self.diskCachePath];
}

- (nullable NSString *)cachePathForKey:(nullable NSString *)key inPath:(nonnull NSString *)path {
    if(!key) return nil;
    NSString *filename = SDDiskCacheFileNameForKey(key);
    return [path stringByAppendingPathComponent:filename];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [self removeExpiredDataWithBlock:nil];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    
    UIApplication *application = [UIApplication performSelector:@selector(sharedApplication)];
    __block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    [self removeExpiredDataWithBlock:^{
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
}

#pragma mark - Hash

#define SD_MAX_FILE_EXTENSION_LENGTH (NAME_MAX - CC_MD5_DIGEST_LENGTH * 2 - 1)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
static inline NSString * _Nonnull SDDiskCacheFileNameForKey(NSString * _Nullable key) {
    const char *str = key.UTF8String;
    if (str == NULL) {
        str = "";
    }
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSURL *keyURL = [NSURL URLWithString:key];
    NSString *ext = keyURL ? keyURL.pathExtension : key.pathExtension;
    // File system has file name length limit, we need to check if ext is too long, we don't add it to the filename
    if (ext.length > SD_MAX_FILE_EXTENSION_LENGTH) {
        ext = nil;
    }
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%@",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10],
                          r[11], r[12], r[13], r[14], r[15], ext.length == 0 ? @"" : [NSString stringWithFormat:@".%@", ext]];
    return filename;
}
#pragma clang diagnostic pop

@end
