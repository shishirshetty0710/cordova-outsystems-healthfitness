//
//  AppDelegate+HealthFitness.m
//
//  Created by Luis Bouça on 25/10/2022.
//


#import "AppDelegate+HealthFitness.h"
#import <BackgroundTasks/BackgroundTasks.h>
#import <UserNotifications/UserNotifications.h>

@implementation AppDelegate(AppDelegateHealthFitness)

static NSString* taskId = @"com.outsystems.health.custom";
NSURLSession* sharedSession;
NSUInteger count;

- (HKHealthStore *)sharedHealthStore {
    __strong static HKHealthStore *store = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [[HKHealthStore alloc] init];
    });

    return store;
}

- (void)applicationDidEnterBackground:(UIApplication *)application{
    [self scheduleProcessingTask];
}

// Borrowed from http://nshipster.com/method-swizzling/
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];

        SEL originalSelector = @selector(application:didFinishLaunchingWithOptions:);
        SEL swizzledSelector = @selector(initalizeBackgroundFetch:didFinishLaunchingWithOptions:);

        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);

        BOOL didAddMethod =
        class_addMethod(class,
                        originalSelector,
                        method_getImplementation(swizzledMethod),
                        method_getTypeEncoding(swizzledMethod));

        if (didAddMethod) {
            class_replaceMethod(class,
                                swizzledSelector,
                                method_getImplementation(originalMethod),
                                method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

-(void)scheduleProcessingTask {
    if (@available(iOS 13.0, *)) {
        NSError *error = NULL;
        // cancel existing task (if any)
        [BGTaskScheduler.sharedScheduler cancelTaskRequestWithIdentifier:taskId];
        // new task
        BGProcessingTaskRequest *request = [[BGProcessingTaskRequest alloc] initWithIdentifier:taskId];
        request.requiresNetworkConnectivity = YES;
        request.earliestBeginDate = [NSDate dateWithTimeIntervalSinceNow:UIApplicationBackgroundFetchIntervalMinimum];
        BOOL success = [[BGTaskScheduler sharedScheduler] submitTaskRequest:request error:&error];
        if (!success) {
            // Errorcodes https://stackoverflow.com/a/58224050/872051
            NSLog(@"Failed to submit request: %@", error);
        } else {
            NSLog(@"Success submit request %@", request);
            
            UNAuthorizationOptions options = UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
            
            [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:options completionHandler:^(BOOL granted, NSError * _Nullable error) {
                if (!granted) {
                    NSLog(@"User has declined notifications");
                }
            }];
        }
    }
}

- (BOOL)initalizeBackgroundFetch:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey,id> *)launchOptions{
    
    BOOL handled = [self initalizeBackgroundFetch:application didFinishLaunchingWithOptions:launchOptions];
    
    //initialize the background fetch
    if (@available(iOS 13,*)) {
        [[BGTaskScheduler sharedScheduler] registerForTaskWithIdentifier:taskId usingQueue:nil launchHandler:^(__kindof BGTask * _Nonnull task) {
            [self backgroundRetrievalAndSend];
            [task setTaskCompletedWithSuccess:true];
        }];
    }else{
        [UIApplication.sharedApplication setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    }
    NSURLSessionConfiguration* config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"BGSessionWSHealthKit"];
    config.sessionSendsLaunchEvents = true;
    config.waitsForConnectivity = true;
    config.shouldUseExtendedBackgroundIdleMode = true;
    sharedSession = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];

    return handled;
}
- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler{
    completionHandler([self backgroundRetrievalAndSend]);
}

- (UIBackgroundFetchResult)backgroundRetrievalAndSend{
    //Check userdefaults and if anything is found run the swift functions
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSArray* tasks = [defaults valueForKey:@"BackgroundTasks"];
    if (tasks.count < 1 ) {
        return UIBackgroundFetchResultNoData;
    }
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
        if (settings.authorizationStatus == UNAuthorizationStatusAuthorized && [defaults valueForKey:@"NotificationActive"]) {
            [self fireNotification:false];
        }
    }];
    count = 0;
    return [self doTask:[tasks mutableCopy] withID:0];
    
}

