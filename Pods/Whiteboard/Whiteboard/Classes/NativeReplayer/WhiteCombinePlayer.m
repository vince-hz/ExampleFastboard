//
//  WhiteCombinePlayer.m
//  WhiteSDK
//
//  Created by yleaf on 2019/7/11.
//

#import "WhiteCombinePlayer.h"
#import <AVFoundation/AVFoundation.h>



#ifdef DEBUG
#define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#define DLog(...)
#endif

@interface WhiteCombinePlayer ()
@property (nonatomic, strong, readwrite) AVPlayer *nativePlayer;

@property (nonatomic, assign, getter=isRouteChangedWhilePlaying) BOOL routeChangedWhilePlaying;
@property (nonatomic, assign, getter=isInterruptedWhilePlaying) BOOL interruptedWhilePlaying;

@property (nonatomic, assign, readwrite) NSUInteger pauseReason;

@end

@implementation WhiteCombinePlayer

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self removeObserverWithPlayItem:self.nativePlayer.currentItem];
    [self removeNativePlayerKVO];
}

- (instancetype)initWithNativePlayer:(AVPlayer *)nativePlayer whitePlayer:(WhitePlayer *)whitePlayer
{
    self = [self initWithNativePlayer:nativePlayer];
    _whitePlayer = whitePlayer;
    [self updateWhitePlayerPhase:whitePlayer.phase];
    return self;
}

- (instancetype)initWithMediaUrl:(NSURL *)mediaUrl whitePlayer:(WhitePlayer *)whitePlayer
{
    AVPlayer *videoPlayer = [AVPlayer playerWithURL:mediaUrl];
    return [self initWithNativePlayer:videoPlayer whitePlayer:whitePlayer];
}

- (instancetype)initWithMediaUrl:(NSURL *)mediaUrl
{
    AVPlayer *videoPlayer = [AVPlayer playerWithURL:mediaUrl];
    return [self initWithNativePlayer:videoPlayer];
}

- (instancetype)initWithNativePlayer:(AVPlayer *)nativePlayer
{
    if (self = [super init]) {
        _nativePlayer = nativePlayer;
        _playbackSpeed = 1;
        _pauseReason = WhiteSyncManagerPauseReasonInit;
    }
    [self registerNotificationAndKVO];
    return self;
}

- (void)setWhitePlayer:(WhitePlayer *)whitePlayer
{
    _whitePlayer = whitePlayer;
    [self updateWhitePlayerPhase:whitePlayer.phase];
}

- (void)registerNotificationAndKVO
{
    [self registerAudioSessionNotification];
    [self.nativePlayer addObserver:self forKeyPath:kRateKey options:0 context:nil];
    [self.nativePlayer addObserver:self forKeyPath:kCurrentItemKey options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
}

#pragma mark - Private Methods

/**
 ??????????????????????????????????????????????????????

 @return ????????????????????????????????????
 */
- (BOOL)videoDesireToPlay
{
    return self.nativePlayer.rate != 0;
}

- (BOOL)isLoaded:(NSArray<NSValue *> *)timeRanges
{
    if ([timeRanges count] == 0) {
        return NO;
    }
    CMTimeRange timeRange = [[timeRanges firstObject] CMTimeRangeValue];
    CMTime bufferTime = CMTimeAdd(timeRange.start, timeRange.duration);
    CMTime milestone = CMTimeAdd(self.nativePlayer.currentTime, CMTimeMakeWithSeconds(5.0f, timeRange.duration.timescale));
    
    if (CMTIME_COMPARE_INLINE(bufferTime , >, milestone) && self.nativePlayer.currentItem.status == AVPlayerItemStatusReadyToPlay && !self.isInterruptedWhilePlaying && !self.isRouteChangedWhilePlaying) {
        return YES;
    }
    return NO;
}

- (BOOL)hasEnoughNativeBuffer
{
    return self.nativePlayer.currentItem.isPlaybackLikelyToKeepUp;
}

- (CMTime)itemDuration
{
    NSError *err = nil;
    if ([self.nativePlayer.currentItem.asset statusOfValueForKey:@"duration" error:&err] == AVKeyValueStatusLoaded) {
        AVPlayerItem *playerItem = [self.nativePlayer currentItem];
        NSArray *loadedRanges = playerItem.seekableTimeRanges;
        if (loadedRanges.count > 0) {
            CMTimeRange range = [[loadedRanges firstObject] CMTimeRangeValue];
            return (range.duration);
        } else {
            return (kCMTimeInvalid);
        }
    } else {
        return (kCMTimeInvalid);
    }
}

#pragma mark - Notification

- (void)registerAudioSessionNotification
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:nil];
    
#if TARGET_OS_IPHONE
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(interruption:)
                                                 name:AVAudioSessionInterruptionNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(routeChange:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];
