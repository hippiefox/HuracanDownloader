//
//  HRCDownloadMaid.h
//  starSpeed
//
//  Created by pulei yu on 2023/7/20.
//

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const HRCDownloadMaidCachePath;
@class HRCDownReceipt;
/** The download state */
typedef NS_ENUM(NSUInteger, HRCDownMaidState) {
    HRCDownMaidStateNone,       /** default */
    HRCDownMaidStateWillResume, /** waiting */
    HRCDownMaidStateDownloading, /** downloading */
    HRCDownMaidStateSuspened,   /** suspened */
    HRCDownMaidStateCompleted,  /** download completed */
    HRCDownMaidStateFailed,     /** download failed */
    HRCDownMaidStateURLFailed
};

/** The download prioritization */
typedef NS_ENUM(NSInteger, HRCDownMaidPrior) {
    HRCDownMaidPriorFIFO, /** first in first out */
    HRCDownMaidPriorLIFO /** last in first out */
};

typedef void (^HRCMaidSucessBlock)(NSURLRequest *_Nullable, NSHTTPURLResponse *_Nullable, NSURL *_Nonnull);
typedef void (^HRCMaidFailureBlock)(NSURLRequest *_Nullable, NSHTTPURLResponse *_Nullable,  NSError *_Nonnull);
typedef void (^HRCMaidProgressBlock)(NSProgress *_Nonnull, HRCDownReceipt *);


@interface HRCDownReceipt : NSObject <NSCoding>


@property (nonatomic, copy) HRCMaidSucessBlock successBlock;
@property (nonatomic, copy) HRCMaidFailureBlock failureBlock;
@property (nonatomic, copy) HRCMaidProgressBlock progressBlock;


/**
 * Download State
 */
@property (nonatomic, assign, readonly) HRCDownMaidState state;
@property (nonatomic, assign) HRCDownMaidState lastState;

@property (nonatomic, copy, readonly, nonnull) NSString *url;
@property (nonatomic, copy, readonly, nonnull) NSString *filePath;
@property (nonatomic, copy, readonly, nullable) NSString *filename;
@property (nonatomic, copy, readonly, nullable) NSString *truename;
@property (nonatomic, copy, readonly) NSString *speed;  // KB/s
@property (nonatomic, copy, nonnull) NSString *headerJSONStr;

@property (assign, nonatomic) long long initBytes;
@property (assign, nonatomic, readonly) long long totalWritten;
@property (assign, nonatomic, readonly) long long totalExpected;

@property (nonatomic, copy, readonly, nonnull) NSProgress *progress;
@property (nonatomic, strong, readonly, nullable) NSError *error;

@end


@protocol HRCDownlControlDelegate <NSObject>

- (void)suspendWithURL:(NSString *_Nonnull)url;
- (void)suspendWithDownloadReceipt:(HRCDownReceipt *_Nonnull)receipt;

- (void)removeWithURL:(NSString *_Nonnull)url;
- (void)removeWithDownReceipt:(HRCDownReceipt *_Nonnull)receipt;

@end


@interface HRCDownloadMaid : NSObject <HRCDownlControlDelegate>


@property (nonatomic, assign) HRCDownMaidPrior downlPrior;


+ (instancetype)oneInstance;


- (instancetype)init;

- (instancetype)initOfSession:(NSURLSession *)session
         downPrior:(HRCDownMaidPrior)downloadPrioritization
         maxDown:(NSInteger)maximumActiveDownloads;


- (HRCDownReceipt *)downFileWithURL:(NSString *_Nullable)url
                                headers:(NSString *)headerJSONStr
                               progress:(nullable void (^)(NSProgress *downloadProgress, HRCDownReceipt *receipt))downloadProgressBlock
                            target:(nullable NSURL * (^)(NSURL *targetPath, NSURLResponse *response))destination
                                success:(nullable void (^)(NSURLRequest *request, NSHTTPURLResponse *_Nullable response, NSURL *filePath))success
                                failure:(nullable void (^)(NSURLRequest *request, NSHTTPURLResponse *_Nullable response, NSError *error))failure;



- (HRCDownReceipt *_Nullable)downReceiptForURL:(NSString *)url;

- (void)updateReceipt:(HRCDownReceipt *)receipt
                  Url:(NSString *)url
              Headers:(NSString *)headerJSONStr;

@end

NS_ASSUME_NONNULL_END
