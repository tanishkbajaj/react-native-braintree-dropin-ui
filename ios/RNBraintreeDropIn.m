#import "RNBraintreeDropIn.h"
#import <React/RCTUtils.h>
#import "BTThreeDSecureRequest.h"
#include "BTPayPalDriver.h"
#include "BTVenmoDriver.h"
#import "BTVenmoAppSwitchRequestURL.h"

@implementation RNBraintreeDropIn

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}
RCT_EXPORT_MODULE(RNBraintreeDropIn)


#pragma mark -
#pragma mark Paypal Payment
#pragma mark -

RCT_EXPORT_METHOD(payPalPayment:(NSDictionary*)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    
    NSString* clientToken = options[@"clientToken"];
    if (!clientToken) {
        reject(@"NO_CLIENT_TOKEN", @"You must provide a client token", nil);
        return;
    }
    
    BTAPIClient *apiClient = [[BTAPIClient alloc] initWithAuthorization:clientToken];
    
    self.dataCollector = [[BTDataCollector alloc] initWithAPIClient:apiClient];
    [self.dataCollector collectCardFraudData:^(NSString * _Nonnull deviceDataCollector) {
    // Save deviceData
   
    }];
    
    BTPayPalDriver *driver = [[BTPayPalDriver alloc] initWithAPIClient:apiClient];
    driver.viewControllerPresentingDelegate = self;
    driver.appSwitchDelegate = self; // Optional
    
    NSString* amount = options[@"amount"];
    
    BTPayPalRequest *payPalRequest = [[BTPayPalRequest alloc] initWithAmount:amount];  //Here you need to enter the amount
    payPalRequest.currencyCode = options[@"currencyCode"];
    
    
    // One time payment if an amount is present
    if (payPalRequest.amount) {
        
        [driver requestOneTimePayment:payPalRequest completion:^(BTPayPalAccountNonce * _Nullable payPalAccount, NSError * _Nullable error) {
            
            if (payPalAccount != nil) {
                
                [[self class] resolveBTPayment:payPalAccount resolver:resolve];
            }
            else{
                reject(error.localizedDescription, error.localizedDescription, error);
            }
        }];
    } else {
        
        [driver requestBillingAgreement:payPalRequest completion:^(BTPayPalAccountNonce * _Nullable payPalAccount, NSError * _Nullable error) {
            
            if (payPalAccount != nil && error != nil) {
                
                [[self class] resolveBTPayment:payPalAccount resolver:resolve];
            }else
            {
                reject(error.localizedDescription, error.localizedDescription, error);
            }
        }];
    }
}




+ (void)resolveBTPayment:(BTPayPalAccountNonce* _Nullable)result resolver:(RCTPromiseResolveBlock _Nonnull)resolve {
    
    //TODO: Add more information if needed for Venmo
    NSMutableDictionary* jsResult = [NSMutableDictionary new];
    jsResult [@"nonce"]=result.nonce;
    jsResult [@"type"]=result.type;
    jsResult [@"localizedDescription"]=result.localizedDescription;
    jsResult [@"email"]=result.email; // Payer's email address
    jsResult [@"firstName"]=result.firstName; // Payer's first name.
    jsResult [@"lastName"] = result.lastName; //Payer's last name.
    jsResult[@"phone"] = result.phone; //Payer's phone number.
    jsResult[@"billing_region"] = result.billingAddress.region; // The billing address.
    jsResult[@"shipping_region"] = result.shippingAddress.region; //The shipping address.
    jsResult [@"clientMetadataId"] = result.clientMetadataId; // Client Metadata Id associated with this transaction.
    jsResult [@"payerId"] = result.payerId; //Optional. Payer Id associated with this transaction. Will be provided for Billing Agreement and Checkout.
    NSLog(@"check the jsResult %@", jsResult);
    
    resolve(jsResult);
}

#pragma mark -
#pragma mark Venmo Payment
#pragma mark -

- (BOOL)isiOSAppAvailableForAppSwitch {
    BOOL isAtLeastIos9 = ([[[UIDevice currentDevice] systemVersion] intValue] >= 9);
    return [[UIApplication sharedApplication] canOpenURL:[BTVenmoAppSwitchRequestURL baseAppSwitchURL]] && isAtLeastIos9;
}


RCT_EXPORT_METHOD(checkIfVenmoInstalled:(RCTResponseSenderBlock)callback){
  callback(@[[NSNumber numberWithBool:[self isiOSAppAvailableForAppSwitch]]]);
}

