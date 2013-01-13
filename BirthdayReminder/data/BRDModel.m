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
#import "BRRecordMsgBoard.h"
#import "BRRecordFriend.h"
#import "BRDSettings.h"
#import <AddressBook/AddressBook.h>
#import <Social/Social.h>
#import <Accounts/Accounts.h>
#import "LangManager.h"
#import "ThemeManager.h"

typedef enum : int
{
    FacebookActionGetFriendsBirthdays = 1,
    FacebookActionPostToWall,
    FacebookActionGetMe,
    FacebookActionToggleMainCategoryFIsUserFavorite

}FacebookAction;

@interface BRDModel()


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
        _sharedInstance.lang = [LangManager sharedManager].dic;
        _sharedInstance.theme = [ThemeManager sharedManager].dic;
        //_sharedInstance.facebookAccount = nil;
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
        NSString* fbId = [defaults objectForKey:KUserDefaultFbId];
        NSString* fbName = [defaults objectForKey:KUserDefaultFbName];
        if(nil != fbId && nil != fbName) {
            _sharedInstance.fbId = fbId;
            _sharedInstance.fbName = fbName;
        }
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

-(NSMutableArray*)mArrFriends{
    
    if( nil == _mArrFriends){
        _mArrFriends = [[NSMutableArray alloc] init];
    } 
    return _mArrFriends;
}

//-(NSMutableArray*)subCategories{
//    
//    if(!_subCategories){
//        _subCategories = [NSMutableArray array];
//    }
//    return _subCategories;
//}

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


- (void)authenticateWithFacebook {
    
    if(nil != self.fbId 
       && self.currentFacebookAction != FacebookActionGetFriendsBirthdays){
        [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationFacebookMeDidUpdate object:self userInfo:nil];
        return;
    }
    
    //Centralized iOS user Twitter, Facebook and Sina Weibo accounts are accessed by apps via the ACAccountStore 
    //if(nil != self.facebookAccount)return;
    
    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    
    ACAccountType *accountTypeFacebook = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook];
    
    // At first, we only ask for the basic read
    NSArray* permissions = @[@"email", @"read_stream",@"read_friendlists", @"friends_birthday", @"publish_stream"];
    
    NSDictionary* options =@{ACFacebookAppIdKey:KFacebookKey,ACFacebookPermissionsKey: permissions,ACFacebookAudienceKey:ACFacebookAudienceOnlyMe};    
    
    //Replace with your Facebook.com app ID
    //    NSDictionary *options = @{ACFacebookAppIdKey: @"500954283270682",
    //ACFacebookPermissionsKey: @[@"email", @"read_stream",@"read_friendlists"] ,ACFacebookAudienceKey:ACFacebookAudienceFriends};
    
    [accountStore requestAccessToAccountsWithType:accountTypeFacebook options:options completion:^(BOOL granted, NSError *error) {
        if(granted) {
            //The completition handler may not fire in the main thread and as we are going to 
            
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
            PRPLog(@"Facebook Authorized! accounts:%@ -[%@ , %@]",
                   accounts,
                   NSStringFromClass([self class]),NSStringFromSelector(_cmd));
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
                case FacebookActionToggleMainCategoryFIsUserFavorite:
                    [self fetchFacebookMe];
                    
                    
                default:
                    PRPLog(@"self.facebookAccount= %@-[%@ , %@]",
                           self.facebookAccount,
                           NSStringFromClass([self class]),NSStringFromSelector(_cmd));
            }
            
        } else {
            
            if ([error code] == ACErrorAccountNotFound) {
                NSLog(@"No Facebook Account Found");
                
                dispatch_sync(dispatch_get_main_queue(), ^{
                    NSDictionary *userInfo = @{@"error": self.lang[@"warnNoFBAccountFound"]};
                    [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationFacebookMeDidUpdate object:self userInfo:userInfo];
                });
                
            }
            else {
                NSLog(@"Facebook SSO Authentication Failed: %@",error);
            }
        }
    }];
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

