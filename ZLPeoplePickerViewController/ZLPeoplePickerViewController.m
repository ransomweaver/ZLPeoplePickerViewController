//
//  ZLPeoplePickerViewController.m
//  ZLPeoplePickerViewControllerDemo
//
//  Created by Zhixuan Lai on 11/4/14.
//  Copyright (c) 2014 Zhixuan Lai. All rights reserved.
//

#import "ZLPeoplePickerViewController.h"
#import "ZLResultsTableViewController.h"

#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>

#import "ZLAddressBook.h"
#import "APContact+Sorting.h"
#import "LRIndexedCollationWithSearch.h"

@interface ZLPeoplePickerViewController () <
ABPeoplePickerNavigationControllerDelegate, ABPersonViewControllerDelegate,
ABNewPersonViewControllerDelegate, ABUnknownPersonViewControllerDelegate,
UISearchBarDelegate, UISearchControllerDelegate, UISearchResultsUpdating>
@property (strong, nonatomic) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UISearchController *searchController;
@property (strong, nonatomic)
ZLResultsTableViewController *resultsTableViewController;

// for state restoration
@property BOOL searchControllerWasActive;
@property BOOL searchControllerSearchFieldWasFirstResponder;

@end

static NSMutableArray *cachedPartitionedContacts = nil;
static int matchCount = 0;
static NSArray * emailsToMatch = nil;

@implementation ZLPeoplePickerViewController

@dynamic refreshControl;    // getter and setter methods implemened by the superclass

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)setup {
    _numberOfSelectedPeople = ZLNumSelectionNone;
    self.filedMask = ZLContactFieldDefault;
    self.showAddButton = YES;
}

+ (void)setEmailsToMatch:(NSArray*)emails {
    emailsToMatch = emails;
}

+ (int)getMatchCount {
    return matchCount;
}

+ (void)initializeAddressBook {
    //[[ZLAddressBook sharedInstance] loadContacts:nil];
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // callback
        ZLAddressBookDidChangeContactsCallback didChangeContactsCallback = ^(NSArray *contacts) {
            NSUInteger sectionCount = [[[LRIndexedCollationWithSearch currentCollation] sectionTitles] count];
            NSMutableArray *sections = [NSMutableArray arrayWithCapacity:sectionCount];
            for (int i = 0; i < sectionCount; i++) {
                [sections addObject:@[].mutableCopy];
            }
            
            NSMutableSet *allPhoneNumbers = [NSMutableSet set];
            for (APContact *contact in contacts) {
                
                if (emailsToMatch && contact.emails.count > 0) {
                    for (NSString * email in contact.emails) {
                        if ([emailsToMatch containsObject:email]) {
                            matchCount++;
                        }
                    }
                    
                }
                
                // only display one linked contacts
                if(contact.phones && [contact.phones count] > 0 && ![allPhoneNumbers containsObject:contact.phones[0]]) {
                    [allPhoneNumbers addObject:contact.phones[0]];
                }
                
                // add new contact
                SEL selector = @selector(firstName);
                if (contact.lastNamePhonetic.length > 0) {
                    selector = @selector(lastNamePhonetic);
                } else if (contact.lastName.length > 0) {
                    selector = @selector(lastName);
                } else if (contact.firstNamePhonetic.length > 0) {
                    selector = @selector(firstNamePhonetic);
                } else if (contact.firstName.length == 0) {
                    selector = @selector(compositeName);
                }
                NSInteger index = [[LRIndexedCollationWithSearch currentCollation]
                                   sectionForObject:contact
                                   collationStringSelector:selector];
                // contact.sectionIndex = index;
                [sections[index] addObject:contact];
            }
            
            for (NSInteger i = 0; i < sections.count; i++) {
                NSArray *sorted = [sections[i] sortedArrayWithOptions:NSSortConcurrent usingComparator:^NSComparisonResult(id obj1, id obj2) {
                    return [[obj1 compositeName] compare:[obj2 compositeName] options:NSNumericSearch|NSForcedOrderingSearch];
                }];
                sections[i] = sorted;
            }
            
            cachedPartitionedContacts = [sections copy];
        };
        
        [ZLAddressBook sharedInstance].didChangeContactsCallback = didChangeContactsCallback;
        [[ZLAddressBook sharedInstance] loadContactsInBackground:^(BOOL succeeded, NSError *error) {
            didChangeContactsCallback([ZLAddressBook sharedInstance].contacts);
        }];
    });
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _resultsTableViewController = [[ZLResultsTableViewController alloc] init];
    _searchController = [[UISearchController alloc]
                         initWithSearchResultsController:self.resultsTableViewController];
    self.searchController.searchResultsUpdater = self;
    [self.searchController.searchBar sizeToFit];
    self.tableView.tableHeaderView = self.searchController.searchBar;
    
    // we want to be the delegate for our filtered table so
    // didSelectRowAtIndexPath is called for both tables
    self.resultsTableViewController.tableView.delegate = self;
    self.searchController.delegate = self;
    //    self.searchController.dimsBackgroundDuringPresentation = NO; //
    //    default is YES
    self.searchController.searchBar.delegate =
    self; // so we can monitor text changes + others
    
    // Search is now just presenting a view controller. As such, normal view
    // controller
    // presentation semantics apply. Namely that presentation will walk up the
    // view controller
    // hierarchy until it finds the root view controller or one that defines a
    // presentation context.
    //
    self.definesPresentationContext =
    YES; // know where you want UISearchController to be displayed
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.tableView addSubview:self.refreshControl];
    [self.refreshControl addTarget:self
                            action:@selector(refreshControlAction:)
                  forControlEvents:UIControlEventValueChanged];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    self.navigationItem.title = @"Contacts";
    if (self.title.length) {
        self.navigationItem.title = self.title;
    }
    if (_showAddButton) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                                  initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                  target:self
                                                  action:@selector(showNewPersonViewController)];
    }
    
    if (cachedPartitionedContacts) {
        [self setPartitionedContacts:cachedPartitionedContacts];
        [self.tableView reloadData];
    } else {
        [self refreshControlAction:self.refreshControl];
    }
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(addressBookDidChangeNotification:)
     name:ZLAddressBookDidChangeNotification
     object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // restore the searchController's active state
    if (self.searchControllerWasActive) {
        self.searchController.active = self.searchControllerWasActive;
        _searchControllerWasActive = NO;
        
        if (self.searchControllerSearchFieldWasFirstResponder) {
            [self.searchController.searchBar becomeFirstResponder];
            _searchControllerSearchFieldWasFirstResponder = NO;
        }
    }
}