RCT_EXPORT_METHOD(venmoPayment:(NSDictionary*)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
   
    
    // Start the Vault flow, or...
    
    NSString* clientToken = options[@"clientToken"];
    if (!clientToken) {
        reject(@"NO_CLIENT_TOKEN", @"You must provide a client token", nil);
        return;
    }
    
    BTAPIClient *apiClient = [[BTAPIClient alloc] initWithAuthorization:clientToken];
    
    self.dataCollector = [[BTDataCollector alloc] initWithAPIClient:apiClient];
    [self.dataCollector collectCardFraudData:^(NSString * _Nonnull deviceDataCollector) {
    // Save deviceData
   
    }];
    
    
    //APPROACH: 1
    //https://developers.braintreepayments.com/guides/venmo/client-side/ios/v4
    
    BTVenmoDriver *venmoDriver = [[BTVenmoDriver alloc] initWithAPIClient:apiClient];
    venmoDriver.appSwitchDelegate = self; // Optional
    
    //We do not need to show Venmo App on store
    /*if(!venmoDriver.isiOSAppAvailableForAppSwitch){
        [venmoDriver openVenmoAppPageInAppStore];
        reject(@"ERROR", @"The Venmo app is not installed on this device", nil);
        return;
    }*/
    
    
    [venmoDriver authorizeAccountAndVault:false completion:^(BTVenmoAccountNonce * _Nullable venmoAccount, NSError * _Nullable error) {
        
        if (venmoAccount != nil ) {
            [[self class] bTVenmoAccountNonce:venmoAccount resolver:resolve];
        }
        else
        {
            reject(error.localizedDescription, error.localizedDescription, error);
        }
        
    }];
    
}

+ (void)bTVenmoAccountNonce:(BTVenmoAccountNonce* _Nullable)result resolver:(RCTPromiseResolveBlock _Nonnull)resolve {
    
    //TODO: Add more information if needed for Venmo
    NSMutableDictionary* jsResult = [NSMutableDictionary new];
    jsResult [@"username"] = result.username;
    jsResult [@"type"] = result.type;
    jsResult [@"localizedDescription"] = result.localizedDescription;
    jsResult [@"nonce"] = result.nonce; // The one-time use payment method nonce
    jsResult [@"type"] = result.type; // The type of the tokenized data, e.g. PayPal, Venmo, MasterCard, Visa, Amex.
    //jsResult[@"phone"] = result.isDefault;  //True if this nonce is the customer's default payment method, otherwise false.
   
    NSLog(@"check the jsResult %@", jsResult);
    
    resolve(jsResult);
}

+ (void)resolveVenmoPayment:(BTPaymentMethodNonce* _Nullable)result resolver:(RCTPromiseResolveBlock _Nonnull)resolve {
    
    
    NSMutableDictionary* jsResult = [NSMutableDictionary new];

    
    jsResult [@"nonce"]=result.nonce; // The one-time use payment method nonce
    jsResult [@"localizedDescription"]=result.localizedDescription; // Payer's first name.
    jsResult [@"type"] = result.type; // The type of the tokenized data, e.g. PayPal, Venmo, MasterCard, Visa, Amex.
    //jsResult[@"phone"] = result.isDefault;  //True if this nonce is the customer's default payment method, otherwise false.
   
    NSLog(@"check the jsResult %@", jsResult);
    
    resolve(jsResult);
}


#pragma mark BTAppSwitchDelegate

- (void)paymentDriverWillPerformAppSwitch:(__unused id)sender {
    // If there is a presented view controller, dismiss it before app switch
    // so that the result of the app switch can be shown in this view controller.
    
}


#pragma mark - BTViewControllerPresentingDelegate

- (void)paymentDriver:(__unused id)driver requestsPresentationOfViewController:(UIViewController *)viewController {
    
}

- (void)paymentDriver:(__unused id)driver requestsDismissalOfViewController:(__unused UIViewController *)viewController {
    
}

#pragma mark -
#pragma mark Helpers
#pragma mark -

- (UIViewController*)reactRoot {
    UIViewController *root  = [UIApplication sharedApplication].keyWindow.rootViewController;
    UIViewController *maybeModal = root.presentedViewController;
    
    UIViewController *modalRoot = root;
    
    if (maybeModal != nil) {
        modalRoot = maybeModal;
    }
    
    return modalRoot;
}


#pragma mark -
#pragma mark BTDropInController //TODO: Future Enhancement
#pragma mark -

