//
//  TITokenFieldView.m
//  TITokenFieldView
//
//  Created by Tom Irving on 16/02/2010.
//  Copyright 2010 Tom Irving. All rights reserved.
//

#import "TITokenFieldView.h"
#import <QuartzCore/QuartzCore.h>

//==========================================================
#pragma mark - Private Additions -
//==========================================================

@interface UIColor (Private)
- (BOOL)ti_getRed:(CGFloat *)red green:(CGFloat *)green blue:(CGFloat *)blue alpha:(CGFloat *)alpha;
@end

@interface UIView (Private)
- (void)ti_setHeight:(CGFloat)height;
- (void)ti_setWidth:(CGFloat)width;
- (void)ti_setOriginY:(CGFloat)originY;
@end

@interface TITokenField (Private)
- (void)processLeftoverText;
- (void)setShadowHidden:(BOOL)hidden;
- (void)updateHeight:(BOOL)scrollToTop;
- (void)scrollForEdit:(BOOL)shouldMove;
- (void)performButtonAction;
@end

//==========================================================
#pragma mark - TITokenFieldView -
//==========================================================

@interface TITokenFieldView (Private)
- (void)resultsForSubstring:(NSString *)substring;
- (void)tokenFieldResized:(TITokenField *)aTokenField;
@end

@implementation TITokenFieldView
@synthesize showAlreadyTokenized;
@synthesize delegate;
@synthesize tokenField;
@synthesize resultsTable;
@synthesize contentView;
@synthesize separator;
@synthesize sourceArray;

NSString * const kTextEmpty = @" "; // Just a space
NSString * const kTextHidden = @"`"; // This character isn't available on iOS (yet) so it's safe.

CGFloat const kTokenFieldHeight = 42;
CGFloat const kSeparatorHeight = 1;