- (NSDictionary *)_parseQueryString:(NSString *)query {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:6];
    NSArray *pairs = [query componentsSeparatedByString:@"&"];
    
    for (NSString *pair in pairs) {
        NSArray *elements = [pair componentsSeparatedByString:@"="];
        NSString *key = [[elements objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *val = [[elements objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        [dict setObject:val forKey:key];
    }
    return dict;
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
    NSDictionary *params = @{@"fields" : @"name, id, birthday"};
    
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeFacebook requestMethod:SLRequestMethodGET URL:requestURL parameters:params];
    
    request.account = self.facebookAccount;
    __block NSString* errMsg;
    [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        if (error != nil) {
            errMsg = [error description];
            NSLog(@"Error getting my Facebook friend birthdays: %@",error);
            dispatch_sync(dispatch_get_main_queue(), ^{
                //update the view on the main thread
                NSDictionary *userInfo;
                userInfo = @{@"error":errMsg};
                [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationFacebookBirthdaysDidUpdate object:self userInfo:userInfo];
            });
        }
        else
        {
            // Facebook's me/friends Graph API returns a root dictionary
            NSDictionary *resultD = (NSDictionary *) [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
            NSLog(@"Facebook returned friends: %@",resultD);
            // with a 'data' key - an array of Facebook friend dictionaries
            NSArray *birthdayDictionaries = resultD[@"data"];
            if(nil == birthdayDictionaries){
                dispatch_sync(dispatch_get_main_queue(), ^{
                    //update the view on the main thread
                    NSDictionary *userInfo;
                    errMsg = [resultD description];
                    userInfo = @{@"error":errMsg};
                    [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationFacebookBirthdaysDidUpdate object:self userInfo:userInfo];
                });

                return;
            }
            
            NSDictionary* paging =  resultD[@"paging"];
            NSString* nextUrlStr = paging[@"next"];
            NSURL *url = [NSURL URLWithString:nextUrlStr];
            NSDictionary* queryParams = [self _parseQueryString: [url query]];
            NSString* access_token = queryParams[@"access_token"];
            
            PRPLog(@"self.fbId:%@ \n scheme:%@ \n host:%@ \n port:%@ \n path:%@ \n pathComponents:%@ \n parameterString:%@ \n query:%@ \n access_token:%@ \n fragment:%@ \n -[%@ , %@]",
                   self.fbId,
                   [url scheme],
                   [url host],
                   [url port],
                   [url path],
                   [url pathComponents],
                   [url parameterString],
                   [url query],
                   access_token,
                   [url fragment],
                   NSStringFromClass([self class]),NSStringFromSelector(_cmd)
                   );
            self.access_token = access_token;
            
            
            
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
                NSDictionary *userInfo;
                if(nil != errMsg) {
                    userInfo = @{@"error":errMsg};
                } else {
                    userInfo = @{@"birthdays":birthdays};
                }
                
                [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationFacebookBirthdaysDidUpdate object:self userInfo:userInfo];
            });
        }
    }];
}