#endif
}

#pragma mark - Notification

- (void)playerItemDidReachEnd:(NSNotification *)notification
{
    if (notification.object == self.nativePlayer.currentItem && [self.delegate respondsToSelector:@selector(nativePlayerDidFinish)]) {
        [self.delegate nativePlayerDidFinish];
    }
}

- (void)interruption:(NSNotification *)notification
{
    NSDictionary *interruptionDict = notification.userInfo;
    NSInteger interruptionType = [interruptionDict[AVAudioSessionInterruptionTypeKey] integerValue];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (interruptionType == AVAudioSessionInterruptionTypeBegan && [self videoDesireToPlay]) {
            self.interruptedWhilePlaying = YES;
            [self pause];
        } else if (interruptionType == AVAudioSessionInterruptionTypeEnded && self.isInterruptedWhilePlaying) {
            self.interruptedWhilePlaying = NO;
            NSInteger resume = [interruptionDict[AVAudioSessionInterruptionOptionKey] integerValue];
            if (resume == AVAudioSessionInterruptionOptionShouldResume) {
                [self play];
            }
        }
    });
}

- (void)routeChange:(NSNotification *)notification
{
    NSDictionary *routeChangeDict = notification.userInfo;
    NSInteger routeChangeType = [routeChangeDict[AVAudioSessionRouteChangeReasonKey] integerValue];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (routeChangeType == AVAudioSessionRouteChangeReasonOldDeviceUnavailable && [self videoDesireToPlay]) {
            self.routeChangedWhilePlaying = YES;
            [self pause];
        } else if (routeChangeType == AVAudioSessionRouteChangeReasonNewDeviceAvailable && self.isRouteChangedWhilePlaying) {
            self.routeChangedWhilePlaying = NO;
            [self play];
        }
    });
}

#pragma mark - KVO
static NSString * const kRateKey = @"rate";
static NSString * const kCurrentItemKey = @"currentItem";
static NSString * const kStatusKey = @"status";
static NSString * const kPlaybackLikelyToKeepUpKey = @"playbackLikelyToKeepUp";
static NSString * const kPlaybackBufferFullKey = @"playbackBufferFull";
static NSString * const kPlaybackBufferEmptyKey = @"playbackBufferEmpty";
static NSString * const kLoadedTimeRangesKey = @"loadedTimeRanges";

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {

    if (object != self.nativePlayer.currentItem && object != self.nativePlayer) {
        return;
    }
    
    if (object == self.nativePlayer && [keyPath isEqualToString:kStatusKey]) {
        if (self.nativePlayer.status == AVPlayerStatusFailed) {
            [self pause];
            if ([self.delegate respondsToSelector:@selector(combineVideoPlayerError:)]) {
                [self.delegate combineVideoPlayerError:self.nativePlayer.error];
            }
        }
    } else if (object == self.nativePlayer && [keyPath isEqualToString:kCurrentItemKey]) {
        // ?????????????????? CurrentItem??????????????????Video ??????????????????
        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
        AVPlayerItem *lastPlayerItem = [change objectForKey:NSKeyValueChangeOldKey];
        if (lastPlayerItem != (id)[NSNull null]) {
            @try {
                [self removeObserverWithPlayItem:lastPlayerItem];
            } @catch(id anException) {
                //do nothing, obviously it wasn't attached because an exception was thrown
            }
        }
        if (newPlayerItem != (id)[NSNull null]) {
            [self addObserverWithPlayItem:newPlayerItem];
        }

    } else if ([keyPath isEqualToString:kRateKey]) {
        if ([self.delegate respondsToSelector:@selector(combineVideoPlayStateChange:)]) {
            [self.delegate combineVideoPlayStateChange:[self videoDesireToPlay]];
        }
    } else if ([keyPath isEqualToString:kStatusKey]) {
        if (self.nativePlayer.currentItem.status == AVPlayerItemStatusFailed) {
            [self pause];
            if ([self.delegate respondsToSelector:@selector(combineVideoPlayerError:)]) {
                [self.delegate combineVideoPlayerError:self.nativePlayer.currentItem.error];
            }
        }
    } else if ([keyPath isEqualToString:kPlaybackLikelyToKeepUpKey]) {
        DLog(@"isPlaybackLikelyToKeepUp %d", self.nativePlayer.currentItem.isPlaybackLikelyToKeepUp);
        if (self.nativePlayer.currentItem.isPlaybackLikelyToKeepUp) {
            [self nativeEndBuffering];
        }
    } else if ([keyPath isEqualToString:kPlaybackBufferFullKey]) {
        DLog(@"isPlaybackBufferFull %d", self.nativePlayer.currentItem.isPlaybackBufferFull);
        if (self.nativePlayer.currentItem.isPlaybackBufferFull) {
            [self nativeEndBuffering];
        }
    } else if ([keyPath isEqualToString:kPlaybackBufferEmptyKey]) {
        DLog(@"isPlaybackBufferEmpty %d", self.nativePlayer.currentItem.isPlaybackBufferEmpty);
        if (self.nativePlayer.currentItem.isPlaybackBufferEmpty) {
            [self nativeStartBuffering];
        }
    } else if ([keyPath isEqualToString:kLoadedTimeRangesKey]) {
        NSArray *timeRanges = (NSArray *)change[NSKeyValueChangeNewKey];
        if ([self.delegate respondsToSelector:@selector(loadedTimeRangeChange:)]) {
            [self.delegate loadedTimeRangeChange:timeRanges];
        }
    }
}