#pragma mark Main Shit
- (id)initWithFrame:(CGRect)frame {
	
    if ((self = [super initWithFrame:frame])){
		
		[self setBackgroundColor:[UIColor clearColor]];
		[self setDelaysContentTouches:NO];
		[self setMultipleTouchEnabled:NO];
		[self setScrollEnabled:YES];
		
		showAlreadyTokenized = NO;
		
		resultsArray = [[NSMutableArray alloc] init];
		
		// This view (contentView) is created for convenience, because it resizes and moves with the rest of the subviews.
		contentView = [[UIView alloc] initWithFrame:CGRectMake(0, kTokenFieldHeight, self.bounds.size.width, self.bounds.size.height - kTokenFieldHeight)];
		[contentView setBackgroundColor:[UIColor clearColor]];
		[self addSubview:contentView];
		[self setContentSize:CGSizeMake(self.bounds.size.width, self.contentView.frame.origin.y + self.contentView.bounds.size.height + 2)];
		[contentView release];
		
		tokenField = [[TITokenField alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, kTokenFieldHeight)];
		[tokenField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
		[tokenField setDelegate:self];
		[self addSubview:tokenField];
		[tokenField release];
		
		separator = [[UIView alloc] initWithFrame:CGRectMake(0, kTokenFieldHeight, self.bounds.size.width, kSeparatorHeight)];
		[separator setBackgroundColor:[UIColor colorWithWhite:0.7 alpha:1]];
		[self addSubview:separator];
		[separator release];
		
		resultsTable = [[UITableView alloc] initWithFrame:CGRectMake(0, kTokenFieldHeight + 1, self.bounds.size.width, 10)];
		[resultsTable setSeparatorColor:[UIColor colorWithWhite:0.85 alpha:1]];
		[resultsTable setBackgroundColor:[UIColor colorWithRed:0.92 green:0.92 blue:0.92 alpha:1]];
		[resultsTable setDelegate:self];
		[resultsTable setDataSource:self];
		[resultsTable setHidden:YES];
		[self addSubview:resultsTable];
		[resultsTable release];
		
		[self bringSubviewToFront:separator];
		[self bringSubviewToFront:tokenField];
		[self updateContentSize];
	}
	
    return self;
}

- (void)setFrame:(CGRect)frame {
	
	[super setFrame:frame];
	
	CGFloat width = frame.size.width;
	[separator ti_setWidth:width];
	[resultsTable ti_setWidth:width];
	[contentView ti_setWidth:width];
	[contentView ti_setHeight:frame.size.height - kTokenFieldHeight];
	[tokenField ti_setWidth:width];
	
	[self updateContentSize];
	[self layoutSubviews];
}

- (void)setContentOffset:(CGPoint)offset {
	[super setContentOffset:offset];
	[self layoutSubviews];
}

- (void)layoutSubviews {
	
	CGFloat relativeFieldHeight = tokenField.bounds.size.height - self.contentOffset.y;
	[resultsTable ti_setHeight:(self.bounds.size.height - relativeFieldHeight)];
}

- (void)updateContentSize {
	
	// I add 1 here so it'll do that elastic scrolling thing.
	// As a user, I like to drag a view around just for the sake of it.
	// Hopefully other people get the same weird kick :)
	[self setContentSize:CGSizeMake(self.bounds.size.width, self.contentView.frame.origin.y + self.contentView.bounds.size.height + 1)];
}

- (BOOL)canBecomeFirstResponder {
	return YES;
}

- (BOOL)becomeFirstResponder {
	return [tokenField becomeFirstResponder];
}

- (BOOL)resignFirstResponder {
	return [tokenField resignFirstResponder];
}

- (NSArray *)tokenTitles {
	return tokenField.tokenTitles;
}

#pragma mark TableView Methods

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	if ([delegate respondsToSelector:@selector(tokenField:resultsTableView:heightForRowAtIndexPath:)]){
		return [delegate tokenField:tokenField resultsTableView:tableView heightForRowAtIndexPath:indexPath];
	}
	
	return 44;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	
	// Hide the UITableView and shadow, then resize if there are no matches.
	
	if ([delegate respondsToSelector:@selector(tokenField:didFinishSearch:)]){
		[delegate tokenField:tokenField didFinishSearch:resultsArray];
	}
	
	BOOL hideTable = !resultsArray.count;
	[resultsTable setHidden:hideTable];
	[tokenField setShadowHidden:hideTable];
	[tokenField scrollForEdit:!hideTable];
	
	[separator setBackgroundColor:(hideTable ? [UIColor colorWithWhite:0.7 alpha:1] : 
								   [UIColor colorWithRed:0.588 green:0.588 blue:0.588 alpha:0.4])];
	
	return resultsArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	
	if ([delegate respondsToSelector:@selector(tokenField:resultsTableView:cellForObject:)]){
		return [delegate tokenField:tokenField resultsTableView:tableView cellForObject:[resultsArray objectAtIndex:indexPath.row]];
	}
	
    static NSString * CellIdentifier = @"ResultsCell";
    
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
	[cell.textLabel setText:[resultsArray objectAtIndex:indexPath.row]];
	
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	
	[tokenField addTokenWithTitle:[resultsArray objectAtIndex:indexPath.row]];
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark TextField Methods

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
	
	[resultsArray removeAllObjects];
	[resultsTable reloadData];
	
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
	[resultsTable reloadData];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
	[resultsTable setHidden:YES];
}