RCT_EXPORT_METHOD(show:(NSDictionary*)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    
    /*
    
    if([options[@"darkTheme"] boolValue]){
        if (@available(iOS 13.0, *)) {
            BTUIKAppearance.sharedInstance.colorScheme = BTUIKColorSchemeDynamic;
        } else {
            BTUIKAppearance.sharedInstance.colorScheme = BTUIKColorSchemeDark;
        }
    } else {
        BTUIKAppearance.sharedInstance.colorScheme = BTUIKColorSchemeLight;
    }
    
    if(options[@"fontFamily"]){
        [BTUIKAppearance sharedInstance].fontFamily = options[@"fontFamily"];
    }
    if(options[@"boldFontFamily"]){
        [BTUIKAppearance sharedInstance].boldFontFamily = options[@"boldFontFamily"];
    }
    
    self.resolve = resolve;
    self.reject = reject;
    self.applePayAuthorized = NO;
    
    NSString* clientToken = options[@"clientToken"];
    if (!clientToken) {
        reject(@"NO_CLIENT_TOKEN", @"You must provide a client token", nil);
        return;
    }
    
    
    BTAPIClient *apiClient = [[BTAPIClient alloc] initWithAuthorization:clientToken];

     
     BTDropInRequest *request = [[BTDropInRequest alloc] init];
     
     NSDictionary* threeDSecureOptions = options[@"threeDSecure"];
     if (threeDSecureOptions) {
     NSNumber* threeDSecureAmount = threeDSecureOptions[@"amount"];
     if (!threeDSecureAmount) {
     reject(@"NO_3DS_AMOUNT", @"You must provide an amount for 3D Secure", nil);
     return;
     }
     
     request.threeDSecureVerification = YES;
     BTThreeDSecureRequest *threeDSecureRequest = [[BTThreeDSecureRequest alloc] init];
     threeDSecureRequest.amount = [NSDecimalNumber decimalNumberWithString:threeDSecureAmount.stringValue];
     request.threeDSecureRequest = threeDSecureRequest;
     
     }
     
     
     self.dataCollector = [[BTDataCollector alloc] initWithAPIClient:apiClient];
     [self.dataCollector collectCardFraudData:^(NSString * _Nonnull deviceDataCollector) {
     // Save deviceData
     self.deviceDataCollector = deviceDataCollector;
     }];
     
     if([options[@"vaultManager"] boolValue]){
     request.vaultManager = YES;
     }
     
     if([options[@"cardDisabled"] boolValue]){
     request.cardDisabled = YES;
     }
     
     if([options[@"applePay"] boolValue]){
     NSString* merchantIdentifier = options[@"merchantIdentifier"];
     NSString* countryCode = options[@"countryCode"];
     NSString* currencyCode = options[@"currencyCode"];
     NSString* merchantName = options[@"merchantName"];
     NSDecimalNumber* orderTotal = [NSDecimalNumber decimalNumberWithDecimal:[options[@"orderTotal"] decimalValue]];
     if(!merchantIdentifier || !countryCode || !currencyCode || !merchantName || !orderTotal){
     reject(@"MISSING_OPTIONS", @"Not all required Apple Pay options were provided", nil);
     return;
     }
     self.braintreeClient = [[BTAPIClient alloc] initWithAuthorization:clientToken];
     
     self.paymentRequest = [[PKPaymentRequest alloc] init];
     self.paymentRequest.merchantIdentifier = merchantIdentifier;
     self.paymentRequest.merchantCapabilities = PKMerchantCapability3DS;
     self.paymentRequest.countryCode = countryCode;
     self.paymentRequest.currencyCode = currencyCode;
     self.paymentRequest.supportedNetworks = @[PKPaymentNetworkAmex, PKPaymentNetworkVisa, PKPaymentNetworkMasterCard, PKPaymentNetworkDiscover, PKPaymentNetworkChinaUnionPay];
     self.paymentRequest.paymentSummaryItems =
     @[
     [PKPaymentSummaryItem summaryItemWithLabel:merchantName amount:orderTotal]
     ];
     
     self.viewController = [[PKPaymentAuthorizationViewController alloc] initWithPaymentRequest: self.paymentRequest];
     self.viewController.delegate = self;
     }else{
     request.applePayDisabled = YES;
     }
     
     BTDropInController *dropIn = [[BTDropInController alloc] initWithAuthorization:clientToken request:request handler:^(BTDropInController * _Nonnull controller, BTDropInResult * _Nullable result, NSError * _Nullable error) {
     [self.reactRoot dismissViewControllerAnimated:YES completion:nil];
     
     //result.paymentOptionType == .ApplePay
     //NSLog(@"paymentOptionType = %ld", result.paymentOptionType);
     
     if (error != nil) {
     reject(error.localizedDescription, error.localizedDescription, error);
     } else if (result.cancelled) {
     reject(@"USER_CANCELLATION", @"The user cancelled", nil);
     } else {
     if (threeDSecureOptions && [result.paymentMethod isKindOfClass:[BTCardNonce class]]) {
     BTCardNonce *cardNonce = (BTCardNonce *)result.paymentMethod;
     if (!cardNonce.threeDSecureInfo.liabilityShiftPossible && cardNonce.threeDSecureInfo.wasVerified) {
     reject(@"3DSECURE_NOT_ABLE_TO_SHIFT_LIABILITY", @"3D Secure liability cannot be shifted", nil);
     } else if (!cardNonce.threeDSecureInfo.liabilityShifted && cardNonce.threeDSecureInfo.wasVerified) {
     reject(@"3DSECURE_LIABILITY_NOT_SHIFTED", @"3D Secure liability was not shifted", nil);
     } else{
     [[self class] resolvePayment:result deviceData:self.deviceDataCollector resolver:resolve];
     }
     } else if(result.paymentMethod == nil && (result.paymentOptionType == 16 || result.paymentOptionType == 18)){ //Apple Pay
     // UIViewController *ctrl = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
     // [ctrl presentViewController:self.viewController animated:YES completion:nil];
     UIViewController *rootViewController = RCTPresentedViewController();
     [rootViewController presentViewController:self.viewController animated:YES completion:nil];
     } else{
     [[self class] resolvePayment:result deviceData:self.deviceDataCollector resolver:resolve];
     }
     }
     }];
     [self.reactRoot presentViewController:dropIn animated:YES completion:nil];
     */
    
         
}

