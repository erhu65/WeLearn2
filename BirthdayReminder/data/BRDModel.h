//
//  BRDModel.h
//  BirthdayReminder
//
//  Created by Nick Kuh on 26/07/2012.
//  Copyright (c) 2012 Nick Kuh. All rights reserved.
//
#define BRNotificationFacebookMeDidUpdate        @"BRNotificationFacebookMeDidUpdate"

#define BRNotificationAddressBookBirthdaysDidUpdate        @"BRNotificationAddressBookBirthdaysDidUpdate"
#define BRNotificationFacebookBirthdaysDidUpdate            @"BRNotificationFacebookBirthdaysDidUpdate"
#define BRNotificationCachedBirthdaysDidUpdate          @"BRNotificationCachedBirthdaysDidUpdate"

#define BRNotificationMainCategoriesDidUpdate            @"BRNotificationMainCategoriesDidUpdate"

#define BRNotificationSubCategoriesDidUpdate            @"BRNotificationSubCategoriesDidUpdate"

#define BRNotificationVideosDidUpdate            @"BRNotificationVideosDidUpdate"
#define BRNotificationVideoDidUpdate            @"BRNotificationVideoDidUpdate"

#define BRNotificationSocketURLDidUpdate            @"BRNotificationSocketURLDidUpdate"


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


@property(nonatomic, strong)NSDictionary* fbMe;
@property(nonatomic, strong)NSString* fbName;
@property(nonatomic, strong)NSString* fbId;

@property (nonatomic,readonly) NSArray *addressBookBirthdays;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

- (void)saveChanges;
- (void)cancelChanges;

-(NSMutableDictionary *) getExistingBirthdaysWithUIDs:(NSArray *)uids;

- (void)fetchAddressBookBirthdays;
- (void)fetchFacebookBirthdays;
- (void)fetchFacebookMe;

@property BOOL  mainCategoriesSortIsDesc;
@property mainCategoriesSortType mainCategoriesSortType;
@property(nonatomic, strong)NSMutableArray* mainCategories;
@property(nonatomic, strong)NSString* mainCategoriesSelectedUid;
@property(nonatomic, strong)BRRecordMainCategory* currentSelectMainCategory;
- (void)fetchMainCategoriesWithPage:(NSNumber*)page;
-(void)mainCategoriesSort;

@property BOOL  subCategoriesSortIsDesc;
@property subCategoriesSortType subCategoriesSortType;
@property(nonatomic, strong)NSMutableArray* subCategories;
@property(nonatomic, strong)NSString* subCategoriesSelectedUid;
@property(nonatomic, strong)BRRecordSubCategory* currentSelectSubCategory;
- (void)fetchSubCategoriesWithPage:(NSNumber*)page;
-(void)subCategoriesSort;



@property(nonatomic, strong)NSMutableArray* videos;
@property(nonatomic, strong)NSMutableArray* videosTemp;
@property(nonatomic, strong)NSString* videoSelectedUid;
@property(nonatomic, strong)BRRecordVideo* currentSelectedVideo;

@property(nonatomic, strong)NSString* socketUrl;

- (void)fetchVideosWithPage:(NSNumber*)page;
- (void)fetchVideoByUid:(NSString*)uid;
- (void)filterVideoByNameOrDesc:(NSString*)strSearch;
- (BRRecordVideo*)findVideoByYoutubeKey:(NSString*)youtubeKey;


- (void)getSocketUrl;


-(void) importBirthdays:(NSArray *)birthdaysToImport;
- (void)postToFacebookWall:(NSString *)message withFacebookID:(NSString *)facebookID;

-(void) updateCachedBirthdays;


@end
