/**
 * Copyright (c) 2013, Pecunia Project. All rights reserved.
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

#import "NSDictionary+PecuniaAdditions.h"

// XML to NSDictionary conversion mostly taken from http://troybrant.net/blog/2010/09/simple-xml-to-nsdictionary-converter/
#pragma mark - XML reader helper class

NSString *const kXMLReaderTextNodeKey = @"text";

@interface XMLReader : NSObject  <NSXMLParserDelegate>
{
    NSMutableArray          *dictionaryStack;
    NSMutableString         *textInProgress;
    NSError __autoreleasing **errorPointer;
}

- (id)initWithError: (NSError **)error;
- (NSDictionary *)objectWithData: (NSData *)data;

@end

@implementation XMLReader

- (id)initWithError: (NSError **)error
{
    if (self = [super init]) {
        errorPointer = error;
    }
    return self;
}

- (NSDictionary *)objectWithData: (NSData *)data
{
    dictionaryStack = [[NSMutableArray alloc] init];
    textInProgress = [[NSMutableString alloc] init];

    // Initialize the stack with a fresh dictionary.
    [dictionaryStack addObject: [NSMutableDictionary dictionary]];

    // Parse the XML.
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData: data];
    parser.delegate = self;
    BOOL success = [parser parse];

    // Return the stack’s root dictionary on success
    if (success) {
        return dictionaryStack[0];
    }

    return nil;
}

#pragma mark NSXMLParserDelegate methods

- (void)     parser: (NSXMLParser *)parser
    didStartElement: (NSString *)elementName
       namespaceURI: (NSString *)namespaceURI
      qualifiedName: (NSString *)qName
         attributes: (NSDictionary *)attributeDict
{
    // Get the dictionary for the current level in the stack
    NSMutableDictionary *parentDict = [dictionaryStack lastObject];

    // Create the child dictionary for the new element, and initilaize it with the attributes.
    NSMutableDictionary *childDict = [NSMutableDictionary dictionary];
    [childDict addEntriesFromDictionary: attributeDict];

    // If there’s already an item for this key, it means we need to create an array.
    id existingValue = parentDict[elementName];
    if (existingValue) {
        NSMutableArray *array = nil;
        if ([existingValue isKindOfClass: [NSMutableArray class]]) {
            array = (NSMutableArray *)existingValue;
        } else {
            array = [NSMutableArray array];
            [array addObject: existingValue];
            parentDict[elementName] = array;
        }

        [array addObject: childDict];
    } else {
        // No existing value, so update the dictionary
        parentDict[elementName] = childDict;
    }

    [dictionaryStack addObject: childDict];
}

- (void)   parser: (NSXMLParser *)parser
    didEndElement: (NSString *)elementName
     namespaceURI: (NSString *)namespaceURI
    qualifiedName: (NSString *)qName
{
    NSMutableDictionary *dictInProgress = [dictionaryStack lastObject];

    if ([textInProgress length] > 0) {
        dictInProgress[kXMLReaderTextNodeKey] = textInProgress;
        textInProgress = [[NSMutableString alloc] init];
    }

    // Pop the current dict since we are done with this tag.
    [dictionaryStack removeLastObject];
}

- (void)parser: (NSXMLParser *)parser foundCharacters: (NSString *)string
{
    [textInProgress appendString: string];
}

- (void)parser: (NSXMLParser *)parser parseErrorOccurred: (NSError *)parseError
{
    if (errorPointer != nil) {
        *errorPointer = parseError;
    }
}

@end

#pragma mark - NSDictionary category

@implementation NSDictionary (PecuniaAdditions)

+ (NSDictionary *)dictionaryForXMLData: (NSData *)data error: (NSError **)error
{
    XMLReader *reader = [[XMLReader alloc] initWithError: error];
    return [reader objectWithData: data];
}

+ (NSDictionary *)dictionaryForXMLString: (NSString *)string error: (NSError **)error
{
    NSData *data = [string dataUsingEncoding: NSUTF8StringEncoding];
    return [self dictionaryForXMLData: data error: error];
}

@end
