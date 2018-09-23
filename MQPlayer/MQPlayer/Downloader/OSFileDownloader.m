//
//  OSFileDownloader.m
//  DownloaderManager
//
//  Created by alpface on 2017/6/4.
//  Copyright © 2017年 alpface. All rights reserved.
//

#import "OSFileDownloader.h"
#import "OSFileDownloaderSessionPrivateDelegate.h"

/// 后台任务的标识符
#define kBackgroundDownloadSessionIdentifier \
        [NSString stringWithFormat:@"%@.OSFileDownloader", \
        [NSBundle mainBundle].bundleIdentifier]

static NSString * const OSFileDownloadOriginalRemoteURLPathKey = @"OSFileDownloadOriginalRemoteURLPathKey";
static NSString * const OSFileDownloadLocalURLKey = @"OSFileDownloadLocalURLKey";
NSString * const OSFileDownloaderDefaultFolderNameKey = @"OSFileDownloaderDefaultFolderNameKey";
static void *ProgressObserverContext = &ProgressObserverContext;

@interface OSFileDownloadOperation : NSObject <OSFileDownloadOperation>

/** 状态改变回调 */
@property (nonatomic, copy) void (^statusChangeHandler)(OSFileDownloadStatus status);
/** 触发取消时回调，让OSFileDownloader取消下载 */
@property (nullable, copy) void (^cancellationHandler)(void);
/** 触发暂停时回调，让OSFileDownloader暂停下载 */
@property (nullable, copy) void (^pausingHandler)(void);
/** 触发恢复下载时回调，让OSFileDownloader恢复下载 */
@property (nullable, copy) void (^resumingHandler)(void);
/** 进度回调 */
@property (nonatomic, nullable, copy) void (^progressHandler)(NSProgress *progress);
/** 下载完成时回调，不管成功失败 */
@property (nonatomic, nullable, copy) void (^completionHandler)(NSURLResponse *response, NSURL * _Nullable filePath, NSError * _Nullable error);
/** 恢复下载时所在文件的字节数 */
@property (nonatomic, assign) ino64_t resumedFileSizeInBytes;
/** 下载的url */
@property (nonatomic, copy) NSString *urlPath;
/** 下载会话对象 NSURLSessionDataTask */
@property (nonatomic, strong) NSURLSessionDataTask *sessionTask;
/** 下载时发送的错误信息栈 */
@property (nonatomic, strong) NSArray<NSString *> *errorMessagesStack;
/** 最后的HTTP状态码 */
@property (nonatomic, assign) NSInteger lastHttpStatusCode;
/** 最终文件存储的本地完整路径，默认是所在的目录+文件名(下载url名称) */
@property (nonatomic, strong) NSURL *localURL;
/** 文件的类型 */
@property (nonatomic, copy) NSString *MIMEType;
/** 文件下载状态 */
@property (nonatomic, assign) OSFileDownloadStatus status;
/** 流 */
@property (nonatomic, strong) NSOutputStream *outputStream;
/** 自定义进度对象 */
@property (nonatomic, strong) OSFileDownloadProgress *progressObj;
/** 用于文件下载的对象 */
@property (nonatomic, weak) OSFileDownloader *downloader;
/** 原始的urlPath, 由于OSFileDownloader会对错误的urlPath进行处理，所以需要保存原始的urlPath，以便回调给外界参照 */
@property (nonatomic, copy) NSString *originalURLString;

- (instancetype)initWithURL:(NSString *)urlPath
            sessionDataTask:(nullable NSURLSessionDataTask *)sessionDownloadTask
                 downloader:(OSFileDownloader *)downloader;

@end

#pragma mark *** OSFileDownloader ***

@interface OSFileDownloader () <NSURLSessionDelegate, NSURLSessionDataDelegate, NSURLSessionTaskDelegate>

@property (nonatomic, strong) NSURLSession *backgroundSeesion;
@property (nonatomic, strong) NSOperationQueue *backgroundSeesionQueue;
@property (nonatomic, strong) OSFileDownloaderSessionPrivateDelegate *sessionDelegate;
@property (nonatomic, strong) NSProgress *totalProgress;

@end

@implementation OSFileDownloader

@synthesize maxConcurrentDownloads = _maxConcurrentDownloads;

////////////////////////////////////////////////////////////////////////
#pragma mark - initialize
////////////////////////////////////////////////////////////////////////

- (instancetype)init
{
    self = [super init];
    if (self) {
        // 创建任务进度管理对象 UnitCount是一个基于UI上的完整任务的单元数
        // 这个方法创建了一个NSProgress实例作为当前实例的子类，以要执行的任务单元总数来初始化
        self.totalProgress = [NSProgress progressWithTotalUnitCount:0];
        // 对任务进度对象的完成比例进行监听:监听progress的fractionCompleted的改变,
        // NSKeyValueObservingOptionInitial观察最初的值（在注册观察服务时会调用一次触发方法）
        // fractionCompleted的返回值是0到1，显示了任务的整体进度。如果当没有子实例的话，fractionCompleted就是简单的完成任务数除以总得任务数。
        [self.totalProgress addObserver:self
                             forKeyPath:NSStringFromSelector(@selector(fractionCompleted))
                                options:NSKeyValueObservingOptionInitial
                                context:ProgressObserverContext];
        
        _sessionDelegate = [[OSFileDownloaderSessionPrivateDelegate alloc] initWithDownloader:self];
        _backgroundSeesion = [NSURLSession sessionWithConfiguration:[self createBackgroundSessionConfig] delegate:self delegateQueue:self.backgroundSeesionQueue];
        _backgroundSeesion.sessionDescription = @"OSFileDownload_BackgroundSession";
    }
    return self;
}


