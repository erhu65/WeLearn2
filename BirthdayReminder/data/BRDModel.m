//
//  BRDModel.m
//  BirthdayReminder
//
//  Created by Nick Kuh on 26/07/2012.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//

#import "BRDModel.h"
#import "BRDBirthday.h"
#import "BRDBirthdayImport.h"
#import "BRRecordMainCategory.h"
#import "BRRecordSubCategory.h"
#import "BRRecordVideo.h"
#import "BRDSettings.h"
#import <AddressBook/AddressBook.h>
#import <Social/Social.h>
#import <Accounts/Accounts.h>

typedef enum : int
{
    FacebookActionGetFriendsBirthdays = 1,
    FacebookActionPostToWall,
    FacebookActionGetMe
}FacebookAction;

@interface BRDModel()

@property (nonatomic, strong) ACAccount* facebookAccount;
@property FacebookAction currentFacebookAction;
@property (nonatomic,strong) NSString *postToFacebookMessage;
@property (nonatomic,strong) NSString *postToFacebookID;

@end

@implementation BRDModel
{
    
    
}

static BRDModel *_sharedInstance = nil;
+ (BRDModel*)sharedInstance
{
    if( !_sharedInstance ) {
		_sharedInstance = [[BRDModel alloc] init];
	}
	return _sharedInstance;
}

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

-(ACAccount*)facebookAccount{
    if(nil == _facebookAccount){
        [self authenticateWithFacebook];
    }
    return _facebookAccount;
}

-(NSMutableArray*)mainCategories{
    
    if(!_mainCategories){
        _mainCategories = [NSMutableArray array];
    }
    return _mainCategories;
}

-(NSMutableArray*)subCategories{
    
    if(!_subCategories){
        _subCategories = [NSMutableArray array];
    }
    return _subCategories;
}


-(void) extractBirthdaysFromAddressBook:(ABAddressBookRef)addressBook
{
    NSLog(@"extractBirthdaysFromAddressBook");
    CFArrayRef people = ABAddressBookCopyArrayOfAllPeople(addressBook);
    
    CFIndex peopleCount = ABAddressBookGetPersonCount(addressBook);
    
    BRDBirthdayImport *birthday;
    
    //this is just a placeholder for now - we'll get the array populated later in the chapter
    NSMutableArray *birthdays = [NSMutableArray array];
    
    for (int i = 0; i < peopleCount; i++)
    {
        ABRecordRef addressBookRecord = CFArrayGetValueAtIndex(people, i);
        CFDateRef birthdate  = ABRecordCopyValue(addressBookRecord, kABPersonBirthdayProperty);
        if (birthdate == nil) continue;
        CFStringRef firstName = ABRecordCopyValue(addressBookRecord, kABPersonFirstNameProperty);
        if (firstName == nil) {
            CFRelease(birthdate);
            continue;
        }
        NSLog(@"Found contact with birthday: %@, %@",firstName,birthdate);
        
        birthday = [[BRDBirthdayImport alloc] initWithAddressBookRecord:addressBookRecord];
        [birthdays addObject: birthday];
        
        CFRelease(firstName);
        CFRelease(birthdate);
    }
    
    CFRelease(people);
    
    //order the birthdays alphabetically by name
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    [birthdays sortUsingDescriptors:sortDescriptors];
    
    
    //dispatch a notification with an array of birthday objects
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:birthdays,@"birthdays", nil];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationAddressBookBirthdaysDidUpdate object:self userInfo:userInfo];
}

- (void)fetchAddressBookBirthdays
{
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, NULL);
    
    switch (ABAddressBookGetAuthorizationStatus()) {
        case kABAuthorizationStatusNotDetermined:
        {
            ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
                if (granted) {
                    NSLog(@"Access to the Address Book has been granted");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // completion handler can occur in a background thread and this call will update the UI on the main thread
                        [self extractBirthdaysFromAddressBook:ABAddressBookCreateWithOptions(NULL, NULL)];
                    });
                }
                else {
                    NSLog(@"Access to the Address Book has been denied");
                }
            });
            break;
        }
        case kABAuthorizationStatusAuthorized:
        {
            NSLog(@"User has already granted access to the Address Book");
            [self extractBirthdaysFromAddressBook:addressBook];
            break;
        }
        case kABAuthorizationStatusRestricted:
        {
            NSLog(@"User has restricted access to Address Book possibly due to parental controls");
            break;
        }
        case kABAuthorizationStatusDenied:
        {
            NSLog(@"User has denied access to the Address Book");
            break;
        }
    }
    
    CFRelease(addressBook);
}



- (void)fetchFacebookBirthdays
{
    NSLog(@"fetchFacebookBirthdays");
    
    if (self.facebookAccount == nil) {
        self.currentFacebookAction = FacebookActionGetFriendsBirthdays;
        [self authenticateWithFacebook];
        return;
    }
    
    //We've got an authenticated Facebook Account if the code executes here
    NSURL *requestURL = [NSURL URLWithString:@"https://graph.facebook.com/me/friends"];
    NSDictionary *params = @{@"fields" : @"name,id,birthday"};
    
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeFacebook requestMethod:SLRequestMethodGET URL:requestURL parameters:params];
    
    request.account = self.facebookAccount;
    
    [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        if (error != nil) {
            NSLog(@"Error getting my Facebook friend birthdays: %@",error);
        }
        else
        {
            // Facebook's me/friends Graph API returns a root dictionary
            NSDictionary *resultD = (NSDictionary *) [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
            NSLog(@"Facebook returned friends: %@",resultD);
            // with a 'data' key - an array of Facebook friend dictionaries
            NSArray *birthdayDictionaries = resultD[@"data"];
            
            int birthdayCount = [birthdayDictionaries count];
            NSDictionary *facebookDictionary;
            
            NSMutableArray *birthdays = [NSMutableArray array];
            BRDBirthdayImport *birthday;
            NSString *birthDateS;
            
            for (int i = 0; i < birthdayCount; i++)
            {
                facebookDictionary = birthdayDictionaries[i];
                birthDateS = facebookDictionary[@"birthday"];
                if (!birthDateS) continue;
                //create an instance of BRDBirthdayImport
                NSLog(@"Found a Facebook Birthday: %@",facebookDictionary);
                birthday = [[BRDBirthdayImport alloc] initWithFacebookDictionary:facebookDictionary];
                [birthdays addObject: birthday];
            }
            
            //Order the birthdays by name
            NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
            NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
            [birthdays sortUsingDescriptors:sortDescriptors];
            
            dispatch_sync(dispatch_get_main_queue(), ^{
                //update the view on the main thread
                NSDictionary *userInfo = @{@"birthdays":birthdays};
                [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationFacebookBirthdaysDidUpdate object:self userInfo:userInfo];
            });
        }
    }];
}