-(UIBackgroundFetchResult) doTask:(NSMutableArray*) tasks withID:(int) index{
    NSDictionary *task = tasks[index];
    NSNumber* function = [task valueForKey:@"function"];
    NSDate* startD = [task valueForKey:@"startDate"];
    NSDate* endD = [task valueForKey:@"endDate"];
    switch(function.intValue){
        default:{
            [self findWorkouts:startD withEndDate:endD callbackFunction:^(NSArray<NSDictionary<NSString *,id> *> * _Nullable itemList, NSString * _Nullable error) {
                if (error != nil) {
                    NSLog(@"%@", error);
                    [self doTask:tasks withID:index+1];
                    return;
                }
                NSError *errorJSON;
                NSData* jsonItemList = [NSJSONSerialization dataWithJSONObject:itemList
                                                                   options:0 // Pass 0 if you don't care about the readability of the generated string
                                                                     error:&errorJSON];
                
                [self sendPostRequest:jsonItemList];
                NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
                if (tasks.count>index+1) {
                    [tasks removeObjectAtIndex:index];
                    [defaults setValue:tasks forKey:@"BackgroundTasks"];
                    [defaults synchronize];
                    [self doTask:tasks withID:index];
                }else{
                    [tasks removeObjectAtIndex:index];
                    [defaults setValue:tasks forKey:@"BackgroundTasks"];
                    [defaults synchronize];
                    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
                        if (settings.authorizationStatus == UNAuthorizationStatusAuthorized && [defaults valueForKey:@"NotificationActive"]) {
                            [self fireNotification:true];
                        }
                    }];
                }
            }];
            return UIBackgroundFetchResultNewData;
        }
        case 1:{
            NSString* type = [task valueForKey:@"type"];
            NSString* unit = [task valueForKey:@"units"];
            [self querySampleType:type inUnits:unit withStartDate:startD withEndDate:endD callbackFunction:^(NSArray<NSDictionary<NSString *,id> *> * _Nullable itemList, NSString * _Nullable error) {
                
                if (error != nil) {
                    NSLog(@"%@", error);
                    [self doTask:tasks withID:index+1];
                    return;
                }
                NSError *errorJSON;
                NSData* jsonItemList = [NSJSONSerialization dataWithJSONObject:itemList
                                                                   options:0 // Pass 0 if you don't care about the readability of the generated string
                                                                     error:&errorJSON];
                
                [self sendPostRequest:jsonItemList];
                NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
                if (tasks.count>index+1) {
                    [tasks removeObjectAtIndex:index];
                    [defaults setValue:tasks forKey:@"BackgroundTasks"];
                    [defaults synchronize];
                    [self doTask:tasks withID:index];
                }else{
                    [tasks removeObjectAtIndex:index];
                    [defaults setValue:tasks forKey:@"BackgroundTasks"];
                    [defaults synchronize];
                    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
                        if (settings.authorizationStatus == UNAuthorizationStatusAuthorized && [defaults valueForKey:@"NotificationActive"]) {
                            [self fireNotification:true];
                        }
                    }];
                }
            }];
            return UIBackgroundFetchResultNewData;
        }
        case 2:{
            NSString* type = [task valueForKey:@"type"];
            NSArray<NSString *>* units = [task valueForKey:@"units"];
            [self queryCorrelationType:type withUnits:units[0] withStartDate:startD withEndDate:endD callbackFunction:^(NSArray<NSDictionary<NSString *,id> *> * _Nullable itemList, NSString * _Nullable error) {
                
                if (error != nil) {
                    NSLog(@"%@", error);
                    [self doTask:tasks withID:index+1];
                    return;
                }
                NSError *errorJSON;
                NSData* jsonItemList = [NSJSONSerialization dataWithJSONObject:itemList
                                                                   options:0 // Pass 0 if you don't care about the readability of the generated string
                                                                     error:&errorJSON];
                
                [self sendPostRequest:jsonItemList];
                NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
                if (tasks.count>index+1) {
                    [tasks removeObjectAtIndex:index];
                    [defaults setValue:tasks forKey:@"BackgroundTasks"];
                    [defaults synchronize];
                    [self doTask:tasks withID:index];
                }else{
                    [tasks removeObjectAtIndex:index];
                    [defaults setValue:tasks forKey:@"BackgroundTasks"];
                    [defaults synchronize];
                    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
                        if (settings.authorizationStatus == UNAuthorizationStatusAuthorized && [defaults valueForKey:@"NotificationActive"]) {
                            [self fireNotification:true];
                        }
                    }];
                }
            }];
            return UIBackgroundFetchResultNewData;
        }
    }
}