- (void)setDownloadDelegate:(id<OSFileDownloaderDelegate>)downloadDelegate {
    if (_downloadDelegate == downloadDelegate) {
        return;
    }
    _downloadDelegate = downloadDelegate;
    self.sessionDelegate.downloadDelegate = downloadDelegate;
}



- (void)getDownloadTasks:(void (^)(NSArray *downloadTasks))downloadTasksBlock {
    [self.backgroundSeesion getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        if (downloadTasksBlock) {
            downloadTasksBlock(downloadTasks);
        }
    }];
}

- (OSFileDownloadOperation *)getDownloadOperationByTask:(NSURLSessionDataTask *)task {
    @synchronized (_activeDownloadsDictionary) {
        OSFileDownloadOperation *downloadOperation = nil;
        downloadOperation = [self.activeDownloadsDictionary objectForKey:@(task.taskIdentifier)];
        if (downloadOperation) {
            return downloadOperation;
        }
        NSString *urlPath = [[task taskDescription] copy];
        if (urlPath) {
            self.totalProgress.totalUnitCount++;

            // 将此totalProgress注册为当前线程任务的根进度管理对象，向下分支出一个子任务 比如子任务进度总数为10个单元 即当子任务完成时 父progerss对象进度走1个单元
            [self.totalProgress becomeCurrentWithPendingUnitCount:1];
            
            downloadOperation = [[OSFileDownloadOperation alloc] initWithURL:urlPath sessionDataTask:task downloader:self];
            // 注意: 必须和becomeCurrentWithPendingUnitCount成对使用,必须在同一个线程
            [self.totalProgress resignCurrent];
            
            // 将下载任务保存到activeDownloadsDictionary中
            [self.activeDownloadsDictionary setObject:downloadOperation
                                               forKey:@(task.taskIdentifier)];
            [self initializeDownloadCallBack:downloadOperation];
            [self.sessionDelegate _beginDownloadTaskWithDownloadOperation:downloadOperation];
        }
        
        return downloadOperation;
        
    }
}


////////////////////////////////////////////////////////////////////////
#pragma mark - Download
////////////////////////////////////////////////////////////////////////

- (id<OSFileDownloadOperation>)downloadTaskWithURLPath:(NSString *)urlPath
                                      localPath:(NSString *)localPath
                                            progress:(void (^ _Nullable)(NSProgress * _Nullable))downloadProgressBlock
                                   completionHandler:(void (^ _Nullable)(NSURLResponse * _Nullable, NSURL * _Nullable, NSError * _Nullable))completionHandler {
    id<OSFileDownloadOperation> item = [self downloadWithURL:urlPath localPath:localPath];
    item.progressHandler = downloadProgressBlock;
    item.completionHandler = completionHandler;
    return item;
    
}

- (id<OSFileDownloadOperation>)downloadTaskWithRequest:(NSURLRequest *)request
                                      localPath:(NSString *)localPath
                                            progress:(void (^ _Nullable)(NSProgress * _Nullable))downloadProgressBlock
                                   completionHandler:(void (^ _Nullable)(NSURLResponse * _Nullable, NSURL * _Nullable, NSError * _Nullable))completionHandler {
    id<OSFileDownloadOperation> item = [self downloadWithRequest:request originalURLString:nil localPath:localPath];
    item.progressHandler = downloadProgressBlock;
    item.completionHandler = completionHandler;
    return item;
}

- (id<OSFileDownloadOperation>)downloadWithURL:(NSString *)urlPath localPath:(NSString *)localPath {
    NSMutableString *originalURLString = urlPath.mutableCopy;
    /*
     解决URLWithString return nil问题
     原因：urlPath中可能存在空格导致
     */
    NSURL *remoteURL = [self smartURLForString:urlPath];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:remoteURL
                                                           cachePolicy:NSURLRequestReloadIgnoringCacheData
                                                       timeoutInterval:30.0];
    
    return [self downloadWithRequest:request originalURLString:originalURLString localPath:localPath];
}