- (void)fetchFacebookMe
{    
    
    if(nil != self.fbMe){
        [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationFacebookMeDidUpdate object:self userInfo:nil];
        return;
    }
    
    if (self.facebookAccount == nil) {
        self.currentFacebookAction = FacebookActionGetMe;
        [self authenticateWithFacebook];
        return;
    }
    
    //We've got an authenticated Facebook Account if the code executes here
    NSURL *requestURL = [NSURL URLWithString:@"https://graph.facebook.com/me"];
    NSDictionary *params = @{@"fields" : @"name,id,birthday"};
    
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeFacebook requestMethod:SLRequestMethodGET URL:requestURL parameters:params];
    
    request.account = self.facebookAccount;
    __block NSDictionary *resultD;
    __weak __block BRDModel *weakSelf = self;
    [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        if (error != nil) {
            NSLog(@"Error getting my Facebook friend birthdays: %@",error);
        }
        else
        {
            // Facebook's me/friends Graph API returns a root dictionary
            resultD = (NSDictionary *) [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
            weakSelf.fbMe = resultD;
            weakSelf.fbName = [resultD objectForKey:@"name"];
            weakSelf.fbId = [resultD objectForKey:@"id"];
            PRPLog(@"Facebook returned friends: %@ -[%@ , %@]",
                   resultD,
                   NSStringFromClass([self class]),
                   NSStringFromSelector(_cmd));
            
            dispatch_sync(dispatch_get_main_queue(), ^{
//                //update the view on the main thread
                NSDictionary *userInfo = @{@"FacebookMe":resultD};
                [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationFacebookMeDidUpdate object:self userInfo:userInfo];
            });
        }
    }];
}


#pragma mark mainCategories
- (void)fetchMainCategoriesWithPage:(NSNumber*)page{
    
    //[self.mainCategories removeAllObjects];
    
    dispatch_queue_t concurrentQueue = 
    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    /* If we have not already saved an array of 10,000
     random numbers to the disk before, generate these numbers now
     and then save them to the disk in an array */
    dispatch_async(concurrentQueue, ^{
                
//        dispatch_sync(concurrentQueue, ^{
//            
//            
//        });
//        __block NSMutableArray *randomNumbers = nil;
//        /* Read the numbers from disk and sort them in an
//         ascending fashion */
//        dispatch_sync(concurrentQueue, ^{
//            
// 
//        });
        NSString* urlMainCategores = [NSString stringWithFormat:@"%@/MainCategories", BASE_URL];
        urlMainCategores = [urlMainCategores stringByAppendingFormat:@"?page=%d", [page intValue]];
        NSURL *url = [NSURL URLWithString:urlMainCategores];
        
        //NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
        [urlRequest setTimeoutInterval:30.0f];
        [urlRequest setHTTPMethod:@"GET"];
        
        NSURLResponse *response;
        NSError *error;
        NSString* errMsg = @"";
        NSNumber* page = @0;
        NSNumber* lastPage = @0;
        
        NSData *data = [NSURLConnection sendSynchronousRequest:urlRequest
                                             returningResponse:&response
                                                         error:&error];
        PRPLog(@"http request url: %@\n  -[%@ , %@]",
               urlMainCategores,
               NSStringFromClass([self class]),
               NSStringFromSelector(_cmd));

        if ([data length] > 0 &&
            error == nil){
            
            NSString*  resStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

            PRPLog(@"%lu bytes of data was returned \n resStr: %@\n-[%@ , %@]",
                   (unsigned long)[data length],
                   resStr,
                   NSStringFromClass([self class]),
                   NSStringFromSelector(_cmd));
//            PRPLog(@"response %@ -[%@ , %@]",
//                   [response description],
//                   NSStringFromClass([self class]),
//                   NSStringFromSelector(_cmd));
            
            /* Now try to deserialize the JSON object into a dictionary */
            error = nil;
            id jsonObject = [NSJSONSerialization 
                             JSONObjectWithData:data
                             options:NSJSONReadingAllowFragments
                             error:&error];
            
            if (jsonObject != nil &&
                error == nil){
                
                PRPLog(@"Successfully deserialized....-[%@ , %@]",
                       NSStringFromClass([self class]),
                       NSStringFromSelector(_cmd));
                
                if ([jsonObject isKindOfClass:[NSDictionary class]]){
                    
                    NSDictionary *deserializedDictionary = (NSDictionary *)jsonObject;
        
                    PRPLog(@"Deserialized JSON Dictionary = %@ \n -[%@ , %@]",
                           deserializedDictionary,
                           NSStringFromClass([self class]),
                           NSStringFromSelector(_cmd));
                    
                    page = [deserializedDictionary objectForKey:@"page"];
                    lastPage = [deserializedDictionary objectForKey:@"lastPage"]; 
                    
                    PRPLog(@"page= %@ \n lastPage= %@  -[%@ , %@]",
                           page,
                           lastPage,
                           NSStringFromClass([self class]),
                           NSStringFromSelector(_cmd));
                    
                    NSArray* MainCategories = [deserializedDictionary objectForKey:@"MainCategories"]; 
                    
                    [MainCategories enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop){
                        //create an instance of BRDBirthdayImport
                        NSDictionary* dicRecord = (NSDictionary*)obj;
                        BRRecordMainCategory* record = [[BRRecordMainCategory alloc] initWithJsonDic:dicRecord];
                
                        //[self.mainCategories addObject: record];
                        [self.mainCategories insertObject:record atIndex:0];

                    }];
                    
                    
                } else if ([jsonObject isKindOfClass:[NSArray class]]){
                    
                    NSArray *deserializedArray = (NSArray *)jsonObject;
                    PRPLog(@"Deserialized JSON Array = %@-[%@ , %@]",
                           deserializedArray,
                           NSStringFromClass([self class]),
                           NSStringFromSelector(_cmd)); 
                    
                } else {
                    /* Some other object was returned. We don't know how to deal
                     with this situation as the deserializer only returns dictionaries
                     or arrays */
                    PRPLog(@"Some other object was returned. We don't know how to deal with this situation as the deserializer only returns dictionaries-[%@ , %@]",
                           error,
                           NSStringFromClass([self class]),
                           NSStringFromSelector(_cmd));
                errMsg = @"Some other object was returned. We don't know how to deal with this situation as the deserializer only returns dictionaries";
                }
                
            }else if (error != nil){
                
                PRPLog(@"An error happened while deserializing the JSON data.\n %@-[%@ , %@]",
                       error,
                       NSStringFromClass([self class]),
                       NSStringFromSelector(_cmd));    
                errMsg = [NSString stringWithFormat:@"An error happened while deserializing the JSON data %@",  [error description]];
            }

            
        }
        else if ([data length] == 0 &&
                 error == nil){
            PRPLog(@"No data was returned.-[%@ , %@]",
                   (unsigned long)[data length],
                   NSStringFromClass([self class]),
                   NSStringFromSelector(_cmd));
            errMsg = @"No data was returned.";
        }
        else if (error != nil){
            PRPLog(@"Error happened = %@-[%@ , %@]",
                   [error description],
                   NSStringFromClass([self class]),
                   NSStringFromSelector(_cmd));
            errMsg = [NSString stringWithFormat:@"Error happened = %@",  [error description]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{

            NSDictionary *userInfo = @{@"errMsg":errMsg,
                                        @"page":page,
                                        @"lastPage": lastPage};
            
            [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationMainCategoriesDidUpdate object:self userInfo:userInfo];
        
        });
        
    });
}

