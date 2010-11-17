//
//  BankStatementPrintView.m
//  Pecunia
//
//  Created by Frank Emminghaus on 17.10.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "BankStatementPrintView.h"
#import "StatCatAssignment.h"
#import "BankStatement.h"
#import "BankAccount.h"

@implementation BankStatementPrintView


- (id)initWithStatements:(NSArray*)stats printInfo:(NSPrintInfo*)pi
{	
	paperSize = [pi paperSize ];
	topMargin = [pi topMargin ];
	bottomMargin = [pi bottomMargin ];
	leftMargin = [pi leftMargin ];
	rightMargin = [pi rightMargin ];
	purposeWidth = paperSize.width - leftMargin - rightMargin - 320;
	pageHeight = paperSize.height - topMargin - bottomMargin;
	pageWidth = paperSize.width - leftMargin - rightMargin;
	dateWidth = 37;
	amountWidth = 75;
	purposeWidth = pageWidth - dateWidth - 3*amountWidth;
	padding = 3;
	currentPage = 1;
	
	statements = [[NSMutableArray alloc ] initWithCapacity:100 ];
	for(StatCatAssignment *stat in stats) [statements addObject:stat.statement ];

	NSSortDescriptor	*sd = [[[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES] autorelease];
	NSArray				*sds = [NSArray arrayWithObject:sd];
	[statements sortUsingDescriptors:sds ];

	statHeights = (int*)malloc([statements count ]*sizeof(int));
	
	dateFormatter = [[NSDateFormatter alloc ] init ];
	[dateFormatter setDateFormat: @"dd.MM." ];
	
	numberFormatter = [[NSNumberFormatter alloc ] init ];
	[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle ];
	[numberFormatter setMinimumFractionDigits:2 ];
	
	debitNumberFormatter = [numberFormatter copy ];
	[debitNumberFormatter setMinusSign:@"" ];
	
	
	NSRect frame;
	
	frame.origin.x = 0;
	frame.origin.y = 0;
	frame.size = paperSize;
	
    self = [super initWithFrame:frame];
    if (self) {
		int height = [self getStatementHeights ];
		frame.size.height = height;
		[self setFrame:frame ];
    }
    return self;
}

-(NSString*)textFromStatement:(BankStatement*)statement
{
	NSMutableString *s = [NSMutableString stringWithString:@"" ];
	if (statement.transactionText && [statement.transactionText length ] > 0) {
		[s appendString:statement.transactionText ];
		[s appendString:@"\n" ];
	}
	if (statement.remoteName && [statement.remoteName length ] > 0) {
		[s appendString:statement.remoteName ];
		[s appendString:@"\n" ];
	}
	[s appendString:statement.purpose ];
	return s;
}


-(int)getStatementHeights
{
	NSSize size;
	size.width = purposeWidth-2*padding;
	size.height = 400;
	int page = 0;
	int idx = 0;
	int h = 65;
	int height;
	NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithCapacity:1 ];
	[attributes setObject:[NSFont userFontOfSize:9 ] forKey:NSFontAttributeName ];
	
	NSRect r = [@"01.01.\n10.10." boundingRectWithSize:size options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes ];
	minStatHeight = r.size.height;	
	
	for(BankStatement *stat in statements) {
		NSString *s = [self textFromStatement:stat ];
		r = [s boundingRectWithSize:size options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes ];
		height = r.size.height;
		if (height < minStatHeight) height = minStatHeight;
		if (h + height + 5 > pageHeight) {
			page++;
			h = 50;
		}
		h += height + 5;
		statHeights[idx++] = height;
	}
	totalPages = page+1;
	return page*pageHeight+h+18;
}

-(BOOL)isFlipped
{
	return YES;
}