- (void)didMoveToParentViewController:(UIViewController *)parent {
    if (![parent isEqual:self.parentViewController]) {
        [self invokeReturnDelegate];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:ZLAddressBookDidChangeNotification
     object:nil];
}

#pragma mark - Action
+ (instancetype)presentPeoplePickerViewControllerForParentViewController:
(UIViewController *)parentViewController {
    UINavigationController *navController =
    [[UINavigationController alloc] init];
    ZLPeoplePickerViewController *peoplePicker =
    [[ZLPeoplePickerViewController alloc] init];
    [navController pushViewController:peoplePicker animated:NO];
    peoplePicker.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                                     initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                     target:peoplePicker
                                                     action:@selector(doneButtonAction:)];
    peoplePicker.delegate = (id<ZLPeoplePickerViewControllerDelegate>)parentViewController;
    [parentViewController presentViewController:navController
                                       animated:YES
                                     completion:nil];
    return peoplePicker;
}

- (void)doneButtonAction:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
    [self invokeReturnDelegate];
}

- (void)refreshControlAction:(UIRefreshControl *)aRefreshControl {
    [aRefreshControl beginRefreshing];
    [self reloadData:^(BOOL succeeded, NSError *error) {
        [aRefreshControl endRefreshing];
    }];
}

- (void)addressBookDidChangeNotification:(NSNotification *)note {
    //NSLog(@"didChangeNotification!");
    //[self performSelector:@selector(reloadData) withObject:nil];
    
    __weak __typeof(self) weakSelf = self;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (cachedPartitionedContacts) {
            [weakSelf setPartitionedContacts:cachedPartitionedContacts];
        } else {
            [weakSelf setPartitionedContactsWithContacts:[ZLAddressBook sharedInstance].contacts];
        }
        [weakSelf.tableView reloadData];
    });
}

- (void)reloadData {
    [self reloadData:nil];
}