-(void)mainCategoriesSort{

     self.mainCategories = [[self.mainCategories sortedArrayUsingComparator: ^(id a, id b) {
        BRRecordMainCategory *A = ( BRRecordMainCategory* ) a;
        BRRecordMainCategory *B = ( BRRecordMainCategory* ) b;
        
        if(self.mainCategoriesSortType == mainCategoriesSortTypeSortByName){
            
            static NSStringCompareOptions comparisonOptions = NSCaseInsensitiveSearch | NSNumericSearch |
            NSWidthInsensitiveSearch | NSForcedOrderingSearch;
            NSLocale *currentLocale = [NSLocale currentLocale];
            
            NSString* firstStr;
            NSString* secondStr;
            if(!self.mainCategoriesSortIsDesc){
                
                firstStr = A.name;
                secondStr = B.name;
                
            } else {
                
                firstStr = B.name;
                secondStr = A.name;
            }            
            NSRange string1Range = NSMakeRange(0, [firstStr length]);
            
            return [secondStr compare:secondStr options:comparisonOptions range:string1Range locale:currentLocale];
            
        } else {
            NSDate* firstDate;
            NSDate* secondDate;
            
            if(self.mainCategoriesSortIsDesc){
                
                firstDate = A.created_at;
                secondDate = B.created_at;
                
            } else {
                firstDate = B.created_at;
                secondDate = A.created_at;
            }            
            
            return [firstDate compare:secondDate];
         
        } 
  
    }] mutableCopy];
}


#pragma mark subCategories
- (void)fetchSubCategoriesWithPage:(NSNumber*)page{
    
    //[self.mainCategories removeAllObjects];
    
    dispatch_queue_t concurrentQueue = 
    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    /* If we have not already saved an array of 10,000
     random numbers to the disk before, generate these numbers now
     and then save them to the disk in an array */
    dispatch_async(concurrentQueue, ^{
        
        //        dispatch_sync(concurrentQueue, ^{
        //            
        //            
        //        });
        //        __block NSMutableArray *randomNumbers = nil;
        //        /* Read the numbers from disk and sort them in an
        //         ascending fashion */
        //        dispatch_sync(concurrentQueue, ^{
        //            
        // 
        //        });
        NSString* urlMainCategores = [NSString stringWithFormat:@"%@/SubCategories", BASE_URL];
        //urlMainCategores = [urlMainCategores stringByAppendingFormat:@"?page=%d", [page intValue]];
        urlMainCategores = [urlMainCategores stringByAppendingFormat:@"?main=%@", self.mainCategoriesSelectedUid];
        NSURL *url = [NSURL URLWithString:urlMainCategores];
        
        //NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
        [urlRequest setTimeoutInterval:30.0f];
        [urlRequest setHTTPMethod:@"GET"];
        
        NSURLResponse *response;
        NSError *error;
        NSString* errMsg = @"";
        NSNumber* page = @0;
        NSNumber* lastPage = @0;
        
        NSData *data = [NSURLConnection sendSynchronousRequest:urlRequest
                                             returningResponse:&response
                                                         error:&error];
        PRPLog(@"http request url: %@\n  -[%@ , %@]",
               urlMainCategores,
               NSStringFromClass([self class]),
               NSStringFromSelector(_cmd));
        
        if ([data length] > 0 &&
            error == nil){
            
            NSString*  resStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
            PRPLog(@"%lu bytes of data was returned \n resStr: %@\n-[%@ , %@]",
                   (unsigned long)[data length],
                   resStr,
                   NSStringFromClass([self class]),
                   NSStringFromSelector(_cmd));
            //            PRPLog(@"response %@ -[%@ , %@]",
            //                   [response description],
            //                   NSStringFromClass([self class]),
            //                   NSStringFromSelector(_cmd));
            
            /* Now try to deserialize the JSON object into a dictionary */
            error = nil;
            id jsonObject = [NSJSONSerialization 
                             JSONObjectWithData:data
                             options:NSJSONReadingAllowFragments
                             error:&error];
            
            if (jsonObject != nil &&
                error == nil){
                
                PRPLog(@"Successfully deserialized....-[%@ , %@]",
                       NSStringFromClass([self class]),
                       NSStringFromSelector(_cmd));
                
                if ([jsonObject isKindOfClass:[NSDictionary class]]){
                    
                    NSDictionary *deserializedDictionary = (NSDictionary *)jsonObject;
                    
                    PRPLog(@"Deserialized JSON Dictionary = %@ \n -[%@ , %@]",
                           deserializedDictionary,
                           NSStringFromClass([self class]),
                           NSStringFromSelector(_cmd));
                    
                    page = [deserializedDictionary objectForKey:@"page"];
                    lastPage = [deserializedDictionary objectForKey:@"lastPage"]; 
                    
                    PRPLog(@"page= %@ \n lastPage= %@  -[%@ , %@]",
                           page,
                           lastPage,
                           NSStringFromClass([self class]),
                           NSStringFromSelector(_cmd));
                    
                    NSArray* SubCategories = [deserializedDictionary objectForKey:@"SubCategories"]; 
                    
                    [SubCategories enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop){
                        //create an instance of BRDBirthdayImport
                        NSDictionary* dicRecord = (NSDictionary*)obj;
                        BRRecordSubCategory* record = [[BRRecordSubCategory alloc] initWithJsonDic:dicRecord];
                        
                        //[self.subCategories addObject: record];
                        [self.subCategories insertObject:record atIndex:0];
                        
                    }];
                
                } else if ([jsonObject isKindOfClass:[NSArray class]]){
                    
                    NSArray *deserializedArray = (NSArray *)jsonObject;
                    PRPLog(@"Deserialized JSON Array = %@-[%@ , %@]",
                           deserializedArray,
                           NSStringFromClass([self class]),
                           NSStringFromSelector(_cmd)); 
                    
                } else {
                    /* Some other object was returned. We don't know how to deal
                     with this situation as the deserializer only returns dictionaries
                     or arrays */
                    PRPLog(@"Some other object was returned. We don't know how to deal with this situation as the deserializer only returns dictionaries-[%@ , %@]",
                           error,
                           NSStringFromClass([self class]),
                           NSStringFromSelector(_cmd));
                    errMsg = @"Some other object was returned. We don't know how to deal with this situation as the deserializer only returns dictionaries";
                }
                
            }else if (error != nil){
                
                PRPLog(@"An error happened while deserializing the JSON data.\n %@-[%@ , %@]",
                       error,
                       NSStringFromClass([self class]),
                       NSStringFromSelector(_cmd));    
                errMsg = [NSString stringWithFormat:@"An error happened while deserializing the JSON data %@",  [error description]];
            }
            
            
        }
        else if ([data length] == 0 &&
                 error == nil){
            PRPLog(@"No data was returned.-[%@ , %@]",
                   (unsigned long)[data length],
                   NSStringFromClass([self class]),
                   NSStringFromSelector(_cmd));
            errMsg = @"No data was returned.";
        }
        else if (error != nil){
            PRPLog(@"Error happened = %@-[%@ , %@]",
                   [error description],
                   NSStringFromClass([self class]),
                   NSStringFromSelector(_cmd));
            errMsg = [NSString stringWithFormat:@"Error happened = %@",  [error description]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSDictionary *userInfo = @{@"errMsg":errMsg,
            @"page":page,
            @"lastPage": lastPage};
            
            [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationSubCategoriesDidUpdate object:self userInfo:userInfo];
            
        });
        
    });
}