- (id<OSFileDownloadOperation>)downloadWithRequest:(NSURLRequest *)request originalURLString:(NSString *)originalURLString localPath:(NSString *)localPath  {
    if (!originalURLString.length) {
        originalURLString = request.URL.path;
    }
    NSAssert(request, @"Error: request do't is nil");

    NSUInteger taskIdentifier = 0;
    NSURL *remoteURL = request.URL;
    NSURL *localURL = nil;
    if (!localPath.length) {
        localURL = [self getDefaultLocalFilePathWithRemoteURL:remoteURL];
    }
    else {
        localURL = [NSURL fileURLWithPath:localPath];
    }
    NSString *urlPath = remoteURL.absoluteString;
    
    BOOL res = [self.sessionDelegate _shouldAllowedDownloadTaskWithURL:urlPath localPath:localPath];
    if (!res) {
        return nil;
    }
    
    OSFileDownloadOperation *downloadOperation = [self getDownloadOperationByURL:urlPath];
    // 若已经在下载中，则返回其实例对象
    BOOL isDownloading = [self isDownloading:urlPath];
    if (isDownloading) {
        downloadOperation.originalURLString = originalURLString;
        return downloadOperation;
    }
    
    // 无任务下载时，重置总进度
    [self resetProgressIfNoActiveDownloadsRunning];
    
    if (downloadOperation) {
        downloadOperation.originalURLString = originalURLString;
        /*
         此处为了解决当前request对应的url已存在activeDownloadsDictionary中，但是不符合下面条件时(也就是超出最大可下载数量时)，会导致当前request一直在等待中，无法执行下载，
         进入这里你不必担心会超出最大下载数量，因为在activeDownloadsDictionary中肯定没有超出数量
         (self.maxConcurrentDownloads == NSIntegerMax || self.activeDownloadsDictionary.count < self.maxConcurrentDownloads)
         */
        NSURLSessionDataTask *dataTask = downloadOperation.sessionTask;
        // 将下载任务保存到activeDownloadsDictionary中
        [self.activeDownloadsDictionary setObject:downloadOperation
                                           forKey:@(dataTask.taskIdentifier)];
        [self initializeDownloadCallBack:downloadOperation];
        [self.sessionDelegate _beginDownloadTaskWithDownloadOperation:downloadOperation];
        [dataTask resume];
        return downloadOperation;
    }
    else {
        if (self.maxConcurrentDownloads == NSIntegerMax || self.activeDownloadsDictionary.count < self.maxConcurrentDownloads) {
            
            @synchronized (_activeDownloadsDictionary) {
                self.totalProgress.totalUnitCount++;
                [self.totalProgress becomeCurrentWithPendingUnitCount:1];
                
                OSFileDownloadOperation *downloadOperation = [[OSFileDownloadOperation alloc] initWithURL:urlPath sessionDataTask:nil downloader:self];
                downloadOperation.localURL = localURL;
                downloadOperation.originalURLString = originalURLString;
                NSMutableURLRequest *requestM = request.mutableCopy;
                long long cacheFileSize = [self getCacheFileSizeWithPath:downloadOperation.localURL.path];
                NSString *range = [NSString stringWithFormat:@"bytes=%zd-", cacheFileSize];
                [requestM setValue:range forHTTPHeaderField:@"Range"];
                NSAssert(downloadOperation.localURL, @"Error: local file path do't is nil");
                NSOutputStream *stream = [NSOutputStream outputStreamWithURL:downloadOperation.localURL append:YES];
                NSURLSessionDataTask *dataTask = [self.backgroundSeesion dataTaskWithRequest:requestM];
                taskIdentifier = dataTask.taskIdentifier;
                dataTask.taskDescription = urlPath;
                downloadOperation.sessionTask = dataTask;
                downloadOperation.outputStream = stream;
                
                if (cacheFileSize > 0) {
                    downloadOperation.progressObj.resumedFileSizeInBytes = cacheFileSize;
                    downloadOperation.progressObj.receivedFileSize = cacheFileSize;
                    downloadOperation.progressObj.downloadStartDate = [NSDate date];
                    downloadOperation.progressObj.bytesPerSecondSpeed = 0;
                    DLog(@"INFO: Download (id: %@) resumed (offset: %@ bytes, expected: %@ bytes", dataTask.taskDescription, @(cacheFileSize), @(downloadOperation.progressObj.expectedFileTotalSize));
                }
                
                
                [self.totalProgress resignCurrent];
                // 将下载任务保存到activeDownloadsDictionary中
                [self.activeDownloadsDictionary setObject:downloadOperation
                                                   forKey:@(dataTask.taskIdentifier)];
                [self initializeDownloadCallBack:downloadOperation];
                [self.sessionDelegate _beginDownloadTaskWithDownloadOperation:downloadOperation];
                [dataTask resume];
                return downloadOperation;
            }
        }
        else {
            @synchronized (_waitingDownloadArray) {
                // 超出同时的最大下载数量时，将新的任务的aResumeData或者aRemoteURL添加到等待下载数组中
                NSMutableDictionary *waitingDownloadDict = [NSMutableDictionary dictionary];
                [waitingDownloadDict setValue:originalURLString forKey:OSFileDownloadOriginalRemoteURLPathKey];
                [waitingDownloadDict setValue:localPath forKey:OSFileDownloadLocalURLKey];
                [self.waitingDownloadArray addObject:waitingDownloadDict];
                [self.sessionDelegate _didWaitingDownloadForUrlPath:originalURLString];
            }
        }
        
    }
    return nil;
}




- (long long)getCacheFileSizeWithPath:(NSString *)url {
    NSDictionary *fileAtt = [[NSFileManager defaultManager] attributesOfItemAtPath:url error:nil];
    return [fileAtt[NSFileSize] longLongValue];
}

/// 通过urlPath恢复下载
- (void)resumeWithDownloadOperation:(OSFileDownloadOperation *)downloadOperation {
    BOOL isDownloading = [self isDownloading:downloadOperation.urlPath];
    if (!isDownloading) {
        [self downloadWithURL:downloadOperation.urlPath localPath:downloadOperation.localURL.path];
    }
}

- (void)initializeDownloadCallBack:(OSFileDownloadOperation *)downloadOperation  {
    
    if (!downloadOperation) {
        DLog(@"Error: No download item");
        return;
    }
    
    
    __weak typeof(self) weakSelf = self;
    __weak typeof(downloadOperation) weakOperation = downloadOperation;
    NSString *urlPath = [downloadOperation.originalURLString copy];
    downloadOperation.pausingHandler = ^{
        [weakSelf pauseWithURL:urlPath];
    };
    
    downloadOperation.cancellationHandler = ^{
        [weakSelf cancelWithURL:urlPath];
    };
    
    downloadOperation.resumingHandler = ^{
        [weakSelf resumeWithDownloadOperation:weakOperation];
    };
}