- (void)textFieldDidChange:(UITextField *)textField {
	
	[tokenField setShadowHidden:NO];
	[resultsTable setHidden:NO];
	
	[self resultsForSubstring:textField.text];
	
	if ([delegate respondsToSelector:@selector(tokenFieldTextDidChange:)]){
		[delegate tokenFieldTextDidChange:tokenField];
	}
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
	
	if ([string isEqualToString:@""] && [textField.text isEqualToString:kTextEmpty] && tokenField.tokens.count){
		
		//When the backspace is pressed, we capture it, highlight the last token, and hide the cursor.
		
		TIToken * tok = [tokenField.tokens lastObject];
		[tok setSelected:YES];
		[tokenField setText:kTextHidden];
		[tokenField updateHeight:NO];
		
		return NO;
	}
	
	if ([textField.text isEqualToString:kTextHidden] && ![string isEqualToString:@""]){
		// When the text is hidden, we don't want the user to be able to type anything.
		return NO;
	}
	
	if ([textField.text	isEqualToString:kTextHidden] && [string isEqualToString:@""]){
		
		// When the user presses backspace and the text is hidden,
		// we find the highlighted token, and remove it.
		
		for (TIToken * tok in [NSArray arrayWithArray:tokenField.tokens]){
			if (tok.selected){
				[tokenField removeToken:tok];
				return NO;
			}
		}
	}
	
	if ([string isEqualToString:@","]){
		[tokenField processLeftoverText];
		return NO;
	}
	
	return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	
	[tokenField processLeftoverText];
	
	if ([delegate respondsToSelector:@selector(tokenFieldShouldReturn:)]){
		return [delegate tokenFieldShouldReturn:tokenField];
	}
	
	return YES;
}

- (void)tokenFieldResized:(TITokenField *)aTokenField {
	
	[self setContentSize:CGSizeMake(self.bounds.size.width, self.contentView.frame.origin.y + self.contentView.bounds.size.height + 2)];
	
	if ([delegate respondsToSelector:@selector(tokenField:didChangeToFrame:)]){
		[delegate tokenField:aTokenField didChangeToFrame:aTokenField.frame];
	}
}