-(void)subCategoriesSort{
    
    self.subCategories = [[self.subCategories sortedArrayUsingComparator: ^(id a, id b) {
        BRRecordSubCategory *A = ( BRRecordSubCategory* ) a;
        BRRecordSubCategory *B = ( BRRecordSubCategory* ) b;
        
        if(self.subCategoriesSortType == subCategoriesSortTypeSortByName){
            
            static NSStringCompareOptions comparisonOptions = NSCaseInsensitiveSearch | NSNumericSearch |
            NSWidthInsensitiveSearch | NSForcedOrderingSearch;
            NSLocale *currentLocale = [NSLocale currentLocale];
            
            NSString* firstStr;
            NSString* secondStr;
            if(!self.subCategoriesSortIsDesc){
                
                firstStr = A.name;
                secondStr = B.name;
                
            } else {
                
                firstStr = B.name;
                secondStr = A.name;
            }            
            NSRange string1Range = NSMakeRange(0, [firstStr length]);
            
            return [secondStr compare:secondStr options:comparisonOptions range:string1Range locale:currentLocale];
            
        } else {
            NSDate* firstDate;
            NSDate* secondDate;
            
            if(self.subCategoriesSortIsDesc){
                
                firstDate = A.created_at;
                secondDate = B.created_at;
                
            } else {
                firstDate = B.created_at;
                secondDate = A.created_at;
            }            
            
            return [firstDate compare:secondDate];
            
        } 
        
    }] mutableCopy];
}


#pragma mark Videos
-(NSMutableArray*)videos{
    
    if(!_videos){
        _videos = [NSMutableArray array];
    }
    return _videos;
}