-(void) sendPostRequest:(NSData*)body{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    
    NSString* url = [defaults valueForKey:@"url"];
    if (url == nil) {
        return;
    }
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]];

    [urlRequest setHTTPMethod:@"POST"];
    
    NSArray* headers = [defaults valueForKey:@"headers"];
    for (NSDictionary* header in headers) {
        [urlRequest setValue:[header valueForKey:@"Value"] forHTTPHeaderField:[header valueForKey:@"Key"]];
    }
    
    NSURL* tempDir = NSFileManager.defaultManager.temporaryDirectory;
    count = count + 1;
    NSURL* localURL = [tempDir URLByAppendingPathComponent:[NSString stringWithFormat:@"throwaway%lu.json",(unsigned long)count] isDirectory:false];
    [body writeToURL:localURL atomically:true];
    
    NSURLSessionUploadTask *task = [sharedSession uploadTaskWithRequest:urlRequest fromFile:localURL];
    [task resume];
}

-(void) fireNotification:(BOOL) isCompleted{
    // Create Notification Content
    UNMutableNotificationContent * notificationContent = [[UNMutableNotificationContent alloc] init];
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    // Configure Notification Content
    notificationContent.title = [defaults valueForKey:@"NotificationTitle"];
    if (isCompleted) {
        notificationContent.body = [defaults valueForKey:@"NotificationContentCompleted"];
    }else{
        notificationContent.body = [defaults valueForKey:@"NotificationContentRunning"];
    }
    // Add Trigger
    UNTimeIntervalNotificationTrigger *notificationTrigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1.0 repeats:false];
    
    // Create Notification Request
    UNNotificationRequest* notificationRequest = [UNNotificationRequest requestWithIdentifier:@"local_notification_background" content:notificationContent trigger:notificationTrigger];
    
    // Add Request to User Notification Center
    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:notificationRequest withCompletionHandler:^(NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"Unable to Add Notification Request (\(error), \(error.localizedDescription))");
        }
    }];
}


- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    if (error != nil) {
        NSLog(@"Information retrieved in background failed to be sent to webservice!");
        NSLog(@"%@",error.localizedDescription);
    }
}

- (HKSampleType *)getHKSampleType:(NSString *)elem {
    
    HKSampleType *type = nil;

    type = [HKObjectType quantityTypeForIdentifier:elem];
    if (type != nil) {
        return type;
    }

    type = [HKObjectType categoryTypeForIdentifier:elem];
    if (type != nil) {
        return type;
    }

    type = [HKObjectType correlationTypeForIdentifier:elem];
    if (type != nil) {
        return type;
    }

    if ([elem isEqualToString:@"workoutType"]) {
        return [HKObjectType workoutType];
    }
    
    if (@available(iOS 11.0, *)) {
        type = [HKObjectType seriesTypeForIdentifier:elem];
        if (type != nil) {
            return type;
        } else {
            // Fallback on earlier versions
        }
    }

    // leave this here for if/when apple adds other sample types
    return type;

}
- (NSString *)stringFromDate:(NSDate *)date {
    __strong static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
        [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
    });

    return [formatter stringFromDate:date];
}