#pragma mark Results Methods
- (void)resultsForSubstring:(NSString *)substring {
	
	// The brute force searching method.
	// Takes the input string and compares it against everything in the source array.
	// If the source is massive, this could take some time.
	// You could always subclass and override this if needed or do it on a background thread.
	// GCD would be great for that.
	
	[resultsArray removeAllObjects];
	[resultsTable reloadData];
	
	NSUInteger loc = [[substring substringWithRange:NSMakeRange(0, 1)] isEqualToString:@" "] ? 1 : 0;
	NSString * typedString = [[substring substringWithRange:NSMakeRange(loc, substring.length - 1)] lowercaseString];
	
	NSArray * sourceCopy = [sourceArray copy];
	
	for (NSString * sourceObject in sourceCopy){
		
		NSString * query = [sourceObject lowercaseString];		
		if ([query rangeOfString:typedString].location != NSNotFound){
			
			if (showAlreadyTokenized){
				if (![resultsArray containsObject:sourceObject]){
					[resultsArray addObject:sourceObject];
				}
			}
			else
			{
				BOOL shouldAdd = YES;
				
				NSArray * tokensCopy = [tokenField.tokens copy];
				for (TIToken * token in tokensCopy){
					if ([[token.title lowercaseString] rangeOfString:query].location != NSNotFound){
						shouldAdd = NO;
						break;
					}
				}
				[tokensCopy release];
				
				if (shouldAdd){
					if (![resultsArray containsObject:sourceObject]){
						[resultsArray addObject:sourceObject];
					}
				}
			}
		}
	}
	
	[sourceCopy release];
	
	[resultsArray sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
	[resultsTable reloadData];
}

#pragma mark - Other stuff

- (NSString *)description {
	return [NSString stringWithFormat:@"<TITokenFieldView %p; Token count = %d>", self, self.tokenTitles.count];
}

- (void)dealloc {
	[self setDelegate:nil];
	[resultsArray release];
	[sourceArray release];
	[super dealloc];
}

@end

//==========================================================
#pragma mark - TITokenField -
//==========================================================
@implementation TITokenField
@synthesize tokens;
@synthesize numberOfLines;
@synthesize addButtonSelector;
@synthesize addButtonTarget;
@synthesize selectedToken;

#pragma mark Init
- (id)initWithFrame:(CGRect)frame {
	
    if ((self = [super initWithFrame:frame])){
		[self setup];
    }
	
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
	
	if ((self = [super initWithCoder:aDecoder])){
		[self setup];
	}
	
	return self;
}

- (void)setup {
	
	[self setBorderStyle:UITextBorderStyleNone];
	[self setTextColor:[UIColor blackColor]];
	[self setFont:[UIFont systemFontOfSize:14]];
	[self setBackgroundColor:[UIColor whiteColor]];
	[self setAutocorrectionType:UITextAutocorrectionTypeNo];
	[self setAutocapitalizationType:UITextAutocapitalizationTypeNone];
	[self setTextAlignment:UITextAlignmentLeft];
	[self setKeyboardType:UIKeyboardTypeDefault];
	[self setReturnKeyType:UIReturnKeyDefault];
	[self setClearsOnBeginEditing:NO];
	
	[self addTarget:self action:@selector(didBeginEditing) forControlEvents:UIControlEventEditingDidBegin];
	[self addTarget:self action:@selector(didEndEditing) forControlEvents:UIControlEventEditingDidEnd];
	[self addTarget:self action:@selector(didChangeText) forControlEvents:UIControlEventEditingChanged];
	
	addButton = [UIButton buttonWithType:UIButtonTypeContactAdd];
	[addButton setUserInteractionEnabled:YES];
	[addButton setHidden:YES];
	[addButton addTarget:self action:@selector(performButtonAction) forControlEvents:UIControlEventTouchUpInside];
	[self setRightView:addButton];
	
	[self setAddButtonAction:nil target:nil];
	
	[self setPromptText:@"To:"];
	[self setText:kTextEmpty];
	
	tokens = [[NSMutableArray alloc] init];
	selectedToken = nil;
	
	[self.layer setShadowColor:[[UIColor blackColor] CGColor]];
	[self.layer setShadowOpacity:0.6];
	[self.layer setShadowRadius:12];
}

- (void)setFrame:(CGRect)frame {
	[super setFrame:frame];
	[self setShadowHidden:!self.layer.shadowPath];
	[self updateHeight:YES];
}

- (void)setShadowHidden:(BOOL)hidden {
	[self.layer setMasksToBounds:hidden];
	[self.layer setShadowPath:(hidden ? nil : [[UIBezierPath bezierPathWithRect:self.bounds] CGPath])];
}

- (void)setText:(NSString *)text {
	[super setText:((text.length == 0 || [text isEqualToString:@""]) ? kTextEmpty : text)];
}

#pragma mark Event Handling
- (void)didBeginEditing {
	for (TIToken * token in tokens) [self addToken:token];
}

- (void)didEndEditing {
	
	[selectedToken setSelected:NO];
	selectedToken = nil;
	
	[self processLeftoverText];
	for (TIToken * token in tokens) [token removeFromSuperview];
	
	NSString * untokenized = kTextEmpty;
	
	if (tokens.count){
		
		NSMutableArray * titles = [[NSMutableArray alloc] init];
		for (TIToken * token in tokens) [titles addObject:token.title];
		
		untokenized = [titles componentsJoinedByString:@", "];
		CGSize untokSize = [untokenized sizeWithFont:[UIFont systemFontOfSize:14]];
		
		if (untokSize.width > self.bounds.size.width - 120){
			untokenized = [NSString stringWithFormat:@"%d recipients",  titles.count];
		}
		
		[titles release];
	}
	
	[self setText:untokenized];
	[self setShadowHidden:YES];
	[self updateHeight:NO];
}

- (void)didChangeText {
	
	if (self.text.length == 0 || [self.text isEqualToString:@""]){
		[self setText:kTextEmpty];
	}
}

- (void)processLeftoverText {
	
	if (![self.text isEqualToString:kTextEmpty] && ![self.text isEqualToString:kTextHidden] && 
		[[self.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] != 0){
		
		NSUInteger loc = [[self.text substringWithRange:NSMakeRange(0, 1)] isEqualToString:@" "] ? 1 : 0;
		[self addTokenWithTitle:[self.text substringWithRange:NSMakeRange(loc, self.text.length - 1)]];
	}
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
	
	// Stop the cut, copy, select and selectAll appearing when the text is 'empty'.
	if (action == @selector(cut:) || action == @selector(copy:) || action == @selector(select:) || action == @selector(selectAll:))
		return ![self.text isEqualToString:kTextEmpty];
	
	return [super canPerformAction:action withSender:sender];
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
	
	if (selectedToken && touch.view == self){
		[self deselectSelectedToken];
	}
	
	return [super beginTrackingWithTouch:touch withEvent:event];
}

#pragma mark Token Handling
- (void)addTokenWithTitle:(NSString *)title {
	
	if (title){
		TIToken * token = [[TIToken alloc] initWithTitle:title];
		[self addToken:token];
		[token release];
	}
}

- (void)addToken:(TIToken *)token {
	
	[self becomeFirstResponder];
	
	[token addTarget:self action:@selector(tokenTouchDown:) forControlEvents:UIControlEventTouchDown];
	[token addTarget:self action:@selector(tokenTouchUpInside:) forControlEvents:UIControlEventTouchUpInside];
	[self addSubview:token];
	
	if (![tokens containsObject:token]) [tokens addObject:token];
	
	[self updateHeight:NO];
	[self setText:kTextEmpty];
}

- (void)removeToken:(TIToken *)token {
	
	if (token == selectedToken)  
		selectedToken = nil;
	
	[token removeFromSuperview];
	[tokens removeObject:token];
	
	[self setText:kTextEmpty];
	[self updateHeight:NO];
}

- (void)selectToken:(TIToken *)token {
	
	[self deselectSelectedToken];
	
	selectedToken = token;
	[selectedToken setSelected:YES];
	
	if (![self isFirstResponder]) 
		[self becomeFirstResponder];
	
	[self setText:kTextHidden];
}

- (void)deselectSelectedToken {
	
	[selectedToken setSelected:NO];
	selectedToken = nil;
	
	[self setText:kTextEmpty];
}

- (void)tokenTouchDown:(TIToken *)token {
	
	if (selectedToken != token){
		[selectedToken setSelected:NO];
		selectedToken = nil;
	}
}

- (void)tokenTouchUpInside:(TIToken *)token {
	[self selectToken:token];
}

- (CGFloat)layoutTokens {
	
	// Adapted from Joe Hewitt's Three20 layout method.
	
	CGFloat fontHeight = (self.font.ascender - self.font.descender) + 1;
	CGFloat lineHeight = fontHeight + 15;
	CGFloat topMargin = floor(fontHeight / 1.75);
	CGFloat leftMargin = self.leftView ? self.leftView.bounds.size.width + 12 : 8;
	CGFloat rightMargin = 16;
	CGFloat rightMarginWithButton = addButton.hidden ? 8 : 46;
	CGFloat initialPadding = 8;
	CGFloat tokenPadding = 4;
	
	numberOfLines = 1;
	cursorLocation.x = leftMargin;
	cursorLocation.y = topMargin - 1;
	
	for (TIToken * token in tokens){
		
		if (token.superview){
			
			CGFloat lineWidth = cursorLocation.x + token.bounds.size.width + rightMargin;
			
			if (lineWidth >= self.bounds.size.width){
				
				numberOfLines++;
				cursorLocation.x = leftMargin;
				
				if (numberOfLines > 1) cursorLocation.x = initialPadding;
				cursorLocation.y += lineHeight;
			}
			
			CGRect newFrame = (CGRect){cursorLocation, token.bounds.size};
			
			if (!CGRectEqualToRect(token.frame, newFrame)){
				
				[token setFrame:newFrame];
				[token setAlpha:0.6];
				
				[UIView animateWithDuration:0.3 animations:^{[token setAlpha:1];}];
			}
			
			cursorLocation.x += token.bounds.size.width + tokenPadding;
			
		}
		
		CGFloat leftoverWidth = self.bounds.size.width - (cursorLocation.x + rightMarginWithButton);
		
		if (leftoverWidth < 50){
			
			numberOfLines++;
			cursorLocation.x = leftMargin;
			
			if (numberOfLines > 1) cursorLocation.x = initialPadding;
			cursorLocation.y += lineHeight;
		}
	}
	
	return cursorLocation.y + fontHeight + topMargin + 5;
}

#pragma mark View Handlers
- (void)updateHeight:(BOOL)scrollToTop {
	
	CGFloat previousHeight = self.bounds.size.height;
	CGFloat newHeight = [self layoutTokens];
	
	TITokenFieldView * parentView = (TITokenFieldView *)self.superview;
	
	if (previousHeight && previousHeight != newHeight){
		
		// Animating this seems to invoke the triple-tap-delete-key-loop-problem-thing™
		
		[UIView animateWithDuration:(previousHeight < newHeight ? 0.3 : 0) animations:^{
			[parentView.separator ti_setOriginY:newHeight];
			[parentView.resultsTable ti_setOriginY:newHeight + 1];
			[parentView.contentView ti_setOriginY:newHeight];
			[self ti_setHeight:newHeight];
		} completion:^(BOOL complete){
			[parentView tokenFieldResized:self];
			if (scrollToTop) [parentView setContentOffset:CGPointMake(0, 0) animated:YES];
		}];
	}
}

- (void)scrollForEdit:(BOOL)shouldMove {
	
	TITokenFieldView * parentView = (TITokenFieldView *)self.superview;
	
	[parentView setScrollsToTop:!shouldMove];
	[parentView setScrollEnabled:!shouldMove];
	
	CGFloat offset = numberOfLines == 1 || !shouldMove ? 0 : (self.bounds.size.height - kTokenFieldHeight) + 1;
	[parentView setContentOffset:CGPointMake(0, self.frame.origin.y + offset) animated:YES];
}

#pragma mark Other
- (NSArray *)tokenTitles {
	
	NSMutableArray * titles = [[NSMutableArray alloc] init];
	for (TIToken * token in tokens) [titles addObject:token.title];
	return [titles autorelease];
}

- (void)setPromptText:(NSString *)text {
	
	if (text){
		
		UILabel * label = (UILabel *)self.leftView;
		
		if (!label || ![label isKindOfClass:[UILabel class]]){
			label = [[UILabel alloc] initWithFrame:CGRectZero];
			[label setFont:[UIFont systemFontOfSize:15]];
			[label setTextColor:[UIColor colorWithWhite:0.5 alpha:1]];
			[self setLeftView:label];
			[label release];
			
			[self setLeftViewMode:UITextFieldViewModeAlways];
		}
		
		[label setText:text];
		[label sizeToFit];
	}
	else
	{
		[self setLeftView:nil];
	}
	
	[self layoutTokens];
}

- (void)setAddButtonAction:(SEL)action target:(id)sender {
	
	[self setAddButtonSelector:action];
	[self setAddButtonTarget:sender];
	
	[addButton setHidden:(!action || !sender)];
	[self setRightViewMode:(addButton.hidden ? UITextFieldViewModeNever : UITextFieldViewModeAlways)];
}

- (void)performButtonAction {
	
	if (!self.editing) [self becomeFirstResponder];	
	[addButtonTarget performSelector:addButtonSelector];
}

- (CGRect)textRectForBounds:(CGRect)bounds {
	
	if ([self.text isEqualToString:kTextHidden]) return CGRectMake(0, -20, 0, 0);
	
	CGRect frame = CGRectOffset(bounds, cursorLocation.x, cursorLocation.y + 3);
	frame.size.width -= (cursorLocation.x + 8 + (addButton.hidden ? 0 : 28));
	
	return frame;
}

- (CGRect)editingRectForBounds:(CGRect)bounds {
	return [self textRectForBounds:bounds];
}

- (CGRect)placeholderRectForBounds:(CGRect)bounds {
	return [self textRectForBounds:bounds];
}

- (CGRect)leftViewRectForBounds:(CGRect)bounds {
	return ((CGRect){{8, 11}, self.leftView.bounds.size});
}

- (CGRect)rightViewRectForBounds:(CGRect)bounds {
	
	return ((CGRect){{bounds.size.width - addButton.bounds.size.width - 6, 
		bounds.size.height - addButton.bounds.size.height - 6}, addButton.bounds.size});
}

- (NSString *)description {
	return [NSString stringWithFormat:@"<TITokenField %p; prompt = \"%@\">", self, ((UILabel *)self.leftView).text];
}

- (void)dealloc {
	[self setDelegate:nil];
	[tokens release];
    [super dealloc];
}

@end

//==========================================================
#pragma mark - TIToken -
//==========================================================
#define kTokenTitleFont [UIFont systemFontOfSize:14]

@implementation TIToken
@synthesize highlighted;
@synthesize selected;
@synthesize title;
@synthesize croppedTitle;
@synthesize tintColor;
@synthesize representedObject;

- (id)initWithTitle:(NSString *)aTitle representedObject:(id)object {
	
	if ((self = [super init])){
		
		title = [aTitle copy];
		croppedTitle = [(aTitle.length > 24 ? [[aTitle substringToIndex:24] stringByAppendingString:@"..."] : aTitle) copy];
		representedObject = [object retain];
		tintColor = [[UIColor colorWithRed:0.367 green:0.406 blue:0.973 alpha:1] retain];
		
		CGSize tokenSize = [croppedTitle sizeWithFont:kTokenTitleFont];
		[self setFrame:CGRectMake(0, 0, tokenSize.width + 17, tokenSize.height + 8)];
		[self setBackgroundColor:[UIColor clearColor]];
	}
	
	return self;
}

- (id)initWithTitle:(NSString *)aTitle {
	return [self initWithTitle:aTitle representedObject:nil];
}

- (void)drawRect:(CGRect)rect {
	
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	CGSize titleSize = [croppedTitle sizeWithFont:kTokenTitleFont];
	
	CGRect bounds = CGRectMake(0, 0, titleSize.width + 17, titleSize.height + 5);
	CGRect textBounds = bounds;
	textBounds.origin.x = (bounds.size.width - titleSize.width) / 2;
	textBounds.origin.y += 4;
	
	CGFloat arcValue = (bounds.size.height / 2) + 1;
	
	CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
	CGPoint endPoint = CGPointMake(0, self.bounds.size.height + 10);
	
	// Draw the outline.
	CGContextSaveGState(context);
	CGContextBeginPath(context);
	CGContextAddArc(context, arcValue, arcValue, arcValue, (M_PI / 2), (3 * M_PI / 2), NO);
	CGContextAddArc(context, bounds.size.width - arcValue, arcValue, arcValue, 3 * M_PI / 2, M_PI / 2, NO);
	CGContextClosePath(context);
	
	CGFloat red = 1;
	CGFloat green = 1;
	CGFloat blue = 1;
	CGFloat alpha = 1;
	[tintColor ti_getRed:&red green:&green blue:&blue alpha:&alpha];
	
	if (selected || highlighted){
        // highlighted outline color
		CGContextSetFillColor(context, (CGFloat[4]){red, green, blue, 1});
		CGContextFillPath(context);
		CGContextRestoreGState(context);
	}
	else
	{
		CGContextClip(context);
		CGFloat locations[2] = {0, 0.95};
        // unhighlighted outline color
		CGFloat components[8] = {red + .2, green +.2, blue +.2, alpha, red, green, blue, alpha};
		CGGradientRef gradient = CGGradientCreateWithColorComponents(colorspace, components, locations, 2);
		CGContextDrawLinearGradient(context, gradient, CGPointZero, endPoint, 0);
		CGGradientRelease(gradient);
		CGContextRestoreGState(context);
	}
    
    // Draw a white background so we can use alpha to lighten the inner gradient
    CGContextSaveGState(context);
	CGContextBeginPath(context);
	CGContextAddArc(context, arcValue, arcValue, (bounds.size.height / 2), (M_PI / 2) , (3 * M_PI / 2), NO);
	CGContextAddArc(context, bounds.size.width - arcValue, arcValue, arcValue - 1, (3 * M_PI / 2), (M_PI / 2), NO);
	CGContextClosePath(context);
    CGContextSetFillColor(context, (CGFloat[4]){1, 1, 1, 1});
    CGContextFillPath(context);
    CGContextRestoreGState(context);
	
	// Draw the inner gradient.
	CGContextSaveGState(context);
	CGContextBeginPath(context);
	CGContextAddArc(context, arcValue, arcValue, (bounds.size.height / 2), (M_PI / 2) , (3 * M_PI / 2), NO);
	CGContextAddArc(context, bounds.size.width - arcValue, arcValue, arcValue - 1, (3 * M_PI / 2), (M_PI / 2), NO);
	CGContextClosePath(context);
	
	CGContextClip(context);
	
	CGFloat locations[2] = {0, selected || highlighted ? 0.8 : 0.4};
    CGFloat highlightedComp[8] = {red, green, blue, .6, red, green, blue, 1};
    CGFloat nonHighlightedComp[8] = {red, green, blue, .2, red, green, blue, .4};
	
	CGGradientRef gradient = CGGradientCreateWithColorComponents (colorspace, selected || highlighted ? highlightedComp : nonHighlightedComp, locations, 2);
	CGContextDrawLinearGradient(context, gradient, CGPointZero, endPoint, 0);
	CGGradientRelease(gradient);
	CGColorSpaceRelease(colorspace);
	
	[(selected || highlighted ? [UIColor whiteColor] : [UIColor blackColor]) set];
	[croppedTitle drawInRect:textBounds withFont:kTokenTitleFont];
	
	CGContextRestoreGState(context);
}

- (void)setHighlighted:(BOOL)flag {
	
	if (highlighted != flag){
		highlighted = flag;
		[self setNeedsDisplay];
	}
}

- (void)setSelected:(BOOL)flag {
	
	if (selected != flag){
		selected = flag;
		[self setNeedsDisplay];
	}
}

- (void)setTintColor:(UIColor *)newTintColor {
	
	if (!newTintColor) newTintColor = [UIColor colorWithRed:0.867 green:0.906 blue:0.973 alpha:1];
	
	[newTintColor retain];
	[tintColor release];
	tintColor = newTintColor;
	
	[self setNeedsDisplay];
}

- (NSString *)description {
	return [NSString stringWithFormat:@"<TIToken %p; title = \"%@\">", self, title];
}

- (void)dealloc {
	[croppedTitle release];
	[title release];
	[tintColor release];
	[representedObject release];
    [super dealloc];
}

@end

//==========================================================
#pragma mark - Private Additions -
//==========================================================
@implementation UIColor (Private)

- (BOOL)ti_getRed:(CGFloat *)red green:(CGFloat *)green blue:(CGFloat *)blue alpha:(CGFloat *)alpha {
	
	CGColorSpaceModel colorSpaceModel = CGColorSpaceGetModel(CGColorGetColorSpace(self.CGColor));
	const CGFloat * components = CGColorGetComponents(self.CGColor);
	
	if (colorSpaceModel == kCGColorSpaceModelMonochrome){
		
		if (red) *red = components[0];
		if (green) *green = components[0];
		if (blue) *blue = components[0];
		if (alpha) *alpha = components[1];
		return YES;
	}
	
	if (colorSpaceModel == kCGColorSpaceModelRGB){
		
		if (red) *red = components[0];
		if (green) *green = components[1];
		if (blue) *blue = components[2];
		if (alpha) *alpha = components[3];
		return YES;
	}
	
	return NO;
}

@end

@implementation UIView (Private)

- (void)ti_setHeight:(CGFloat)height {
	
	CGRect newFrame = self.frame;
	newFrame.size.height = height;
	[self setFrame:newFrame];
}

- (void)ti_setWidth:(CGFloat)width {
	
	CGRect newFrame = self.frame;
	newFrame.size.width = width;
	[self setFrame:newFrame];
}

- (void)ti_setOriginY:(CGFloat)originY {
	
	CGRect newFrame = self.frame;
	newFrame.origin.y = originY;
	[self setFrame:newFrame];
}

@end