-(void)drawHeaderForPage:(int)page
{
	int baseHeight = page*pageHeight;
	int hBase = 0;
	
	// Attributes for header text
	NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithCapacity:1 ];
	[attributes setObject:[NSFont fontWithName:@"Helvetica-Bold" size:9 ] forKey:NSFontAttributeName ];
	[NSBezierPath setDefaultLineWidth:0.5 ];
	
	// first header rect
	NSRect headerFrame = NSMakeRect(0, baseHeight+1, pageWidth, 45);
	[[NSColor lightGrayColor ] setFill ];
	[NSBezierPath fillRect:headerFrame ];
	[NSBezierPath strokeRect:headerFrame ];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(0, baseHeight+20) toPoint:NSMakePoint(pageWidth, baseHeight+20) ];
	
	// first header text
	BankStatement *stat = [statements objectAtIndex:0 ];
	if (stat == nil) return;
	BankAccount *account = stat.account;
	NSString *s = [NSString stringWithFormat:@"Konto: %@\tBLZ: %@\t%@", account.accountNumber, account.bankCode, account.bankName ];
	NSAttributedString *as = [[[NSAttributedString alloc ] initWithString:s attributes: attributes ] autorelease ];
	headerFrame.origin.y += 1;
	headerFrame.origin.x += padding;
	[as drawInRect:headerFrame ];

	// dates
	hBase+=dateWidth;
	headerFrame = NSMakeRect(0, baseHeight+20, dateWidth, 25);
//	[NSBezierPath strokeRect:headerFrame ];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(hBase, baseHeight+20) toPoint:NSMakePoint(hBase, baseHeight+45) ];
	as = [[[NSAttributedString alloc ] initWithString:@"Datum\nValuta" attributes: attributes] autorelease];
	headerFrame.origin.y += 1;
	headerFrame.origin.x += padding;
	[as drawInRect:headerFrame ];
	
	// purpose
	hBase+=purposeWidth;
	headerFrame = NSMakeRect(dateWidth, baseHeight+20, purposeWidth, 25);
//	[NSBezierPath strokeRect:headerFrame ];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(hBase, baseHeight+20) toPoint:NSMakePoint(hBase, baseHeight+45) ];
	as = [[[NSAttributedString alloc ] initWithString:@"Buchungstext\nBuchungshinweis" attributes: attributes] autorelease];
	headerFrame.origin.y += 1;
	headerFrame.origin.x += padding;
	[as drawInRect:headerFrame ];
	
	// debit
	hBase+=amountWidth;
	headerFrame = NSMakeRect(dateWidth+purposeWidth, baseHeight+20, amountWidth, 25);
//	[NSBezierPath strokeRect:headerFrame ];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(hBase, baseHeight+20) toPoint:NSMakePoint(hBase, baseHeight+45) ];
	as = [[[NSAttributedString alloc ] initWithString:[NSString stringWithFormat: @"Belastungen\nin %@", account.currency ] attributes: attributes] autorelease];
	headerFrame.origin.y += 1;
	headerFrame.origin.x += padding;
	[as drawInRect:headerFrame ];
	
	// credit
	hBase+=amountWidth;
	headerFrame = NSMakeRect(dateWidth+purposeWidth+amountWidth, baseHeight+20, amountWidth, 25);
//	[NSBezierPath strokeRect:headerFrame ];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(hBase, baseHeight+20) toPoint:NSMakePoint(hBase, baseHeight+45) ];
	as = [[[NSAttributedString alloc ] initWithString:[NSString stringWithFormat: @"Gutschriften\nin %@", account.currency ] attributes: attributes] autorelease];
	headerFrame.origin.y += 1;
	headerFrame.origin.x += padding;
	[as drawInRect:headerFrame ];
	
	// balance
	headerFrame = NSMakeRect(dateWidth+purposeWidth+2*amountWidth, baseHeight+20, amountWidth, 25);
//	[NSBezierPath strokeRect:headerFrame ];
	as = [[[NSAttributedString alloc ] initWithString:[NSString stringWithFormat: @"Zwischensaldo\nin %@", account.currency ] attributes: attributes] autorelease];
	headerFrame.origin.y += 1;
	headerFrame.origin.x += padding;
	[as drawInRect:headerFrame ];
}

-(void)finalizePage:(int)page atPosition:(int)pos
{
	int baseHeight = page*pageHeight;
	int hBase = 0;
	[NSBezierPath strokeLineFromPoint:NSMakePoint(0, baseHeight+pos) toPoint:NSMakePoint(pageWidth, baseHeight+pos) ];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(hBase, baseHeight+45) toPoint:NSMakePoint(hBase, baseHeight+pos) ];
	hBase+=dateWidth;
	[NSBezierPath strokeLineFromPoint:NSMakePoint(hBase, baseHeight+45) toPoint:NSMakePoint(hBase, baseHeight+pos) ];
	hBase+=purposeWidth;
	[NSBezierPath strokeLineFromPoint:NSMakePoint(hBase, baseHeight+45) toPoint:NSMakePoint(hBase, baseHeight+pos) ];
	hBase+=amountWidth;
	[NSBezierPath strokeLineFromPoint:NSMakePoint(hBase, baseHeight+45) toPoint:NSMakePoint(hBase, baseHeight+pos) ];
	hBase+=amountWidth;
	[NSBezierPath strokeLineFromPoint:NSMakePoint(hBase, baseHeight+45) toPoint:NSMakePoint(hBase, baseHeight+pos) ];
	hBase+=amountWidth;
	[NSBezierPath strokeLineFromPoint:NSMakePoint(hBase, baseHeight+45) toPoint:NSMakePoint(hBase, baseHeight+pos) ];
}