- (void)fetchFbFriendsWithVideosCount:(NSString*)access_token 
                                 fbId:(NSString*)fbId
                            withBlock:(void (^)(NSDictionary* userInfo))block{
    
    if (nil == self.fbId) {
        self.currentFacebookAction = FacebookActionGetMe;
        [self authenticateWithFacebook];
        return;
    }
    
    dispatch_queue_t concurrentQueue = 
    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    /* If we have not already saved an array of 10,000
     random numbers to the disk before, generate these numbers now
     and then save them to the disk in an array */
    dispatch_async(concurrentQueue, ^{
        
        NSString* urlMainCategores = [NSString stringWithFormat:@"%@/friends-videos-with-count?access_token=%@&fbId=%@", BASE_URL, self.access_token, self.fbId];
        NSURL *url = [NSURL URLWithString:urlMainCategores];
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
        [urlRequest setTimeoutInterval:30.0f];
        [urlRequest setHTTPMethod:@"GET"];
        
        NSURLResponse *response;
        NSError *error;
        NSString* errMsg;
        NSMutableArray* mArrTemp = [[NSMutableArray alloc] init];
        NSData *data = [NSURLConnection sendSynchronousRequest:urlRequest
                                             returningResponse:&response
                                                         error:&error];
        PRPLog(@"fetchFbFriendsWithVideosCount http request url: %@\n  -[%@ , %@]",
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
                           NSStringFromSelector(_cmd));;
                    
                } else if ([jsonObject isKindOfClass:[NSArray class]]){
                    
                    NSArray *arrFriends = (NSArray *)jsonObject;
                    PRPLog(@"Deserialized JSON Array = %@-[%@ , %@]",
                           arrFriends,
                           NSStringFromClass([self class]),
                           NSStringFromSelector(_cmd)); 
                    
                    [arrFriends enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop){
                        NSDictionary* dicRecord = (NSDictionary*)obj;
                        BRRecordFriend* record = [[BRRecordFriend alloc] initWithJsonDic:dicRecord];
                        
                        [mArrTemp addObject:record];
                        
                    }];
                    self.mArrFriends = mArrTemp;
                    
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
                
            } else if (error != nil){
                
                PRPLog(@"An error happened while deserializing the JSON data.\n %@-[%@ , %@]",
                       error,
                       NSStringFromClass([self class]),
                       NSStringFromSelector(_cmd));    
                errMsg = [NSString stringWithFormat:@"An error happened while deserializing the JSON data %@",  [error description]];
            }
        } else if ([data length] == 0 &&
                 error == nil){
            PRPLog(@"No data was returned.-[%@ , %@]",
                   (unsigned long)[data length],
                   NSStringFromClass([self class]),
                   NSStringFromSelector(_cmd));
            errMsg = @"No data was returned.";
        } else if (error != nil){
            PRPLog(@"Error happened = %@-[%@ , %@]",
                   [error description],
                   NSStringFromClass([self class]),
                   NSStringFromSelector(_cmd));
            errMsg = [NSString stringWithFormat:@"Error happened = %@",  [error description]];
        }
        
        dispatch_sync(dispatch_get_main_queue(), ^(){
            
            NSDictionary *userInfo;
                if(nil != errMsg){
                    userInfo = @{@"error": errMsg};
                } else {
                    userInfo = @{@"mArrTemp": [mArrTemp mutableCopy]};
                    
                }
            block(userInfo); 
            
        });

        
    });
    
 
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
            NSLog(@"Error getting user facebook info: %@",error);
        }
        else
        {     
           dispatch_sync(dispatch_get_main_queue(), ^{
               
                // Facebook's me/friends Graph API returns a root dictionary
                resultD = (NSDictionary *) [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
                
                NSDictionary* error = resultD[@"error"];
                NSString* errorMsg = error[@"message"];
                if(nil != error){
                
                    NSDictionary *userInfo = @{@"error":errorMsg};
                    [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationFacebookMeDidUpdate object:self userInfo:userInfo];
                    return;
                }
                
                weakSelf.fbMe = resultD;
                weakSelf.fbName = [resultD objectForKey:@"name"];
                weakSelf.fbId = [resultD objectForKey:@"id"];
               
               NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
               [defaults setObject:weakSelf.fbId forKey:KUserDefaultFbId];
               [defaults setObject:weakSelf.fbName forKey:KUserDefaultFbName];
               [defaults synchronize];
               
                PRPLog(@"Facebook returned friends: %@ -[%@ , %@]",
                       resultD,
                       NSStringFromClass([self class]),
                       NSStringFromSelector(_cmd));
//                //update the view on the main thread
                NSDictionary *userInfo = @{@"FacebookMe":resultD,
               @"msg": self.lang[@"actionFbAuthOkYouCanDoItAgain"]};
                [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationFacebookMeDidUpdate object:self userInfo:userInfo];
            });
        }
    }];
}


#pragma mark mainCategories
- (void)fetchMainCategoriesWithPage:(NSNumber*)page
                          WithBlock:(void (^)(NSDictionary* userInfo))block{
    
    if (nil == self.fbId) {
        self.currentFacebookAction = FacebookActionGetMe;
        [self authenticateWithFacebook];
        return;
    }
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
        NSString* fbId;
        if(nil != self.fbId) {
            fbId = self.fbId;
        } else {
            fbId = @"";
        }
        NSString* urlMainCategores = [NSString stringWithFormat:@"%@/MainCategories", BASE_URL];
        urlMainCategores = [urlMainCategores stringByAppendingFormat:@"?page=%d&fbId=%@", [page intValue], fbId];
        NSURL *url = [NSURL URLWithString:urlMainCategores];
        
        //NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
        [urlRequest setTimeoutInterval:30.0f];
        [urlRequest setHTTPMethod:@"GET"];
        
        NSURLResponse *response;
        NSError *error;
        NSString* errMsg;
        NSNumber* page = @0;
        NSNumber* lastPage = @0;
        NSMutableArray* mArrTemp = [[NSMutableArray alloc] init];
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
                        
                        [mArrTemp addObject:record];
                        //[self.mainCategories addObject: record];
                        //[self.mainCategories insertObject:record atIndex:0];

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

            NSDictionary *userInfo;
            if(nil != errMsg){
                userInfo = @{@"error":errMsg};
            } else {
                userInfo = @{
                @"docs": [mArrTemp mutableCopy],
                @"page":page,
                @"lastPage": lastPage};
                
            }
            block(userInfo);
            
//            NSDictionary *userInfo = @{@"errMsg":errMsg,
//                                       @"docs": [self.mainCategories mutableCopy],
//                                        @"page":page,
//                                        @"lastPage": lastPage};
//            
//            [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationMainCategoriesDidUpdate object:self userInfo:userInfo];
        
        });
        
    });
}