- (NSString*) convertHKWorkoutActivityTypeToString:(HKWorkoutActivityType) which {
  switch(which) {
    case HKWorkoutActivityTypeAmericanFootball:
      return @"HKWorkoutActivityTypeAmericanFootball";
    case HKWorkoutActivityTypeArchery:
      return @"HKWorkoutActivityTypeArchery";
    case HKWorkoutActivityTypeAustralianFootball:
      return @"HKWorkoutActivityTypeAustralianFootball";
    case HKWorkoutActivityTypeBadminton:
      return @"HKWorkoutActivityTypeBadminton";
    case HKWorkoutActivityTypeBaseball:
      return @"HKWorkoutActivityTypeBaseball";
    case HKWorkoutActivityTypeBasketball:
      return @"HKWorkoutActivityTypeBasketball";
    case HKWorkoutActivityTypeBowling:
      return @"HKWorkoutActivityTypeBowling";
    case HKWorkoutActivityTypeBoxing:
      return @"HKWorkoutActivityTypeBoxing";
    case HKWorkoutActivityTypeClimbing:
      return @"HKWorkoutActivityTypeClimbing";
    case HKWorkoutActivityTypeCricket:
      return @"HKWorkoutActivityTypeCricket";
    case HKWorkoutActivityTypeCrossTraining:
      return @"HKWorkoutActivityTypeCrossTraining";
    case HKWorkoutActivityTypeCurling:
      return @"HKWorkoutActivityTypeCurling";
    case HKWorkoutActivityTypeCycling:
      return @"HKWorkoutActivityTypeCycling";
    case HKWorkoutActivityTypeDance:
      return @"HKWorkoutActivityTypeDance";
    case HKWorkoutActivityTypeDanceInspiredTraining:
      return @"HKWorkoutActivityTypeDanceInspiredTraining";
    case HKWorkoutActivityTypeElliptical:
      return @"HKWorkoutActivityTypeElliptical";
    case HKWorkoutActivityTypeEquestrianSports:
      return @"HKWorkoutActivityTypeEquestrianSports";
    case HKWorkoutActivityTypeFencing:
      return @"HKWorkoutActivityTypeFencing";
    case HKWorkoutActivityTypeFishing:
      return @"HKWorkoutActivityTypeFishing";
    case HKWorkoutActivityTypeFunctionalStrengthTraining:
      return @"HKWorkoutActivityTypeFunctionalStrengthTraining";
    case HKWorkoutActivityTypeGolf:
      return @"HKWorkoutActivityTypeGolf";
    case HKWorkoutActivityTypeGymnastics:
      return @"HKWorkoutActivityTypeGymnastics";
    case HKWorkoutActivityTypeHandball:
      return @"HKWorkoutActivityTypeHandball";
    case HKWorkoutActivityTypeHiking:
      return @"HKWorkoutActivityTypeHiking";
    case HKWorkoutActivityTypeHockey:
      return @"HKWorkoutActivityTypeHockey";
    case HKWorkoutActivityTypeHunting:
      return @"HKWorkoutActivityTypeHunting";
    case HKWorkoutActivityTypeLacrosse:
      return @"HKWorkoutActivityTypeLacrosse";
    case HKWorkoutActivityTypeMartialArts:
      return @"HKWorkoutActivityTypeMartialArts";
    case HKWorkoutActivityTypeMindAndBody:
      return @"HKWorkoutActivityTypeMindAndBody";
    case HKWorkoutActivityTypeMixedMetabolicCardioTraining:
      return @"HKWorkoutActivityTypeMixedMetabolicCardioTraining";
    case HKWorkoutActivityTypePaddleSports:
      return @"HKWorkoutActivityTypePaddleSports";
    case HKWorkoutActivityTypePlay:
      return @"HKWorkoutActivityTypePlay";
    case HKWorkoutActivityTypePreparationAndRecovery:
      return @"HKWorkoutActivityTypePreparationAndRecovery";
    case HKWorkoutActivityTypeRacquetball:
      return @"HKWorkoutActivityTypeRacquetball";
    case HKWorkoutActivityTypeRowing:
      return @"HKWorkoutActivityTypeRowing";
    case HKWorkoutActivityTypeRugby:
      return @"HKWorkoutActivityTypeRugby";
    case HKWorkoutActivityTypeRunning:
      return @"HKWorkoutActivityTypeRunning";
    case HKWorkoutActivityTypeSailing:
      return @"HKWorkoutActivityTypeSailing";
    case HKWorkoutActivityTypeSkatingSports:
      return @"HKWorkoutActivityTypeSkatingSports";
    case HKWorkoutActivityTypeSnowSports:
      return @"HKWorkoutActivityTypeSnowSports";
    case HKWorkoutActivityTypeSoccer:
      return @"HKWorkoutActivityTypeSoccer";
    case HKWorkoutActivityTypeSoftball:
      return @"HKWorkoutActivityTypeSoftball";
    case HKWorkoutActivityTypeSquash:
      return @"HKWorkoutActivityTypeSquash";
    case HKWorkoutActivityTypeStairClimbing:
      return @"HKWorkoutActivityTypeStairClimbing";
    case HKWorkoutActivityTypeSurfingSports:
      return @"HKWorkoutActivityTypeSurfingSports";
    case HKWorkoutActivityTypeSwimming:
      return @"HKWorkoutActivityTypeSwimming";
    case HKWorkoutActivityTypeTableTennis:
      return @"HKWorkoutActivityTypeTableTennis";
    case HKWorkoutActivityTypeTennis:
      return @"HKWorkoutActivityTypeTennis";
    case HKWorkoutActivityTypeTrackAndField:
      return @"HKWorkoutActivityTypeTrackAndField";
    case HKWorkoutActivityTypeTraditionalStrengthTraining:
      return @"HKWorkoutActivityTypeTraditionalStrengthTraining";
    case HKWorkoutActivityTypeVolleyball:
      return @"HKWorkoutActivityTypeVolleyball";
    case HKWorkoutActivityTypeWalking:
      return @"HKWorkoutActivityTypeWalking";
    case HKWorkoutActivityTypeWaterFitness:
      return @"HKWorkoutActivityTypeWaterFitness";
    case HKWorkoutActivityTypeWaterPolo:
      return @"HKWorkoutActivityTypeWaterPolo";
    case HKWorkoutActivityTypeWaterSports:
      return @"HKWorkoutActivityTypeWaterSports";
    case HKWorkoutActivityTypeWrestling:
      return @"HKWorkoutActivityTypeWrestling";
    case HKWorkoutActivityTypeYoga:
      return @"HKWorkoutActivityTypeYoga";
    case HKWorkoutActivityTypeOther:
      return @"HKWorkoutActivityTypeOther";
    default:
      return @"unknown";
  }
}

