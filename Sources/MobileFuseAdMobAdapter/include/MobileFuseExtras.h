//
// MobileFuseExtras.h
//

#import <GoogleMobileAds/GoogleMobileAds.h>

@import MobileFuseSDK;

typedef NS_ENUM(NSUInteger, MobileFuseAdapterErrorCode) {
    MOBILEFUSE_ADAPTER_ERROR_INITIALIZATION_FAILED = 1,
    MOBILEFUSE_ADAPTER_ERROR_AD_NOT_LOADED,
    MOBILEFUSE_ADAPTER_ERROR_AD_NOT_FILLED,
    MOBILEFUSE_ADAPTER_ERROR_AD_ERROR,
};

@interface MobileFuseExtras : NSObject <GADAdNetworkExtras, IMFInitializationCallbackReceiver>

/// Use this to indicate if debug mode is on for logging.
@property(nonatomic) BOOL enableDebugLogging;

/// Use this to mute audio for ads
@property(nonatomic) BOOL muteAudio;

+ (void)setMuted:(BOOL)muted;
+ (BOOL)isMuted;
+ (NSString *)errorDomain;
+ (MFBannerAdSize)getBannerSizeFromGoogleAdSize:(GADAdSize)adSize;
+ (UIViewController*)getRootViewController;
+ (void)initializeMobileFuseSDKFromServerConfiguration:(GADMediationServerConfiguration *)configuration withCompletionHandler:(GADMediationAdapterSetUpCompletionBlock)completionHandler;
+ (NSString *)getPlacementIdFromAdConfiguration:(GADMediationAdConfiguration *)adConfiguration;
+ (NSString *)getPublisherIdFromServerConfiguration:(GADMediationServerConfiguration *)serverConfiguration;
+ (NSString *)getAppIdFromServerConfiguration:(GADMediationServerConfiguration *)serverConfiguration;
+ (NSDictionary *)getDictionaryFromJsonString:(NSString *)json;

+ (GADVersionNumber)adSDKVersion;
+ (GADVersionNumber)adapterVersion;
+ (NSString *)adapterVersionName;

+ (BOOL)needsCustomEventIntegration;

@end
