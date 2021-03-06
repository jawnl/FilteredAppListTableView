//
//  FilteredAppListTableView.m
//  
//  
//  Copyright (c) 2011-2013 deVbug
//  
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "FilteredAppListTableView.h"
#import "../MBProgressHUD/MBProgressHUD.h"

#import <objc/runtime.h>



extern NSInteger compareDisplayNames(NSString *a, NSString *b, void *context);
extern NSArray *applicationDisplayIdentifiersForType(FilteredAppType type);
extern NSString * SBSCopyLocalizedApplicationNameForDisplayIdentifier(NSString *identifier);



@interface FilteredAppListTableView ()
@property (nonatomic) NSInteger hudTag;

- (void)loadInstalledAppData;
- (id)makeCell:(NSString *)identifier;

- (int)numberOfSectionsInTableView:(UITableView *)tableView;
- (id)tableView:(UITableView *)tableView titleForHeaderInSection:(int)section;
- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(int)section;
- (id)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView;
- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index;
@end


Class newHudClass;

@implementation FilteredAppListTableView

@synthesize tableView, delegate, filteredAppType, enableForceType;
@synthesize hudLabelText, hudDetailsLabelText;
@synthesize noneTextColor, normalTextColor, forceTextColor;
@synthesize hudTag;
@synthesize iconMargin;
@synthesize cellStyle;

- (id)initForContentSize:(CGSize)size delegate:(id<FilteredAppListDelegate>)_delegate filteredAppType:(FilteredAppType)type enableForce:(BOOL)enableForce {
	if ((self = [super init]) != nil) {
		self.delegate = _delegate;
		self.filteredAppType = type;
		self.enableForceType = enableForce;
		_list = nil;
		self.hudLabelText = @"Loading Data";
		self.hudDetailsLabelText = @"Please wait...";
		[self setDefaultTextColor];
		
		srand(time(NULL));
		self.hudTag = rand() % 200000;
		
		self.iconMargin = 4.0f;
		self.cellStyle = UITableViewCellStyleDefault;
		
		char hudClassName[100] = "";
		memset(hudClassName, 0, 100);
		sprintf(hudClassName, "MBHud%dSubclass", self.hudTag);
		
		newHudClass = objc_allocateClassPair([MBProgressHUD class], hudClassName, 0);
		objc_registerClassPair(newHudClass);
		
		window = [[UIApplication sharedApplication] keyWindow];
		
		tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height) style:UITableViewStylePlain];
		tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[tableView setDelegate:self];
		[tableView setDataSource:self];
	}
	
	return self;
}

- (UIView *)view {
	return tableView;
}

- (void)setDefaultTextColor {
	self.noneTextColor = [UIColor blackColor];
	self.normalTextColor = [UIColor colorWithRed:81/255.0 green:102/255.0 blue:145/255.0 alpha:1];
	self.forceTextColor = [UIColor colorWithRed:181/255.0 green:181/255.0 blue:181/255.0 alpha:1];
}

- (void)setTextColors:(UIColor *)noneColor normalTextColor:(UIColor *)normalColor forceTextColor:(UIColor *)forceColor {
	self.noneTextColor = noneColor;
	self.normalTextColor = normalColor;
	self.forceTextColor = forceColor;
}

- (void)dealloc {
	MBProgressHUD *HUD = (MBProgressHUD *)[window viewWithTag:self.hudTag];
	[HUD removeFromSuperview];
	
	[tableView release];
	self.hudLabelText = nil;
	self.hudDetailsLabelText = nil;
	self.noneTextColor = nil;
	self.normalTextColor = nil;
	self.forceTextColor = nil;
	[_list release];
	
	[super dealloc];
}



