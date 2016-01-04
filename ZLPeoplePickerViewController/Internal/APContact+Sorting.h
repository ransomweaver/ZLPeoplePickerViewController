//
//  APContact+Sorting.h
//  ZLPeoplePickerViewControllerDemo
//
//  Created by Zhixuan Lai on 11/5/14.
//  Copyright (c) 2014 Zhixuan Lai. All rights reserved.
//

#import <APAddressBook/APContact.h>

@interface APContact (Sorting)

- (NSString *)firstNameOrCompositeName;
- (NSString *)lastNameOrCompositeName;
- (NSString *)firstName;
- (NSString *)middleName;
- (NSString *)lastName;
- (NSString *)compositeName;
- (NSString *)company;
- (NSString *)jobTitle;
- (NSArray *)emailsArray;
- (NSArray *)phonesArray;
- (NSArray *)sanitizedPhones;

@end
