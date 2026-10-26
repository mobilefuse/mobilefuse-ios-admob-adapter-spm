//
//  MobileFuseBannerCustomEvent.m
//

#import "MobileFuseBannerCustomEvent.h"

#import <GoogleMobileAds/GoogleMobileAds.h>
#import <objc/runtime.h>

#include <stdatomic.h>

@import MobileFuseSDK;

// Silence deprecation warnings
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface MobileFuseBannerCustomEvent () <GADMediationAdapter, GADMediationBannerAd, IMFAdCallbackReceiver> {
    // MobileFuse banner ad
    MFBannerAd *_bannerAd;

    // The completion handler to call when the ad loading succeeds or fails.
    GADMediationBannerLoadCompletionHandler _loadCompletionHandler;

    // The ad event delegate to forward ad rendering events to the Google Mobile Ads SDK.
    id<GADMediationBannerAdEventDelegate> _adEventDelegate;
}

// Legacy support
@property(nonatomic, weak, nullable) id<GADCustomEventBannerDelegate> delegate;

@end

@implementation MobileFuseBannerCustomEvent

const uint kRemoveOrphanedAdDelay = 30;

@synthesize delegate;

#pragma mark GADMediationBannerAd implementation
/* These methods are the currently supported methods for the Google Mobile Ads SDK */

- (void)loadBannerForAdConfiguration:(GADMediationBannerAdConfiguration *)adConfiguration completionHandler:(GADMediationBannerLoadCompletionHandler)completionHandler {
    __block atomic_flag completionHandlerCalled = ATOMIC_FLAG_INIT;
    __block GADMediationBannerLoadCompletionHandler originalCompletionHandler = [completionHandler copy];

    _loadCompletionHandler = ^id<GADMediationBannerAdEventDelegate>(_Nullable id<GADMediationBannerAd> ad, NSError *_Nullable error) {
        // Only allow completion handler to be called once.
        if (atomic_flag_test_and_set(&completionHandlerCalled)) {
            return nil;
        }

        id<GADMediationBannerAdEventDelegate> delegate = nil;
        if (originalCompletionHandler) {
            // Call original handler and hold on to its return value.
            delegate = originalCompletionHandler(ad, error);
        }

        // Release reference to handler. Objects retained by the handler will also be released.
        originalCompletionHandler = nil;

        return delegate;
    };
    
    if(_bannerAd) {
        // Destroy the old ad instance
        [_bannerAd destroy];
        _bannerAd = nil;
    }
    
    NSString *placementId = [MobileFuseExtras getPlacementIdFromAdConfiguration:adConfiguration];
    if (placementId == nil || [placementId isEqualToString:@""]) {
        NSLog(@"[MobileFuse Adapter] Unable to get banner placement ID from server. Did you set your Custom Event up correctly in the AdMob dashboard's mediation settings?");
        return;
    }
    
    NSLog(@"[MobileFuse Adapter] Creating banner ad with placement id: %@", placementId);
    
    _bannerAd = [[MFBannerAd alloc] initWithPlacementId:placementId withSize:[MobileFuseExtras getBannerSizeFromGoogleAdSize:adConfiguration.adSize]];
    [_bannerAd registerAdCallbackReceiver:self];
    
    if (adConfiguration.isTestRequest) {
        NSLog(@"[MobileFuse Adapter] Test mode enabled for banner ad (adConfiguration.isTestRequest is YES)");
        [_bannerAd setTestMode:YES];
    }
    
    NSLog(@"[MobileFuse Adapter] MobileFuseExtras isMuted: %@", [MobileFuseExtras isMuted] ? @"YES" : @"NO");
    [_bannerAd setMuted:[MobileFuseExtras isMuted]];
    
    [_bannerAd loadAd];
}

- (nonnull UIView *)view {
    return _bannerAd;
}

#pragma mark GADCustomEventBanner
/* These methods are used if an older version of the Google Mobile Ads SDK is in use */

