//
//  MobileFuseNativeCustomEvent.m
//  

#import "MobileFuseNativeCustomEvent.h"
#include <stdatomic.h>

#import <Foundation/Foundation.h>

@interface MobileFuseNativeCustomEvent () <GADMediationAdapter, GADMediationNativeAd, IMFAdCallbackReceiver> {
    
  /// The completion handler to call when the ad loading succeeds or fails.
  GADMediationNativeLoadCompletionHandler _loadCompletionHandler;

  /// The ad event delegate to forward ad rendering events to the Google Mobile Ads SDK.
  id<GADMediationNativeAdEventDelegate> _adEventDelegate;

  /// Native ad view options.
  GADNativeAdViewAdOptions *_nativeAdViewAdOptions;

  /// The native ad object
  MFNativeAd *_nativeAd;
}

@end

@implementation MobileFuseNativeCustomEvent

/// Used to store the ad's images. In order to implement the GADMediationNativeAd protocol, we use
/// this class to return the images property.
NSArray<GADNativeAdImage *> *_images;

/// Used to store the ad's icon. In order to implement the GADMediationNativeAd protocol, we use
/// this class to return the icon property.
GADNativeAdImage *_icon;

/// Used to store the ad's ad choices view. In order to implement the GADMediationNativeAd protocol,
/// we use this class to return the adChoicesView property.
UIView *_adChoicesView;

- (nullable NSString *)headline {
  return _nativeAd.getTitle;
}

- (nullable NSArray<GADNativeAdImage *> *)images {
  return _images;
}

- (nullable NSString *)body {
  return _nativeAd.getDescriptionText;
}

- (nullable NSString *)advertiser {
  return _nativeAd.getSponsoredText;
}

- (nullable GADNativeAdImage *)icon {
  return _icon;
}

- (nullable NSString *)callToAction {
  return _nativeAd.getCtaButtonText;
}

- (nullable UIView *)mediaView {
  return _nativeAd.getMainVideoView;
}

- (BOOL)hasVideoContent {
  return _nativeAd.hasMainVideo;
}

- (void)loadNativeAdForAdConfiguration:(GADMediationNativeAdConfiguration *)adConfiguration
                     completionHandler:(GADMediationNativeLoadCompletionHandler)completionHandler {
    __block atomic_flag completionHandlerCalled = ATOMIC_FLAG_INIT;
    __block GADMediationNativeLoadCompletionHandler originalCompletionHandler = [completionHandler copy];
    _loadCompletionHandler = ^id<GADMediationNativeAdEventDelegate>(_Nullable id<GADMediationNativeAd> ad, NSError *_Nullable error) {
        // Only allow completion handler to be called once.
        if (atomic_flag_test_and_set(&completionHandlerCalled)) {
            return nil;
        }
        id<GADMediationNativeAdEventDelegate> delegate = nil;
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
        NSLog(@"[MobileFuse Adapter] Unable to get native placement ID from server. Did you set your Custom Event up correctly in the AdMob dashboard's mediation settings?");
        return;
    }
    NSLog(@"[MobileFuse Adapter] Creating native ad with placement id: %@", placementId);
    _nativeAd = [[MFNativeAd alloc] initWithPlacementId:placementId];
    [_nativeAd registerAdCallbackReceiver:self];
    if (adConfiguration.isTestRequest) {
        NSLog(@"[MobileFuse Adapter] Test mode enabled for native ad (adConfiguration.isTestRequest is YES)");
        [_nativeAd setTestMode:YES];
    }
    [_nativeAd loadAd];
}

+ (Class<GADAdNetworkExtras>)networkExtrasClass {
    return [MobileFuseExtras class];
}

+ (GADVersionNumber)adSDKVersion {
    return [MobileFuseExtras adSDKVersion];
}

+ (GADVersionNumber)adapterVersion {
    return [MobileFuseExtras adapterVersion];
}

// Indicates if the custom event handles user clicks. Return YES if the custom event should handle
// user clicks.
- (BOOL)handlesUserClicks {
  return NO;
}

- (BOOL)handlesUserImpressions {
  return NO;
}

#pragma mark IMFAdCallbackReceiver implementation

- (void)onAdLoaded:(MFAd *)ad {
    MFNativeAd *nativeAd = (MFNativeAd *)ad;
    if (nativeAd.getMainImage) {
        _images = @[ [[GADNativeAdImage alloc] initWithImage:nativeAd.getMainImage] ];
    }
    if (nativeAd.hasIcon) {
        _icon = [[GADNativeAdImage alloc] initWithImage:nativeAd.getIconImage];
    }
    _nativeAd = nativeAd;
    _adEventDelegate = _loadCompletionHandler(self, nil);
}

#pragma mark GADMediatedUnifiedNativeAd implementation

// Because the Sample SDK has click and impression tracking via methods on its native ad object
// which the developer is required to call, there's no need to pass it a reference to the UIView
// being used to display the native ad. So there's no need to implement
// mediatedNativeAd:didRenderInView:viewController:clickableAssetViews:nonClickableAssetViews here.
// If your mediated network does need a reference to the view, this method can be used to provide
// one.
// You can also access the clickable and non-clickable views by asset key if the mediation network
// needs this information.
- (void)didRenderInView:(UIView *)view
       clickableAssetViews:(NSDictionary<GADNativeAssetIdentifier, UIView *> *)clickableAssetViews
    nonclickableAssetViews:
        (NSDictionary<GADNativeAssetIdentifier, UIView *> *)nonclickableAssetViews
            viewController:(UIViewController *)viewController {
    [_nativeAd registerViewForInteraction:view withClickableViews:[clickableAssetViews allValues]];
}

- (void)didUntrackView:(UIView *)view {
    // This method is called when the mediatedNativeAd is no longer rendered in the provided view.
    // Here you would remove any tracking from the view that has mediated native ad.
    [_nativeAd unregisterViews];
}

- (void)didRecordImpression {
  if (_nativeAd) {
    //[_nativeAd recordImpression];
  }
}

- (void)didRecordClickOnAssetWithName:(GADNativeAssetIdentifier)assetName
                                 view:(UIView *)view
                       viewController:(UIViewController *)viewController {
  if (_nativeAd) {
    //[_nativeAd handleClickOnView:view];
  }
}

+ (void)setUpWithConfiguration:(GADMediationServerConfiguration *)configuration completionHandler:(GADMediationAdapterSetUpCompletionBlock)completionHandler {
    [MobileFuseExtras initializeMobileFuseSDKFromServerConfiguration:configuration withCompletionHandler:completionHandler];
}

@end
