//
//  HRCDownloadMaid.m
//  starSpeed
//
//  Created by pulei yu on 2023/7/20.
//

#import "HRCDownloadMaid.h"

#import <CommonCrypto/CommonDigest.h>


NSString *const HRCDownloadMaidCachePath = @"HRCDownloadMaidCache";

static NSString * __cacheDirPath(void) {
    NSFileManager *filemgr = [NSFileManager defaultManager];
    static dispatch_once_t oneTimeToken;
    static NSString *cacheFolder;

    dispatch_once(&oneTimeToken, ^{
        if (!cacheFolder) {
            NSString *cacheDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
            cacheFolder = [cacheDir stringByAppendingPathComponent:HRCDownloadMaidCachePath];
        }

        NSError *error = nil;

        if (![filemgr createDirectoryAtPath:cacheFolder withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"Failed to create cache:: %@", cacheFolder);
            cacheFolder = nil;
        }
    });
    return cacheFolder;
}

static NSString * MD5ofString(NSString *str) {
    if (str == nil) {
        return nil;
    }

    const char *cstring = str.UTF8String;
    unsigned char bytes[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cstring, (CC_LONG)strlen(cstring), bytes);

    NSMutableString *md5String = [NSMutableString string];

    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [md5String appendFormat:@"%02x", bytes[i]];
    }

    return md5String;
}

static NSString * LocalReceiptsPath() {
    return [__cacheDirPath() stringByAppendingPathComponent:@"maidReceipts.data"];
}

static unsigned long long fileSizeAtPath(NSString *path) {
    signed long long fileSize = 0;
    NSFileManager *fileManager = [NSFileManager defaultManager];

    if ([fileManager fileExistsAtPath:path]) {
        NSError *error = nil;
        NSDictionary *fileDict = [fileManager attributesOfItemAtPath:path error:&error];

        if (!error && fileDict) {
            fileSize = [fileDict fileSize];
        }
    }

    return fileSize;
}

@interface HRCDownReceipt ()
@property (strong, nonatomic) NSOutputStream *stream;

@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, copy) NSString *filename;
@property (nonatomic, copy) NSString *truename;
@property (nonatomic, copy) NSString *speed;  // KB/s
@property (nonatomic, assign) HRCDownMaidState state;


@property (assign, nonatomic) long long totalWritten;
@property (assign, nonatomic) long long totalExpected;
@property (nonatomic, copy) NSProgress *progress;


@property (nonatomic, assign) NSUInteger totalRead;
@property (nonatomic, strong) NSDate *date;



@end
@implementation HRCDownReceipt