- (void)fetchVideosWithPage:(NSNumber*)page{
    
    //[self.mainCategories removeAllObjects];
    
    dispatch_queue_t concurrentQueue = 
    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    /* If we have not already saved an array of 10,000
     random numbers to the disk before, generate these numbers now
     and then save them to the disk in an array */
    dispatch_async(concurrentQueue, ^{
        
        //        dispatch_sync(concurrentQueue, ^{
        //            
        //            
        //        });
        //        __block NSMutableArray *randomNumbers = nil;
        //        /* Read the numbers from disk and sort them in an
        //         ascending fashion */
        //        dispatch_sync(concurrentQueue, ^{
        //            
        // 
        //        });
        NSString* urlVideos= [NSString stringWithFormat:@"%@/Videos", BASE_URL];
        urlVideos = [urlVideos stringByAppendingFormat:@"?page=%d", [page intValue]];
        urlVideos = [urlVideos stringByAppendingFormat:@"&sub=%@", self.subCategoriesSelectedUid];
        PRPLog(@"http request url: %@\n  -[%@ , %@]",
               urlVideos,
               NSStringFromClass([self class]),
               NSStringFromSelector(_cmd));
        NSURL *url = [NSURL URLWithString:urlVideos];
        
        //NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
        [urlRequest setTimeoutInterval:30.0f];
        [urlRequest setHTTPMethod:@"GET"];
        
        NSURLResponse *response;
        NSError *error;
        NSString* errMsg = @"";
        NSNumber* page = @0;
        NSNumber* lastPage = @0;
        
        NSData *data = [NSURLConnection sendSynchronousRequest:urlRequest
                                             returningResponse:&response
                                                         error:&error];
        if ([data length] > 0 &&
            error == nil){
            
            NSString*  resStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
            PRPLog(@"%lu bytes of data was returned \n resStr: %@\n-[%@ , %@]",
                   (unsigned long)[data length],
                   resStr,
                   NSStringFromClass([self class]),
                   NSStringFromSelector(_cmd));
            //            PRPLog(@"response %@ -[%@ , %@]",
            //                   [response description],
            //                   NSStringFromClass([self class]),
            //                   NSStringFromSelector(_cmd));
            
            /* Now try to deserialize the JSON object into a dictionary */
            error = nil;
            id jsonObject = [NSJSONSerialization 
                             JSONObjectWithData:data
                             options:NSJSONReadingAllowFragments
                             error:&error];
            
            if (jsonObject != nil &&
                error == nil){
                
                PRPLog(@"Successfully deserialized....-[%@ , %@]",
                       NSStringFromClass([self class]),
                       NSStringFromSelector(_cmd));
                
                if ([jsonObject isKindOfClass:[NSDictionary class]]){
                    
                    NSDictionary *deserializedDictionary = (NSDictionary *)jsonObject;
                    if([deserializedDictionary objectForKey:@"error"]){
                        errMsg = [deserializedDictionary objectForKey:@"error"];
                    } else {
                        PRPLog(@"Deserialized JSON Dictionary = %@ \n -[%@ , %@]",
                               deserializedDictionary,
                               NSStringFromClass([self class]),
                               NSStringFromSelector(_cmd));
                        
                        page = [deserializedDictionary objectForKey:@"page"];
                        lastPage = [deserializedDictionary objectForKey:@"lastPage"]; 
                        
                        PRPLog(@"page= %@ \n lastPage= %@  -[%@ , %@]",
                               page,
                               lastPage,
                               NSStringFromClass([self class]),
                               NSStringFromSelector(_cmd));
                        
                        page = [deserializedDictionary objectForKey:@"page"];
                        lastPage = [deserializedDictionary objectForKey:@"lastPage"]; 
                        
                        PRPLog(@"page= %@ \n lastPage= %@  -[%@ , %@]",
                               page,
                               lastPage,
                               NSStringFromClass([self class]),
                               NSStringFromSelector(_cmd));
                        NSArray* videos = [deserializedDictionary objectForKey:@"videos"]; 
                        
                        [videos enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop){
                            //create an instance of BRDBirthdayImport
                            NSDictionary* dicRecord = (NSDictionary*)obj;
                            BRRecordVideo* record = [[BRRecordVideo alloc] initWithJsonDic:dicRecord];
                            
                            //[self.subCategories addObject: record];
                            [self.videos insertObject:record atIndex:0];
                            
                        }];
                    }
                    
                } else if ([jsonObject isKindOfClass:[NSArray class]]){
                    
                    NSArray *deserializedArray = (NSArray *)jsonObject;
                    PRPLog(@"Deserialized JSON Array = %@-[%@ , %@]",
                           deserializedArray,
                           NSStringFromClass([self class]),
                           NSStringFromSelector(_cmd)); 
                    
                } else {
                    /* Some other object was returned. We don't know how to deal
                     with this situation as the deserializer only returns dictionaries
                     or arrays */
                    PRPLog(@"Some other object was returned. We don't know how to deal with this situation as the deserializer only returns dictionaries-[%@ , %@]",
                           error,
                           NSStringFromClass([self class]),
                           NSStringFromSelector(_cmd));
                    errMsg = @"Some other object was returned. We don't know how to deal with this situation as the deserializer only returns dictionaries";
                }
                
            }else if (error != nil){
                
                PRPLog(@"An error happened while deserializing the JSON data.\n %@-[%@ , %@]",
                       error,
                       NSStringFromClass([self class]),
                       NSStringFromSelector(_cmd));    
                errMsg = [NSString stringWithFormat:@"An error happened while deserializing the JSON data %@",  [error description]];
            }
            
            
        }
        else if ([data length] == 0 &&
                 error == nil){
            PRPLog(@"No data was returned.-[%@ , %@]",
                   (unsigned long)[data length],
                   NSStringFromClass([self class]),
                   NSStringFromSelector(_cmd));
            errMsg = @"No data was returned.";
        }
        else if (error != nil){
            PRPLog(@"Error happened = %@-[%@ , %@]",
                   [error description],
                   NSStringFromClass([self class]),
                   NSStringFromSelector(_cmd));
            errMsg = [NSString stringWithFormat:@"Error happened = %@",  [error description]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSDictionary *userInfo = @{@"errMsg":errMsg,
            @"page":page,
            @"lastPage": lastPage};
            self.videosTemp = [self.videos mutableCopy];
            [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationVideosDidUpdate object:self userInfo:userInfo];
            
        });
        
    });
}

- (void)fetchVideoByUid:(NSString*)uid
{
    //[self.mainCategories removeAllObjects];
    dispatch_queue_t concurrentQueue = 
    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    /* If we have not already saved an array of 10,000
     random numbers to the disk before, generate these numbers now
     and then save them to the disk in an array */
    dispatch_async(concurrentQueue, ^{
        
        //        dispatch_sync(concurrentQueue, ^{
        //            
        //            
        //        });
        //        __block NSMutableArray *randomNumbers = nil;
        //        /* Read the numbers from disk and sort them in an
        //         ascending fashion */
        //        dispatch_sync(concurrentQueue, ^{
        //            
        // 
        //        });
        NSString* urlVideos= [NSString stringWithFormat:@"%@/Videos/%@", BASE_URL, uid];
        PRPLog(@"http request url: %@\n  -[%@ , %@]",
               urlVideos,
               NSStringFromClass([self class]),
               NSStringFromSelector(_cmd));
        
        NSURL *url = [NSURL URLWithString:urlVideos];
        //NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
        [urlRequest setTimeoutInterval:30.0f];
        [urlRequest setHTTPMethod:@"GET"];
        
        NSURLResponse *response;
        NSError *error;
        NSString* errMsg = @"";
  
        NSData *data = [NSURLConnection sendSynchronousRequest:urlRequest
                                             returningResponse:&response
                                                         error:&error];
        if ([data length] > 0 &&
            error == nil){
            
            NSString*  resStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
            PRPLog(@"%lu bytes of data was returned \n resStr: %@\n-[%@ , %@]",
                   (unsigned long)[data length],
                   resStr,
                   NSStringFromClass([self class]),
                   NSStringFromSelector(_cmd));
            //            PRPLog(@"response %@ -[%@ , %@]",
            //                   [response description],
            //                   NSStringFromClass([self class]),
            //                   NSStringFromSelector(_cmd));
            
            /* Now try to deserialize the JSON object into a dictionary */
            error = nil;
            id jsonObject = [NSJSONSerialization 
                             JSONObjectWithData:data
                             options:NSJSONReadingAllowFragments
                             error:&error];
            
            if (jsonObject != nil &&
                error == nil){
                
                PRPLog(@"Successfully deserialized....-[%@ , %@]",
                       NSStringFromClass([self class]),
                       NSStringFromSelector(_cmd));
                
                if ([jsonObject isKindOfClass:[NSDictionary class]]){
                    
                    NSDictionary *deserializedDictionary = (NSDictionary *)jsonObject;
                    if([deserializedDictionary objectForKey:@"error"]){
                        errMsg = [deserializedDictionary objectForKey:@"error"];
                    } else {
                        PRPLog(@"Deserialized JSON Dictionary = %@ \n -[%@ , %@]",
                               deserializedDictionary,
                               NSStringFromClass([self class]),
                               NSStringFromSelector(_cmd));
                        
          
                        NSDictionary* videoDic = [deserializedDictionary objectForKey:@"video"]; 
                        self.currentSelectedVideo = [[BRRecordVideo alloc] initWithJsonDic:videoDic];
                        
                    }
                    
                } else if ([jsonObject isKindOfClass:[NSArray class]]){
                    
                    NSArray *deserializedArray = (NSArray *)jsonObject;
                    PRPLog(@"Deserialized JSON Array = %@-[%@ , %@]",
                           deserializedArray,
                           NSStringFromClass([self class]),
                           NSStringFromSelector(_cmd)); 
                    
                } else {
                    /* Some other object was returned. We don't know how to deal
                     with this situation as the deserializer only returns dictionaries
                     or arrays */
                    PRPLog(@"Some other object was returned. We don't know how to deal with this situation as the deserializer only returns dictionaries-[%@ , %@]",
                           error,
                           NSStringFromClass([self class]),
                           NSStringFromSelector(_cmd));
                    errMsg = @"Some other object was returned. We don't know how to deal with this situation as the deserializer only returns dictionaries";
                }
                
            }else if (error != nil){
                
                PRPLog(@"An error happened while deserializing the JSON data.\n %@-[%@ , %@]",
                       error,
                       NSStringFromClass([self class]),
                       NSStringFromSelector(_cmd));    
                errMsg = [NSString stringWithFormat:@"An error happened while deserializing the JSON data %@",  [error description]];
            }
            
            
        }
        else if ([data length] == 0 &&
                 error == nil){
            PRPLog(@"No data was returned.-[%@ , %@]",
                   (unsigned long)[data length],
                   NSStringFromClass([self class]),
                   NSStringFromSelector(_cmd));
            errMsg = @"No data was returned.";
        }
        else if (error != nil){
            PRPLog(@"Error happened = %@-[%@ , %@]",
                   [error description],
                   NSStringFromClass([self class]),
                   NSStringFromSelector(_cmd));
            errMsg = [NSString stringWithFormat:@"Error happened = %@",  [error description]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSDictionary *userInfo = @{@"errMsg":errMsg};
            [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationVideoDidUpdate object:self userInfo:userInfo];
            
        });
        
    });
}