- (void)fetchMainCategoriesFavoriteWithPage:(NSNumber*)page
                                       byFB:(NSString*)fbId
                                  WithBlock:(void (^)(NSDictionary* userInfo))block{
    
    if (nil == fbId) {
        self.currentFacebookAction = FacebookActionGetMe;
        [self authenticateWithFacebook];
        return;
    }


    //[self.mainCategories removeAllObjects];
    dispatch_queue_t concurrentQueue = 
    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    /* If we have not already saved an array of 10,000
     random numbers to the disk before, generate these numbers now
     and then save them to the disk in an array */
    dispatch_async(concurrentQueue, ^{
        NSString* urlMainCategores = [NSString stringWithFormat:@"%@/MainCategories", BASE_URL];
        urlMainCategores = [urlMainCategores stringByAppendingFormat:@"?page=%d&fbId=%@&favorite=yes", [page intValue], fbId];
        NSURL *url = [NSURL URLWithString:urlMainCategores];
        
        //NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
        [urlRequest setTimeoutInterval:30.0f];
        [urlRequest setHTTPMethod:@"GET"];
        
        NSURLResponse *response;
        NSError *error;
        NSString* errMsg;
        NSNumber* page = @0;
        NSNumber* lastPage = @0;
        NSMutableArray* mArrTemp = [[NSMutableArray alloc] init];
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
                    
                    page = (NSNumber*)[deserializedDictionary objectForKey:@"page"];
                    lastPage = (NSNumber*) [deserializedDictionary objectForKey:@"lastPage"]; 
                    
                    NSArray* MainCategories = [deserializedDictionary objectForKey:@"MainCategories"];     
                    
                    PRPLog(@"MainCategories.count:%d, page= %@  lastPage= %@  -[%@ , %@]",
                           MainCategories.count,
                           page,
                           lastPage,
                           NSStringFromClass([self class]),
                           NSStringFromSelector(_cmd));

                    [MainCategories enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop){
                        //create an instance of BRDBirthdayImport
                        NSDictionary* dicRecord = (NSDictionary*)obj;
                        BRRecordMainCategory* record = [[BRRecordMainCategory alloc] initWithJsonDic:dicRecord];
                        [mArrTemp addObject:record];
                        
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
            
            NSDictionary *userInfo;
            if(nil != errMsg){
                userInfo = @{@"error":errMsg};
            } else {
                
                userInfo = @{
                @"docs": [mArrTemp mutableCopy],
                @"page":page,
                @"lastPage": lastPage};
                
            }
            block(userInfo);
        });
        
    });

}
-(void)toggleFavoriteMainCateogry:(NSString*)sn
                              uid:(NSString*)uid
                           byFbid:(NSString*)fbId
                      withNewBool:(BOOL)isMyFavorite
                  inSelectedIndex:(int)selectedIndex
                        WithBlock:(void (^)(NSDictionary* userInfo))block{

    if (nil == fbId) {
        self.currentFacebookAction = FacebookActionGetMe;
        [self authenticateWithFacebook];
        return;
    }
    
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
        NSString* urlMainCategoresUpdFollowers = [NSString stringWithFormat:@"%@/MainCategories/%@", BASE_URL, sn];
        NSURL *url = [NSURL URLWithString:urlMainCategoresUpdFollowers];
        
        //NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
        [urlRequest setTimeoutInterval:30.0f];
        [urlRequest setHTTPMethod:@"POST"];
        NSString* actioinDoFavorite = (!isMyFavorite)?@"add":@"del";
        NSString *body = [NSString stringWithFormat:@"fbId=%@&mainCategoryId=%@&actioinDoFavorite=%@&_method=%@", fbId, uid, actioinDoFavorite, @"put"];
        
        [urlRequest setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
        
        NSURLResponse *response;
        NSError *error;
        NSString* errMsg;
        NSString* msg;

        NSData *data = [NSURLConnection sendSynchronousRequest:urlRequest
                                             returningResponse:&response
                                                         error:&error];
        PRPLog(@"urlMainCategoresUpdFollowers: %@\n  -[%@ , %@]",
               urlMainCategoresUpdFollowers,
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
                    
                    msg = [deserializedDictionary objectForKey:@"msg"]; 
                    
                    NSString* error = [deserializedDictionary objectForKey:@"error"]; 
                    if(error) errMsg = error;

                    
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
            
            NSDictionary *userInfo;
            
            if(nil != errMsg){
                userInfo = @{@"error":errMsg};
            } else {
                
               userInfo = @{@"updedIndex":[NSNumber numberWithInt:selectedIndex]
                ,@"msg": msg};
            }
            
            block(userInfo);
            
//            [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationMainCategoriesDidUpdate object:self userInfo:userInfo];
            
        });
        
    });
}