// ???????????? KVOController ??? KVO ??????
- (void)addObserverWithPlayItem:(AVPlayerItem *)item
{
    [item addObserver:self forKeyPath:kStatusKey options:NSKeyValueObservingOptionNew context:nil];
    [item addObserver:self forKeyPath:kLoadedTimeRangesKey options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context:nil];
    [item addObserver:self forKeyPath:kPlaybackLikelyToKeepUpKey options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context:nil];
    [item addObserver:self forKeyPath:kPlaybackBufferFullKey options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context:nil];
    [item addObserver:self forKeyPath:kPlaybackBufferEmptyKey options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context:nil];
}

- (void)removeObserverWithPlayItem:(AVPlayerItem *)item
{
    [item removeObserver:self forKeyPath:kStatusKey];
    [item removeObserver:self forKeyPath:kLoadedTimeRangesKey];
    [item removeObserver:self forKeyPath:kPlaybackLikelyToKeepUpKey];
    [item removeObserver:self forKeyPath:kPlaybackBufferFullKey];
    [item removeObserver:self forKeyPath:kPlaybackBufferEmptyKey];
}

- (void)removeNativePlayerKVO
{
    [self.nativePlayer removeObserver:self forKeyPath:kRateKey];
    [self.nativePlayer removeObserver:self forKeyPath:kCurrentItemKey];
}

#pragma mark - NativePlayer Buffering
- (void)nativeStartBuffering
{
    if ([self.delegate respondsToSelector:@selector(combinePlayerStartBuffering)]) {
        [self.delegate combinePlayerStartBuffering];
    }
    
    if ([self.delegate respondsToSelector:@selector(nativePlayerStartBuffering)]) {
        [self.delegate nativePlayerStartBuffering];
    }

    DLog(@"startNativeBuffering");
    
    //?????? native ????????????
    self.pauseReason = self.pauseReason | WhiteSyncManagerPauseReasonWaitingNativePlayerBuffering;
    
    //whitePlayer ?????? buffering ???????????????????????????????????????????????????????????????????????????
    [self pauseWhitePlayer];
}

- (void)nativeEndBuffering
{
    BOOL isBuffering  = (self.pauseReason & WhiteSyncManagerPauseReasonWaitingWhitePlayerBuffering) || (self.pauseReason & WhiteSyncManagerPauseReasonWaitingNativePlayerBuffering);
    //?0?
    self.pauseReason = self.pauseReason & ~WhiteSyncManagerPauseReasonWaitingNativePlayerBuffering;

    DLog(@"nativeEndBuffering %lu", (unsigned long)self.pauseReason);
    
    /**
     1. WhitePlayer ????????????(?01)?????????
     2. WhitePlayer ????????????(?00)???????????????
     */
    if (self.pauseReason & WhiteSyncManagerPauseReasonWaitingWhitePlayerBuffering) {
        [self.nativePlayer pause];
    } else if (isBuffering && [self.delegate respondsToSelector:@selector(combinePlayerEndBuffering)]) {
        [self.delegate combinePlayerEndBuffering];
    }
    
    if ([self.delegate respondsToSelector:@selector(nativePlayerEndBuffering)]) {
        [self.delegate nativePlayerEndBuffering];
    }

    /**
     1. ????????????????????????100?????????????????????????????????????????????????????????????????????API
     2. ????????????????????????000??????????????????
     3. whitePlayer ???????????????101???110?????????????????????????????????????????????????????????
     */
    if (self.pauseReason == WhiteSyncManagerPauseReasonNone) {
        [self playNativePlayer];
        [self playWhitePlayer];
    } else if (self.pauseReason & SyncManagerWaitingPauseReasonPlayerPause) {
        [self.nativePlayer pause];
        [self.whitePlayer pause];
    }
}

#pragma mark - white player buffering
- (void)whitePlayerStartBuffing
{
    self.pauseReason = self.pauseReason | WhiteSyncManagerPauseReasonWaitingWhitePlayerBuffering;

    [self.nativePlayer pause];
    
    if ([self.delegate respondsToSelector:@selector(combinePlayerStartBuffering)]) {
        [self.delegate combinePlayerStartBuffering];
    }
}

