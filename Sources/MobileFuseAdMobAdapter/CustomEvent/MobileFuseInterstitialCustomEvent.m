//
//  MobileFuseInterstitialCustomEvent.m
//

#import "MobileFuseInterstitialCustomEvent.h"

#import <GoogleMobileAds/GoogleMobileAds.h>
#import <objc/runtime.h>

#include <stdatomic.h>

@import MobileFuseSDK;

// Silence deprecation warnings
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface MobileFuseInterstitialCustomEvent () <GADMediationAdapter, GADMediationInterstitialAd, IMFAdCallbackReceiver> {
    // MobileFuse interstitial ad
    MFInterstitialAd *_interstitialAd;

    // The completion handler to call when the ad loading succeeds or fails.
    GADMediationInterstitialLoadCompletionHandler _loadCompletionHandler;

    // The ad event delegate to forward ad rendering events to the Google Mobile Ads SDK.
    id<GADMediationInterstitialAdEventDelegate> _adEventDelegate;
}

// Legacy support
@property(nonatomic, weak, nullable) id<GADCustomEventInterstitialDelegate> delegate;

@end

@implementation MobileFuseInterstitialCustomEvent

@synthesize delegate;

#pragma mark GADMediationInterstitialAd implementation
/* These methods are the currently supported methods for the Google Mobile Ads SDK */

- (void)loadInterstitialForAdConfiguration: (GADMediationInterstitialAdConfiguration *)adConfiguration completionHandler: (GADMediationInterstitialLoadCompletionHandler)completionHandler {
    __block atomic_flag completionHandlerCalled = ATOMIC_FLAG_INIT;
    __block GADMediationInterstitialLoadCompletionHandler originalCompletionHandler = [completionHandler copy];

    _loadCompletionHandler = ^id<GADMediationInterstitialAdEventDelegate>(_Nullable id<GADMediationInterstitialAd> ad, NSError *_Nullable error) {
        // Only allow completion handler to be called once.
        if (atomic_flag_test_and_set(&completionHandlerCalled)) {
            return nil;
        }

        id<GADMediationInterstitialAdEventDelegate> delegate = nil;
        if (originalCompletionHandler) {
            // Call original handler and hold on to its return value.
            delegate = originalCompletionHandler(ad, error);
        }

        // Release reference to handler. Objects retained by the handler will also be released.
        originalCompletionHandler = nil;

        return delegate;
    };
    
    if(![MobileFuse isReady]) { // If the MobileFuse SDK isn't ready to show an ad, wait a bit and try again
        NSLog(@"[MobileFuse Adapter] MobileFuse SDK is not ready, make sure you call [MobileFuse initWithAppId:withPublisherId:withDelegate]");
        return;
    }
    
    if(_interstitialAd) {
        // Destroy the old ad instance
        [_interstitialAd destroy];
        _interstitialAd = nil;
    }
    
    NSString *placementId = [MobileFuseExtras getPlacementIdFromAdConfiguration:adConfiguration];
    if (placementId == nil || [placementId isEqualToString:@""]) {
        NSLog(@"[MobileFuse Adapter] Unable to get interstitial placement ID from server. Did you set your Custom Event up correctly in the AdMob dashboard's mediation settings?");
        return;
    }
    
    NSLog(@"[MobileFuse Adapter] Creating interstitial ad with placement id: %@", placementId);

    _interstitialAd = [[MFInterstitialAd alloc] initWithPlacementId:placementId];
    [_interstitialAd registerAdCallbackReceiver:self];
    
    if (adConfiguration.isTestRequest) {
        NSLog(@"[MobileFuse Adapter] Test mode enabled for interstitial ad (adConfiguration.isTestRequest is YES)");
        [_interstitialAd setTestMode:YES];
    }
    [_interstitialAd loadAd];
}

// Present the interstitial ad using the provided view controller
- (void)presentFromViewController:(UIViewController *)viewController {
    if ([_interstitialAd isLoaded]) {
        [viewController.view addSubview:_interstitialAd];
        [_interstitialAd showAd];
    } else {
        NSError *error = [[NSError alloc] initWithDomain:[MobileFuseExtras errorDomain] code:MOBILEFUSE_ADAPTER_ERROR_AD_NOT_LOADED userInfo:@{ NSLocalizedDescriptionKey:@"[MobileFuse Adapter] Tried to present an interstitial ad but the ad was not ready" }];
        _adEventDelegate = _loadCompletionHandler(self, error);
    }
}

#pragma mark GADCustomEventInterstitial
/* These methods are used if an older version of the Google Mobile Ads SDK is in use */

- (void)requestInterstitialAdWithParameter:(NSString *)serverParameter
                                     label:(NSString *)serverLabel
                                   request:(GADCustomEventRequest *)request {
    if ([MobileFuseExtras needsCustomEventIntegration] == NO) return;
    
    NSLog(@"[MobileFuse Adapter] Requesting interstitial from MobileFuse SDK");
    
    [self loadMobileFuseInterstitialWithParameter:serverParameter];
}