- (NSString *)filePath {
    NSString *path = [__cacheDirPath() stringByAppendingPathComponent:self.filename];

    if (![path isEqualToString:_filePath]) {
        if (_filePath && ![[NSFileManager defaultManager] fileExistsAtPath:_filePath]) {
            NSString *dir = [_filePath stringByDeletingLastPathComponent];
            [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
        }

        _filePath = path;
    }

    return _filePath;
}

- (NSOutputStream *)stream
{
    if (_stream == nil) {
        _stream = [NSOutputStream outputStreamToFileAtPath:self.filePath append:YES];
    }

    return _stream;
}

- (NSString *)filename {
    if (_filename == nil) {
        NSString *pathExtension = self.url.pathExtension;

        if (pathExtension.length) {
            _filename = [NSString stringWithFormat:@"%@.%@", MD5ofString(self.url), pathExtension];
        } else {
            _filename = MD5ofString(self.url);
        }
    }

    return _filename;
}

- (NSProgress *)progress {
    if (_progress == nil) {
        _progress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
    }

    @try {
        _progress.totalUnitCount = self.totalExpected;
        _progress.completedUnitCount = self.totalWritten;
    } @catch (NSException *exception) {
    }
    return _progress;
}

- (long long)totalWritten {
    return fileSizeAtPath(self.filePath);
}

- (instancetype)initWithURL:(NSString *)url {
    if (self = [self init]) {
        self.url = url;
        self.totalExpected = 1;
    }

    return self;
}

- (NSString *)truename {
    if (_truename == nil) {
        _truename = self.url.lastPathComponent;
    }

    return _truename;
}

#pragma mark - NSCoding
- (void)encodeWithCoder:(NSCoder *)aCoder
{
    // --new
    [aCoder encodeObject:self.headerJSONStr forKey:NSStringFromSelector(@selector(headerJSONStr))];
    [aCoder encodeObject:@(self.lastState) forKey:NSStringFromSelector(@selector(lastState))];
    [aCoder encodeObject:@(self.initBytes) forKey:NSStringFromSelector(@selector(initBytes))];

    [aCoder encodeObject:self.url forKey:NSStringFromSelector(@selector(url))];
    [aCoder encodeObject:self.filePath forKey:NSStringFromSelector(@selector(filePath))];
    [aCoder encodeObject:@(self.state) forKey:NSStringFromSelector(@selector(state))];
    [aCoder encodeObject:@(self.totalWritten) forKey:NSStringFromSelector(@selector(totalWritten))];
    [aCoder encodeObject:self.filename forKey:NSStringFromSelector(@selector(filename))];
    [aCoder encodeObject:@(self.totalExpected) forKey:NSStringFromSelector(@selector(totalExpected))];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];

    if (self) {
        // --new
        self.headerJSONStr = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(headerJSONStr))];
        self.lastState = [[aDecoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(lastState))] unsignedIntegerValue];
        self.initBytes = [[aDecoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(initBytes))] unsignedIntegerValue];

        self.url = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(url))];
        self.filePath = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(filePath))];
        self.state = [[aDecoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(state))] unsignedIntegerValue];
        self.filename = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(filename))];
        self.totalWritten = [[aDecoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(totalWritten))] unsignedIntegerValue];
        self.totalExpected = [[aDecoder decodeObjectOfClass:[NSNumber class] forKey:NSStringFromSelector(@selector(totalExpected))] unsignedIntegerValue];
    }

    return self;
}

@end


#pragma mark -

#if OS_OBJECT_USE_OBJC
#define MCDispatchQueueSetterSementics strong
#else
#define MCDispatchQueueSetterSementics assign
#endif

@interface HRCDownloadMaid () <NSURLSessionDataDelegate>
@property (nonatomic, MCDispatchQueueSetterSementics) dispatch_queue_t syncQueue;
@property (strong, nonatomic) NSURLSession *__selfSession;

@property (nonatomic, strong) NSMutableArray *queuedTasks;
@property (nonatomic, strong) NSMutableDictionary *tasks;

@property (nonatomic, strong) NSMutableDictionary *allDownReceipts;
@property (assign, nonatomic) UIBackgroundTaskIdentifier bgTaskId;

@property (nonatomic, assign) NSInteger maxctiveDowns;
@property (nonatomic, assign) NSInteger activeReqCount;

@end

@implementation HRCDownloadMaid

+ (NSURLSessionConfiguration *)oneURLSessionConfiguration {
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];

    configuration.HTTPShouldUsePipelining = NO;
    configuration.allowsCellularAccess = YES;
    configuration.timeoutIntervalForRequest = 59.0;
    configuration.HTTPMaximumConnectionsPerHost = 10;
    configuration.HTTPShouldSetCookies = YES;

    configuration.requestCachePolicy = NSURLRequestUseProtocolCachePolicy;
    configuration.discretionary = YES;
    return configuration;
}

- (instancetype)init {
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];

    queue.maxConcurrentOperationCount = 1;
    NSURLSessionConfiguration *oneConfiguration = [self.class oneURLSessionConfiguration];

    NSURLSession *session = [NSURLSession sessionWithConfiguration:oneConfiguration delegate:self delegateQueue:queue];

    return [self initOfSession:session
                     downPrior:HRCDownMaidPriorFIFO
                       maxDown:3 ];
}