- (void)filterVideoByNameOrDesc:(NSString*)searchFor
{
    __block NSMutableArray* arrayTemp = [[NSMutableArray alloc] init];
    
    self.videos = nil;
    [self.videosTemp enumerateObjectsUsingBlock:^(id obj , NSUInteger idx, BOOL *stop){
        BRRecordVideo* record = (BRRecordVideo*)obj;
        if ([record.name rangeOfString:searchFor].location != NSNotFound
            ||[record.desc rangeOfString:searchFor].location != NSNotFound
            ) {
            
            [arrayTemp insertObject:record atIndex:0];
        }
        
    }];
    
    if([searchFor length]>0){
        self.videos = arrayTemp;
    } else {
        self.videos = [BRDModel sharedInstance].videosTemp;
    }
    
}
- (BRRecordVideo*)findVideoByYoutubeKey:(NSString*)youtubeKey
{
    __block BRRecordVideo* video;
    
    [self.videosTemp enumerateObjectsUsingBlock:^(id obj , NSUInteger idx, BOOL *stop){
        BRRecordVideo* record = (BRRecordVideo*)obj;
        if([record.youtubeKey isEqualToString:youtubeKey]){
            video = record;
            *stop = YES;
        }
        
    }];
    PRPLog(@"found video by key:%@ -[%@ , %@] \n ",
           youtubeKey,
           NSStringFromClass([self class]),
           NSStringFromSelector(_cmd));
    return video;
}


- (void)getSocketUrl
{

    //[self.mainCategories removeAllObjects];
    dispatch_queue_t concurrentQueue = 
    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    /* If we have not already saved an array of 10,000
     random numbers to the disk before, generate these numbers now
     and then save them to the disk in an array */
    dispatch_async(concurrentQueue, ^{
        
        //        dispatch_sync(concurrentQueue, ^{
        //            
        //            
        //        });
        //        __block NSMutableArray *randomNumbers = nil;
        //        /* Read the numbers from disk and sort them in an
        //         ascending fashion */
        //        dispatch_sync(concurrentQueue, ^{
        //            
        // 
        //        });
        NSString* urlGetSocketUrl = [NSString stringWithFormat:@"%@/coffeescript/welearn_socket_url", BASE_URL];
        PRPLog(@"http request url: %@\n  -[%@ , %@]",
               urlGetSocketUrl,
               NSStringFromClass([self class]),
               NSStringFromSelector(_cmd));
        
        NSURL *url = [NSURL URLWithString:urlGetSocketUrl];
        //NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
        [urlRequest setTimeoutInterval:30.0f];
        [urlRequest setHTTPMethod:@"GET"];
        
        NSURLResponse *response;
        NSError *error;
        NSString* errMsg = @"";
        
        NSData *data = [NSURLConnection sendSynchronousRequest:urlRequest
                                             returningResponse:&response
                                                         error:&error];
        if ([data length] > 0 &&
            error == nil){
            
            NSString*  resStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
            PRPLog(@"%lu bytes of data was returned \n resStr: %@\n-[%@ , %@]",
                   (unsigned long)[data length],
                   resStr,
                   NSStringFromClass([self class]),
                   NSStringFromSelector(_cmd));
            //            PRPLog(@"response %@ -[%@ , %@]",
            //                   [response description],
            //                   NSStringFromClass([self class]),
            //                   NSStringFromSelector(_cmd));
            
            /* Now try to deserialize the JSON object into a dictionary */
            error = nil;
            id jsonObject = [NSJSONSerialization 
                             JSONObjectWithData:data
                             options:NSJSONReadingAllowFragments
                             error:&error];
            
            if (jsonObject != nil &&
                error == nil){
                
                PRPLog(@"Successfully deserialized....-[%@ , %@]",
                       NSStringFromClass([self class]),
                       NSStringFromSelector(_cmd));
                
                if ([jsonObject isKindOfClass:[NSDictionary class]]){
                    
                    NSDictionary *deserializedDictionary = (NSDictionary *)jsonObject;
                    if([deserializedDictionary objectForKey:@"error"]){
                        errMsg = [deserializedDictionary objectForKey:@"error"];
                    } else {
                        PRPLog(@"Deserialized JSON Dictionary = %@ \n -[%@ , %@]",
                               deserializedDictionary,
                               NSStringFromClass([self class]),
                               NSStringFromSelector(_cmd));
                        
                        
                        self.socketUrl = [deserializedDictionary objectForKey:@"url"]; 

                    }
                    
                } else if ([jsonObject isKindOfClass:[NSArray class]]){
                    
                    NSArray *deserializedArray = (NSArray *)jsonObject;
                    PRPLog(@"Deserialized JSON Array = %@-[%@ , %@]",
                           deserializedArray,
                           NSStringFromClass([self class]),
                           NSStringFromSelector(_cmd)); 
                    
                } else {
                    /* Some other object was returned. We don't know how to deal
                     with this situation as the deserializer only returns dictionaries
                     or arrays */
                    PRPLog(@"Some other object was returned. We don't know how to deal with this situation as the deserializer only returns dictionaries-[%@ , %@]",
                           error,
                           NSStringFromClass([self class]),
                           NSStringFromSelector(_cmd));
                    errMsg = @"Some other object was returned. We don't know how to deal with this situation as the deserializer only returns dictionaries";
                }
                
            }else if (error != nil){
                
                PRPLog(@"An error happened while deserializing the JSON data.\n %@-[%@ , %@]",
                       error,
                       NSStringFromClass([self class]),
                       NSStringFromSelector(_cmd));    
                errMsg = [NSString stringWithFormat:@"An error happened while deserializing the JSON data %@",  [error description]];
            }
            
        }
        else if ([data length] == 0 &&
                 error == nil){
            PRPLog(@"No data was returned.-[%@ , %@]",
                   (unsigned long)[data length],
                   NSStringFromClass([self class]),
                   NSStringFromSelector(_cmd));
            errMsg = @"No data was returned.";
        }
        else if (error != nil){
            PRPLog(@"Error happened = %@-[%@ , %@]",
                   [error description],
                   NSStringFromClass([self class]),
                   NSStringFromSelector(_cmd));
            errMsg = [NSString stringWithFormat:@"Error happened = %@",  [error description]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSDictionary *userInfo = @{@"errMsg":errMsg};
            [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationSocketURLDidUpdate object:self userInfo:userInfo];
            
        });
        
    });

    
}
     