-(void)toggleFavoriteVideo:(NSString*)uid
                    byFbid:(NSString*)fbId
               withBool:(BOOL)isMyFavorite
           inSelectedIndex:(int)selectedIndex
                 WithBlock:(void (^)(NSDictionary* userInfo))block{
    
    if (nil == fbId) {
        self.currentFacebookAction = FacebookActionGetMe;
        [self authenticateWithFacebook];
        return;
    }
    
    dispatch_queue_t concurrentQueue = 
    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    /* If we have not already saved an array of 10,000
     random numbers to the disk before, generate these numbers now
     and then save them to the disk in an array */
    dispatch_async(concurrentQueue, ^{

        NSString* urlVideoFavoriteToggleFollowers;
        urlVideoFavoriteToggleFollowers = [NSString stringWithFormat:@"%@/coffeecup/VideoFollower/create", BASE_URL];
        NSString* actionVideoToggleFavorite = (!isMyFavorite)?@"add":@"del";
        
        NSURL *url = [NSURL URLWithString:urlVideoFavoriteToggleFollowers];
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
        [urlRequest setTimeoutInterval:30.0f];
        NSString *body = [NSString stringWithFormat:@"actionVideoToggleFavorite=%@&fbId=%@&videoId=%@", actionVideoToggleFavorite, fbId, uid];
        [urlRequest setHTTPMethod:@"POST"];
        [urlRequest setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
                
        NSURLResponse *response;
        NSError *error;
        NSString* errMsg;
        NSString* msg;
        
        NSData *data = [NSURLConnection sendSynchronousRequest:urlRequest
                                             returningResponse:&response
                                                         error:&error];
        PRPLog(@"urlMainCategoresUpdFollowers: %@\n  body: %@-[%@ , %@]",
               urlVideoFavoriteToggleFollowers,
               body,
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
                    
                    msg = [deserializedDictionary objectForKey:@"msg"]; 
                    
                    NSString* error = [deserializedDictionary objectForKey:@"error"]; 
                    if(error) errMsg = error;
                    
                    
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
            
            NSDictionary *userInfo;
            
            if(nil != errMsg){
                userInfo = @{@"error":errMsg};
            } else {
                
                userInfo = @{@"updedIndex":[NSNumber numberWithInt:selectedIndex]
                ,@"msg": msg};
            }
            
            block(userInfo);            
        });
        
    });

}

