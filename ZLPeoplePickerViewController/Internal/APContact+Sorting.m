//
//  APContact+Sorting.m
//  ZLPeoplePickerViewControllerDemo
//
//  Created by Zhixuan Lai on 11/5/14.
//  Copyright (c) 2014 Zhixuan Lai. All rights reserved.
//

#import "APContact+Sorting.h"

@implementation APContact (Sorting)
- (NSString *)firstNameOrCompositeName {
    if (self.name.firstName) {
        return self.name.firstName;
    }
    return self.name.compositeName;
}

- (NSString *)lastNameOrCompositeName {
    if (self.name.lastName) {
        return self.name.lastName;
    }
    return self.name.compositeName;
}

- (NSString *)firstName {
    return self.name.firstName;
}
- (NSString *)middleName {
    return self.name.middleName;
}
- (NSString *)lastName {
    return self.name.lastName;
}
- (NSString *)compositeName {
    return self.name.compositeName;
}
- (NSString *)company {
    return self.job.company;
}
- (NSString *)jobTitle {
    return self.job.jobTitle;
}

- (NSArray *)emailsArray {
    NSMutableArray * emailsArr = [NSMutableArray array];
    for (APEmail * email in self.emails) {
        if (email.address != nil) {
            [emailsArr addObject:email.address];
        }
    }
    
    return emailsArr;
}

- (NSArray *)phonesArray {
    NSMutableArray * phonesArr = [NSMutableArray array];
    for (APPhone * phone in self.phones) {
        if (phone.number != nil) {
            [phonesArr addObject:phone.number];
        }
    }
    
    return phonesArr;
}

- (NSArray *)linkedContacts {
    return nil;
}

- (NSArray *)sanitizedPhones {
    NSMutableArray *mutableArray = [self.phonesArray mutableCopy];
    for (int i = 0; i < mutableArray.count; i++) {
        NSString *phone = mutableArray[i];
        NSCharacterSet *setToRemove =
        [NSCharacterSet characterSetWithCharactersInString:@"0123456789٠١٢٣٤٥٦٧٨٩"];
        NSCharacterSet *setToKeep = [setToRemove invertedSet];
        
        NSString * number = [[phone componentsSeparatedByCharactersInSet:setToKeep]
                             componentsJoinedByString:@""];
        if ([number hasPrefix:@"1"]) {
            number = [number substringFromIndex:1];
        }
        mutableArray[i] = number;
    }
    
    return [mutableArray copy];
    
}

@end