- (void)postToFacebookWall:(NSString *)message withFacebookID:(NSString *)facebookID
{
    NSLog(@"postToFacebookWall");
    
    if (self.facebookAccount == nil) {
        //We're not authorized yet so store the Facebook message and id and start the authentication flow
        self.postToFacebookMessage = message;
        self.postToFacebookID = facebookID;
        self.currentFacebookAction = FacebookActionPostToWall;
        [self authenticateWithFacebook];
        return;
    }
    
    NSLog(@"We're authorized so post to Facebook!");
    
    NSDictionary *params = @{@"message":message};
    
    //Use the user's Facebook ID to call the post to friend feed Graph API path
    NSString *postGraphPath = [NSString stringWithFormat:@"https://graph.facebook.com/%@/feed",facebookID];
    
    NSURL *requestURL = [NSURL URLWithString:postGraphPath];
    
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeFacebook requestMethod:SLRequestMethodPOST URL:requestURL parameters:params];
    request.account = self.facebookAccount;
    
    [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        if (error != nil) {
            NSLog(@"Error posting to Facebook: %@",error);
        }
        else
        {
            //Facebook returns a dictionary with the id of the new post - this might be useful for other projects
            NSDictionary *dict = (NSDictionary *) [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
            NSLog(@"Successfully posted to Facebook! Post ID: %@",dict);
        }
    }];
    
}


- (void)authenticateWithFacebook {
    
    //Centralized iOS user Twitter, Facebook and Sina Weibo accounts are accessed by apps via the ACAccountStore 
    //if(nil != self.facebookAccount)return;
    
    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    
    ACAccountType *accountTypeFacebook = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook];
    
    // At first, we only ask for the basic read
    NSArray* permissions = @[@"email", @"read_stream",@"read_friendlists", @"friends_birthday"];
    
    NSDictionary* options =@{ACFacebookAppIdKey:KFacebookKey,ACFacebookPermissionsKey: permissions,ACFacebookAudienceKey:ACFacebookAudienceOnlyMe};    
    
    //Replace with your Facebook.com app ID
//    NSDictionary *options = @{ACFacebookAppIdKey: @"500954283270682",
//ACFacebookPermissionsKey: @[@"email", @"read_stream",@"read_friendlists"] ,ACFacebookAudienceKey:ACFacebookAudienceFriends};
    
    [accountStore requestAccessToAccountsWithType:accountTypeFacebook options:options completion:^(BOOL granted, NSError *error) {
        if(granted) {
            //The completition handler may not fire in the main thread and as we are going to 
            NSLog(@"Facebook Authorized!");
            /** 
             * The user granted us the basic read permission.
             * Now we can ask for more permissions
             **/
//            NSMutableDictionary* options2 = [options mutableCopy];    
//            NSArray*readPermissions =@[@"read_stream",@"read_friendlists"];
//            [options2 setObject:readPermissions forKey:ACFacebookPermissionsKey];
//            
//            
            NSArray *accounts = [accountStore accountsWithAccountType:accountTypeFacebook];
            self.facebookAccount = [accounts lastObject];
            
            //By checking what Facebook action the user was trying to perform before the authorization process we can complete the Facebook action when the authorization succeeds
            switch (self.currentFacebookAction) {
                case FacebookActionGetFriendsBirthdays:
                    [self fetchFacebookBirthdays];
                    break;
                case FacebookActionPostToWall:
                    //TODO - post to a friend's Facebook Wall
                    [self postToFacebookWall:self.postToFacebookMessage withFacebookID:self.postToFacebookID];
                    break;
                case FacebookActionGetMe:
                    //TODO - post to a friend's Facebook Wall
                    [self fetchFacebookMe];
                    break;
 
                default:
                    PRPLog(@"self.facebookAccount= %@-[%@ , %@]",
                           self.facebookAccount,
                           NSStringFromClass([self class]),NSStringFromSelector(_cmd));
            }
        } else {
            
            if ([error code] == ACErrorAccountNotFound) {
                NSLog(@"No Facebook Account Found");
            }
            else {
                NSLog(@"Facebook SSO Authentication Failed: %@",error);
            }
        }
    }];
}