- (void)reloadData:(void (^)(BOOL succeeded, NSError *error))completionBlock {
    
    //NSLog(@"start.");
    __block NSArray *contacts = @[];
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [[ZLAddressBook sharedInstance] loadContactsInBackground:^(BOOL succeeded, NSError *error) {
        if (!error) {
            contacts = [ZLAddressBook sharedInstance].contacts;
        }
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(succeeded, error);
            });
        }
        //NSLog(@"complete.");
        dispatch_semaphore_signal(semaphore);
    }];
    
    //NSLog(@"wait...");
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    [self setPartitionedContactsWithContacts:contacts];
    [self.tableView reloadData];
    
    //NSLog(@"finish.");
}

#pragma mark - UISearchBarDelegate

- (void)searchBarCancelButtonClicked:(UISearchBar *)aSearchBar {
    [aSearchBar resignFirstResponder];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)aSearchBar {
    [aSearchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)aSearchBar {
    [aSearchBar setShowsCancelButton:NO animated:YES];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    APContact *contact = [self contactForRowAtIndexPath:indexPath];
    
    if (![tableView isEqual:self.tableView]) {
        contact = [(ZLResultsTableViewController *)
                   self.searchController.searchResultsController
                   contactForRowAtIndexPath:indexPath];
    }
    
    if (![self shouldEnableCellforContact:contact]) {
        return;
    }
    
    if (self.delegate &&
        [self.delegate
         respondsToSelector:@selector(peoplePickerViewController:
                                      didSelectPerson:)]) {
             [self.delegate peoplePickerViewController:self
                                       didSelectPerson:contact.recordID];
         }
    
    if ([self.selectedPeople containsObject:contact.recordID]) {
        [self.selectedPeople removeObject:contact.recordID];
    } else {
        if (self.selectedPeople.count < self.numberOfSelectedPeople) {
            [self.selectedPeople addObject:contact.recordID];
        }
    }
    
    //    NSLog(@"heree");
    
    [tableView reloadData];
    [self.tableView reloadData];
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:
(UISearchController *)searchController {
    // update the filtered array based on the search text
    NSString *searchText = searchController.searchBar.text;
    
    if (!searchText.length) {
        ZLResultsTableViewController *tableController = self.resultsTableViewController;
        tableController.filedMask = self.filedMask;
        tableController.selectedPeople = self.selectedPeople;
        [tableController setPartitionedContactsWithContacts:@[]];
        [tableController.tableView reloadData];
        return;
    }
    
    __block NSMutableArray *searchResults = [[self.partitionedContacts
                                              valueForKeyPath:@"@unionOfArrays.self"] mutableCopy];
    
    // strip out all the leading and trailing spaces
    NSString *strippedStr =
    [searchText stringByTrimmingCharactersInSet:
     [NSCharacterSet whitespaceCharacterSet]];
    
    // break up the search terms (separated by spaces)
    NSArray *searchItems = nil;
    if (strippedStr.length > 0) {
        searchItems = [strippedStr componentsSeparatedByString:@" "];
    }
    // build all the "AND" expressions for each value in the searchString
    NSMutableArray *andMatchPredicates = [NSMutableArray array];
    
    for (NSString *searchString in searchItems) {
        NSMutableArray *searchItemsPredicate = [NSMutableArray array];
        
        // TODO: match phone number matching
        
        // name field matching
        NSPredicate *finalPredicate = [NSPredicate
                                       predicateWithFormat:@"compositeName CONTAINS[c] %@", searchString];
        [searchItemsPredicate addObject:finalPredicate];
        
        NSPredicate *predicate =
        [NSPredicate predicateWithFormat:@"ANY SELF.emails CONTAINS[c] %@",
         searchString];
        [searchItemsPredicate addObject:predicate];
        
        predicate = [NSPredicate
                     predicateWithFormat:@"ANY SELF.addresses.street CONTAINS[c] %@",
                     searchString];
        [searchItemsPredicate addObject:predicate];
        predicate = [NSPredicate
                     predicateWithFormat:@"ANY SELF.addresses.city CONTAINS[c] %@",
                     searchString];
        [searchItemsPredicate addObject:predicate];
        predicate = [NSPredicate
                     predicateWithFormat:@"ANY SELF.addresses.zip CONTAINS[c] %@",
                     searchString];
        [searchItemsPredicate addObject:predicate];
        predicate = [NSPredicate
                     predicateWithFormat:@"ANY SELF.addresses.country CONTAINS[c] %@",
                     searchString];
        [searchItemsPredicate addObject:predicate];
        predicate = [NSPredicate
                     predicateWithFormat:
                     @"ANY SELF.addresses.countryCode CONTAINS[c] %@", searchString];
        [searchItemsPredicate addObject:predicate];
        
        //        NSNumberFormatter *numFormatter = [[NSNumberFormatter alloc]
        //        init];
        //        [numFormatter setNumberStyle:NSNumberFormatterNoStyle];
        //        NSNumber *targetNumber = [numFormatter
        //        numberFromString:searchString];
        //        if (targetNumber != nil) {   // searchString may not convert
        //        to a number
        //            predicate = [NSPredicate predicateWithFormat:@"ANY
        //            SELF.sanitizePhones CONTAINS[c] %@", searchString];
        //            [searchItemsPredicate addObject:predicate];
        //        }
        
        // company
        predicate = [NSPredicate predicateWithFormat:@"SELF.company CONTAINS[c] %@", searchString];
        [searchItemsPredicate addObject:predicate];
        // note
        predicate = [NSPredicate predicateWithFormat:@"SELF.note CONTAINS[c] %@", searchString];
        [searchItemsPredicate addObject:predicate];
        // phone
        NSNumberFormatter *numFormatter = [[NSNumberFormatter alloc] init];
        [numFormatter setNumberStyle:NSNumberFormatterNoStyle];
        NSNumber *targetNumber = [numFormatter
                                  numberFromString:searchString];
        if (targetNumber != nil) {   // searchString may not convert to a number
            predicate = [NSPredicate predicateWithFormat:@"ANY SELF.phones CONTAINS[c] %@", searchString];
            [searchItemsPredicate addObject:predicate];
        }
        // firstNamePhonetic
        predicate = [NSPredicate predicateWithFormat:@"SELF.firstNamePhonetic CONTAINS[c] %@", searchString];
        [searchItemsPredicate addObject:predicate];
        // lastNamePhonetic
        predicate = [NSPredicate predicateWithFormat:@"SELF.lastNamePhonetic CONTAINS[c] %@", searchString];
        [searchItemsPredicate addObject:predicate];
        
        // at this OR predicate to our master AND predicate
        NSCompoundPredicate *orMatchPredicates =
        (NSCompoundPredicate *)[NSCompoundPredicate
                                orPredicateWithSubpredicates:searchItemsPredicate];
        [andMatchPredicates addObject:orMatchPredicates];
    }
    
    __block NSCompoundPredicate *finalCompoundPredicate = nil;
    
    // match up the fields of the Product object
    finalCompoundPredicate = (NSCompoundPredicate *)
    [NSCompoundPredicate andPredicateWithSubpredicates:andMatchPredicates];
    
    searchResults = [[searchResults
                      filteredArrayUsingPredicate:finalCompoundPredicate] mutableCopy];
    
    // hand over the filtered results to our search results table
    __weak typeof (self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        searchResults = [[searchResults filteredArrayUsingPredicate:finalCompoundPredicate] mutableCopy];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            ZLResultsTableViewController *tableController = weakSelf.resultsTableViewController;
            tableController.filedMask = weakSelf.filedMask;
            tableController.selectedPeople = weakSelf.selectedPeople;
            [tableController setPartitionedContactsWithContacts:searchResults];
            [tableController.tableView reloadData];
        });
    });
}