-(NSMutableArray*)mainCategoriesSort:(NSMutableArray*)docs{

     NSMutableArray* tempDocs = [[docs sortedArrayUsingComparator: ^(id a, id b) {
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
    
    return tempDocs;
}


#pragma mark subCategories
- (void)fetchSubCategoriesWithPage:(NSNumber*)page
                   mainCategoryUid:(NSString*)mainCategoryUid
withBlock:(void (^)(NSDictionary* userInfo))block{
    
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
        urlMainCategores = [urlMainCategores stringByAppendingFormat:@"?main=%@", mainCategoryUid];
        NSURL *url = [NSURL URLWithString:urlMainCategores];
        
        //NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
        [urlRequest setTimeoutInterval:30.0f];
        [urlRequest setHTTPMethod:@"GET"];
        
        NSURLResponse *response;
        NSError *error;
        NSString* errMsg;
        NSNumber* page = @0;
        NSNumber* lastPage = @0;
        NSMutableArray* mArrTemp = [[NSMutableArray alloc] init];

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
                        [mArrTemp addObject:record];
                        //[self.subCategories insertObject:record atIndex:0];
                        
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
            
            NSDictionary *userInfo;
            if(nil != errMsg){
                userInfo = @{@"error":errMsg};
            } else {
                userInfo = @{
                @"mTempArr": [mArrTemp mutableCopy],
                @"page":page,
                @"lastPage": lastPage};
            }
            block(userInfo);            
//            NSDictionary *userInfo = @{@"errMsg":errMsg,
//            @"page":page,
//            @"lastPage": lastPage};
//            
//            [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationSubCategoriesDidUpdate object:self userInfo:userInfo];
            
        });
        
    });
}

-(NSMutableArray*)subCategoriesSort:(NSMutableArray*)docs;{
    
    NSMutableArray* tempDocs = [[docs sortedArrayUsingComparator: ^(id a, id b) {
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
    return tempDocs;
}


#pragma mark Videos
//-(NSMutableArray*)videos{
//    
//    if(!_videos){
//        _videos = [NSMutableArray array];
//    }
//    return _videos;
//}

- (void)fetchVideosWithPage:(NSNumber*)page
    withSubCategoryId:(NSString*)subCategoryId
    withBlock:(void (^)(NSDictionary* userInfo))block{
    
    //[self.mainCategories removeAllObjects];
    
    dispatch_queue_t concurrentQueue = 
    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    /* If we have not already saved an array of 10,000
     random numbers to the disk before, generate these numbers now
     and then save them to the disk in an array */
    dispatch_async(concurrentQueue, ^{
        
        NSString* fbId;
        if(nil != self.fbId) {
            fbId = self.fbId;
        } else {
            fbId = @"";
        }
        
        NSString* urlVideos= [NSString stringWithFormat:@"%@/Videos", BASE_URL];
        urlVideos = [urlVideos stringByAppendingFormat:@"?page=%d", [page intValue]];
        urlVideos = [urlVideos stringByAppendingFormat:@"&sub=%@&fbId=%@", subCategoryId, fbId];
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
        NSString* errMsg;
        NSNumber* page = @0;
        NSNumber* lastPage = @0;
        NSMutableArray* mArrTemp = [[NSMutableArray alloc] init];
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
                            [mArrTemp addObject:record];
                            //[self.subCategories addObject: record];
                            //[self.videos insertObject:record atIndex:0];
                            
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
            
            NSDictionary *userInfo;
            
            if(nil != errMsg){
                userInfo = @{@"error":errMsg};
            } else {
                userInfo = @{
                @"mTempArr": [mArrTemp mutableCopy],
                @"page":page,
                @"lastPage": lastPage};
            }
            block(userInfo);   
            
//            [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationVideosDidUpdate object:self userInfo:userInfo];
            
        });
        
    });
}
- (void)fetchUserFavoriteVideosWithPage:(NSNumber*)page 
                                   fbId:(NSString*)fbId
                              withBlock:(void (^)(NSDictionary* userInfo))block{

    
    if (nil == fbId) {
        self.currentFacebookAction = FacebookActionGetMe;
        [self authenticateWithFacebook];
        return;
    }
    
    dispatch_queue_t concurrentQueue = 
    dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    /* If we have not already saved an array of 10,000
     random numbers to the disk before, generate these numbers now
     and then save them to the disk in an array */
    dispatch_async(concurrentQueue, ^{
        
        NSString* userFavoriteVideosurlVideos= [NSString stringWithFormat:@"%@/Videos?page=%d&favorite=yes&fbId=%@", BASE_URL, [page intValue], fbId];
        PRPLog(@"http userFavoriteVideosurlVideos : %@\n  -[%@ , %@]",
               userFavoriteVideosurlVideos,
               NSStringFromClass([self class]),
               NSStringFromSelector(_cmd));
        NSURL *url = [NSURL URLWithString:userFavoriteVideosurlVideos];
          
        //NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
        [urlRequest setTimeoutInterval:30.0f];
        [urlRequest setHTTPMethod:@"GET"];
        
        NSURLResponse *response;
        NSError *error;
        NSString* errMsg;
        NSNumber* page = @0;
        NSNumber* lastPage = @0;
        NSMutableArray* mArrTemp = [[NSMutableArray alloc] init];
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
                        NSArray* videos = [deserializedDictionary objectForKey:@"docs"]; 
                        
                        [videos enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop){
                            //create an instance of BRDBirthdayImport
                            NSDictionary* dicRecord = (NSDictionary*)obj;
                            BRRecordVideo* record = [[BRRecordVideo alloc] initWithJsonDic:dicRecord];
                            [mArrTemp addObject:record];
                            //[self.subCategories addObject: record];
                            //[self.videos insertObject:record atIndex:0];
                            
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
            
            NSDictionary *userInfo;
            
            if(nil != errMsg){
                userInfo = @{@"error":errMsg};
            } else {
                userInfo = @{
                @"mTempArr": [mArrTemp mutableCopy],
                @"page":page,
                @"lastPage": lastPage};
            }
            block(userInfo);   
            
            //            [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationVideosDidUpdate object:self userInfo:userInfo];
            
        });
        
    });
}