- (void)loadFilteredList {
	MBProgressHUD *HUD = nil;
	if ((HUD = (MBProgressHUD *)[window viewWithTag:self.hudTag]) == nil) {
		HUD = (MBProgressHUD *)[[newHudClass alloc] initWithView:window];
		[window addSubview:HUD];
		[HUD release];
	}
	HUD.labelText = hudLabelText;
	HUD.detailsLabelText = hudDetailsLabelText;
	HUD.labelFont = [UIFont fontWithName:@"Helvetica" size:24];
	HUD.detailsLabelFont = [UIFont fontWithName:@"Helvetica" size:18];
	HUD.tag = self.hudTag;
	[HUD show:YES];
	
	[self performSelector:@selector(loadInstalledAppData) withObject:nil afterDelay:0.1f];
}


- (void)loadInstalledAppData {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[tableView setDataSource:nil];
	[_list release];
	_list = [[NSMutableArray alloc] init];
	
	NSSet *set = [NSSet setWithArray:applicationDisplayIdentifiersForType(filteredAppType)];
	NSArray *sortedArray = [[set allObjects] sortedArrayUsingFunction:compareDisplayNames context:NULL];
	
	/**
	 * 0x3131 = 'ㄱ'    0x1100 = 'ᄀ'
	 * 0x3132 = 'ㄲ'    0x1101 = 'ᄁ'
	 * 0x3134 = 'ㄴ'    0x1102 = 'ᄂ'
	 * 0x3137 = 'ㄷ'    0x1103 = 'ᄃ'
	 * 0x3138 = 'ㄸ'    0x1104 = 'ᄄ'
	 * 0x3139 = 'ㄹ'    0x1105 = 'ᄅ'
	 * 0x3141 = 'ㅁ'    0x1106 = 'ᄆ'
	 * 0x3142 = 'ㅂ'    0x1107 = 'ᄇ'
	 * 0x3143 = 'ㅃ'    0x1108 = 'ᄈ'
	 * 0x3145 = 'ㅅ'    0x1109 = 'ᄉ'
	 * 0x3146 = 'ㅆ'    0x110A = 'ᄊ'
	 * 0x3147 = 'ㅇ'    0x110B = 'ᄋ'
	 * 0x3148 = 'ㅈ'    0x110C = 'ᄌ'
	 * 0x3149 = 'ㅉ'    0x110D = 'ᄍ'
	 * 0x314A = 'ㅊ'    0x110E = 'ᄎ'
	 * 0x314B = 'ㅋ'    0x110F = 'ᄏ'
	 * 0x314C = 'ㅌ'    0x1110 = 'ᄐ'
	 * 0x314D = 'ㅍ'    0x1111 = 'ᄑ'
	 * 0x314E = 'ㅎ'    0x1112 = 'ᄒ'
	 * 
	 * 0x3131 : ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ
	 * 0x1100 : ᄀᄁᄂᄃᄄᄅᄆᄇᄈᄉᄊᄋᄌᄍᄎᄏᄐᄑᄒ
	 **/
	
	// http://pastebin.com/7YkT4dbk
	// 한글 로마자 변환 프로그램 by 동성
	NSString *choCharset = @"ᄀᄁᄂᄃᄄᄅᄆᄇᄈᄉᄊᄋᄌᄍᄎᄏᄐᄑᄒ";
	
	unichar header = ' ', temp;
	for (NSString *displayId in sortedArray) {
		if ([delegate respondsToSelector:@selector(isOtherFilteredForIdentifier:)])
			if ([delegate isOtherFilteredForIdentifier:displayId])
				continue;
		
		NSString *name = SBSCopyLocalizedApplicationNameForDisplayIdentifier(displayId);
		
		if (name && name.length > 0 && strlen([name UTF8String]) > 0) {
			@try {
				temp = [[name uppercaseString] characterAtIndex:0];
				[name release];
				
				if(0xAC00 <= temp && temp <= 0xD7AF) {
					unsigned int choSung = (temp - 0xAC00) / (21*28);
					temp = [[choCharset substringWithRange:NSMakeRange(choSung, 1)] characterAtIndex:0];
				}
				
				if (header != temp) {
					header = temp;
					[_list addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSString stringWithCharacters:&header length:1], @"section", nil]];
				}
			}
			@catch (NSException *e) {
				//
			}
			@finally {
				//
			}
		}
		
		if ([_list count] > 0) {
			NSMutableArray *arr = [[_list objectAtIndex:[_list count]-1] objectForKey:@"data"];
			if (arr == nil)
				arr = [NSMutableArray array];
			FilteredAppListCell *cell = [self makeCell:displayId];
			[cell loadAndDelayedSetIcon];
			[arr addObject:cell];
			
			[[_list objectAtIndex:[_list count]-1] setObject:arr forKey:@"data"];
		}
	}
	
	[tableView setDataSource:self];
	[tableView reloadData];
	
	MBProgressHUD *HUD = (MBProgressHUD *)[window viewWithTag:self.hudTag];
	[HUD hide:YES];
	
	[pool release];
}