- (void)findWorkouts:(NSDate*) startD withEndDate:(NSDate*)endD callbackFunction:(void (^)(NSArray<NSDictionary<NSString *,id> *> * _Nullable itemList, NSString * _Nullable error)) callbackFunction{
    
    NSPredicate *workoutPredicate = [HKQuery predicateForSamplesWithStartDate:startD endDate:endD options:HKQueryOptionStrictEndDate];
    
    NSSet *types = [NSSet setWithObjects:[HKWorkoutType workoutType], nil];
    [[self sharedHealthStore] requestAuthorizationToShareTypes:nil readTypes:types completion:^(BOOL success, NSError * _Nullable error) {
        if (!success) {
            NSLog(@"%@", error.localizedDescription);
            callbackFunction(nil, error.localizedDescription);
        } else {
            HKSampleQuery *query = [[HKSampleQuery alloc] initWithSampleType:[HKWorkoutType workoutType] predicate:workoutPredicate limit:HKObjectQueryNoLimit sortDescriptors:nil resultsHandler:^(HKSampleQuery *sampleQuery, NSArray *results, NSError *innerError) {
                if (innerError) {
                    NSLog(@"%@", innerError.localizedDescription);
                    callbackFunction(nil, innerError.localizedDescription);
                } else {
                    NSMutableArray *finalResults = [[NSMutableArray alloc] initWithCapacity:results.count];

                    for (HKWorkout *workout in results) {
                        NSString *workoutActivity = [self convertHKWorkoutActivityTypeToString:workout.workoutActivityType];


                        // TODO: use a float value, or switch to metric
                        double miles = [workout.totalDistance doubleValueForUnit:[HKUnit mileUnit]];
                        miles = round(miles*100.0)/100.0;
                        NSString *milesString = [NSString stringWithFormat:@"%ld", (long) miles];

                        NSEnergyFormatter *energyFormatter = [NSEnergyFormatter new];
                        energyFormatter.forFoodEnergyUse = NO;
                        double joules = [workout.totalEnergyBurned doubleValueForUnit:[HKUnit jouleUnit]];
                        joules = round(joules*100.0)/100.0;
                        NSString *calories = [energyFormatter stringFromJoules:joules];
                        
                        NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
                        NSMutableDictionary *entry = [
                                @{
                                    @"duration": [formatter stringFromTimeInterval:workout.duration],
                                    @"startDate": [self stringFromDate:workout.startDate],
                                    @"endDate": [self stringFromDate:workout.endDate],
                                    @"distance": milesString,
                                    @"energy": calories,
                                    @"Source":@{
                                        @"OS":[NSString stringWithFormat:@"%ld.%ld.%ld",(long)workout.sourceRevision.operatingSystemVersion.majorVersion,(long)workout.sourceRevision.operatingSystemVersion.minorVersion,(long)workout.sourceRevision.operatingSystemVersion.patchVersion],
                                        @"Device": workout.sourceRevision.productType,
                                        @"BundleID": workout.sourceRevision.source.bundleIdentifier,
                                        @"Name": workout.sourceRevision.source.name
                                    },
                                    @"activityType": workoutActivity
                                } mutableCopy
                        ];

                        [finalResults addObject:entry];
                    }
                    callbackFunction(finalResults,nil);
                }
            }];
            [[self sharedHealthStore] executeQuery:query];
        }
    }];
}

