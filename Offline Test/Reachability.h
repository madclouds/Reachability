//
//  Reachability.h
//  Offline Test
//
//  Created by Erik Bye on 8/8/18.
//  Copyright © 2018 Planning Center. All rights reserved.
//

@import Foundation;
@import SystemConfiguration;
@import UIKit;
@import Darwin.POSIX.netinet.in;

NS_ASSUME_NONNULL_BEGIN

@class Reachability;

typedef NS_ENUM(NSInteger, MCTReachabilityNetworkStatus) {
    MCTReachabilityNetworkNotReachable     = 0,
    MCTReachabilityNetworkReachableViaWiFi = 1,
#if    TARGET_OS_IPHONE
    MCTReachabilityNetworkReachableViaWWAN = 2
#endif
};
typedef void (^MCTReachabilityStatusChange)(Reachability *, MCTReachabilityNetworkStatus);

@interface Reachability : NSObject

- (BOOL)startNotifier;
- (BOOL)stopNotifier;
- (BOOL)isReachable;
+ (nullable instancetype)newReachabilityWithURL:(NSURL *)URL;
+ (nullable instancetype)newReachabilityWithHostName:(NSString *)hostName;

@property (nonatomic, strong, readonly, nullable) NSString *host;

@end

OBJC_EXTERN NSString *const MCTReachabilityStatusChangedNotification;

OBJC_EXTERN NSString *const kMCTReachabilityStatus;

NS_ASSUME_NONNULL_END