- (void)pauseWithURL:(NSString *)urlPath {
    BOOL isDownloading = [self isDownloading:urlPath];
    if (isDownloading) {
        
        [self pauseWithURL:urlPath completionHandler:^{
            [self.sessionDelegate _pauseWithURL:urlPath];
        }];
        
    }
    // 当任务没有在(activeDownloadsDictionary)下载中是无法直接取消的
    // 所以这里判断如果在等待中就移除等待中任务，并通知代码
    BOOL isWaiting = [self isWaiting:urlPath];
    if (isWaiting) {
        [self removeDownloadTaskFromWaitingDownloadArrayByUrlPath:urlPath];
        [self.sessionDelegate _pauseWithURL:urlPath];
    }
}

- (void)pauseWithURL:(NSString *)urlPath completionHandler:(void (^)(void))completion {
    
    // 根据downloadIdentifier获取tashIdentifier
    NSInteger taskIdentifier = [self getDownloadTaskIdentifierByURL:urlPath];
    
    // 当taskIdentifier!=NSNotFound时有效
    if (taskIdentifier != NSNotFound) {
        [self pauseWithTaskIdentifier:taskIdentifier completionHandler:completion];
    } else {
        [self removeDownloadTaskFromWaitingDownloadArrayByUrlPath:urlPath];
    }
    
}


- (void)pauseWithTaskIdentifier:(NSUInteger)taskIdentifier completionHandler:(void (^)(void))completion {
    
    // 从正在下载的集合中根据taskIdentifier获取到OSFileDownloadOperation
    OSFileDownloadOperation *downloadOperation = [self.activeDownloadsDictionary objectForKey:@(taskIdentifier)];
    if (downloadOperation) {
        NSURLSessionDataTask *downloadTask = (NSURLSessionDataTask *)downloadOperation.sessionTask;
        if (downloadTask) {
            if (completion) {
                // 有时suspend无效
                // [downloadTask suspend];
                [downloadTask cancel];
            } else {
                [downloadTask cancel];
            }
            completion();
            // 此时会调用NSURLSessionTaskDelegate 的 URLSession:task:didCompleteWithError:
        } else {
            DLog(@"INFO: NSURLSessionDownloadTask cancelled (task not found): %@", downloadOperation.urlPath);
            NSError *error = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
            // 当downloadTask不存在时执行下载失败的回调
            [self.sessionDelegate handleDownloadFailureWithError:error downloadOperation:downloadOperation taskIdentifier:taskIdentifier response:nil];
        }
    }
}

/// 根据urlPath删除或取消下载中的任务
- (void)cancelWithURL:(NSString *)urlPath {
    // 取消任务时，如果在activeDownloadsDictionary(下载中)，就直接取消
    // 否则就判断是否在waitingDownloadArray(等待中)，若在就移除，并通知代理
    NSInteger taskIdentifier = [self getDownloadTaskIdentifierByURL:urlPath];
    if (taskIdentifier != NSNotFound) {
        [self cancelWithTaskIdentifier:taskIdentifier];
    } else {
        BOOL res = [self removeDownloadTaskFromWaitingDownloadArrayByUrlPath:urlPath];
        if (res) {
            
            NSError *cancelError = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
            OSFileDownloadOperation *item = [[OSFileDownloadOperation alloc] initWithURL:urlPath sessionDataTask:nil downloader:self];
            [self.sessionDelegate handleDownloadFailureWithError:cancelError downloadOperation:item taskIdentifier:NSNotFound response:nil];
        }
    }
}

