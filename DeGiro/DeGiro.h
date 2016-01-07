//
//  DeGiro.h
//  DeGiro
//
//  Created by Taras Kalapun on 9/3/15.
//  Copyright (c) 2015 Taras Kalapun. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DeGiro : NSObject

+ (instancetype)shared;

@property (nonatomic, strong) NSString *sessionId;
@property (nonatomic, strong) NSString *baseCurrency;
@property (nonatomic, strong) NSDictionary *currencyRates;
@property (nonatomic, strong) NSDate *lastUpdate;

- (BOOL)needsReLogin;

- (void)loginWithUsername:(NSString *)username password:(NSString *)password completion:(void (^)(NSString *accountId, NSError *error))completion;
- (void)loadAccountWithUsername:(NSString *)username password:(NSString *)password completion:(void (^)(NSString *accountId, NSError *error))completion;
- (void)loadPortfolioWithCompletion:(void (^)(NSDictionary *data, NSError *error))completion;

@end