- (instancetype)initOfSession:(NSURLSession *)session downPrior:(HRCDownMaidPrior)downloadPrioritization maxDown:(NSInteger)maximumActiveDownloads {
    if (self = [super init]) {
        self.downlPrior = downloadPrioritization;
        self.maxctiveDowns = maximumActiveDownloads;
        self.__selfSession = session;

        self.queuedTasks = [[NSMutableArray alloc] init];
        self.tasks = [[NSMutableDictionary alloc] init];
        self.activeReqCount = 0;

        NSString *name = [NSString stringWithFormat:@"com.sps.downManager.synchronizationqueue-%@", [[NSUUID UUID] UUIDString]];
        self.syncQueue = dispatch_queue_create([name cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_SERIAL);

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }

    return self;
}

+ (instancetype)oneInstance {
    static HRCDownloadMaid *sharedInstance = nil;
    static dispatch_once_t oneTimeToken;

    dispatch_once(&oneTimeToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (NSMutableDictionary *)allDownReceipts {
    if (_allDownReceipts == nil) {
        NSDictionary *receipts = [NSKeyedUnarchiver unarchiveObjectWithFile:LocalReceiptsPath()];
        _allDownReceipts = receipts != nil ? receipts.mutableCopy : [NSMutableDictionary dictionary];
    }

    return _allDownReceipts;
}

- (void)saveReceipts:(NSDictionary *)receipts {
    [NSKeyedArchiver archiveRootObject:receipts toFile:LocalReceiptsPath()];
}

- (HRCDownReceipt *)updateReceiptWithURL:(NSString *)url state:(HRCDownMaidState)state {
    HRCDownReceipt *receipt = [self downReceiptForURL:url];

    receipt.state = state;

    [self saveReceipts:self.allDownReceipts];

    return receipt;
}

- (HRCDownReceipt *)downFileWithURL:(NSString *_Nullable)url
                            headers:(NSString *)headerJSONStr
                           progress:(nullable void (^)(NSProgress *downloadProgress, HRCDownReceipt *receipt))downloadProgressBlock
                             target:(nullable NSURL * (^)(NSURL *targetPath, NSURLResponse *response))destination
                            success:(nullable void (^)(NSURLRequest *request, NSHTTPURLResponse *_Nullable response, NSURL *filePath))success
                            failure:(nullable void (^)(NSURLRequest *request, NSHTTPURLResponse *_Nullable response, NSError *error))failure {
    __block HRCDownReceipt *receipt = [self downReceiptForURL:url];

    receipt.headerJSONStr = headerJSONStr;
    // 同步数据
    [self saveReceipts:self.allDownReceipts];
    dispatch_sync(self.syncQueue, ^{
        NSString *URLIdentifier = url;

        receipt.failureBlock = failure;
        receipt.progressBlock = downloadProgressBlock;
        receipt.successBlock = success;

        if (URLIdentifier == nil) {
            if (failure) {
                NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadURL userInfo:nil];
                dispatch_async(dispatch_get_main_queue(), ^{
                    failure(nil, nil, error);
                });
            }

            return;
        }

        if (receipt.state == HRCDownMaidStateCompleted && receipt.totalWritten == receipt.totalExpected) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (receipt.successBlock) {
                    receipt.successBlock(nil, nil, [NSURL URLWithString:receipt.url]);
                }
            });
            return;
        }

        if (receipt.state == HRCDownMaidStateDownloading && receipt.totalWritten != receipt.totalExpected) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (receipt.progressBlock) {
                    receipt.progressBlock(receipt.progress, receipt);
                }
            });
            return;
        }

        NSURLSessionDataTask *task = self.tasks[receipt.url];

        // 当请求暂停一段时间后。转态会变化。所有要判断下状态
        if (!task || ((task.state != NSURLSessionTaskStateRunning) && (task.state != NSURLSessionTaskStateSuspended))) {
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:receipt.url]];

            NSString *range = [NSString stringWithFormat:@"bytes=%lld-", receipt.totalWritten];
            [request setValue:range forHTTPHeaderField:@"Range"];

            // 添加headers
            if (headerJSONStr && headerJSONStr.length > 0) {
                NSData *jsonData = [headerJSONStr dataUsingEncoding:NSUTF8StringEncoding];
                NSError *err;
                NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                    options:NSJSONReadingMutableContainers
                                                                      error:&err];

                if (err == nil) {
                    for (NSString *key in dic) {
                        NSString *v = dic[key];
                        [request addValue:v forHTTPHeaderField:key];
                    }
                }

                NSLog(@"dic::::%@", request.allHTTPHeaderFields);
            }

            // 开始任务
            NSURLSessionDataTask *task = [self.__selfSession dataTaskWithRequest:request];
            task.taskDescription = receipt.url;
            self.tasks[receipt.url] = task;
            [self.queuedTasks addObject:task];
        }

        [self resumeWithDownloadReceipt:receipt];
    });
    return receipt;
}

