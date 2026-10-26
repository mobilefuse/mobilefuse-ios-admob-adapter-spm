//
// MobileFuseRewardedCustomEvent.m
//

@import MobileFuseSDK;

#import "MobileFuseRewardedCustomEvent.h"

#include <stdatomic.h>

// Silence deprecation warnings
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface MobileFuseRewardedCustomEvent () <GADMediationAdapter, GADMediationRewardedAd, IMFAdCallbackReceiver> {
    // MobileFuse rewarded ad
    MFRewardedAd *_rewardedAd;
    
    // Completion handler to call when rewarded ad finishes loading
    GADMediationRewardedLoadCompletionHandler _loadCompletionHandler;
    
    // Delegate for receiving rewarded ad notifications
    id<GADMediationRewardedAdEventDelegate> _adEventDelegate;
}

@end

@implementation MobileFuseRewardedCustomEvent

- (void)loadRewardedAdForAdConfiguration:(GADMediationRewardedAdConfiguration *)adConfiguration completionHandler:(GADMediationRewardedLoadCompletionHandler)completionHandler {
    __block atomic_flag completionHandlerCalled = ATOMIC_FLAG_INIT;
    __block GADMediationRewardedLoadCompletionHandler originalCompletionHandler = [completionHandler copy];

    _loadCompletionHandler = ^id<GADMediationRewardedAdEventDelegate>(_Nullable id<GADMediationRewardedAd> ad, NSError *_Nullable error) {
        // Only allow completion handler to be called once.
        if (atomic_flag_test_and_set(&completionHandlerCalled)) {
          return nil;
        }

        id<GADMediationRewardedAdEventDelegate> delegate = nil;
        if (originalCompletionHandler) {
          // Call original handler and hold on to its return value.
          delegate = originalCompletionHandler(ad, error);
        }

        // Release reference to handler. Objects retained by the handler will also be released.
        originalCompletionHandler = nil;

        return delegate;
    };
    
    NSString *placementId = [MobileFuseExtras getPlacementIdFromAdConfiguration:adConfiguration];
    if (placementId == nil || [placementId isEqualToString:@""]) {
        NSLog(@"[MobileFuse Adapter] Unable to get rewarded placement ID from server. Did you set your Custom Event up correctly in the AdMob dashboard's mediation settings?");
        return;
    }
    
    NSLog(@"[MobileFuse Adapter] Creating rewarded ad with placement id: %@", placementId);
    
    _rewardedAd = [[MFRewardedAd alloc] initWithPlacementId:placementId];
    [_rewardedAd registerAdCallbackReceiver:self];
    
    if (adConfiguration.isTestRequest) {
        NSLog(@"[MobileFuse Adapter] Test mode enabled for rewarded ad (adConfiguration.isTestRequest is YES)");
        [_rewardedAd setTestMode:YES];
    }
    [_rewardedAd loadAd];
}

#pragma mark GADMediationRewardedAd implementation

- (void)presentFromViewController:(UIViewController *)viewController {
    [viewController.view addSubview:_rewardedAd];
    [_rewardedAd showAd];
}

#pragma mark IMFAdCallbackReceiver implementation

- (void)onAdLoaded:(MFAd *)ad {
    NSLog(@"[MobileFuse Adapter] onAdLoaded");
    _adEventDelegate = _loadCompletionHandler(self, nil);
}

- (void)onAdNotFilled:(MFAd *)ad {
    NSLog(@"[MobileFuse Adapter] onAdNotFilled");
    
    // No fill error
    NSError *error = [[NSError alloc] initWithDomain:[MobileFuseExtras errorDomain] code:MOBILEFUSE_ADAPTER_ERROR_AD_NOT_FILLED userInfo:@{ NSLocalizedDescriptionKey:@"[MobileFuse Adapter] Ad was not filled" }];
    _adEventDelegate = _loadCompletionHandler(self, error);
}

- (void)onAdClosed:(MFAd *)ad {
    NSLog(@"[MobileFuse Adapter] onAdClosed");
    [_adEventDelegate willDismissFullScreenView];
    [_adEventDelegate didEndVideo];
    [_adEventDelegate didDismissFullScreenView];
}

- (void)onAdError:(MFAd *)ad withError:(MFAdError *)error {
    NSLog(@"[MobileFuse Adapter] onAdError with message: %@", error.message);
    _adEventDelegate = _loadCompletionHandler(nil, error);
}

- (void)onAdRendered:(MFAd *)ad {
    NSLog(@"[MobileFuse Adapter] onAdRendered");
    [_adEventDelegate willPresentFullScreenView];
    [_adEventDelegate didStartVideo];
    [_adEventDelegate reportImpression];
}

- (void)onAdClicked:(MFAd *)ad {
    NSLog(@"[MobileFuse Adapter] onAdClicked");
    [_adEventDelegate reportClick];
}

- (void)onAdExpired:(MFAd *)ad {
    NSLog(@"[MobileFuse Adapter] onAdExpired");
    
    // Destroy the ad when expired
    if(_rewardedAd) {
        [_rewardedAd destroy];
        _rewardedAd = nil;
    }
}

- (void)onUserEarnedReward:(MFAd *)ad {
    NSLog(@"[MobileFuse Adapter] onUserEarnedReward");
    [_adEventDelegate didRewardUser];
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