/*
- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                       didAuthorizePayment:(PKPayment *)payment
                                completion:(void (^)(PKPaymentAuthorizationStatus))completion
{
    
    // Example: Tokenize the Apple Pay payment
    BTApplePayClient *applePayClient = [[BTApplePayClient alloc]
                                        initWithAPIClient:self.braintreeClient];
    [applePayClient tokenizeApplePayPayment:payment
                                 completion:^(BTApplePayCardNonce *tokenizedApplePayPayment,
                                              NSError *error) {
        if (tokenizedApplePayPayment) {
            // On success, send nonce to your server for processing.
            // If applicable, address information is accessible in `payment`.
            // NSLog(@"description = %@", tokenizedApplePayPayment.localizedDescription);
            
            completion(PKPaymentAuthorizationStatusSuccess);
            self.applePayAuthorized = YES;
            
            
            NSMutableDictionary* result = [NSMutableDictionary new];
            [result setObject:tokenizedApplePayPayment.nonce forKey:@"nonce"];
            [result setObject:@"Apple Pay" forKey:@"type"];
            [result setObject:[NSString stringWithFormat: @"%@ %@", @"", tokenizedApplePayPayment.type] forKey:@"description"];
            [result setObject:[NSNumber numberWithBool:false] forKey:@"isDefault"];
            [result setObject:self.deviceDataCollector forKey:@"deviceData"];
            
            self.resolve(result);
            
        } else {
            // Tokenization failed. Check `error` for the cause of the failure.
            
            // Indicate failure via the completion callback:
            completion(PKPaymentAuthorizationStatusFailure);
        }
    }];
}

// Be sure to implement -paymentAuthorizationViewControllerDidFinish:
- (void)paymentAuthorizationViewControllerDidFinish:(PKPaymentAuthorizationViewController *)controller{
    [self.reactRoot dismissViewControllerAnimated:YES completion:nil];
    if(self.applePayAuthorized == NO){
        self.reject(@"USER_CANCELLATION", @"The user cancelled", nil);
    }
}
 
 
 + (void)resolvePayment:(BTDropInResult* _Nullable)result deviceData:(NSString * _Nonnull)deviceDataCollector resolver:(RCTPromiseResolveBlock _Nonnull)resolve {
     //NSLog(@"result = %@", result);
     
     NSMutableDictionary* jsResult = [NSMutableDictionary new];
     [jsResult setObject:result.paymentMethod.nonce forKey:@"nonce"];
     [jsResult setObject:result.paymentMethod.type forKey:@"type"];
     [jsResult setObject:result.paymentDescription forKey:@"description"];
     [jsResult setObject:[NSNumber numberWithBool:result.paymentMethod.isDefault] forKey:@"isDefault"];
     [jsResult setObject:deviceDataCollector forKey:@"deviceData"];
     
     resolve(jsResult);
 }
 
 
 NSString * const VenmoAppStoreUrl = @"https://itunes.apple.com/us/app/venmo-send-receive-money/id351727428";

 - (void)openVenmoAppPageInAppStore {
     NSURL *venmoAppStoreUrl = [NSURL URLWithString:VenmoAppStoreUrl];
     if (@available(iOS 10.0, *)) {
         [[UIApplication sharedApplication] openURL:venmoAppStoreUrl options:[NSDictionary dictionary] completionHandler:nil];
     } else {

         [[UIApplication sharedApplication] openURL:venmoAppStoreUrl];

     }
 }

*/


- (void)appSwitcher:(nonnull id)appSwitcher didPerformSwitchToTarget:(BTAppSwitchTarget)target {
    
}

- (void)appSwitcherWillPerformAppSwitch:(nonnull id)appSwitcher {
    
}

- (void)appSwitcherWillProcessPaymentInfo:(nonnull id)appSwitcher {
    
}

@end
