//
//  AppDelegate+HealthFitness.m
//
//  Created by Luis Bouça on 25/10/2022.
//


#import "AppDelegate+HealthFitness.h"
#import "Outsystems-Swift.h"
#import <BackgroundTasks/BackgroundTasks.h>
#import <UserNotifications/UserNotifications.h>

@implementation AppDelegate(AppDelegateHealthFitness)

static NSString* taskId = @"com.outsystems.health.custom";
NSURLSession* sharedSession;
NSUInteger count;

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
        request.earliestBeginDate = [NSDate dateWithTimeIntervalSinceNow:5];
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
    sharedSession = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    NSArray* jsonS = [defaults valueForKey:@"JSONs"];
    
    if( jsonS != nil){
        NSString* url = [defaults valueForKey:@"url"];
        if (url == nil) {
            return handled;
        }
        for(NSData* body in jsonS) {
                
            NSURL* urlR =[NSURL URLWithString:url];
            NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:urlR];
            
            //create the Method "GET" or "POST"
            [urlRequest setHTTPMethod:@"POST"];
            
            NSArray* headers = [defaults valueForKey:@"headers"];
            for (NSDictionary* header in headers) {
                [urlRequest setValue:[header valueForKey:@"Value"] forHTTPHeaderField:[header valueForKey:@"Key"]];
            }
            
            [urlRequest setHTTPBody:body];
            NSURLSession *session = [NSURLSession sharedSession];
            NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (error != nil) {
                    NSLog(@"Information retrieved in background failed to be sent to webservice!");
                    NSLog(@"%@",error.localizedDescription);
                }
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                if(httpResponse.statusCode != 200)
                {
                    NSLog(@"Information retrieved in background failed to be sent to webservice!");
                }
            }];
            [dataTask resume];
        }
    }
    jsonS = [[NSArray alloc]init];
    [defaults setValue:jsonS forKey:@"JSONs"];
    [defaults synchronize];
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
    count = tasks.count;
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
        if (settings.authorizationStatus == UNAuthorizationStatusAuthorized && [defaults valueForKey:@"NotificationActive"]) {
            [self fireNotification:false];
        }
    }];
    
    OSHealthFitness* pluginInstance = [self.viewController getCommandInstance:@"OSHealthFitness"];
    [defaults setValue:[[NSArray alloc]init] forKey:@"BackgroundTasks"];
    for (NSDictionary* task in tasks) {
        NSNumber* function = [task valueForKey:@"function"];
        NSDate* startD = [task valueForKey:@"startDate"];
        NSDate* endD = [task valueForKey:@"endDate"];
        switch(function.intValue){
            default:{
                [pluginInstance findWorkouts:startD withEndDate:endD callbackFunction:^(NSArray<NSDictionary<NSString *,id> *> * _Nullable itemList, NSString * _Nullable error) {
                    count = count -1;
                    if (error != nil) {
                        return;
                    }
                    NSError *errorJSON;
                    NSData* jsonItemList = [NSJSONSerialization dataWithJSONObject:itemList
                                                                       options:0 // Pass 0 if you don't care about the readability of the generated string
                                                                         error:&errorJSON];
                    NSArray* jsons = [defaults valueForKey:@"JSONs"];
                    if (jsons == nil) {
                        jsons = [[NSArray alloc] init];
                    }
                    jsons = [jsons arrayByAddingObject:jsonItemList];
                    [defaults setValue:jsons forKey:@"JSONs"];
                    [defaults synchronize];
                    if (count < 1) {
                        [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
                            if (settings.authorizationStatus == UNAuthorizationStatusAuthorized && [defaults valueForKey:@"NotificationActive"]) {
                                [self fireNotification:true];
                            }
                        }];
                        [defaults setBool:true forKey:@"HDUCompleted"];
                        
                        NSDate* currentDate = [NSDate date];
                        
                        NSDateFormatter * dateFormatter = [[NSDateFormatter alloc] init];
                        NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
                        [dateFormatter setTimeZone:timeZone];
                        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:SS.SSS'Z'"];
                        
                        NSString* currentDateString = [dateFormatter stringFromDate:currentDate];
                        
                        [defaults setValue:currentDateString forKey:@"HDUDate"];
                        [defaults synchronize];
                    }
                }];
                break;
            }
            case 1:{
                NSString* type = [task valueForKey:@"type"];
                NSString* unit = [task valueForKey:@"unit"];
                [pluginInstance querySampleType:type inUnits:unit withStartDate:startD withEndDate:endD callbackFunction:^(NSArray<NSDictionary<NSString *,id> *> * _Nullable itemList, NSString * _Nullable error) {
                    
                    count = count -1;
                    if (error != nil) {
                        return;
                    }
                    NSError *errorJSON;
                    NSData* jsonItemList = [NSJSONSerialization dataWithJSONObject:itemList
                                                                       options:0 // Pass 0 if you don't care about the readability of the generated string
                                                                         error:&errorJSON];
                    NSArray* jsons = [defaults valueForKey:@"JSONs"];
                    if (jsons == nil) {
                        jsons = [[NSArray alloc] init];
                    }
                    jsons = [jsons arrayByAddingObject:jsonItemList];
                    [defaults setValue:jsons forKey:@"JSONs"];
                    [defaults synchronize];
                    if (count < 1) {
                        [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
                            if (settings.authorizationStatus == UNAuthorizationStatusAuthorized && [defaults valueForKey:@"NotificationActive"]) {
                                [self fireNotification:true];
                            }
                        }];
                        [defaults setBool:true forKey:@"HDUCompleted"];
                        
                        NSDate* currentDate = [NSDate date];
                        
                        NSDateFormatter * dateFormatter = [[NSDateFormatter alloc] init];
                        NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
                        [dateFormatter setTimeZone:timeZone];
                        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:SS.SSS'Z'"];
                        
                        NSString* currentDateString = [dateFormatter stringFromDate:currentDate];
                        
                        [defaults setValue:currentDateString forKey:@"HDUDate"];
                        [defaults synchronize];
                    }
                }];
                break;
            }
            case 2:{
                NSString* type = [task valueForKey:@"type"];
                NSArray<NSString *>* units = [task valueForKey:@"units"];
                [pluginInstance queryCorrelationType:type withUnits:units withStartDate:startD withEndDate:endD callbackFunction:^(NSArray<NSDictionary<NSString *,id> *> * _Nullable itemList, NSString * _Nullable error) {
                    
                    count = count -1;
                    if (error != nil) {
                        return;
                    }
                    NSError *errorJSON;
                    NSData* jsonItemList = [NSJSONSerialization dataWithJSONObject:itemList
                                                                       options:0 // Pass 0 if you don't care about the readability of the generated string
                                                                         error:&errorJSON];
                    NSArray* jsons = [defaults valueForKey:@"JSONs"];
                    if (jsons == nil) {
                        jsons = [[NSArray alloc] init];
                    }
                    jsons = [jsons arrayByAddingObject:jsonItemList];
                    [defaults setValue:jsons forKey:@"JSONs"];
                    [defaults synchronize];
                    if (count < 1) {
                        [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
                            if (settings.authorizationStatus == UNAuthorizationStatusAuthorized && [defaults valueForKey:@"NotificationActive"]) {
                                [self fireNotification:true];
                            }
                        }];
                        [defaults setBool:true forKey:@"HDUCompleted"];
                        
                        NSDate* currentDate = [NSDate date];
                        
                        NSDateFormatter * dateFormatter = [[NSDateFormatter alloc] init];
                        NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
                        [dateFormatter setTimeZone:timeZone];
                        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:SS.SSS'Z'"];
                        
                        NSString* currentDateString = [dateFormatter stringFromDate:currentDate];
                        
                        [defaults setValue:currentDateString forKey:@"HDUDate"];
                        [defaults synchronize];
                    }
                }];
                break;
            }
        }
    }
    
    return UIBackgroundFetchResultNewData;
    
}
-(void) sendPostRequest:(NSData*)body{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    
    NSString* url = [defaults valueForKey:@"url"];
    if (url == nil) {
        return;
    }
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]];

    //create the Method "GET" or "POST"
    [urlRequest setHTTPMethod:@"POST"];
    
    NSArray* headers = [defaults valueForKey:@"headers"];
    for (NSDictionary* header in headers) {
        [urlRequest setValue:[header valueForKey:@"Value"] forHTTPHeaderField:[header valueForKey:@"Key"]];
    }
    
    NSURL* tempDir = NSFileManager.defaultManager.temporaryDirectory;
    NSURL* localURL = [tempDir URLByAppendingPathComponent:@"throwaway" isDirectory:true];
    [body writeToURL:localURL atomically:true];
    [urlRequest setHTTPBody:body];
    
    /*NSURLSessionDataTask *dataTask = [sharedSession dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if(httpResponse.statusCode != 200)
        {
            NSLog(@"Information retrieved in background failed to be sent to webservice!");
        }
    }];
    [dataTask resume];*/
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
        NSLog(@"Information retrieved in background failed to be sent to webservice!");;
    }
    NSLog(@"Information retrieved in background completed!");;
}

@end
