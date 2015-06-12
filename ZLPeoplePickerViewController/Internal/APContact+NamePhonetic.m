//
// Created by vertuxx on 15/06/12.
// Copyright (c) 2015 Zhixuan Lai. All rights reserved.
//

#import "APContact+NamePhonetic.h"

#include <objc/runtime.h>
#include <objc/message.h>
#include <objc/objc.h>

#if !__has_feature(objc_arc)
#error This code needs compiler option -fobjc-arc
#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

// objc_msgSend方式に変更
// Type *(*func)(id, SEL, param1, ...) = (Type *(*)(id, SEL, param1, ...))objc_msgSend;
typedef NSString *(*objc_msgSend_stringProperty)(id, SEL, ABPropertyID, ABRecordRef);

@implementation APContact (NamePhonetic)

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];

        NSArray *selectors = @[
                @[[NSValue valueWithPointer:@selector(initWithRecordRef:fieldMask:)],
                        [NSValue valueWithPointer:@selector(initWithRecordRef_Workaround:fieldMask:)]]
        ];

        for (NSArray *value in selectors) {
            SEL originalSelector = [value.firstObject pointerValue];
            SEL swizzledSelector = [value.lastObject pointerValue];

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
        }
    });
}

- (instancetype)initWithRecordRef_Workaround:(ABRecordRef)recordRef fieldMask:(APContactField)fieldMask
{
    self = [self initWithRecordRef_Workaround:recordRef fieldMask:fieldMask];

    objc_msgSend_stringProperty stringProperty = (objc_msgSend_stringProperty)objc_msgSend;
    self.firstNamePhonetic = stringProperty(self, @selector(stringProperty:fromRecord:), kABPersonFirstNamePhoneticProperty, recordRef);
    self.lastNamePhonetic  = stringProperty(self, @selector(stringProperty:fromRecord:), kABPersonLastNamePhoneticProperty, recordRef);

    return self;
}

#pragma mark - Setter/Getter

- (void)setFirstNamePhonetic:(NSString *)firstNamePhonetic
{
    objc_setAssociatedObject(self, @selector(firstNamePhonetic), firstNamePhonetic, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)firstNamePhonetic
{
    return objc_getAssociatedObject(self, @selector(firstNamePhonetic));
}

- (void)setLastNamePhonetic:(NSString *)lastNamePhonetic
{
    objc_setAssociatedObject(self, @selector(lastNamePhonetic), lastNamePhonetic, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)lastNamePhonetic
{
    return objc_getAssociatedObject(self, @selector(lastNamePhonetic));
}

@end

#pragma clang diagnostic pop