- (void)loadMobileFuseInterstitialWithParameter:(NSString *)serverParameter {
    if ([MobileFuseExtras needsCustomEventIntegration] == NO) return;
    
    dispatch_async(dispatch_get_main_queue(), ^ {
        if(![MobileFuse isReady]) { // If the MobileFuse SDK isn't ready to show a banner ad, wait a bit and try again
            NSLog(@"[MobileFuse Adapter] MobileFuse SDK is not ready, make sure you call [MobileFuse initWithAppId:withPublisherId:withDelegate]");
            return;
        }
        
        if(self->_interstitialAd) {
            // Destroy the old ad instance
            [self->_interstitialAd destroy];
            self->_interstitialAd = nil;
        }
        
        NSDictionary *configuration = [MobileFuseExtras getDictionaryFromJsonString:serverParameter];
        
        NSLog(@"[MobileFuse Adapter] Server parameter: %@", serverParameter);
        
        if(!configuration[@"placementId"]) {
            NSLog(@"[MobileFuse Adapter] Unable to get interstitial placement ID from server. Did you set your Custom Event up correctly in the AdMob dashboard's mediation settings?");
            return;
        }
        
        self->_interstitialAd = [[MFInterstitialAd alloc] initWithPlacementId:configuration[@"placementId"]];
        [self->_interstitialAd registerAdCallbackReceiver:self];
        
        [self->_interstitialAd loadAd];
    });
}

+ (BOOL)legacyConformsToProtocol:(Protocol *)protocol {
    // As we don't declare that we conform to the protocol in the class (which breaks support for 9.0.0+), we need to specify it here
    if ([MobileFuseExtras needsCustomEventIntegration] == YES && protocol == @protocol(GADCustomEventInterstitial)) {
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

// Present the interstitial ad as a modal view using the provided view controller
- (void)presentFromRootViewController:(UIViewController *)rootViewController {
    if ([MobileFuseExtras needsCustomEventIntegration] == NO) return;
    
    if ([_interstitialAd isLoaded]) {
        [rootViewController.view addSubview:_interstitialAd];
        [_interstitialAd showAd];
    }
}

#pragma mark IMFAdCallbackReceiver methods

- (void)onAdLoaded:(MFAd *)ad {
    NSLog(@"[MobileFuse Adapter] onAdLoaded");
    
    if ([MobileFuseExtras needsCustomEventIntegration]) {
        [self.delegate customEventInterstitialDidReceiveAd:(id<GADCustomEventInterstitial>)self];
    } else {
        _adEventDelegate = _loadCompletionHandler(self, nil);
    }
}

- (void)onAdNotFilled:(MFAd *)ad {
    NSLog(@"[MobileFuse Adapter] onAdNotFilled");
    
    // No fill error
    NSError *error = [[NSError alloc] initWithDomain:[MobileFuseExtras errorDomain] code:MOBILEFUSE_ADAPTER_ERROR_AD_NOT_FILLED userInfo:@{ NSLocalizedDescriptionKey:@"[MobileFuse Adapter] Ad was not filled" }];
    if ([MobileFuseExtras needsCustomEventIntegration]) {
        [self.delegate customEventInterstitial:(id<GADCustomEventInterstitial>)self didFailAd:error];
    } else {
        _adEventDelegate = _loadCompletionHandler(nil, error);
    }
}

- (void)onAdClosed:(MFAd *)ad {
    NSLog(@"[MobileFuse Adapter] onAdClosed");
    if ([MobileFuseExtras needsCustomEventIntegration]) {
        [self.delegate customEventInterstitialDidDismiss:(id<GADCustomEventInterstitial>)self];
    } else {
        [_adEventDelegate willDismissFullScreenView];
        [_adEventDelegate didDismissFullScreenView];
    }
    
    // Destroy the ad when closed
    if(_interstitialAd) {
        [_interstitialAd destroy];
        _interstitialAd = nil;
    }
}

- (void)onAdRendered:(MFAd *)ad {
    NSLog(@"[MobileFuse Adapter] onAdRendered");
    if ([MobileFuseExtras needsCustomEventIntegration]) {
        [self.delegate customEventInterstitialWillPresent:(id<GADCustomEventInterstitial>)self];
    } else {
        [_adEventDelegate willPresentFullScreenView];
        [_adEventDelegate reportImpression];
    }
}

- (void)onAdClicked:(MFAd *)ad {
    NSLog(@"[MobileFuse Adapter] onAdClicked");
    if ([MobileFuseExtras needsCustomEventIntegration]) {
        [self.delegate customEventInterstitialWasClicked:(id<GADCustomEventInterstitial>)self];
    } else {
        [_adEventDelegate reportClick];
    }
}

- (void)onAdExpired:(MFAd *)ad {
    NSLog(@"[MobileFuse Adapter] onAdExpired");
    
    // Destroy the ad when expired
    if(_interstitialAd) {
        [_interstitialAd destroy];
        _interstitialAd = nil;
    }
}

- (void)onAdError:(MFAd *)ad withError:(MFAdError *)error {
    NSLog(@"[MobileFuse Adapter] onAdError with message: %@", error.message);
    if ([MobileFuseExtras needsCustomEventIntegration]) {
        [self.delegate customEventInterstitial:(id<GADCustomEventInterstitial>)self didFailAd:error];
    } else {
        _adEventDelegate = _loadCompletionHandler(self, error);
    }
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