- (void)drawRect:(NSRect)dirtyRect {
	NSSize size;
    NSRect rect;
	int    page = 0;
	int    idx = 0;
	int    height;
	BOOL   isNegative;
		
	NSParagraphStyle *ps = [NSParagraphStyle defaultParagraphStyle ];
	NSMutableParagraphStyle *mps = [ps mutableCopy ];
	[mps setAlignment:NSRightTextAlignment ];
	
	NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithCapacity:1 ];
	[attributes setObject:[NSFont userFontOfSize:9 ] forKey:NSFontAttributeName ];
	
	NSMutableDictionary *amountAttributes = [NSMutableDictionary dictionaryWithCapacity:2 ];
	[amountAttributes setObject:[NSFont userFontOfSize:9 ] forKey:NSFontAttributeName ];
	[amountAttributes setObject:mps forKey:NSParagraphStyleAttributeName ];
	
	NSDecimalNumber *debitSum = [NSDecimalNumber zero ];
	NSDecimalNumber *creditSum = [NSDecimalNumber zero ];
	NSDecimalNumber *currentSaldo;
	
	size.width = purposeWidth-2*padding;
	size.height = 400;
	int h = 50;
	
	[self drawHeaderForPage:0 ];
	
	// start saldo
	rect.origin.x = dateWidth+padding;
	rect.origin.y = h;
	rect.size.width = purposeWidth-2*padding;
	rect.size.height = 12;
	[@"Anfangssaldo:" drawInRect:rect withAttributes:attributes ];
	rect.origin.x = dateWidth+purposeWidth+2*amountWidth+padding;
	rect.size.width = amountWidth-2*padding;
	BankStatement *stat = [statements objectAtIndex:0 ];
	NSDecimalNumber *startSaldo = [stat.saldo decimalNumberBySubtracting:stat.value ];
	[[numberFormatter stringFromNumber:startSaldo ] drawInRect:rect withAttributes:amountAttributes ];
	h+=15;

	// draw statements
	for(BankStatement *stat in statements) {
		int hBase = 0;
		height = statHeights[idx++];
		if (h + height + 5 > pageHeight) {
			[self finalizePage:page atPosition: h ];
			page++;
			h = 50;
			[self drawHeaderForPage:page ];
		}
		rect.origin.x = hBase+padding;
		rect.origin.y = page*pageHeight + h;
		rect.size.height = height;
		
		// dates
		rect.size.width = dateWidth-2*padding;
		NSString *s = [NSString stringWithFormat:@"%@\n%@", [dateFormatter stringFromDate: stat.date ], [dateFormatter stringFromDate: stat.valutaDate ] ];
		[s drawInRect:rect withAttributes:attributes ];
		hBase+=dateWidth;
		
		// purpose
		rect.size.width = purposeWidth-2*padding;
		rect.origin.x = hBase+padding;
		s = [self textFromStatement:stat ];
		[s drawInRect:rect withAttributes:attributes ];
		hBase+=purposeWidth;
		
		NSDecimalNumber *value = stat.value;
		if ([value compare:[NSDecimalNumber zero ] ] == NSOrderedAscending) {
			isNegative = YES;
			debitSum = [debitSum decimalNumberByAdding:value ];
		} else {
			isNegative = NO;
			creditSum = [creditSum decimalNumberByAdding:value ];
		}
		
		// debit
		rect.size.width = amountWidth-2*padding;
		rect.origin.x = hBase+padding;
		if (isNegative == YES) [[debitNumberFormatter stringFromNumber:value ] drawInRect:rect withAttributes:amountAttributes ];
		hBase+=amountWidth;
		
		// credit
		rect.size.width = amountWidth-2*padding;
		rect.origin.x = hBase+padding;
		if (isNegative == NO) [[numberFormatter stringFromNumber:value ] drawInRect:rect withAttributes:amountAttributes ];
		hBase+=amountWidth;

		// saldo
		rect.size.width = amountWidth-2*padding;
		rect.origin.x = hBase+padding;
		[[numberFormatter stringFromNumber:stat.saldo ] drawInRect:rect withAttributes:amountAttributes ];
		currentSaldo = stat.saldo;
		hBase+=amountWidth;
		
		h += height+5;
	}
	[self finalizePage:page atPosition: h ];
	
	// draw final sum
	rect.origin.x = 0;
	rect.origin.y = page*pageHeight + h + 1;
	rect.size.width = pageWidth;
	rect.size.height = 16;
	[NSBezierPath strokeRect:rect ];
	rect.origin.x += padding;
	rect.size.width = 200;
	[@"Summe" drawInRect:rect withAttributes:attributes ];
	
	rect.origin.x = dateWidth+purposeWidth+padding;
	rect.size.width = amountWidth-2*padding;
	[[debitNumberFormatter stringFromNumber:debitSum ] drawInRect:rect withAttributes:amountAttributes ];

	rect.origin.x = dateWidth+purposeWidth+amountWidth+padding;
	rect.size.width = amountWidth-2*padding;
	[[numberFormatter stringFromNumber:creditSum ] drawInRect:rect withAttributes:amountAttributes ];

	rect.origin.x = dateWidth+purposeWidth+2*amountWidth+padding;
	rect.size.width = amountWidth-2*padding;
	[[numberFormatter stringFromNumber:currentSaldo ] drawInRect:rect withAttributes:amountAttributes ];
	
}