- (void)querySampleType:(NSString*) sampleTypeString inUnits:(NSString*) unitString withStartDate:(NSDate*) startD withEndDate:(NSDate*)endD callbackFunction:(void (^)(NSArray<NSDictionary<NSString *,id> *> * _Nullable itemList, NSString * _Nullable error)) callbackFunction{
    
    NSPredicate *predicate = [HKQuery predicateForSamplesWithStartDate:startD endDate:endD options:HKQueryOptionStrictEndDate];
    
    HKSampleType *type = [self getHKSampleType:sampleTypeString];
    HKUnit *unit = nil;
    if (unitString != nil) {
        if ([unitString isEqualToString:@"mmol/L"]) {
            // @see https://stackoverflow.com/a/30196642/1214598
            unit = [[HKUnit moleUnitWithMetricPrefix:HKMetricPrefixMilli molarMass:HKUnitMolarMassBloodGlucose] unitDividedByUnit:HKUnit.literUnit];
        } else if ([unitString isEqualToString:@"m/s"]){
            unit = [HKUnit.meterUnit unitDividedByUnit:HKUnit.secondUnit];
        }else {
            // issue 51
            // @see https://github.com/Telerik-Verified-Plugins/HealthKit/issues/51
            if ([unitString isEqualToString:@"percent"]) {
                unit = [HKUnit unitFromString:@"%"];
            }else{
                unit = [HKUnit unitFromString:unitString];
            }
        }
        
    }
    
    NSSet *types = [NSSet setWithObjects:type, nil];
    [[self sharedHealthStore] requestAuthorizationToShareTypes:nil readTypes:types completion:^(BOOL success, NSError * _Nullable error) {
        if (!success) {
            NSLog(@"%@", error.localizedDescription);
            callbackFunction(nil, error.localizedDescription);
        } else {
            NSSortDescriptor *endDateSort = [NSSortDescriptor sortDescriptorWithKey:HKSampleSortIdentifierEndDate ascending:false];
            HKSampleQuery *query = [[HKSampleQuery alloc] initWithSampleType:type predicate:predicate limit:HKObjectQueryNoLimit sortDescriptors:@[endDateSort] resultsHandler:^(HKSampleQuery *sampleQuery, NSArray *results, NSError *innerError) {
                if (innerError) {
                    NSLog(@"%@", innerError.localizedDescription);
                    callbackFunction(nil, innerError.localizedDescription);
                } else {
                    NSMutableArray *finalResults = [[NSMutableArray alloc] initWithCapacity:results.count];

                    for (HKSample *sample in results) {

                        NSMutableDictionary *entry = [
                                @{
                                    @"startDate": [self stringFromDate:sample.startDate],
                                    @"endDate": [self stringFromDate:sample.endDate],
                                    @"Source":@{
                                        @"OS":[NSString stringWithFormat:@"%ld.%ld.%ld",(long)sample.sourceRevision.operatingSystemVersion.majorVersion,(long)sample.sourceRevision.operatingSystemVersion.minorVersion,(long)sample.sourceRevision.operatingSystemVersion.patchVersion],
                                        @"Device": sample.sourceRevision.productType,
                                        @"BundleID": sample.sourceRevision.source.bundleIdentifier,
                                        @"Name": sample.sourceRevision.source.name
                                    },
                                } mutableCopy
                        ];

                          // case-specific indices
                          if ([sample isKindOfClass:[HKCategorySample class]]) {

                              HKCategorySample *csample = (HKCategorySample *) sample;
                              entry[@"value"] = @(csample.value);

                          } else if ([sample isKindOfClass:[HKCorrelationType class]]) {

                              HKCorrelation *correlation = (HKCorrelation *) sample;
                              entry[@"value"] = correlation.correlationType.identifier;

                          } else if ([sample isKindOfClass:[HKQuantitySample class]]) {

                              HKQuantitySample *qsample = (HKQuantitySample *) sample;
                              double quantity = [qsample.quantity doubleValueForUnit:unit];
                              quantity = round(quantity*100.0)/100.0;
                              [entry setValue:@(quantity) forKey:@"value"];

                          }

                        [finalResults addObject:entry];
                    }
                    callbackFunction(finalResults,nil);
                }
            }];
            [[self sharedHealthStore] executeQuery:query];
        }
    }];
}

