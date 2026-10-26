//
// MobileFuseExtras.m
//

#import "MobileFuseExtras.h"

// Adapter version number is SDK_VERSION.ADAPTER_REVISION (e.g 1.0.0.000)
#define ADAPTER_REVISION (@"0") // Increment this if we need to release a patched adapter for a particular SDK version (and set to 0 for next new SDK version)

@implementation MobileFuseExtras

static BOOL _muted = YES; // Mute by default
static GADMediationAdapterSetUpCompletionBlock _gadAdapterSetupCompletionHandler = nil;

+ (void)setMuted:(BOOL)muted {
    _muted = muted;
}

+ (BOOL)isMuted {
    return _muted;
}

+ (NSString *)errorDomain {
    return @"com.MobileFuse.MobileFuseGoogleAdapter";
}

+ (MFBannerAdSize)getBannerSizeFromGoogleAdSize:(GADAdSize)adSize {
    @try {
        CGSize size = adSize.size;
        if(size.width == 320 && size.height == 50) {
            return MOBILEFUSE_BANNER_SIZE_320x50;
        } else if(size.width == 300 && size.height == 250) {
            return MOBILEFUSE_BANNER_SIZE_300x250;
        } else if(size.width == 300 && size.height == 50) {
            return MOBILEFUSE_BANNER_SIZE_300x50;
        } else if(size.width == 728 && size.height == 90) {
            return MOBILEFUSE_BANNER_SIZE_728x90;
        }
        
        // No match with predefined sizes. Match the size using our formula
        if (((double)size.width / (double)size.height) < 3.0) {
            return MOBILEFUSE_BANNER_SIZE_300x250;
        } else if (size.width > 520) {
            return MOBILEFUSE_BANNER_SIZE_728x90;
        }
    }
    @catch (id exception) { }
    
    return MOBILEFUSE_BANNER_SIZE_320x50;
}

+ (UIViewController *)getRootViewController {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindow *keyWindow = ((UIWindowScene *)scene).keyWindow;
        if (keyWindow) {
            return keyWindow.rootViewController;
        }
    }
    return nil;
}

+ (NSString *)getPlacementIdFromAdConfiguration:(GADMediationAdConfiguration *)adConfiguration {
    NSString *placementId = nil;
    @try {
        NSString* parameter = adConfiguration.credentials.settings[@"parameter"];
        NSDictionary* configuration = [self getDictionaryFromJsonString:parameter];
        placementId = configuration[@"placementId"];
    }
    @catch (id exception) {
        NSLog(@"[MobileFuse Adapter] Warning: could not get placement ID from GAD configuration: %@", [exception message]);
    }
    return placementId;
}

+ (void)initializeMobileFuseSDKFromServerConfiguration:(GADMediationServerConfiguration *)configuration withCompletionHandler:(GADMediationAdapterSetUpCompletionBlock)completionHandler {
    NSString *appId = [MobileFuseExtras getAppIdFromServerConfiguration:configuration];
    NSString *publisherId = [MobileFuseExtras getPublisherIdFromServerConfiguration:configuration];
    if ([MobileFuse isReadyForAppId:appId withPublisherId:publisherId]) {
        completionHandler(nil);
        return;
    }
    _gadAdapterSetupCompletionHandler = completionHandler;
    dispatch_async(dispatch_get_main_queue(), ^{
        [MobileFuse initWithAppId:appId withPublisherId:publisherId withDelegate:(id<IMFInitializationCallbackReceiver>)self];
    });
}

+ (NSString *)getPublisherIdFromServerConfiguration:(GADMediationServerConfiguration *)serverConfiguration {
    return [self getAppKeyComponentWithIndex:0 fromServerConfiguration:serverConfiguration];
}

+ (NSString *)getAppIdFromServerConfiguration:(GADMediationServerConfiguration *)serverConfiguration {
    return [self getAppKeyComponentWithIndex:1 fromServerConfiguration:serverConfiguration];
}