- (void)fetchVideoByUid:(NSString*)uid
withBlock:(void (^)(NSDictionary* userInfo))block
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
        NSString* errMsg;
        NSDictionary* tempDic = [[NSDictionary alloc] init];
  
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
                        tempDic = videoDic;
//                        self.currentSelectedVideo = [[BRRecordVideo alloc] initWithJsonDic:videoDic];
                        
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

            NSDictionary *userInfo;
            
            if(nil != errMsg){
                userInfo = @{@"error":errMsg};
            } else {
                userInfo = @{
                @"tempDic": tempDic};
            }
            block(userInfo);   
            
            
//            NSDictionary *userInfo = @{@"errMsg":errMsg};
//            [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationVideoDidUpdate object:self userInfo:userInfo];
            
        });
        
    });
}

- (BRRecordVideo*)findVideoByYoutubeKey:(NSString*)youtubeKey fromDocs:(NSMutableArray*)docs
{
    __block BRRecordVideo* video;
    
    [docs enumerateObjectsUsingBlock:^(id obj , NSUInteger idx, BOOL *stop){
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

- (void)postMsg:(NSString*)message
      ByVideoId:(NSString*)videoId
           fbId:(NSString*)fbId 
         fbName:(NSString*)fbNmae{
    
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
        NSString* regUdidUrl = [NSString stringWithFormat:@"%@/coffeecup/videoMsg/create", BASE_URL];
        PRPLog(@"http regUdidUrl url: %@\n  -[%@ , %@]",
               regUdidUrl,
               NSStringFromClass([self class]),
               NSStringFromSelector(_cmd));
        
        NSURL *url = [NSURL URLWithString:regUdidUrl];
        //NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
        [urlRequest setTimeoutInterval:30.0f];
        [urlRequest setHTTPMethod:@"POST"];
        
        NSString *body = [NSString stringWithFormat:@"message=%@&videoId=%@&fbId=%@&fbName=%@", message, videoId, fbId, fbNmae];
        
       // NSString *body = @"message=videoId&fbId=BodyValue2";

        [urlRequest setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
        
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
            
            NSDictionary *userInfo = @{@"error":errMsg};
            
            [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationDidPostVideoMsg object:self userInfo:userInfo];
            
        });
        
    });

}
- (void)fetchVideoMsgsByVideoId:(NSString*)videoId
                     withPage:(NSNumber*)page{
    
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
        NSString* urlGetVideoMsgsUrl = [NSString stringWithFormat:@"%@/coffeecup/VideoMsg?videoId=%@&page=%@", BASE_URL, videoId, [page stringValue]];
        PRPLog(@"http request urlGetVideoMsgsUrl: %@\n  -[%@ , %@]",
               urlGetVideoMsgsUrl,
               NSStringFromClass([self class]),
               NSStringFromSelector(_cmd));
        
        NSURL *url = [NSURL URLWithString:urlGetVideoMsgsUrl];
        //NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
        [urlRequest setTimeoutInterval:30.0f];
        [urlRequest setHTTPMethod:@"GET"];
        
        NSURLResponse *response;
        NSError *error;
        NSString* errMsg;
        NSNumber* isLastPage;
        NSNumber* page;
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
                        NSArray* arrMsgs = [deserializedDictionary objectForKey:@"msgs"];
                        isLastPage = (NSNumber*) [deserializedDictionary objectForKey:@"lastPage"];
                        page = (NSNumber*)[deserializedDictionary objectForKey:@"page"];
                        if(nil == self.videoMsgs 
                           || [page integerValue] == 0
                           || [arrMsgs count] == 0
                           ){
                            self.videoMsgs = [[NSMutableArray alloc] init];
                            
                            
                        }

                        [arrMsgs enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop){
                            
                            NSDictionary* dicRecord = (NSDictionary*)obj;
                            BRRecordMsgBoard* record = [[BRRecordMsgBoard alloc] initWithJsonDic:dicRecord];
                            [self.videoMsgs addObject:record];
                            
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
            
            NSDictionary *userInfo = @{@"isLastPage": isLastPage, @"page": page};
            if(nil != errMsg){
                userInfo = @{@"error":errMsg};
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationGetVideoMsgsDidUpdate object:self userInfo:userInfo];
        });
        
    });
}