- (void)queryCorrelationType:(NSString*) typeString withUnits:(NSString*) unitString withStartDate:(NSDate*) startD withEndDate:(NSDate*)endD callbackFunction:(void (^)(NSArray<NSDictionary<NSString *,id> *> * _Nullable itemList, NSString * _Nullable error)) callbackFunction{
    
    NSPredicate *predicate = [HKQuery predicateForSamplesWithStartDate:startD endDate:endD options:HKQueryOptionStrictEndDate];
    
    HKCorrelationType *type = (HKCorrelationType *) [self getHKSampleType:typeString];
    
    HKUnit *unit = ((unitString != nil) ? [HKUnit unitFromString:unitString] : nil);
    
    NSSet *types = [NSSet setWithObjects:type, nil];
    NSSet<HKObjectType *> *requestTypes = [[NSSet alloc] initWithArray:@[[HKCorrelationType quantityTypeForIdentifier:HKQuantityTypeIdentifierBloodPressureDiastolic],[HKCorrelationType quantityTypeForIdentifier:HKQuantityTypeIdentifierBloodPressureSystolic]]];
    
    [[self sharedHealthStore] requestAuthorizationToShareTypes:nil readTypes:requestTypes completion:^(BOOL success, NSError * _Nullable error) {
        if (!success) {
            NSLog(@"%@", error.localizedDescription);
            callbackFunction(nil, error.localizedDescription);
        } else {
            HKCorrelationQuery *query = [[HKCorrelationQuery alloc] initWithType:type predicate:predicate samplePredicates:nil completion:^(HKCorrelationQuery *sampleQuery, NSArray *results, NSError *innerError) {
                if (innerError) {
                    NSLog(@"%@", innerError.localizedDescription);
                    callbackFunction(nil, innerError.localizedDescription);
                } else {
                    NSMutableArray *finalResults = [[NSMutableArray alloc] initWithCapacity:results.count];

                    for (HKSample *sample in results) {

                        NSMutableDictionary *entry = [
                                @{
                                    @"startDate": [self stringFromDate:sample.startDate],
                                    @"endDate": [self stringFromDate:sample.endDate],
                                    @"Source":@{
                                        @"OS":[NSString stringWithFormat:@"%ld.%ld.%ld",(long)sample.sourceRevision.operatingSystemVersion.majorVersion,(long)sample.sourceRevision.operatingSystemVersion.minorVersion,(long)sample.sourceRevision.operatingSystemVersion.patchVersion],
                                        @"Device": sample.sourceRevision.productType,
                                        @"BundleID": sample.sourceRevision.source.bundleIdentifier,
                                        @"Name": sample.sourceRevision.source.name
                                    },
                                } mutableCopy
                        ];
                        
                        
                        HKCorrelation* correlation = (HKCorrelation*)sample;
                        
                        NSMutableArray* items = [[NSMutableArray alloc] init];
                        
                        NSMutableDictionary *item = [[NSMutableDictionary alloc] init];
                        
                        NSSet<HKQuantitySample*>* correlationObj = correlation.objects;
                        for (HKQuantitySample* quantitysample in correlationObj) {
                            item[@"type"] = [quantitysample.sampleType identifier];
                            double quantity = [quantitysample.quantity doubleValueForUnit:unit];
                            quantity = round(quantity*100)/100;
                            item[@"value"] = @(quantity);
                            [items addObject:item];
                        }
                        entry[@"samples"] = items;

                        [finalResults addObject:entry];
                    }
                    callbackFunction(finalResults,nil);
                }
            }];
            [[self sharedHealthStore] executeQuery:query];
        }
    }];
}

@end