- (void)whitePlayerEndBuffering
{
    BOOL isBuffering  = (self.pauseReason & WhiteSyncManagerPauseReasonWaitingWhitePlayerBuffering) || (self.pauseReason & WhiteSyncManagerPauseReasonWaitingNativePlayerBuffering);
    //??0
    self.pauseReason = self.pauseReason & ~WhiteSyncManagerPauseReasonWaitingWhitePlayerBuffering;

    DLog(@"playerEndBuffering %lu", (unsigned long)self.pauseReason);

    /**
     1. native ????????????(?10)??????????????? whitePlayer
     2. native ????????????(?00)???????????????
     */
    if (self.pauseReason & WhiteSyncManagerPauseReasonWaitingNativePlayerBuffering) {
        [self pauseWhitePlayer];
    } else if (isBuffering && [self.delegate respondsToSelector:@selector(combinePlayerEndBuffering)]) {
        [self.delegate combinePlayerEndBuffering];
    }
    
    /**
     1. ????????????????????????100?????????????????????????????????????????????????????????????????????API
     2. ????????????????????????000??????????????????
     3. native ???????????????110???010?????????????????????????????????????????????????????????
     */
    if (self.pauseReason == WhiteSyncManagerPauseReasonNone) {
        [self playNativePlayer];
        [self playWhitePlayer];
    } else if (self.pauseReason & SyncManagerWaitingPauseReasonPlayerPause) {
        [self.nativePlayer pause];
        [self pauseWhitePlayer];
    }
}

#pragma mark - Play Control

- (void)setPlaybackSpeed:(CGFloat)playbackSpeed
{
    _playbackSpeed = playbackSpeed;
    if ([self videoDesireToPlay]) {
        [self playNativePlayer];
    }
    self.whitePlayer.playbackSpeed = playbackSpeed;
}

- (void)playNativePlayer
{
    self.nativePlayer.rate = self.playbackSpeed;
}

- (void)playWhitePlayer
{
    [self.whitePlayer play];
}

- (void)pauseWhitePlayer
{
    [self.whitePlayer pause];
}

#pragma mark - Public Methods
- (NSTimeInterval)videoDuration;
{
    CMTime itemDurationTime = [self itemDuration];
    NSTimeInterval duration = CMTimeGetSeconds(itemDurationTime);
    if (CMTIME_IS_INVALID(itemDurationTime) || !isfinite(duration)) {
        return 0.0f;
    } else {
        return duration;
    }
}

- (void)play
{
    self.pauseReason = self.pauseReason & ~SyncManagerWaitingPauseReasonPlayerPause;
    self.interruptedWhilePlaying = NO;
    self.routeChangedWhilePlaying = NO;
    
    if (self.pauseReason == WhiteSyncManagerPauseReasonNone) {
        [self playNativePlayer];
        [self playWhitePlayer];
    }
}

- (void)pause
{
    self.pauseReason = self.pauseReason | SyncManagerWaitingPauseReasonPlayerPause;
    [self.nativePlayer pause];
    [self pauseWhitePlayer];
}

- (void)updateWhitePlayerPhase:(WhitePlayerPhase)phase
{
    DLog(@"first updateWhitePlayerPhase %ld pauseReason:%ld", phase, self.pauseReason);
    // WhitePlay ?????????????????????pauseReason ?????? whitePlayerBuffering
    if (phase == WhitePlayerPhaseBuffering || phase == WhitePlayerPhaseWaitingFirstFrame) {
        [self whitePlayerStartBuffing];
    }
    // ?????????????????????whitePlayer ??????????????????????????? whitePlayerBuffering
    else if (phase == WhitePlayerPhasePause || phase == WhitePlayerPhasePlaying) {
        [self whitePlayerEndBuffering];
    }
    DLog(@"end updateWhitePlayerPhase %ld pauseReason:%ld", phase, self.pauseReason);
}

- (void)seekToTime:(CMTime)time completionHandler:(void (^)(BOOL finished))completionHandler
{
    NSTimeInterval seekTime = CMTimeGetSeconds(time);
    [self.whitePlayer seekToScheduleTime:seekTime];
    DLog(@"seekTime: %f", seekTime);
    
    __weak typeof(self)weakSelf = self;
    [self.nativePlayer seekToTime:time completionHandler:^(BOOL finished) {
        NSTimeInterval realTime = CMTimeGetSeconds(weakSelf.nativePlayer.currentItem.currentTime);
        DLog(@"realTime: %f", realTime);
        // AVPlayer ??? seek ???????????????, seek ?????????????????? native ???????????????????????? seek
        [weakSelf.whitePlayer seekToScheduleTime:realTime];
        if (finished) {
            completionHandler(finished);
        }
    }];
}

@end
