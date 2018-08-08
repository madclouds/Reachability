//
//  Reachability.m
//  Offline Test
//
//  Created by Erik Bye on 8/8/18.
//  Copyright © 2018 Planning Center. All rights reserved.
//

#import "Reachability.h"
@import Darwin.POSIX.pthread;

@interface Reachability () {
    pthread_mutex_t _mutex;
    BOOL _restart;
}

@property (nonatomic, readonly) SCNetworkReachabilityRef reach;
@property (nonatomic, readwrite, getter = isRunning) BOOL running;

- (void)mct_reachChanged:(SCNetworkReachabilityFlags)flags;

@property (nonatomic, strong) dispatch_queue_t queue;

@end

static void MCTReachabilityHandler(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info);
static NSString *MCTReachabilityFlagsString(SCNetworkReachabilityFlags flags);
static void MCTReachabilityPrintFlags(SCNetworkReachabilityFlags flags, const char *comment);

@implementation Reachability


+ (instancetype)newReachabilityWithURL:(NSURL *)URL {
    return [self newReachabilityWithHostName:[URL host]];
}

+ (instancetype)newReachabilityWithHostName:(NSString *)hostName {
    SCNetworkReachabilityRef reach = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, [hostName UTF8String]);
    if (reach != NULL) {
        return [[self alloc] initWithReachability:reach host:hostName];
    }
    return nil;
}


- (instancetype)initWithReachability:(SCNetworkReachabilityRef)reachability host:(NSString *)host {
    self = [super init];
    if (self) {
        _host = [host copy];
        _reach = reachability;
        _queue = dispatch_queue_create("com.pcococoa.reachability", DISPATCH_QUEUE_SERIAL);
        int status = pthread_mutex_init(&_mutex, NULL);
        NSAssert(status == 0, @"Failed to create mutex");
#pragma unused(status)

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}


- (void)applicationWillResignActive:(NSNotification *)notif {
#pragma unused(notif)
    if ([self isRunning]) {
        [self stopNotifier];
        _restart = YES;
    } else {
        _restart = NO;
    }
}

- (void)applicationDidBecomeActive:(NSNotification *)notif {
#pragma unused(notif)
    if (_restart) {
        [self startNotifier];
        _restart = NO;
    }
}

- (BOOL)startNotifier {
    pthread_mutex_lock(&_mutex);
    if ([self isRunning]) {

        dispatch_async(dispatch_get_main_queue(), ^{
            [self mct_fireReachabilityChanged];
        });
        pthread_mutex_unlock(&_mutex);
        return YES;
    }

    SCNetworkReachabilityContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};

    if (SCNetworkReachabilitySetCallback(self.reach, MCTReachabilityHandler, &context)) {
        if (SCNetworkReachabilitySetDispatchQueue(self.reach, self.queue)) {

            self.running = YES;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self mct_fireReachabilityChanged];
            });
            pthread_mutex_unlock(&_mutex);
            return YES;
        }
    }

    pthread_mutex_unlock(&_mutex);
    return NO;
}

- (BOOL)stopNotifier {
    pthread_mutex_lock(&_mutex);
    if ([self isRunning] && self.reach != NULL) {
        if (SCNetworkReachabilitySetDispatchQueue(self.reach, NULL)) {

            self.running = NO;
            pthread_mutex_unlock(&_mutex);
            return YES;
        }
        pthread_mutex_unlock(&_mutex);
        return NO;
    }
    pthread_mutex_unlock(&_mutex);
    return YES;
}

#pragma mark -
#pragma mark - Changes
- (void)mct_fireReachabilityChanged {
    SCNetworkReachabilityFlags flags;
    if ([self mct_getFlags:&flags]) {
        [self mct_reachChanged:flags];
    }
}

- (void)mct_reachChanged:(SCNetworkReachabilityFlags)flags {
    MCTReachabilityPrintFlags(flags, "Reachability Flags Changed");

    MCTReachabilityNetworkStatus status = [self mct_getReachabilityStatusFromFlags:flags];

    [[NSNotificationCenter defaultCenter] postNotificationName:MCTReachabilityStatusChangedNotification object:self userInfo:@{kMCTReachabilityStatus: @(status)}];
}


#pragma mark -
#pragma mark - Status
- (BOOL)mct_getFlags:(SCNetworkReachabilityFlags *)flags {
    return SCNetworkReachabilityGetFlags(self.reach, flags) == TRUE;
}