/// 根据taskIdentifier删除或取消下载中的任务
- (void)cancelWithTaskIdentifier:(NSUInteger)taskIdentifier {
    OSFileDownloadOperation *downloadOperation = [self.activeDownloadsDictionary objectForKey:@(taskIdentifier)];
    if (downloadOperation) {
        NSURLSessionTask *dataTask = downloadOperation.sessionTask;
        if (dataTask) {
            [dataTask cancel];
            // NSURLSessionTaskDelegate method is called
            // URLSession:task:didCompleteWithError:
        } else {
            DLog(@"INFO: NSURLSessionDownloadTask cancelled (task not found): %@", downloadOperation.urlPath);
            NSError *error = [[NSError alloc] initWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
            [self.sessionDelegate handleDownloadFailureWithError:error downloadOperation:downloadOperation taskIdentifier:taskIdentifier response:nil];
        }
    }
}


////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////

/// 根据url从等待队列中移除一个任务
- (BOOL)removeDownloadTaskFromWaitingDownloadArrayByUrlPath:(NSString *)url {
    @synchronized (_waitingDownloadArray) {
        NSInteger foundIdx = [self.waitingDownloadArray indexOfObjectPassingTest:
                              ^BOOL(NSDictionary<NSString *,NSObject *> * _Nonnull waitingDownloadDict, NSUInteger idx, BOOL * _Nonnull stop) {
                                  NSString *waitingUrlPath = (NSString *)waitingDownloadDict[OSFileDownloadOriginalRemoteURLPathKey];
                                  return [url isKindOfClass:[NSString class]] && [url isEqualToString:waitingUrlPath];
                              }];
        if (foundIdx != NSNotFound) {
            [self.waitingDownloadArray removeObjectAtIndex:foundIdx];
            return YES;
        }
        return NO;
    }
}

////////////////////////////////////////////////////////////////////////
#pragma mark - download status
////////////////////////////////////////////////////////////////////////

- (BOOL)isDownloading:(NSString *)urlPath {
    
    @synchronized (_activeDownloadsDictionary) {
        __block BOOL isDownloading = NO;
        NSInteger taskIdentifier = [self getDownloadTaskIdentifierByURL:urlPath];
        if (taskIdentifier != NSNotFound) {
            OSFileDownloadOperation *downloadOperation = [self.activeDownloadsDictionary objectForKey:@(taskIdentifier)];
            if (downloadOperation) {
                isDownloading = downloadOperation.sessionTask.state == NSURLSessionTaskStateRunning;
            }
        }
        
        return isDownloading;
        
    }
}

- (BOOL)isWaiting:(NSString *)urlPath {
    @synchronized (_waitingDownloadArray) {
        __block BOOL isWaiting = NO;
        
        [self.waitingDownloadArray enumerateObjectsUsingBlock:^(NSDictionary<NSString *,NSObject *> * _Nonnull waitingDownloadDict, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([waitingDownloadDict[OSFileDownloadOriginalRemoteURLPathKey] isKindOfClass:[NSString class]]) {
                NSString *waitingUrlPath = (NSString *)waitingDownloadDict[OSFileDownloadOriginalRemoteURLPathKey];
                if ([waitingUrlPath isEqualToString:urlPath]) {
                    isWaiting = YES;
                    *stop = YES;
                }
            }
        }];
        
        return isWaiting;
    }
}

/// 判断该文件是否下载完成
- (BOOL)isCompletionByRemoteUrlPath:(NSString *)url {
    OSFileDownloadOperation *item = [self getDownloadOperationByURL:url];
    if (item.progressObj.expectedFileTotalSize && [self getCacheFileSizeWithPath:item.localURL.path] == item.progressObj.expectedFileTotalSize) {
        return YES;
    }
    return NO;
}

- (BOOL)hasActiveDownloads {
    BOOL isHasActive = NO;
    if (self.activeDownloadsDictionary.count || self.waitingDownloadArray.count) {
        isHasActive = YES;
    }
    return isHasActive;
}


- (void)checkMaxConcurrentDownloadCountThenDownloadWaitingQueueIfExceeded {
    
    @synchronized (_activeDownloadsDictionary) {
        if (self.maxConcurrentDownloads == NSIntegerMax || self.activeDownloadsDictionary.count < self.maxConcurrentDownloads) {
            if (self.waitingDownloadArray.count) {
                NSDictionary *waitingDownTaskDict = [self.waitingDownloadArray firstObject];
                [self downloadWithURL:waitingDownTaskDict[OSFileDownloadOriginalRemoteURLPathKey] localPath:waitingDownTaskDict[OSFileDownloadLocalURLKey]];
                [self.waitingDownloadArray removeObjectAtIndex:0];
                [self.sessionDelegate _startDownloadTaskFromTheWaitingQueue:waitingDownTaskDict[OSFileDownloadOriginalRemoteURLPathKey]];
            }
        }
    }
}


////////////////////////////////////////////////////////////////////////
#pragma mark - download progress
////////////////////////////////////////////////////////////////////////



- (OSFileDownloadProgress *)getDownloadProgressByURL:(NSString *)urlPath {
    OSFileDownloadProgress *downloadProgress = nil;
    NSInteger taskIdentifier = [self getDownloadTaskIdentifierByURL:urlPath];
    if (taskIdentifier != NSNotFound) {
        downloadProgress = [self downloadProgressByTaskIdentifier:taskIdentifier];
    }
    return downloadProgress;
}


/// 根据taskIdentifier 创建 OSFileDownloadProgress 对象
- (OSFileDownloadProgress *)downloadProgressByTaskIdentifier:(NSUInteger)taskIdentifier {
    OSFileDownloadProgress *progressObj = nil;
    OSFileDownloadOperation *downloadOperation = [self.activeDownloadsDictionary objectForKey:@(taskIdentifier)];
    if (downloadOperation) {
        progressObj = downloadOperation.progressObj;
    }
    return progressObj;
}

////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////


- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    
    if (context == ProgressObserverContext) {
        NSProgress *progress = object;
        if ([keyPath isEqualToString:NSStringFromSelector(@selector(fractionCompleted))]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [[NSNotificationCenter defaultCenter] postNotificationName:OSFileDownloadTotalProgressCanceldNotification object:progress];
            });
        }
    } else {
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
    
}

/// 如果当前没有正在下载中的就重置进度
- (void)resetProgressIfNoActiveDownloadsRunning {
    BOOL hasActiveDownloadsFlag = [self hasActiveDownloads];
    if (hasActiveDownloadsFlag == NO) {
        @try {
            [self.totalProgress removeObserver:self forKeyPath:NSStringFromSelector(@selector(fractionCompleted))];
        } @catch (NSException *exception) {
            DLog(@"Error: Repeated removeObserver(keyPath = fractionCompleted)");
        } @finally {
            
        }
        self.totalProgress = [NSProgress progressWithTotalUnitCount:0];
        [self.totalProgress addObserver:self
                             forKeyPath:NSStringFromSelector(@selector(fractionCompleted))
                                options:NSKeyValueObservingOptionInitial
                                context:ProgressObserverContext];
    }
}



#pragma mark NSURLSessionDataDelegate

/// 接收到响应
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSHTTPURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    
    [self.sessionDelegate URLSession:session dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler];
}