- (id)makeCell:(NSString *)identifier {
	FilteredAppListCell *cell = [[[FilteredAppListCell alloc] initWithStyle:self.cellStyle reuseIdentifier:@"FilteredAppListCell"] autorelease];
	
	cell.iconMargin = self.iconMargin;
	cell.enableForceType = enableForceType;
	cell.displayId = identifier;
	[cell setTextColors:noneTextColor normalTextColor:normalTextColor forceTextColor:forceTextColor];
	
	cell.filteredListType = [delegate filteredListTypeForIdentifier:identifier];
	
	return cell;
}


- (int)numberOfSectionsInTableView:(UITableView *)tableView {
	if (!_list) return 1;
	return ([_list count] == 0 ? 1: [_list count]);
}

- (id)tableView:(UITableView *)tableView titleForHeaderInSection:(int)section {
	if (!_list || [_list count] == 0)
		return nil;
	
	return [[_list objectAtIndex:section] objectForKey:@"section"];
}

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(int)section {
	if (!_list || [_list count] == 0)
		return 0;
	
	return [[[_list objectAtIndex:section] objectForKey:@"data"] count];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
	NSMutableArray *arr = [NSMutableArray array];
	for (int i = 0; i < [_list count]; i++) {
		[arr addObject:[[_list objectAtIndex:i] objectForKey:@"section"]];
	}
	return arr;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
	return index;
}

- (id)tableView:(UITableView *)_tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	FilteredAppListCell *cachedCell = (FilteredAppListCell *)[[[_list objectAtIndex:indexPath.section] objectForKey:@"data"] objectAtIndex:indexPath.row];
	
	FilteredAppListCell *cell = (FilteredAppListCell *)[_tableView dequeueReusableCellWithIdentifier:@"FilteredAppListCell"];
	if (cell == nil) {
		cell = [self makeCell:cachedCell.displayId];
	} else {
		cell.enableForceType = enableForceType;
		cell.displayId = cachedCell.displayId;
		[cell setTextColors:noneTextColor normalTextColor:normalTextColor forceTextColor:forceTextColor];
		
		cell.filteredListType = [delegate filteredListTypeForIdentifier:cachedCell.displayId];
	}
	
	if (!cachedCell.isIconLoaded) {
		[cachedCell loadAndDelayedSetIcon];
		[cell loadIcon];
	} else {
		UIImage *icon = [cachedCell.imageView.image copy];
		[cell setIcon:icon];
		[icon release];
	}
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	FilteredAppListCell *cell = (FilteredAppListCell *)[self.tableView cellForRowAtIndexPath:indexPath];
	
	[cell toggle];
	
	[self.tableView deselectRowAtIndexPath:(NSIndexPath *)indexPath animated:YES];
	
	if (enableForceType == NO && cell.filteredListType == FilteredListForce) return;
	
	[delegate didSelectRowAtCell:cell];
}


@end