#pragma mark - -----------------------

- (NSURLSessionDataTask *)rmTaskWithURLIdentifier:(NSString *)URLIdentifier {
    NSURLSessionDataTask *task = self.tasks[URLIdentifier];

    [self.tasks removeObjectForKey:URLIdentifier];
    return task;
}

- (NSURLSessionDataTask *)safeRmTaskWithURLIdentifier:(NSString *)URLIdentifier {
    __block NSURLSessionDataTask *task = nil;

    dispatch_sync(self.syncQueue, ^{
        task = [self rmTaskWithURLIdentifier:URLIdentifier];
    });
    return task;
}

//This method should only be called from safely within the synchronizationQueue

- (void)safelyRmActiveTaskCount {
    dispatch_sync(self.syncQueue, ^{
        if (self.activeReqCount > 0) {
            self.activeReqCount -= 1;
        }
    });
}

- (void)safelyStartNextIfNeeds {
    dispatch_sync(self.syncQueue, ^{
        if ([self isActiveRequestCountBelowMaxLimit]) {
            while (self.queuedTasks.count > 0) {
                NSURLSessionDataTask *task = [self dequeueTask];
                HRCDownReceipt *receipt = [self downReceiptForURL:task.taskDescription];

                if (task.state == NSURLSessionTaskStateSuspended && receipt.state == HRCDownMaidStateWillResume) {
                    [self startTask:task];
                    break;
                }
            }
        }
    });
}

- (void)startTask:(NSURLSessionDataTask *)task {
    [task resume];
    ++self.activeReqCount;
    [self updateReceiptWithURL:task.taskDescription state:HRCDownMaidStateDownloading];
}

- (void)enqueueTask:(NSURLSessionDataTask *)task {
    switch (self.downlPrior) {
        case HRCDownMaidPriorLIFO: //
            [self.queuedTasks insertObject:task atIndex:0];
            break;

        case HRCDownMaidPriorFIFO: //
            [self.queuedTasks addObject:task];
            break;
    }
}

- (NSURLSessionDataTask *)dequeueTask {
    NSURLSessionDataTask *task = nil;

    task = [self.queuedTasks firstObject];
    [self.queuedTasks removeObject:task];
    return task;
}

- (BOOL)isActiveRequestCountBelowMaxLimit {
    return self.activeReqCount < self.maxctiveDowns;
}

#pragma mark -


- (void)updateReceipt:(HRCDownReceipt *)receipt
                  Url:(NSString *)url
              Headers:(NSString *)headerJSONStr {
    dispatch_sync(self.syncQueue, ^{
        [self.allDownReceipts removeObjectForKey:receipt.url];
        receipt.headerJSONStr = headerJSONStr;
        receipt.url = url;
        [self.allDownReceipts setObject:receipt forKey:receipt.url];
        [self saveReceipts:self.allDownReceipts];
    });
}

- (HRCDownReceipt *)downReceiptForURL:(NSString *)url {
    if (url == nil) {
        return nil;
    }

    HRCDownReceipt *receipt = self.allDownReceipts[url];

    if (receipt) {
        return receipt;
    }

    receipt = [[HRCDownReceipt alloc] initWithURL:url];
    receipt.totalExpected = 1;
    receipt.state = HRCDownMaidStateNone;
    

    dispatch_sync(self.syncQueue, ^{
        [self.allDownReceipts setObject:receipt forKey:url];
        [self saveReceipts:self.allDownReceipts];
    });

    return receipt;
}

#pragma mark -  NSNotification
- (void)appWillTerminate:(NSNotification *)not {
    [self suspendAll];
}

- (void)appDidReceiveMemoryWarning:(NSNotification *)not {
    [self suspendAll];
}

- (void)appWillResignActive:(NSNotification *)not {
    /// 捕获到失去激活状态后
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    BOOL hasApplication = UIApplicationClass && [UIApplicationClass respondsToSelector:@selector(sharedApplication)];

    if (hasApplication) {
        __weak __typeof__ (self) wself = self;
        UIApplication *app = [UIApplicationClass performSelector:@selector(sharedApplication)];
        self.bgTaskId = [app beginBackgroundTaskWithExpirationHandler:^{
            __strong __typeof (wself) sself = wself;

            if (sself) {
                [sself suspendAll];

                [app endBackgroundTask:sself.bgTaskId];
                sself.bgTaskId = UIBackgroundTaskInvalid;
            }
        }];
    }
}