/// 接收到服务器返回的数据
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [self.sessionDelegate URLSession:session dataTask:dataTask didReceiveData:data];
}


////////////////////////////////////////////////////////////////////////
#pragma mark - NSURLSessionTaskDelegate
////////////////////////////////////////////////////////////////////////

/// 当请求完成之后调用该方法
/// 不论是请求成功还是请求失败都调用该方法，如果请求失败，那么error对象有值，否则那么error对象为空
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    [self.sessionDelegate URLSession:session task:task didCompleteWithError:error];
}


/// SSL / TLS 验证
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler{
    
    [self.sessionDelegate URLSession:session task:task didReceiveChallenge:challenge completionHandler:completionHandler];
    
}

////////////////////////////////////////////////////////////////////////
#pragma mark - NSURLSessionDelegate
////////////////////////////////////////////////////////////////////////

/// 后台任务完成时调用
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    [self.sessionDelegate URLSessionDidFinishEventsForBackgroundURLSession:session];
}

/// 当不再需要连接调用Session的invalidateAndCancel直接关闭，或者调用finishTasksAndInvalidate等待当前Task结束后关闭
/// 此时此方法会收到回调
- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error {
    [self.sessionDelegate URLSession:session didBecomeInvalidWithError:error];
}


// 创建并配置backgroundConfiguration
- (NSURLSessionConfiguration *)createBackgroundSessionConfig {
    /********** 创建后台会话配置对象 **********/
    /**
     使用backgroundSessionConfiguration时, 如果未申请后台时间, 进入后台并不会下载，还会导致下面问题:
     在进入前台或App杀死后启动时会回调- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
     didCompleteWithError:(nullable NSError *)error;
     导致任务下载失败，这样非常不好，暂时未找到更改的解决方案
     解决方法：不使用后台下载，使用defaultSessionConfiguration
     */
    
    NSURLSessionConfiguration *backgroundConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    /*
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_7_1) {
        backgroundConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:kBackgroundDownloadSessionIdentifier];
    } else {
        backgroundConfiguration = [NSURLSessionConfiguration backgroundSessionConfiguration:kBackgroundDownloadSessionIdentifier];
    }
     */
    // 同时设置值timeoutIntervalForRequest和timeoutIntervalForResource值NSURLSessionConfiguration，较小的值会受到影响
    // 请求超时时间；默认为60秒
    backgroundConfiguration.timeoutIntervalForRequest = 180;
    // 是否允许蜂窝网络访问（2G/3G/4G）
    backgroundConfiguration.allowsCellularAccess = YES;
    // 限制每次最多连接数；在 iOS 中默认值为4
//     backgroundConfiguration.HTTPMaximumConnectionsPerHost = self.maxConcurrentDownloads;
    // 允许后台任务按系统的最佳时间安排，以获得最佳性能 (仅background session有效)
    // 设置discretionary = YES 后，若iPhone未连接电源则下载没有任何响应，连接电源后立即可以下载
    //    backgroundConfiguration.discretionary = NO;
    
    
    return backgroundConfiguration;
}



////////////////////////////////////////////////////////////////////////
#pragma mark - Private methods
////////////////////////////////////////////////////////////////////////

/// 通过urlPath获取下载任务的TaskIdentifier
- (NSInteger)getDownloadTaskIdentifierByURL:(nonnull NSString *)urlPath {
    NSInteger taskIdentifier = NSNotFound;
    NSArray *aDownloadKeysArray = [self.activeDownloadsDictionary allKeys];
    for (NSNumber *identifier in aDownloadKeysArray)
    {
        OSFileDownloadOperation *downloadOperation = [self.activeDownloadsDictionary objectForKey:identifier];
        if ([downloadOperation.urlPath isEqualToString:urlPath]) {
            taskIdentifier = [identifier unsignedIntegerValue];
            break;
        }
    }
    return taskIdentifier;
}


/// 通过url获取下载任务的downloadOperation
- (id<OSFileDownloadOperation>)getDownloadOperationByURL:(nonnull NSString *)urlPath {
    NSInteger identifier = [self getDownloadTaskIdentifierByURL:urlPath];
    OSFileDownloadOperation *downloadOperation = [self.activeDownloadsDictionary objectForKey:@(identifier)];
    return downloadOperation;
}


/// 获取下载的文件默认存储的的位置，若代理未实现时则使用此默认的
- (NSURL *)getDefaultLocalFilePathWithRemoteURL:(NSURL *)remoteURL {
    NSURL *localFileURL = [[self.class getDefaultLocalFolderPath] URLByAppendingPathComponent:remoteURL.lastPathComponent isDirectory:NO];
    return localFileURL;
}

/// 默认缓存下载文件的本地文件夹
+ (NSURL *)getDefaultLocalFolderPath {
    NSURL *OSFileDownloadDirectoryURL = nil;
    NSError *anError = nil;
    NSArray *documentDirectoryURLsArray = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *documentsDirectoryURL = [documentDirectoryURLsArray firstObject];
    if (documentsDirectoryURL) {
        OSFileDownloadDirectoryURL = [documentsDirectoryURL URLByAppendingPathComponent:OSFileDownloaderDefaultFolderNameKey isDirectory:YES];
        if ([[NSFileManager defaultManager] fileExistsAtPath:OSFileDownloadDirectoryURL.path] == NO) {
            BOOL aCreateDirectorySuccess = [[NSFileManager defaultManager] createDirectoryAtPath:OSFileDownloadDirectoryURL.path withIntermediateDirectories:YES attributes:nil error:&anError];
            if (aCreateDirectorySuccess == NO) {
                DLog(@"Error on create directory: %@", anError);
            } else {
                // 排除备份，即使文件存储在document中，该目录下载的文件也不会被备份到itunes或上传的iCloud中
                BOOL aSetResourceValueSuccess = [OSFileDownloadDirectoryURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:&anError];
                if (aSetResourceValueSuccess == NO) {
                    DLog(@"Error on set resource value (NSURLIsExcludedFromBackupKey): %@", anError);
                }
            }
        }
        return OSFileDownloadDirectoryURL;
    }
    return nil;
    
}


