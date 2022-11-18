//
//  AppDelegate+HealthFitness.h
//
//  Created by Luis Bouça on 25/10/2022.
//

#ifndef AppDelegate_HealthFitness_h
#define AppDelegate_HealthFitness_h

#import "AppDelegate.h"
#import <objc/runtime.h>
#import <HealthKit/HealthKit.h>

@interface AppDelegate (AppDelegateHealthFitness)<NSURLSessionTaskDelegate> {}

@end
#endif /* AppDelegate_HealthFitness_h */