#pragma mark - ABAdressBookUI

#pragma mark Create a new person
- (void)showNewPersonViewController {
    ABNewPersonViewController *picker =
    [[ABNewPersonViewController alloc] init];
    picker.newPersonViewDelegate = self;
    
    UINavigationController *navigation =
    [[UINavigationController alloc] initWithRootViewController:picker];
    [self presentViewController:navigation animated:YES completion:nil];
}
#pragma mark ABNewPersonViewControllerDelegate methods
// Dismisses the new-person view controller.
- (void)newPersonViewController:
(ABNewPersonViewController *)newPersonViewController
       didCompleteWithNewPerson:(ABRecordRef)person {
    [self dismissViewControllerAnimated:YES completion:NULL];
    if (self.delegate &&
        [self.delegate
         respondsToSelector:@selector(newPersonViewControllerDidCompleteWithNewPerson:)]) {
            [self.delegate newPersonViewControllerDidCompleteWithNewPerson:person];
        }
}

#pragma mark - ()
- (void)invokeReturnDelegate {
    if (self.delegate &&
        [self.delegate
         respondsToSelector:@selector(peoplePickerViewController:
                                      didReturnWithSelectedPeople:)]) {
             [self.delegate peoplePickerViewController:self
                           didReturnWithSelectedPeople:[self.selectedPeople allObjects]];
         }
}

@end