+ (NSString *)getAppKeyComponentWithIndex:(unsigned int)componentIndex fromServerConfiguration:(GADMediationServerConfiguration *)configuration {
    NSString *appId = nil;
    @try {
        NSString *parameter = [self getParameterFromServerConfiguration:configuration];
        NSArray *appKeyComponents = [self getAppKeyComponentsFromServerParameter:parameter];
        appId = appKeyComponents[componentIndex];
    }
    @catch (id exception) {
        NSLog(@"[MobileFuse Adapter] Warning: could not get app key component from server configuration: %@", [exception message]);
    }
    return appId;
}

+ (NSArray *)getAppKeyComponentsFromServerParameter:(NSString *)parameter {
    NSArray *appKeyComponents = nil;
    @try {
        NSDictionary *configuration = [self getDictionaryFromJsonString:parameter];
        NSString *appKey = configuration[@"appKey"];
        appKeyComponents = [appKey componentsSeparatedByString:@"_"];
    }
    @catch (id exception) {
        NSLog(@"[MobileFuse Adapter] Warning: could not get app key from configuration parameter: %@", [exception message]);
    }
    return appKeyComponents;
}

+ (NSString *)getParameterFromServerConfiguration:(GADMediationServerConfiguration *)serverConfiguration {
    NSString *parameter = nil;
    @try {
        parameter = serverConfiguration.credentials[0].settings[@"parameter"];
    }
    @catch (id exception) {
        NSLog(@"[MobileFuse Adapter] Warning: could not get app key from GAD configuration: %@", [exception message]);
    }
    return parameter;
}

+ (NSDictionary *)getDictionaryFromJsonString:(NSString *)json {
    NSData *jsonData = [json dataUsingEncoding:NSUTF8StringEncoding];
    return [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
}

- (void)setMuteAudio:(BOOL)muted {
    _muted = muted;
}

- (BOOL)muteAudio {
    return _muted ? YES : NO; // Could be NULL - convert that to NO
}

+ (GADVersionNumber)adSDKVersion {
    NSArray *versionComponents = [[MobileFuse version] componentsSeparatedByString:@"."];

    GADVersionNumber version = {0};
    if (versionComponents.count >= 3) {
        version.majorVersion = [versionComponents[0] integerValue];
        version.minorVersion = [versionComponents[1] integerValue];
        version.patchVersion = [versionComponents[2] integerValue];
    }
    return version;
}

+ (GADVersionNumber)adapterVersion {
    NSString *versionString = [self adapterVersionName];
    NSArray *versionComponents = [versionString componentsSeparatedByString:@"."];

    GADVersionNumber version = {0};
    if (versionComponents.count >= 4) {
        version.majorVersion = [versionComponents[0] integerValue];
        version.minorVersion = [versionComponents[1] integerValue];
        // Adapter versions have 2 patch versions. Multiply the first patch by 100.
        version.patchVersion =
                [versionComponents[2] integerValue] * 100 + [versionComponents[3] integerValue];
    }
    return version;
}

+ (NSString *)adapterVersionName {
    return [NSString stringWithFormat:@"%@.%@", [MobileFuse version], ADAPTER_REVISION];
}

+ (BOOL)needsCustomEventIntegration {
    // Google Mobile Ads SDK versions before 9.0.0 require custom event integrations for certain ad types
    GADVersionNumber gadVersionNumber = [[GADMobileAds sharedInstance] versionNumber];
    return gadVersionNumber.majorVersion < 9; // check if the major version is less than version 9
}

+ (void)onInitSuccess:(NSString *)appId withPublisherId:(NSString *)publisherId {
    _gadAdapterSetupCompletionHandler(nil);
}

+ (void)onInitError:(NSString *)appId withPublisherId:(NSString *)publisherId withError:(MFAdError *)error {
    _gadAdapterSetupCompletionHandler(error);
}

@end