- (void)appDidBecomeActive:(NSNotification *)not {
    Class UIApplicationClass = NSClassFromString(@"UIApplication");

    if (!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }

    if (self.bgTaskId != UIBackgroundTaskInvalid) {
        UIApplication *app = [UIApplication performSelector:@selector(sharedApplication)];
        [app endBackgroundTask:self.bgTaskId];
        self.bgTaskId = UIBackgroundTaskInvalid;
    }
}

#pragma mark - MTDownloadControlDelegate

- (void)resumeWithURL:(NSString *)url {
    if (url == nil) {
        return;
    }

    HRCDownReceipt *receipt = [self downReceiptForURL:url];
    [self resumeWithDownloadReceipt:receipt];
}

- (void)resumeWithDownloadReceipt:(HRCDownReceipt *)receipt {
    if ([self isActiveRequestCountBelowMaxLimit]) {
        NSURLSessionDataTask *task = self.tasks[receipt.url];

        // 当请求暂停一段时间后。转态会变化。所有要判断下状态
        if (!task || ((task.state != NSURLSessionTaskStateRunning) && (task.state != NSURLSessionTaskStateSuspended))) {
            [self downFileWithURL:receipt.url headers:receipt.headerJSONStr progress:receipt.progressBlock target:nil success:receipt.successBlock failure:receipt.failureBlock];
        } else {
            [self startTask:self.tasks[receipt.url]];
            receipt.date = [NSDate date];
        }
    } else {
        receipt.state = HRCDownMaidStateWillResume;
        [self saveReceipts:self.allDownReceipts];
        [self enqueueTask:self.tasks[receipt.url]];
    }
}

- (void)suspendAll {
    for (NSURLSessionDataTask *task in self.queuedTasks) {
        HRCDownReceipt *receipt = [self downReceiptForURL:task.taskDescription];
        receipt.state = HRCDownMaidStateFailed;
        [task suspend];
        [self safelyRmActiveTaskCount];
    }

    [self saveReceipts:self.allDownReceipts];
}

- (void)suspendWithURL:(NSString *)url {
    if (url == nil) {
        return;
    }

    HRCDownReceipt *receipt = [self downReceiptForURL:url];
    [self suspendWithDownloadReceipt:receipt];
}

- (void)suspendWithDownloadReceipt:(HRCDownReceipt *)receipt {
    [self updateReceiptWithURL:receipt.url state:HRCDownMaidStateSuspened];
    NSURLSessionDataTask *task = self.tasks[receipt.url];

    if (task) {
        [task suspend];
        [self safelyRmActiveTaskCount];
        [self safelyStartNextIfNeeds];
        [task cancel];
        receipt.lastState = HRCDownMaidStateSuspened;
        [self saveReceipts:self.allDownReceipts];
    }
}

- (void)removeWithURL:(NSString *)url {
    if (url == nil) {
        return;
    }

    HRCDownReceipt *receipt = [self downReceiptForURL:url];
    [self removeWithDownReceipt:receipt];
}

- (void)removeWithDownReceipt:(HRCDownReceipt *)receipt {
    NSURLSessionDataTask *task = self.tasks[receipt.url];

    if (task) {
        [task cancel];
    }

    [self.queuedTasks removeObject:task];
    [self safeRmTaskWithURLIdentifier:receipt.url];

    dispatch_sync(self.syncQueue, ^{
        [self.allDownReceipts removeObjectForKey:receipt.url];
        [self saveReceipts:self.allDownReceipts];
    });

    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:receipt.filePath error:nil];
}

