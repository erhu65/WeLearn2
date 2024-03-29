//
//  BRDModel.h
//  BirthdayReminder
//
//  Created by Nick Kuh on 26/07/2012.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//
#define BRNotificationFacebookMeDidUpdate        @"BRNotificationFacebookMeDidUpdate"

#define BRNotificationFacebookFriendsDidUpdate        @"BRNotificationFacebookFriendsDidUpdate"

#define BRNotificationAddressBookBirthdaysDidUpdate        @"BRNotificationAddressBookBirthdaysDidUpdate"
#define BRNotificationFacebookBirthdaysDidUpdate            @"BRNotificationFacebookBirthdaysDidUpdate"
#define BRNotificationCachedBirthdaysDidUpdate          @"BRNotificationCachedBirthdaysDidUpdate"

#define BRNotificationMainCategoriesDidUpdate            @"BRNotificationMainCategoriesDidUpdate"

#define BRNotificationSubCategoriesDidUpdate            @"BRNotificationSubCategoriesDidUpdate"

#define BRNotificationVideosDidUpdate            @"BRNotificationVideosDidUpdate"
#define BRNotificationVideoDidUpdate            @"BRNotificationVideoDidUpdate"

#define BRNotificationGetVideoMsgsDidUpdate @"BRNotificationGetVideoMsgsDidUpdate"
#define BRNotificationDidPostVideoMsg @"BRNotificationPostVideoMsgDidUpdate"

#define BRNotificationSocketURLDidUpdate            @"BRNotificationSocketURLDidUpdate"
#define BRNotificationRegisterUdidDidUpdate            @"BRNotificationRegisterUdidDidUpdate"


typedef enum mainCategoriesSortType {
    mainCategoriesSortTypeNoSort = 0,
    mainCategoriesSortTypeSortByName = 1,
    mainCategoriesSortTypeSortByDate = 2
    
} mainCategoriesSortType;

typedef enum subCategoriesSortType {
    subCategoriesSortTypeNoSort = 0,
    subCategoriesSortTypeSortByName = 1,
    subCategoriesSortTypeSortByDate = 2
    
} subCategoriesSortType;

@class BRRecordMainCategory;
@class BRRecordSubCategory;
@class BRRecordVideo;
@class ACAccount;

@interface BRDModel : NSObject

+ (BRDModel*)sharedInstance;

@property (nonatomic, strong) ACAccount* facebookAccount;
@property(nonatomic, strong)NSDictionary* lang;
@property(nonatomic, strong)NSDictionary* theme;

@property(nonatomic, strong)NSDictionary* fbMe;
@property(nonatomic, strong)NSString* fbName;
@property(nonatomic, strong)NSString* fbId;
@property(nonatomic, strong)NSString* access_token;

@property(nonatomic, assign)BOOL isEnebleToggleFavorite;

@property(nonatomic, strong)NSMutableArray* mArrFriends;
@property (nonatomic,readonly) NSArray *addressBookBirthdays;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

- (void)saveChanges;
- (void)cancelChanges;

-(NSMutableDictionary *) getExistingBirthdaysWithUIDs:(NSArray *)uids;
- (void)fetchAddressBookBirthdays;
- (void)fetchFacebookBirthdays;
- (void)fetchFbFriendsWithVideosCount:(NSString*)access_token fbId:(NSString*)fbId
withBlock:(void (^)(NSDictionary* userInfo))block;

- (void)fetchFacebookMe;

@property BOOL mainCategoriesSortIsDesc;
@property BOOL isUserMainCategoryFavoriteNeedUpdate;
@property BOOL isUserVideoFavoriteNeedUpdate;
@property mainCategoriesSortType mainCategoriesSortType;

- (void)fetchMainCategoriesFavoriteWithPage:(NSNumber*)page
                                       byFB:(NSString*)fbId
                                  WithBlock:(void (^)(NSDictionary* userInfo))block;

- (void)fetchMainCategoriesWithPage:(NSNumber*)page 
                          WithBlock:(void (^)(NSDictionary* userInfo))block;
-(void)toggleFavoriteMainCateogry:(NSString*)sn
                              uid:(NSString*)uid
                           byFbid:(NSString*)fbId
                      withNewBool:(BOOL)isMyFavorite
                  inSelectedIndex:(int)selectedIndex
WithBlock:(void (^)(NSDictionary* userInfo))block;
-(NSMutableArray*)mainCategoriesSort:(NSMutableArray*)docs;


@property BOOL  subCategoriesSortIsDesc;
@property subCategoriesSortType subCategoriesSortType;

- (void)fetchSubCategoriesWithPage:(NSNumber*)page 
                   mainCategoryUid:(NSString*)mainCategoryUid
withBlock:(void (^)(NSDictionary* userInfo))block;

-(NSMutableArray*)subCategoriesSort:(NSMutableArray*)docs;

-(void)toggleFavoriteVideo:(NSString*)uid
                           byFbid:(NSString*)fbId
                      withBool:(BOOL)isMyFavorite
                  inSelectedIndex:(int)selectedIndex
                        WithBlock:(void (^)(NSDictionary* userInfo))block;

//@property(nonatomic, strong)NSMutableArray* videoMsgs;

@property(nonatomic, strong)NSString* socketUrl;

- (void)fetchVideosWithPage:(NSNumber*)page 
          withSubCategoryId:(NSString*)subCategoryId
                  withBlock:(void (^)(NSDictionary* userInfo))block;
- (void)fetchUserFavoriteVideosWithPage:(NSNumber*)page 
          fbId:(NSString*)fbId
                  withBlock:(void (^)(NSDictionary* userInfo))block;

- (void)fetchVideoByUid:(NSString*)uid
withBlock:(void (^)(NSDictionary* userInfo))block;
//- (void)filterVideoByNameOrDesc:(NSString*)strSearch;
- (BRRecordVideo*)findVideoByYoutubeKey:(NSString*)youtubeKey fromDocs:(NSMutableArray*)docs;

- (void)postMsg:(NSString*)message
    ByVideoId:(NSString*) videoId
           fbId:(NSString*)fbId 
         fbName:(NSString*)fbNmae;

- (void)fetchVideoMsgsByVideoId:(NSString*)videoId 
                     withPage:(NSNumber*)page
withBlock:(void (^)(NSDictionary* userInfo))block;
-(void)delMsgById:(NSString*)msgId
          VideoId:(NSString*)videoId;



- (void)getSocketUrl;
- (void)registerUdid:(NSString*)udid;
- (void)getProductsWithBlock:(void (^)(NSDictionary* userInfo))block;

-(void) importBirthdays:(NSArray *)birthdaysToImport;
- (void)postToFacebookWall:(NSString *)message withFacebookID:(NSString *)facebookID;

-(void) updateCachedBirthdays;


@end
