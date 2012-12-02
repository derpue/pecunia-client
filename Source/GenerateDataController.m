/**
 * Copyright (c) 2012, Pecunia Project. All rights reserved.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; version 2 of the
 * License.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301  USA
 */

#import "GenerateDataController.h"
#include "MOAssistant.h"
#include "BankUser.h"
#include "Category.h"
#include "BankAccount.h"
#include "BankStatement.h"
#include "ShortDate.h"

#include "GrowlNotification.h"

@interface GenerateDataController ()

@end

@implementation GenerateDataController

@synthesize startYear;
@synthesize endYear;
@synthesize bankCount;
@synthesize maxAccountsPerBank;
@synthesize numberOfStatementsPerBank;

- (id)init;
{
    self = [super initWithWindowNibName: @"GenerateDataController"];
    if (self) {
        calendar = [ShortDate calendar];
        startYear = 2008;
        endYear = 2013;
        bankCount = 5;
        maxAccountsPerBank = 3;
        numberOfStatementsPerBank = 650;
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    self.progressIndicator.doubleValue = 0;
    [self updateTotalCount];
}

- (void)updateTotalCount
{
    NSUInteger totalCount = 0;
    if (endYear > startYear) {
        totalCount = (endYear - startYear + 1) * numberOfStatementsPerBank * bankCount;
    }
    self.totalCountLabel.stringValue = [NSString stringWithFormat: @"%lu", totalCount];
}

- (void)objectDidEndEditing: (id)editor
{
    [self updateTotalCount];
}

- (IBAction)stepperChanged:(id)sender
{
    [self updateTotalCount];
}

- (IBAction)selectFile:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection: NO];
    [panel setAllowedFileTypes: [NSArray arrayWithObject: @"txt"]];
    NSInteger result = [panel runModal];
    if (result == NSFileHandlingPanelOKButton) {
        [self.path setStringValue: panel.URL.path];
    }
}

- (IBAction)close:(id)sender {
    [NSApp stopModal];
}

- (NSDate *)firstDayOfYear: (NSUInteger)year
{
    NSDateComponents *components = [[NSDateComponents alloc] init];
    components.year = year;
    components.month = 1;
    components.day = 1;
    return [calendar dateFromComponents: components];
}

- (NSDate *)firstDayOfQuarter: (NSUInteger)quarter inYear: (NSUInteger)year
{
    NSDateComponents *components = [[NSDateComponents alloc] init];
    components.year = year;
    components.month = 1 + 3 * (quarter - 1);
    components.day = 1;
    return [calendar dateFromComponents: components];
}