- (void)requestBannerAd:(GADAdSize)adSize
              parameter:(NSString *)serverParameter
                  label:(NSString *)serverLabel
                request:(GADCustomEventRequest *)request {
    NSLog(@"[MobileFuse Adapter] Requesting Banner from MobileFuse SDK");
    
    [self loadMobileFuseBannerWithParameter:serverParameter withAdSize:adSize];
}

- (void)loadMobileFuseBannerWithParameter:(NSString *)serverParameter withAdSize:(GADAdSize)adSize {
    dispatch_async(dispatch_get_main_queue(), ^ {
        if(![MobileFuse isReady]) { // If the MobileFuse SDK isn't ready to show a banner ad, wait a bit and try again
            NSLog(@"[MobileFuse Adapter] MobileFuse SDK is not ready, make sure you call [MobileFuse initWithAppId:withPublisherId:withDelegate]");
            return;
        }
        
        if(self->_bannerAd) {
            // Destroy the old ad instance
            [self->_bannerAd destroy];
        }
        
        NSDictionary *configuration = [MobileFuseExtras getDictionaryFromJsonString:serverParameter];
        
        NSLog(@"[MobileFuse Adapter] Server parameter: %@", serverParameter);
        
        if(!configuration[@"placementId"]) {
            NSLog(@"[MobileFuse Adapter] Unable to get banner placement ID from server. Did you set your Custom Event up correctly in the AdMob dashboard's mediation settings?");
            return;
        }
        
        // Set up a new ad
        self->_bannerAd = [[MFBannerAd alloc] initWithPlacementId:configuration[@"placementId"] withSize:[MobileFuseExtras getBannerSizeFromGoogleAdSize:adSize]];
        [self->_bannerAd registerAdCallbackReceiver:self];
        
        NSLog(@"[MobileFuse Adapter] MobileFuseExtras isMuted: %@", [MobileFuseExtras isMuted] ? @"YES" : @"NO");
        [self->_bannerAd setMuted:[MobileFuseExtras isMuted]];
        
        // Start loading it!
        [self->_bannerAd loadAd];
    });
}

+ (BOOL)legacyConformsToProtocol:(Protocol *)protocol {
    // As we don't declare that we conform to the protocol in the class (which breaks support for 9.0.0+), we need to specify it here
    if ([MobileFuseExtras needsCustomEventIntegration] == YES && protocol == @protocol(GADCustomEventBanner)) {
        return YES;
    }
    return [super conformsToProtocol:protocol];
}

+ (void)load {
    // We must make sure 8.x.x has conformsToProtocol but 9.0.0+ does not
    if ([MobileFuseExtras needsCustomEventIntegration]) { // Of course, we only do it if we have detected 8.x.x
        // Using a technique called Swizzling, we replace the 'conformsToProtocol:' method at runtime; this ensures 9.0.0+ will never see it
        Method swizzledMethod = class_getClassMethod([self class], @selector(legacyConformsToProtocol:));
        IMP swizzledImp = method_getImplementation(swizzledMethod);
        Class swizzleClass = object_getClass((id)[self class]);
        
        class_replaceMethod(swizzleClass, @selector(conformsToProtocol:), swizzledImp, method_getTypeEncoding(swizzledMethod));
    }
}

#pragma mark IMFAdCallbackReceiver methods

- (void)onAdLoaded:(MFAd *)ad {
    NSLog(@"[MobileFuse Adapter] onAdLoaded");
    if ([MobileFuseExtras needsCustomEventIntegration]) {
        [self.delegate customEventBanner:(id<GADCustomEventBanner>)self didReceiveAd:ad];
    } else {
        _adEventDelegate = _loadCompletionHandler(self, nil);
    }
    
    // Show the banner ad and provide the root view controller
    UIViewController *rootViewController = [MobileFuseExtras getRootViewController];
    if (rootViewController != nil) {
        [(MFBannerAd*)ad showAdWithViewController:rootViewController];
    }
}

