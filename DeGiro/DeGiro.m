//
//  DeGiro.m
//  DeGiro
//
//  Created by Taras Kalapun on 9/3/15.
//  Copyright (c) 2015 Taras Kalapun. All rights reserved.
//

#import "DeGiro.h"
#import <AFNetworking.h>

@interface DeGiro ()
@property (nonatomic, strong) AFHTTPRequestOperationManager *requestManager;


@property (nonatomic, strong) NSString *accountId;

@end

@implementation DeGiro


+ (instancetype)shared {
    static DeGiro *instance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setup];
        //[self setupDummyData];
    }
    return self;
}

- (BOOL)needsReLogin {
    if (!self.lastUpdate) return YES;
    if ([self.lastUpdate timeIntervalSinceNow] < 5) {
        return NO;
    }
    return YES;
}

- (void)setup {
    
    NSURL *url = [NSURL URLWithString:@"https://www.degiro.eu/trading/secure/"];
    
    
    self.requestManager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:url];
    //self.requestManager.requestSerializer = [AFJSONRequestSerializer serializer];
    self.requestManager.responseSerializer = [AFJSONResponseSerializer serializer];
    [self.requestManager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
}

- (void)updateAccountWithData:(NSDictionary *)data {
    self.sessionId = data[@"jsessionid"];
    self.accountId = data[@"account"];
}

- (void)updateAccountInfoWithData:(NSDictionary *)data {
    
    self.baseCurrency = data[@"baseCurrency"];
    
    NSMutableDictionary *curr = [NSMutableDictionary new];
    for (NSString *currKey in data[@"currencyPairs"]) {
        curr[currKey] = data[@"currencyPairs"][currKey][@"price"];
    }
    
    self.currencyRates = curr;
}

- (void)loadAccountWithUsername:(NSString *)username password:(NSString *)password completion:(void (^)(NSString *accountId, NSError *error))completion {
    [self loginWithUsername:username password:password completion:^(NSString *accountId, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        [self loadAccountInfoWithCompletion:^(NSDictionary *data, NSError *error) {
            if (error) {
                completion(nil, error);
                return;
            }
            completion(self.accountId, nil);
        }];
    }];
}

- (void)loginWithUsername:(NSString *)username password:(NSString *)password completion:(void (^)(NSString *accountId, NSError *error))completion {
    
    NSDictionary *params = @{
                             @"username": username,
                             @"password": password,
                             };

    
    [self.requestManager POST:@"login"
                   parameters:params
                      success:^(AFHTTPRequestOperation *operation, NSDictionary *responseObject) {
                          [self updateAccountWithData:responseObject];
                          self.lastUpdate = [NSDate date];
                          completion(self.accountId, nil);
                      }
                      failure:^(AFHTTPRequestOperation *operation, NSError *error){
                          completion(nil, error);
                      }];
}

- (void)loadAccountInfoWithCompletion:(void (^)(NSDictionary *data, NSError *error))completion {
    NSString *path = [NSString stringWithFormat:@"v4/account/info/%@;jsessionid=%@", self.accountId, self.sessionId];
    [self.requestManager GET:path
                  parameters:nil
                     success:^(AFHTTPRequestOperation *operation, NSDictionary *responseObject) {
                         [self updateAccountInfoWithData:responseObject];
                         completion(responseObject, nil);
                     }
                     failure:^(AFHTTPRequestOperation *operation, NSError *error){
                         completion(nil, error);
                     }];
}

- (void)loadPortfolioWithCompletion:(void (^)(NSDictionary *data, NSError *error))completion {
    
    NSDictionary *params = @{
                             @"portfolio": @"0",
                             @"totalPortfolio": @"0",
                             };
    
    
    NSString *path = [NSString stringWithFormat:@"v4/update/%@;jsessionid=%@", self.accountId, self.sessionId];
    [self.requestManager GET:path
                   parameters:params
                      success:^(AFHTTPRequestOperation *operation, NSDictionary *responseObject) {
                          self.lastUpdate = [NSDate date];
                          
                          completion(responseObject, nil);
                      }
                      failure:^(AFHTTPRequestOperation *operation, NSError *error){
                          completion(nil, error);
                      }];
}

@end