#pragma mark - <NSURLSessionDataDelegate>
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSHTTPURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    HRCDownReceipt *receipt = [self downReceiptForURL:dataTask.taskDescription];

    receipt.totalExpected = receipt.totalWritten + dataTask.countOfBytesExpectedToReceive;
    receipt.state = HRCDownMaidStateDownloading;

    if (receipt.totalWritten == 0) { // 哦 第一次我～～
        receipt.initBytes = dataTask.countOfBytesExpectedToReceive;
    }

    if (receipt.totalWritten <= dataTask.countOfBytesExpectedToReceive) {
        receipt.lastState = HRCDownMaidStateNone;
    }

    if (receipt.totalExpected >= receipt.initBytes && receipt.initBytes != 0) {
        receipt.lastState = HRCDownMaidStateNone;
    }

    [self saveReceipts:self.allDownReceipts];

    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    dispatch_sync(self.syncQueue, ^{
        __block NSError *error = nil;
        HRCDownReceipt *receipt = [self downReceiptForURL:dataTask.taskDescription];

        // Speed
        receipt.totalRead += data.length;
        NSDate *currentDate = [NSDate date];

        if ([currentDate timeIntervalSinceDate:receipt.date] >= 1) {
            double time = [currentDate timeIntervalSinceDate:receipt.date];
            long long speed = receipt.totalRead / time;
            receipt.speed = [self formatByteCount:speed];
            receipt.totalRead = 0.0;
            receipt.date = currentDate;
        }

        // Write Data
        NSInputStream *inputStream =  [[NSInputStream alloc] initWithData:data];
        NSOutputStream *outputStream = [[NSOutputStream alloc] initWithURL:[NSURL fileURLWithPath:receipt.filePath] append:YES];
        [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

        [inputStream open];
        [outputStream open];

        while ([inputStream hasBytesAvailable] && [outputStream hasSpaceAvailable]) {
            uint8_t buffer[1024];

            NSInteger bytesRead = [inputStream read:buffer maxLength:1024];

            if (inputStream.streamError || bytesRead < 0) {
                error = inputStream.streamError;
                break;
            }

            NSInteger bytesWritten = [outputStream write:buffer maxLength:(NSUInteger)bytesRead];

            if (outputStream.streamError || bytesWritten < 0) {
                error = outputStream.streamError;
                break;
            }

            if (bytesRead == 0 && bytesWritten == 0) {
                break;
            }
        }
        [outputStream close];
        [inputStream close];
        
        receipt.progress.completedUnitCount = receipt.totalWritten;
        receipt.progress.totalUnitCount = receipt.totalExpected;

        dispatch_async(dispatch_get_main_queue(), ^{
            if (receipt.progressBlock) {
                receipt.progressBlock(receipt.progress, receipt);
            }
        });
    });
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    HRCDownReceipt *receipt = [self downReceiptForURL:task.taskDescription];

    if (error) {
        receipt.state = HRCDownMaidStateFailed;

        if (error.code == -1005 || error.code == -1001) {
            receipt.lastState = HRCDownMaidStateURLFailed;
        }

        if (error.code == -999) {
            receipt.state = HRCDownMaidStateSuspened;
            receipt.lastState = HRCDownMaidStateSuspened;
        }

        [self saveReceipts:self.allDownReceipts];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (receipt.failureBlock) {
                receipt.failureBlock(task.originalRequest, (NSHTTPURLResponse *)task.response, error);
            }
        });
    } else {
        unsigned long long localSize = fileSizeAtPath(receipt.filePath);

        if (localSize <= 1) {
            receipt.state = HRCDownMaidStateFailed;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (receipt.failureBlock) {
                    receipt.failureBlock(task.originalRequest, (NSHTTPURLResponse *)task.response, error);
                }
            });
            return;
        }

        if (receipt.lastState == HRCDownMaidStateSuspened ||
            receipt.lastState == HRCDownMaidStateURLFailed) {
            [receipt.stream close];
            receipt.stream = nil;
            return;
        }

//        if (localSize >= receipt.totalBytesExpectedToWrite) {
//
//        }

        [receipt.stream close];
        receipt.stream = nil;
        receipt.state = HRCDownMaidStateCompleted;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (receipt.successBlock) {
                receipt.successBlock(task.originalRequest, (NSHTTPURLResponse *)task.response, task.originalRequest.URL);
            }

            receipt.successBlock = nil;
            [self saveReceipts:self.allDownReceipts];
        });
    }

    [self saveReceipts:self.allDownReceipts];
    [self safelyRmActiveTaskCount];
    [self safelyStartNextIfNeeds];
}

- (NSString *)formatByteCount:(long long)size
{
    if(size == 0){
        return @"0KB";
    }
    return [NSByteCountFormatter stringFromByteCount:size countStyle:NSByteCountFormatterCountStyleFile];
}

@end
