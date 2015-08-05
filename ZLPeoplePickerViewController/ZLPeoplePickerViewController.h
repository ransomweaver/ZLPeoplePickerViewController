//
//  ZLPeoplePickerViewController.h
//  ZLPeoplePickerViewControllerDemo
//
//  Created by Zhixuan Lai on 11/4/14.
//  Copyright (c) 2014 Zhixuan Lai. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AddressBook/AddressBook.h>
#import <APAddressBook/APContact.h>
#import "APContact+Sorting.h"
#import "APContact+NamePhonetic.h"
#import "ZLAddressBook.h"
#import "ZLBaseTableViewController.h"

@class ZLPeoplePickerViewController;

@protocol ZLPeoplePickerViewControllerDelegate <NSObject>

/**
 *  Tells the delegate that the people picker has selected a person.
 *
 *  @param peoplePicker The people picker object providing this information.
 *  @param recordId     The person's recordId in ABAddressBook
 */
- (void)peoplePickerViewController:(nonnull ZLPeoplePickerViewController *)peoplePicker
                   didSelectPerson:(nonnull NSNumber *)recordId;

/**
 *  Tells the delegate that the people picker has returned and, if the type is
 *multiple, selected contacts.
 *
 *  @param peoplePicker The people picker object providing this information.
 *  @param people     An array of recordIds
 */
- (void)peoplePickerViewController:(nonnull ZLPeoplePickerViewController *)peoplePicker
       didReturnWithSelectedPeople:(nullable NSArray *)people;

/**
 *  Tells the delegate that the people picker's ABNewPersonViewController did complete
 *  with a new person (can be NULL)
 *
 *  @param person     A valid person that was saved into the Address Book, otherwise NULL
 */

-(void)newPersonViewControllerDidCompleteWithNewPerson:(nullable ABRecordRef)person;

@end

@interface ZLPeoplePickerViewController : ZLBaseTableViewController
@property (weak, nonatomic) id<ZLPeoplePickerViewControllerDelegate> delegate;
@property (nonatomic) NSUInteger numberOfSelectedPeople;

+ (void)setEmailsToMatch:(nullable NSArray*)emails;
+ (int)getMatchCount;
+ (void)initializeAddressBook;
//- (id)init __attribute__((unavailable("-init is not allowed, use
//-initWithType: instead")));
- (nonnull id)initWithStyle:(UITableViewStyle)style __attribute__((unavailable(
                                                                               "-initWithStyle is not allowed, use -init instead")));
+ (nonnull instancetype)presentPeoplePickerViewControllerForParentViewController:
(nonnull UIViewController *)parentViewController;

@property BOOL showAddButton;

@end