-(void)drawPageBorderWithSize:(NSSize)borderSize
{
	NSString *s;
	NSDateFormatter *df = [[[NSDateFormatter alloc ] init ] autorelease ];
	[df setDateStyle: NSDateFormatterMediumStyle ];
	[df setTimeStyle: NSDateFormatterMediumStyle ];
	
	NSParagraphStyle *ps = [NSParagraphStyle defaultParagraphStyle ];
	NSMutableParagraphStyle *mps = [ps mutableCopy ];
	[mps setAlignment:NSRightTextAlignment ];
	
	NSRect frame = [self frame ];
	NSRect newFrame = NSMakeRect(0, 0, borderSize.width, borderSize.height);
	[self setFrame:newFrame ];
	[self lockFocus ];
	
	// Header
	NSRect rect = NSMakeRect(leftMargin, topMargin-30, pageWidth, 25);
	NSBezierPath *bp = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:4 yRadius:4 ];
	NSGradient* aGradient = [[[NSGradient alloc]
							  initWithColorsAndLocations:[NSColor whiteColor], (CGFloat)-0.5, [NSColor orangeColor ], (CGFloat)1.1,
							  nil] autorelease];
	
	[aGradient drawInBezierPath:bp angle:90.0];
	
	NSMutableDictionary *headerAttributes = [NSMutableDictionary dictionaryWithCapacity:1 ];
	[headerAttributes setObject:[NSFont fontWithName:@"Helvetica-Bold" size:16 ] forKey:NSFontAttributeName ];
	[headerAttributes setObject:[NSColor whiteColor ] forKey:NSForegroundColorAttributeName ];
	[headerAttributes setObject:mps forKey:NSParagraphStyleAttributeName ];
	rect.size.width-=10;
	[@"Pecunia" drawInRect:rect withAttributes:headerAttributes ];
	
	// Footer
	NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithCapacity:1 ];
	[attributes setObject:[NSFont fontWithName:@"Helvetica-Bold" size:9 ] forKey:NSFontAttributeName ];
	
	rect = NSMakeRect(leftMargin, topMargin+pageHeight+5, pageWidth, 20);
	s = [NSString stringWithFormat:@"Erstellt am %@", [df stringFromDate:[NSDate date ] ] ];
	[s drawInRect:rect withAttributes:attributes ];
	
	[attributes setObject:mps forKey:NSParagraphStyleAttributeName ];
	s = [NSString stringWithFormat:@"Seite %d von %d", [[NSPrintOperation currentOperation ] currentPage], totalPages ];
	[s drawInRect:rect withAttributes:attributes ];
	
	
	[self unlockFocus ];
	[self setFrame:frame ];
}

-(void)dealloc
{
	[dateFormatter release ];
	[numberFormatter release ];
	[debitNumberFormatter release ];
	[statements release ];
	[super dealloc ];
	
}

@end