////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////

- (void)dealloc {
    
    [self.backgroundSeesion finishTasksAndInvalidate];
    [self.totalProgress removeObserver:self
                            forKeyPath:NSStringFromSelector(@selector(fractionCompleted))
                               context:ProgressObserverContext];
    
}


- (NSString *)description {
    NSMutableDictionary *descriptionDict = [NSMutableDictionary dictionary];
    [descriptionDict setObject:self.activeDownloadsDictionary forKey:@"activeDownloadsDictionary"];
    [descriptionDict setObject:self.waitingDownloadArray forKey:@"waitingDownloadsArray"];
    [descriptionDict setObject:@(self.maxConcurrentDownloads) forKey:@"maxConcurrentDownloads"];
    
    NSString *descriptionString = [NSString stringWithFormat:@"%@", descriptionDict];
    
    return descriptionString;
}


- (void)setMaxConcurrentDownloads:(NSInteger)maxConcurrentDownloads {
    
    if (maxConcurrentDownloads != _maxConcurrentDownloads
        && maxConcurrentDownloads < NSIntegerMax) {
        _maxConcurrentDownloads = maxConcurrentDownloads;
        [self checkMaxConcurrentDownloadCountThenDownloadWaitingQueueIfExceeded];
    }
}

- (NSInteger)maxConcurrentDownloads {
    return _maxConcurrentDownloads ?: NSIntegerMax;
}

- (NSOperationQueue *)backgroundSeesionQueue {
    if (!_backgroundSeesionQueue) {
        _backgroundSeesionQueue = [NSOperationQueue mainQueue];
        _backgroundSeesionQueue.maxConcurrentOperationCount = 1;
        _backgroundSeesionQueue.name = @"com.sey.OSFileDownloaderQueue";
    }
    return _backgroundSeesionQueue;
}

- (NSMutableDictionary<NSNumber *,id<OSFileDownloadOperation>> *)activeDownloadsDictionary {
    if (!_activeDownloadsDictionary) {
        _activeDownloadsDictionary = [NSMutableDictionary dictionaryWithCapacity:0];
    }
    return _activeDownloadsDictionary;
}


- (NSMutableArray<NSDictionary<NSString *,NSObject *> *> *)waitingDownloadArray {
    if (!_waitingDownloadArray) {
        _waitingDownloadArray = [NSMutableArray arrayWithCapacity:0];
    }
    return _waitingDownloadArray;
}

- (void)removeAllWaitingDownloadArray {
    [self.waitingDownloadArray removeAllObjects];
}


- (NSURL *)smartURLForString:(NSString *)str {
    NSURL *     result;
    NSString *  trimmedStr;
    NSRange     schemeMarkerRange;
    NSString *  scheme;
    assert(str != nil);
    
    result = nil;
    trimmedStr = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ( (trimmedStr != nil) && (trimmedStr.length != 0) ) {
        schemeMarkerRange = [trimmedStr rangeOfString:@"://"];
        
        if (schemeMarkerRange.location == NSNotFound) {
            if ([trimmedStr hasPrefix:@"/"]) {
                trimmedStr = [trimmedStr substringFromIndex:1];
            }
            result = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", trimmedStr]];
        } else {
            scheme = [trimmedStr substringWithRange:NSMakeRange(0, schemeMarkerRange.location)];
            assert(scheme != nil);
            
            if ( ([scheme compare:@"http"  options:NSCaseInsensitiveSearch] == NSOrderedSame)
                || ([scheme compare:@"https" options:NSCaseInsensitiveSearch] == NSOrderedSame) ) {
                result = [NSURL URLWithString:trimmedStr];
            } else {
                // 不支持的URL
            }
        }
    }
    
    return result;
}

@end

#pragma mark *** OSFileDownloadOperation ***


@implementation OSFileDownloadOperation

////////////////////////////////////////////////////////////////////////
#pragma mark - initialize
////////////////////////////////////////////////////////////////////////

@synthesize
cancellationHandler = _cancellationHandler,
pausingHandler = _pausingHandler,
resumingHandler = _resumingHandler;

- (instancetype)initWithURL:(NSString *)urlPath
            sessionDataTask:(NSURLSessionDataTask *)sessionDownloadTask downloader:(OSFileDownloader *)downloader {
    if (self = [super init]) {
        self.status = OSFileDownloadStatusNotStarted;
        self.urlPath = urlPath;
        self.sessionTask = sessionDownloadTask;
        self.resumedFileSizeInBytes = 0;
        self.lastHttpStatusCode = 0;
        self.downloader = downloader;
        NSProgress *progress = [[NSProgress alloc] initWithParent:[NSProgress currentProgress] userInfo:nil];
        progress.kind = NSProgressKindFile;
        [progress setUserInfoObject:NSProgressFileOperationKindKey forKey:NSProgressFileOperationKindDownloading];
        [progress setUserInfoObject:urlPath forKey:@"urlPath"];
        progress.cancellable = YES;
        progress.pausable = YES;
        progress.totalUnitCount = NSURLSessionTransferSizeUnknown;
        progress.completedUnitCount = 0;
        
        self.progressObj = [[OSFileDownloadProgress alloc] initWithDownloadProgress:0
                                                                 expectedFileSize:0
                                                                 receivedFileSize:0
                                                           estimatedRemainingTime:0
                                                              bytesPerSecondSpeed:0
                                                                   nativeProgress:progress];
        
    }
    return self;
}


