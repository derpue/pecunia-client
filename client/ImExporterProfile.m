//
//  ImExporterProfile.m
//  Pecunia
//
//  Created by Frank Emminghaus on 20.08.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "ImExporterProfile.h"


@implementation ImExporterProfile

@synthesize name;
@synthesize shortDescription;
@synthesize longDescription;

- (void)dealloc
{
	[name release], name = nil;
	[shortDescription release], shortDescription = nil;
	[longDescription release], longDescription = nil;

	[super dealloc];
}

@end