-(void) updateCachedBirthdays
{    
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    
    NSManagedObjectContext *context = self.managedObjectContext;
    
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"BRDBirthday" inManagedObjectContext:context];
    fetchRequest.entity = entity;
    
    //Fetch all the birthday entities in order of next birthday
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"nextBirthday" ascending:YES];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    fetchRequest.sortDescriptors = sortDescriptors;
    
    NSFetchedResultsController *fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:context sectionNameKeyPath:nil cacheName:nil];
    
    NSError *error = nil;
    if (![fetchedResultsController performFetch:&error]) {
        
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    NSArray *fetchedObjects = fetchedResultsController.fetchedObjects;
    NSInteger resultCount = [fetchedObjects count];
    
    BRDBirthday *birthday;
    
    NSDate *now = [NSDate date];
    NSDateComponents *dateComponentsToday = [[NSCalendar currentCalendar] components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit fromDate:now];
    //This creates a date with time 00:00 today
    NSDate *today = [[NSCalendar currentCalendar] dateFromComponents:dateComponentsToday];
    
    UILocalNotification *reminderNotification;
    int scheduled = 0;
    NSDate *fireDate;
    
    for (int i = 0; i < resultCount; i++) {
        birthday = (BRDBirthday *) fetchedObjects[i];
        
        //if next birthday has past then we'll need to update the birthday entity
        if ([today compare:birthday.nextBirthday] == NSOrderedDescending) {
            //next birthday is now incorrect and is in the past...
            [birthday updateNextBirthdayAndAge];
        }
        
        if (scheduled < 20) {
            //get the scheduled reminder date for this birthday from settings
            fireDate = [[BRDSettings sharedInstance] reminderDateForNextBirthday:birthday.nextBirthday];
            if([now compare:fireDate] != NSOrderedAscending) {
                //this reminder was for today, but the reminder time has now passed - don't schedule a reminder!
            }
            else {
                //create new new local notification to schedule
                reminderNotification = [[UILocalNotification alloc] init];
                //set the schedule reminder date
                reminderNotification.fireDate = fireDate;
                reminderNotification.timeZone = [NSTimeZone defaultTimeZone];
                reminderNotification.alertAction = @"View Birthdays";
                reminderNotification.alertBody = [[BRDSettings sharedInstance] reminderTextForNextBirthday:birthday];
                //play a custom sound with a local notification
                reminderNotification.soundName = @"HappyBirthday.m4a";
                //update the badge count on the Birthday Reminder icon
                reminderNotification.applicationIconBadgeNumber = 1;
                //schedule the notification!
                [[UIApplication sharedApplication] scheduleLocalNotification:reminderNotification];
                scheduled++;
                
            }
        }

    }
    
    [self saveChanges];
    
    //Let any observer's know that the birthdays in our database have been updated
    [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationCachedBirthdaysDidUpdate object:self userInfo:nil];
}


-(NSMutableDictionary *) getExistingBirthdaysWithUIDs:(NSArray *)uids
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    
    NSManagedObjectContext *context = self.managedObjectContext;
    
    //NSPredicates are used to filter results sets.
    //This predicate specifies that the uid attribute from any results must match one or more of the values in the uids array
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"uid IN %@", uids];
    fetchRequest.predicate = predicate;
    
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"BRDBirthday" inManagedObjectContext:context];
    fetchRequest.entity = entity;
    
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"uid" ascending:YES];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    fetchRequest.sortDescriptors = sortDescriptors;
    
    NSFetchedResultsController *fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:context sectionNameKeyPath:nil cacheName:nil];
    
    NSError *error = nil;
    if (![fetchedResultsController performFetch:&error]) {
        
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    NSArray *fetchedObjects = fetchedResultsController.fetchedObjects;
    
    NSInteger resultCount = [fetchedObjects count];
	
	if (resultCount == 0) return [NSMutableDictionary dictionary];//nothing in the Core Data store
	
    BRDBirthday *birthday;
	
	NSMutableDictionary *tmpDict = [NSMutableDictionary dictionary];
	
    int i;
	
    for (i = 0; i < resultCount; i++) {
        birthday =  fetchedObjects[i];
        tmpDict[birthday.uid] = birthday;
    }
    
    return tmpDict;
}

-(void) importBirthdays:(NSArray *)birthdaysToImport
{
    int i;
    int max = [birthdaysToImport count];
    
    BRDBirthday *importBirthday;
    BRDBirthday *birthday;
    
    NSString *uid;
    NSMutableArray *newUIDs = [NSMutableArray array];
    
    for (i=0;i<max;i++)
    {
        importBirthday = birthdaysToImport[i];
        uid = importBirthday.uid;
        [newUIDs addObject:uid];
    }
    
    //use BRDModel's utility method to retrive existing birthdays with matching IDs
    //to the array of birthdays to import
    NSMutableDictionary *existingBirthdays = [self getExistingBirthdaysWithUIDs:newUIDs];
    
    NSManagedObjectContext *context = [BRDModel sharedInstance].managedObjectContext;
    
    for (i=0;i<max;i++)
    {
        importBirthday = birthdaysToImport[i];
        uid = importBirthday.uid;
        
        birthday = existingBirthdays[uid];
        if (birthday) {
            //a birthday with this udid already exists in Core Data, don't create a duplicate
        } else {
            birthday = [NSEntityDescription insertNewObjectForEntityForName:@"BRDBirthday" inManagedObjectContext:context];
            birthday.uid = uid;
            existingBirthdays[uid] = birthday;
        }
        
        //update the new or previously saved birthday entity
        birthday.name = importBirthday.name;
        birthday.uid = importBirthday.uid;
        birthday.picURL = importBirthday.picURL;
        birthday.imageData = importBirthday.imageData;
        birthday.addressBookID = importBirthday.addressBookID;
        birthday.facebookID = importBirthday.facebookID;
        
        birthday.birthDay = importBirthday.birthDay;
        birthday.birthMonth = importBirthday.birthMonth;
        birthday.birthYear = importBirthday.birthYear;
        
        [birthday updateNextBirthdayAndAge];
    }
    
    //save our new and updated changes to the Core Data store
    [self saveChanges];
    
    [self updateCachedBirthdays];
    
}

- (void)saveChanges
{
    NSError *error = nil;
    if ([self.managedObjectContext hasChanges]) {
        if (![self.managedObjectContext save:&error]) {//save failed
            NSLog(@"Save failed: %@",[error localizedDescription]);
        }
        else {
            NSLog(@"Save succeeded");
        }
    }
}

- (void)cancelChanges
{
    [self.managedObjectContext rollback];
}

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"BirthdayReminder" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"BirthdayReminder.sqlite"];
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end