- (MCTReachabilityNetworkStatus)status {
    SCNetworkReachabilityFlags flags;
    if ([self mct_getFlags:&flags]) {
        return [self mct_getReachabilityStatusFromFlags:flags];
    }

    return MCTReachabilityNetworkNotReachable;
}

- (MCTReachabilityNetworkStatus)mct_getReachabilityStatusFromFlags:(SCNetworkReachabilityFlags)flags {
    if ((flags & kSCNetworkReachabilityFlagsReachable) == 0) {
        return MCTReachabilityNetworkNotReachable;
    }

    MCTReachabilityNetworkStatus status = MCTReachabilityNetworkNotReachable;

    if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0) {
        status = MCTReachabilityNetworkReachableViaWiFi;
    }
    if ((flags & kSCNetworkReachabilityFlagsConnectionOnDemand) != 0 || (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0) {
        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0) {
            status = MCTReachabilityNetworkReachableViaWiFi;
        }
    }
#if    TARGET_OS_IPHONE
    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN) {
        status = MCTReachabilityNetworkReachableViaWWAN;
    }
#endif

    return status;
}

- (NSString *)mct_debugFlagsString {
    SCNetworkReachabilityFlags flags;
    if ([self mct_getFlags:&flags]) {
        return MCTReachabilityFlagsString(flags);
    }
    return @"xx xxxxxxx";
}

- (BOOL)isReachableWiFi {
    return (self.status == MCTReachabilityNetworkReachableViaWiFi);
}

- (BOOL)isReachableWWAN {
#if    TARGET_OS_IPHONE
    return (self.status == MCTReachabilityNetworkReachableViaWWAN);
#else
    return NO;
#endif
}

- (BOOL)isReachable {
    return ([self isReachableWiFi] || [self isReachableWWAN]);
}

- (BOOL)isReachableSync {
    return ([self isReachableWiFi] || [self isReachableWWAN]);
}

- (BOOL)isUnReachable {
    return (self.status == MCTReachabilityNetworkNotReachable);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<Reachability: %@>",[self mct_debugFlagsString]];
}

@end


NSString *const MCTReachabilityStatusChangedNotification = @"MCTReachabilityStatusChangedNotification";
NSString *const kMCTReachabilityStatus = @"status";

/**
 *  C
 */
static void MCTReachabilityHandler(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info) {
#pragma unused(target)
#pragma unused(flags)
    if (info == NULL) {
        return;
    }
    Reachability *reach = (__bridge Reachability *)info;
    if (!reach || ![reach isKindOfClass:[Reachability class]]) {

        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [reach mct_fireReachabilityChanged];
    });
}
static void MCTReachabilityPrintFlags(SCNetworkReachabilityFlags flags, const char *comment) {
#pragma unused(flags)
#pragma unused(comment)

}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-function"
static NSString *MCTReachabilityFlagsString(SCNetworkReachabilityFlags flags) {
#if    TARGET_OS_IPHONE
    char wwan = (flags & kSCNetworkReachabilityFlagsIsWWAN)                  ? 'W' : '-';
#else
    char wwan = '-';
#endif
    char tran = (flags & kSCNetworkReachabilityFlagsReachable)            ? 'R' : '-';
    char reac = (flags & kSCNetworkReachabilityFlagsTransientConnection)  ? 't' : '-';
    char requ = (flags & kSCNetworkReachabilityFlagsConnectionRequired)   ? 'c' : '-';
    char traf = (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic)  ? 'C' : '-';
    char inte = (flags & kSCNetworkReachabilityFlagsInterventionRequired) ? 'i' : '-';
    char dema = (flags & kSCNetworkReachabilityFlagsConnectionOnDemand)   ? 'D' : '-';
    char loca = (flags & kSCNetworkReachabilityFlagsIsLocalAddress)       ? 'l' : '-';
    char dire = (flags & kSCNetworkReachabilityFlagsIsDirect)             ? 'd' : '-';
    NSString *status = (flags & kSCNetworkReachabilityFlagsReachable)  ? @"Connected" : @"Not Connected";
    return [NSString stringWithFormat:@"%c%c %c%c%c%c%c%c%c (%@)",wwan,tran,reac,requ,traf,inte,dema,loca,dire, status];
}
#pragma clang diagnostic pop