- (IBAction)start:(id)sender {
    NSError *error;
    NSString *path = self.path.stringValue;
    NSString *s = [NSString stringWithContentsOfFile: path encoding: NSUTF8StringEncoding error: &error];
    if (error) {
        NSLog(@"Error reading demo data template file at %@\n%@", path, [error localizedFailureReason]);
    } else {
        NSMutableDictionary *blocks = [NSMutableDictionary dictionary];
        NSString *blockName = @"";
        NSMutableArray *entries;

        NSArray *lines = [s componentsSeparatedByString: @"\n"];
        for (NSString *line in lines) {
            if (line.length == 0) {
                continue; // Empty line.
            }
            if ([line hasPrefix: @"#"]) {
                continue; // Comment line.
            }
            
            if ([line hasPrefix: @"["] && [line hasSuffix: @"]"]) {
                // Starting new block.
                if (entries != nil) {
                    [blocks setObject: entries forKey: blockName];
                }
                entries = [NSMutableArray array];
                blockName = [line substringWithRange: NSMakeRange(1, line.length - 2)];

                continue;
            }
            [entries addObject: line];
        }

        [self.progressIndicator setIndeterminate: YES];
        [self.progressIndicator startAnimation: self];

        NSManagedObjectContext *context = MOAssistant.assistant.context;

        // Before adding new data remove old data if requested.
        if (self.removeOldDataCheckBox.state == 1) {
            [MOAssistant.assistant clearAllData];
            [Category recreateRoots];
            [Category createDefaultCategories];
        }

        // Once all data is read start by generating bank users and accounts.
        NSArray *banks = [blocks objectForKey: @"Banks"];
        if (banks.count == 0) {
            return;
        }

        NSArray *principals = [blocks objectForKey: @"Principals"];
        if (principals.count == 0) {
            return;
        }

        NSSet *categories = Category.catRoot.allChildren;
        
        // Precompute details for principals.
        NSMutableArray *parsedPrincipals = [NSMutableArray arrayWithCapacity: principals.count];
        for (NSString *principal in principals) {
            NSArray *parts = [principal componentsSeparatedByString: @":"];
            if (parts.count < 4) {
                continue; // Ignore any entry which is not properly specified.
            }

            // Fields are: principal:lowest value:highest value:frequency ([1-9] [d]ay, [w]eek], [m]onth,
            //   [q]uarter, [y]ear):category keywords:purpose
            NSString *principal = [parts objectAtIndex: 0];
            double lowBound = [[parts objectAtIndex: 1] doubleValue];
            double highBound = [[parts objectAtIndex: 2] doubleValue];
            NSString *frequency = [parts objectAtIndex: 3];
            NSString *keywords = @"";
            if (parts.count > 4) {
                keywords = [parts objectAtIndex: 4]; // Optional
            }
            NSString *purpose = @"";
            if (parts.count > 5) {
                purpose = [parts objectAtIndex: 5]; // Optional
            }
            if (principal.length == 0 || (lowBound == 0 && highBound == 0) || frequency.length < 2) {
                continue; // Ignore entries that are not properly specified.
            }
            NSString *count = [frequency substringWithRange: NSMakeRange(0, frequency.length - 1)];
            NSString *unit = [frequency substringFromIndex: frequency.length - 1];
            NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                        [parts objectAtIndex: 0], @"principal",
                                        [NSNumber numberWithDouble: lowBound * 100], @"minBound",
                                        [NSNumber numberWithInteger: (NSInteger)(highBound - lowBound) * 100], @"delta",
                                        [NSNumber numberWithInt: [count intValue]], @"count",
                                        unit, @"unit",
                                        keywords, @"keywords",
                                        purpose, @"purpose",
                                        nil];
            [parsedPrincipals addObject: dictionary];
        }
        if (parsedPrincipals.count == 0) {
            return;
        }

        NSArray *accounts = [blocks objectForKey: @"Accounts"];

        Category *root = [Category bankRoot];
        for (NSUInteger i = 0; i < bankCount; i++) {
            NSInteger randomIndex = arc4random_uniform(banks.count);
            NSString *bank = [banks objectAtIndex: randomIndex];

            BankUser *user = [NSEntityDescription insertNewObjectForEntityForName: @"BankUser"
                                                           inManagedObjectContext: context];
            user.name = bank;
            user.bankCode = @"1234567890";
            user.bankName = bank;
            user.bankURL = @"http://noip.com";
            user.port = @"1";
            user.hbciVersion = @"2.2";
            user.checkCert = [NSNumber numberWithBool: YES];
            user.country = @"DE";
            user.userId = @"0987654321";
            user.customerId = @"";
            user.secMethod = [NSNumber numberWithInt: SecMethod_PinTan];

            // Add account for this bank (actually the bank root to which the real accounts are attached).
            BankAccount *bankRoot = [NSEntityDescription insertNewObjectForEntityForName: @"BankAccount"
                                                                  inManagedObjectContext: context];
            bankRoot.bankName = bank;
            bankRoot.name = bank;
            bankRoot.bankCode = user.bankCode;
            bankRoot.currency = @"EUR";
            bankRoot.country = user.country;
            bankRoot.isBankAcc = [NSNumber numberWithBool: YES];
            bankRoot.parent = root;

            // To each bank root add a few accounts. The actual number depends on the data amount flag.
            NSMutableArray *accountList = [NSMutableArray array];
            NSUInteger accountCount = 1 + arc4random_uniform(maxAccountsPerBank);
            while (accountList.count < accountCount) {
                NSUInteger randomIndex = arc4random_uniform(accounts.count);
                NSString *value = [accounts objectAtIndex: randomIndex];
                if (![accountList containsObject: value]) {
                    [accountList addObject: value];
                }
            }

            for (NSString *accountName in accountList) {
                BankAccount *newAccount = [NSEntityDescription insertNewObjectForEntityForName: @"BankAccount"
                                                                        inManagedObjectContext: context];
                newAccount.bankCode = user.bankCode;
                newAccount.bankName = user.bankName;
                newAccount.isManual = [NSNumber numberWithBool: YES];
                newAccount.userId = user.userId;
                newAccount.customerId = user.customerId;
                //newAccount.collTransferMethod = account.collTransferMethod;
                newAccount.isStandingOrderSupported = [NSNumber numberWithBool: YES];

                newAccount.parent = bankRoot;
                newAccount.isBankAcc = [NSNumber numberWithBool: YES];

                //newAccount.iban = account.iban;
                //newAccount.bic = account.bic;
                //newAccount.owner = account.owner;
                newAccount.accountNumber = @"12341234";
                newAccount.name = accountName;
                newAccount.currency = bankRoot.currency;
                newAccount.country = bankRoot.country;

                // Current balance of the account. Saldos are computed backwards starting with this value.
                double dBalance = ((double)arc4random_uniform(500000) - 250000) / 100.0;
                NSNumber *balance = [NSNumber numberWithDouble: dBalance];
                newAccount.balance = [NSDecimalNumber decimalNumberWithDecimal: balance.decimalValue];
            }
        }

        [self.progressIndicator setIndeterminate: NO];
        self.progressIndicator.maxValue = (endYear - startYear + 1) * numberOfStatementsPerBank * banks.count;

        // Add transactions to each account of a bank.
        for (BankAccount *bank in root.children) {
            NSArray *accounts = bank.children.objectEnumerator.allObjects;
            for (NSUInteger year = startYear; year <= endYear; year++) {
                NSUInteger yearlyLimit = numberOfStatementsPerBank;

                // Reset all counters and start over.
                for (NSMutableDictionary *dictionary in parsedPrincipals) {
                    NSUInteger count = [[dictionary objectForKey: @"count"] integerValue];
                    [dictionary setObject: [NSNumber numberWithInt: count] forKey: @"remaining"];
                }
                
                while (yearlyLimit > 0) {
                    // Walk the principals list repeatedly until we added the required amount of statements
                    // or no principal has a count > 0 anymore.
                    BOOL foundEntry = NO;
                    for (NSMutableDictionary *dictionary in parsedPrincipals) {
                        NSUInteger remaining = [[dictionary objectForKey: @"remaining"] integerValue];
                        if (remaining == 0) {
                            continue;
                        } else {
                            [dictionary setObject: [NSNumber numberWithInt: remaining - 1] forKey: @"remaining"];
                            foundEntry = YES;
                        }

                        // Randomly pick one of the accounts in this bank. Prefer the first one as most important.
                        // It gets most of the transactions.
                        NSInteger randomIndex = (NSInteger)arc4random_uniform(bank.children.count + 6) - 6;
                        if (randomIndex < 0) {
                            randomIndex = 0;
                        }
                        BankAccount *account = [accounts objectAtIndex: randomIndex];
                        
                        double minBound = [[dictionary objectForKey: @"minBound"] doubleValue];
                        NSInteger delta = [[dictionary objectForKey: @"delta"] integerValue];
                        NSString *unit = [dictionary objectForKey: @"unit"];

                        NSDateComponents *components = [[NSDateComponents alloc] init];
                        [components setYear: year];

                        NSUInteger dateUnitMax = 1;
                        switch ([unit characterAtIndex: 0]) {
                            case 'y':
                                break;
                            case 'q':
                                dateUnitMax = 4;
                                break;
                            case 'm':
                                dateUnitMax = 12;
                                break;
                            case 'w':
                                dateUnitMax = 52;
                                break;
                            case 'd':
                                dateUnitMax = 365;
                                break;
                        }

                        for (NSUInteger dateOffset = 0; dateOffset < dateUnitMax; dateOffset++) {
                            NSUInteger randomPart = arc4random_uniform(delta);
                            NSDecimalNumber *value = [NSDecimalNumber decimalNumberWithDecimal: [[NSNumber numberWithDouble: (minBound + randomPart) / 100.0] decimalValue]];

                            NSDate *date;
                            switch ([unit characterAtIndex: 0]) {
                                case 'y': {
                                    NSDate *firstDayOfYear = [self firstDayOfYear: year];
                                    NSDate *firstDayOfNextYear = [self firstDayOfYear: year + 1];
                                    NSDateComponents *temp = [calendar components: NSDayCalendarUnit
                                                                         fromDate: firstDayOfYear
                                                                           toDate:firstDayOfNextYear
                                                                          options: 0];
                                    [components setDay: 1 + arc4random_uniform(temp.day)];
                                    date = [calendar dateFromComponents: components];
                                    break;
                                }
                                case 'q': {
                                    NSDate *firstDayOfYear = [self firstDayOfYear: year];
                                    NSDate *firstDayOfQuarter = [self firstDayOfQuarter: dateOffset + 1
                                                                                 inYear: year];
                                    NSDateComponents *tempBase = [calendar components: NSDayCalendarUnit
                                                                             fromDate: firstDayOfYear
                                                                               toDate: firstDayOfQuarter
                                                                              options: 0];
                                    NSDate *firstDayOfNextQuarter = [self firstDayOfQuarter: dateOffset + 2
                                                                                     inYear: year];
                                    NSDateComponents *temp = [calendar components: NSDayCalendarUnit
                                                                         fromDate: firstDayOfQuarter
                                                                           toDate:firstDayOfNextQuarter
                                                                          options: 0];
                                    [components setDay: tempBase.day + 1 + arc4random_uniform(temp.day)];
                                    date = [calendar dateFromComponents: components];
                                    break;
                                }
                                case 'm': {
                                    [components setMonth: dateOffset + 1];
                                    NSRange r = [calendar rangeOfUnit: NSDayCalendarUnit
                                                               inUnit: NSMonthCalendarUnit
                                                              forDate: [calendar dateFromComponents: components]];
                                    [components setDay: 1 + arc4random_uniform(r.length)];
                                    date = [calendar dateFromComponents: components];
                                    break;
                                }
                                case 'w':
                                    [components setDay: 7 * dateOffset + 1 + arc4random_uniform(7)];
                                    date = [calendar dateFromComponents: components];
                                    break;
                                case 'd':
                                    [components setDay: dateOffset];
                                    date = [calendar dateFromComponents: components];
                                    break;
                            }

                            BankStatement *statement = [NSEntityDescription insertNewObjectForEntityForName: @"BankStatement"
                                                                                     inManagedObjectContext: context];
                            statement.currency = account.currency;
                            statement.localAccount = account.accountNumber;
                            statement.localBankCode = account.bankCode;
                            statement.isManual = [NSNumber numberWithBool: YES];
                            statement.date = date;
                            statement.valutaDate = date;
                            statement.remoteCountry = @"de";
                            statement.value = value;
                            statement.purpose = [dictionary objectForKey: @"purpose"];
                            statement.remoteName = [dictionary objectForKey: @"principal"];
                            NSString *remoteAccount = [NSString stringWithFormat: @"%u", arc4random()];
                            if (remoteAccount.length > 10) {
                                statement.remoteAccount = [remoteAccount substringWithRange: NSMakeRange(0, 10)];
                            } else {
                                statement.remoteAccount = remoteAccount;
                            }

                            [statement addToAccount: account];

                            NSArray *keywords = [[dictionary objectForKey: @"keywords"] componentsSeparatedByString: @","];
                            if (keywords.count > 0) {
                                // Assign this statement to all categories which contain any of the keywords.
                                NSSet *matchingCategories = [categories objectsPassingTest: ^BOOL(id obj, BOOL *stop) {
                                    for (NSString *keyword in keywords) {
                                        return [[obj name] rangeOfString: keyword].length > 0;
                                    }
                                    return NO;
                                }];
                                for (Category *category in matchingCategories) {
                                    [statement assignToCategory: category];
                                }
                            }
                            [self.progressIndicator incrementBy: 1];
                            yearlyLimit--;
                            if (yearlyLimit == 0) {
                                break;
                            }
                        }
                        if (yearlyLimit == 0) {
                            break;
                        }

                    }

                    if (!foundEntry) {
                        [self.progressIndicator incrementBy: yearlyLimit];
                        yearlyLimit = 0; // No principals left, so go to the next year.
                    }
                }
            }

            for (BankAccount *account in accounts) {
                [account repairStatementBalances];
            }
        }

        [root rollup];
        
		if (![context save: &error]) {
			NSAlert *alert = [NSAlert alertWithError: error];
			[alert runModal];
			return;
		}
        [self.progressIndicator stopAnimation: self];

        [GrowlNotification showMessage: NSLocalizedString(@"AP501", nil)
                             withTitle: NSLocalizedString(@"AP500", nil)
                               context: @"Data Generation"];
        [NSApp stopModal];
    }
}

@end