- (void)pause {
    if (self.progressObj.nativeProgress) {
        [self.progressObj.nativeProgress pause];
    }
    else if (self.pausingHandler) {
        self.pausingHandler();
    }
}

- (void)cancel {
    if (self.progressObj.nativeProgress) {
        [self.progressObj.nativeProgress cancel];
    }
    else if (self.cancellationHandler) {
        self.cancellationHandler();
    }
}

- (void)resume {
    if ([self.progressObj.nativeProgress respondsToSelector:@selector(resume)]) {
        [self.progressObj.nativeProgress resume];
    }
    else if (self.resumingHandler) {
        self.resumingHandler();
    }
}



- (void)dealloc {
    
}

////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.urlPath forKey:NSStringFromSelector(@selector(urlPath))];
    [aCoder encodeObject:@(self.status) forKey:NSStringFromSelector(@selector(status))];
    [aCoder encodeObject:self.progressObj forKey:NSStringFromSelector(@selector(progressObj))];
    [aCoder encodeObject:self.errorMessagesStack forKey:NSStringFromSelector(@selector(errorMessagesStack))];
    [aCoder encodeObject:@(self.lastHttpStatusCode) forKey:NSStringFromSelector(@selector(lastHttpStatusCode))];
    [aCoder encodeObject:self.MIMEType forKey:NSStringFromSelector(@selector(MIMEType))];
}

- (id)initWithCoder:(NSCoder *)aCoder
{
    self = [super init];
    if (self)
    {
        self.urlPath = [aCoder decodeObjectForKey:NSStringFromSelector(@selector(urlPath))];
        self.status = [[aCoder decodeObjectForKey:NSStringFromSelector(@selector(status))] unsignedIntegerValue];
        self.progressObj = [aCoder decodeObjectForKey:NSStringFromSelector(@selector(progressObj))];
        self.errorMessagesStack = [aCoder decodeObjectForKey:NSStringFromSelector(@selector(errorMessagesStack))];
        self.lastHttpStatusCode = [[aCoder decodeObjectForKey:NSStringFromSelector(@selector(lastHttpStatusCode))] integerValue];
        self.MIMEType = [aCoder decodeObjectForKey:NSStringFromSelector(@selector(MIMEType))];
    }
    return self;
}


////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////

- (void)setCancellationHandler:(void (^)(void))cancellationHandler {
    _cancellationHandler = cancellationHandler;
    [self.progressObj.nativeProgress setCancellationHandler:cancellationHandler];
}

- (void (^)(void))cancellationHandler {
    return self.progressObj.nativeProgress.cancellationHandler;
}

- (void)setPausingHandler:(void (^)(void))pausingHandler {
    _pausingHandler = pausingHandler;
    [self.progressObj.nativeProgress setPausingHandler:pausingHandler];
}

- (void (^)(void))pausingHandler {
    return self.progressObj.nativeProgress.pausingHandler;
}

- (void)setResumingHandler:(void (^)(void))resumingHandler {
    _resumingHandler = resumingHandler;
    if ([self.progressObj.nativeProgress respondsToSelector:@selector(setResumingHandler:)]) {
        [self.progressObj.nativeProgress setResumingHandler:resumingHandler];
    }
}

- (void (^)(void))resumingHandler {
    return self.progressObj.nativeProgress.resumingHandler;
}

- (void)setProgressHandler:(void (^)(NSProgress * _Nonnull))progressHandler {
    _progressHandler = progressHandler;
    self.progressObj.progressHandler = progressHandler;
}

- (void)setStatus:(OSFileDownloadStatus)status {
    if (_status == status) {
        return;
    }
    [self willChangeValueForKey:@"status"];
    _status = status;
    if (self.statusChangeHandler) {
        XYDispatch_main_async_safe(^{
            self.statusChangeHandler(status);
        })
    }
    [self didChangeValueForKey:@"status"];
    
}


////////////////////////////////////////////////////////////////////////
#pragma mark - description
////////////////////////////////////////////////////////////////////////

- (NSString *)description {
    NSMutableDictionary *descriptionDict = [NSMutableDictionary dictionary];
    [descriptionDict setObject:self.urlPath forKey:@"urlPath"];
    [descriptionDict setObject:@(self.status) forKey:@"status"];
    if (self.progressObj)
    {
        [descriptionDict setObject:self.progressObj forKey:@"progressObj"];
    }
    if (self.localURL) {
        [descriptionDict setObject:self.localURL forKey:@"localURL"];
        [descriptionDict setObject:self.localURL.lastPathComponent forKey:@"fileName"];
    }
    if (self.MIMEType) {
        [descriptionDict setObject:self.MIMEType forKey:@"MIMEType"];
    }
    
    NSString *description = [NSString stringWithFormat:@"%@", descriptionDict];
    
    return description;
}


@end