- (void)onAdNotFilled:(MFAd *)ad {
    NSLog(@"[MobileFuse Adapter] onAdNotFilled");
    
    // No fill error
    NSError *error = [NSError errorWithDomain:[MobileFuseExtras errorDomain] code:MOBILEFUSE_ADAPTER_ERROR_AD_NOT_FILLED userInfo:@{ NSLocalizedDescriptionKey: @"[MobileFuse Adapter] Ad was not filled." }];
    if ([MobileFuseExtras needsCustomEventIntegration]) {
        [self.delegate customEventBanner:(id<GADCustomEventBanner>)self didFailAd:error];
    } else {
        _adEventDelegate = _loadCompletionHandler(nil, error);
    }
}

- (void)onAdClosed:(MFAd *)ad {
    NSLog(@"[MobileFuse Adapter] onAdClosed");
    
    // Destroy the ad when closed
    if(_bannerAd) {
        [_bannerAd destroy];
        _bannerAd = nil;
    }
}

- (void)onAdRendered:(MFAd *)ad {
    NSLog(@"[MobileFuse Adapter] onAdRendered");
    // No google event for this
}

- (void)onAdClicked:(MFAd *)ad {
    NSLog(@"[MobileFuse Adapter] onAdClicked");
    if ([MobileFuseExtras needsCustomEventIntegration]) {
        [self.delegate customEventBannerWasClicked:(id<GADCustomEventBanner>)self];
    } else {
        [_adEventDelegate reportClick];
    }
}

- (void)onAdExpanded:(MFAd *)ad {
    NSLog(@"[MobileFuse Adapter] onAdExpanded");
    if ([MobileFuseExtras needsCustomEventIntegration]) {
        [self.delegate customEventBannerWillPresentModal:(id<GADCustomEventBanner>)self];
    } else {
        [_adEventDelegate willPresentFullScreenView];
    }
}

- (void)onAdCollapsed:(MFAd *)ad {
    NSLog(@"[MobileFuse Adapter] onAdCollapsed");
    if ([MobileFuseExtras needsCustomEventIntegration]) {
        [self.delegate customEventBannerDidDismissModal:(id<GADCustomEventBanner>)self];
    } else {
        [_adEventDelegate willDismissFullScreenView];
        [_adEventDelegate didDismissFullScreenView];
    }
}

- (void)onAdExpired:(MFAd *)ad {
    NSLog(@"[MobileFuse Adapter] onAdExpired");
    
    // Destroy the ad when expired
    if(_bannerAd) {
        [_bannerAd destroy];
        _bannerAd = nil;
    }
}

- (void)onAdError:(MFAd *)ad withError:(MFAdError *)error {
    NSLog(@"[MobileFuse Adapter] onAdError with message: %@", error.message);
    if ([MobileFuseExtras needsCustomEventIntegration]) {
        [self.delegate customEventBanner:(id<GADCustomEventBanner>)self didFailAd:error];
    } else {
        _adEventDelegate = _loadCompletionHandler(self, error);
    }
}

- (void)onAdRemovedFromWindow:(MFAd *)ad {
    NSLog(@"[MobileFuse Adapter] onAdRemovedFromWindow");
    
    // When a banner ad is removed from the window, set a timer that checks if it has a window after 30 seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kRemoveOrphanedAdDelay * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if(!ad.window) {
            NSLog(@"[MobileFuse Adapter] Ad was orphaned, destroying...");
            [ad destroy];
            
            // Clear references
            self.delegate = nil;
            self->_bannerAd = nil;
        }
    });
}

#pragma mark GADMediationAdapter methods

+ (Class<GADAdNetworkExtras>)networkExtrasClass {
    return [MobileFuseExtras class];
}

+ (GADVersionNumber)adSDKVersion {
    return [MobileFuseExtras adSDKVersion];
}

+ (GADVersionNumber)adapterVersion {
    return [MobileFuseExtras adapterVersion];
}

+ (NSString *)adapterVersionName {
    return [MobileFuseExtras adapterVersionName];
}

+ (void)setUpWithConfiguration:(GADMediationServerConfiguration *)configuration completionHandler:(GADMediationAdapterSetUpCompletionBlock)completionHandler {
    [MobileFuseExtras initializeMobileFuseSDKFromServerConfiguration:configuration withCompletionHandler:completionHandler];
}

@end

#pragma clang diagnostic pop