-(void)delMsgById:(NSString*)msgId
            VideoId:(NSString*)videoId{
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
        NSString* urlDelVideoMsgsUrl = [NSString stringWithFormat:@"%@/coffeecup/VideoMsg/%@", BASE_URL, msgId];
        
        PRPLog(@"http urlDelVideoMsgsUrl: %@\n  -[%@ , %@]",
               urlDelVideoMsgsUrl,
               NSStringFromClass([self class]),
               NSStringFromSelector(_cmd));
        
        NSURL *url = [NSURL URLWithString:urlDelVideoMsgsUrl];
        //NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
        NSString *body = [NSString stringWithFormat:@"videoId=%@", videoId];
        [urlRequest setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];

        [urlRequest setTimeoutInterval:30.0f];
        [urlRequest setHTTPMethod:@"DELETE"];
        
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
        
//        dispatch_async(dispatch_get_main_queue(), ^{
//            
//            NSDictionary *userInfo = @{@"errMsg":errMsg};
//            [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationSocketURLDidUpdate object:self userInfo:userInfo];
//        });
        
    });
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
        NSString* errMsg;
        
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
            NSDictionary *userInfo;
            if(nil != errMsg){
                userInfo = @{@"error":errMsg};
            } 
            [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationSocketURLDidUpdate object:self userInfo:userInfo];
        });
        
    });
}

- (void)registerUdid:(NSString*)udid
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
        NSString* regUdidUrl = [NSString stringWithFormat:@"%@/coffeecup/Apns/create", BASE_URL];
        PRPLog(@"http regUdidUrl url: %@\n  -[%@ , %@]",
               regUdidUrl,
               NSStringFromClass([self class]),
               NSStringFromSelector(_cmd));
        
        NSURL *url = [NSURL URLWithString:regUdidUrl];
        //NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
        [urlRequest setTimeoutInterval:30.0f];
        [urlRequest setHTTPMethod:@"POST"];
        
        NSString *body = [NSString stringWithFormat:@"udid=%@", udid];
        [urlRequest setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
        
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
            [[NSNotificationCenter defaultCenter] postNotificationName:BRNotificationRegisterUdidDidUpdate object:self userInfo:userInfo];
            
        });
        
    });
}

     
- (void)postToFacebookWall:(NSString *)message withFacebookID:(NSString *)facebookID
{
    
    /*
     Feed story publishing to other users is disabled for this application
     
     ou probably created this Facebook application recently, which means the February 2013 breaking changes are enabled.
     
     February's Breaking Changes include:
     
     Removing ability to post to friends walls via Graph API
     
     We will remove the ability to post to a user's friends' walls via the Graph API. Specifically, posts against [user_id]/feed where [user_id] is different from the session user, or stream.publish calls where the target_id user is different from the session user, will fail. If you want to allow people to post to their friends' timelines, invoke the feed dialog. Stories that include friends via user mentions tagging or action tagging will show up on the friend’s timeline (assuming the friend approves the tag). For more info, see this blog post.
     
     We are disabling this feature starting in February, if you wish to enable it (only temporarily until February), 
     
     
     go to your app dashboard > Settings > Advanced > Disable "February 2013 Breaking Changes"
     
     
     
     I highly recommend against doing so, however, since starting February this functionality will cause your app to throw the same error again.
     

     
     */
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
