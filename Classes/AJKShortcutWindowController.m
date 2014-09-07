//
//  AJKAddApplicationWindowController.m
//  AJKExtendedOpening
//
//  Created by Harry Jordan on 24/08/2014.
//
//

#import "AJKShortcutWindowController.h"
#import <ShortcutRecorder/ShortcutRecorder.h>


@interface AJKShortcutWindowController () <SRRecorderControlDelegate>

@property (strong) SRValidator *shortcutValidator;

@property (unsafe_unretained, nonatomic) NSTextField *descriptionLabel;
@property (unsafe_unretained, nonatomic) SRRecorderControl *shortcutControl;
@property (unsafe_unretained, nonatomic) NSSegmentedControl *scopeSegmentedControl;

@property (unsafe_unretained, nonatomic) NSButton *createShortcutButton;
@property (unsafe_unretained, nonatomic) NSButton *cancelButton;

@end


@implementation AJKShortcutWindowController

- (instancetype)init
{
	self = [super init];
	
	if(self) {
		self.shortcutValidator = [[SRValidator alloc] init];
		
		[self loadWindow];
	}
	
	return self;
}


- (void)loadWindow
{
	NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0.0, 0.0, 340.0, 266.0) styleMask:NSTitledWindowMask backing:NSBackingStoreBuffered defer:TRUE];
	self.window = window;
	NSView *contentView = window.contentView;
	
	
	CGFloat scopeLabelHeight = 20.0;
	NSRect scopeLabelFrame = NSInsetRect(contentView.bounds, 12.0, 20.0);
	NSRect scopeFrame = scopeLabelFrame;
	
	scopeLabelFrame.origin.y += scopeFrame.size.height - scopeLabelHeight;
	scopeLabelFrame.size.height = scopeLabelHeight;
	
	NSTextField *scopeLabel = [[NSTextField alloc] initWithFrame:scopeLabelFrame];
	[scopeLabel setEditable:FALSE];
	[scopeLabel setBordered:FALSE];
	[scopeLabel setBackgroundColor:[NSColor clearColor]];
	[scopeLabel setFont:[NSFont systemFontOfSize:13.0]];
	[scopeLabel setAlignment:NSCenterTextAlignment];
	[scopeLabel setStringValue:NSLocalizedString(@"Select the scope of the shortcut", @"Scope label text")];
	[contentView addSubview:scopeLabel];
	
	
	CGFloat scopeHeight = 40.0;
	scopeFrame.origin.y += scopeFrame.size.height - scopeHeight - scopeLabelHeight;
	scopeFrame.origin.x += 10.0;
	scopeFrame.size.width -= 10.0;
	scopeFrame.size.height = scopeHeight;
	NSRect descriptionFrame = scopeFrame;
	
	NSSegmentedControl *scopeSegmentedControl = [[NSSegmentedControl alloc] initWithFrame:scopeFrame];
	scopeSegmentedControl.segmentCount = 2;
	[scopeSegmentedControl setLabel:NSLocalizedString(@"Project Folder", @"") forSegment:0];
	[scopeSegmentedControl setLabel:NSLocalizedString(@"Current Document", @"") forSegment:1];
	[scopeSegmentedControl setSelectedSegment:0];
	
	[scopeSegmentedControl sizeToFit];
	scopeFrame.origin.x += (scopeFrame.size.width - scopeSegmentedControl.frame.size.width) / 2;
	scopeSegmentedControl.frame = scopeFrame;
	
	[contentView addSubview:scopeSegmentedControl];
	self.scopeSegmentedControl = scopeSegmentedControl;
	
	
	// Insert the description label
	CGFloat descriptionHeight = 40.0;
	descriptionFrame.origin.y += descriptionFrame.size.height - descriptionHeight - scopeHeight - 26;
	descriptionFrame.origin.x += 10.0;
	descriptionFrame.size.width -= 10.0 * 2;
	descriptionFrame.size.height = descriptionHeight;
	
	NSTextField *descriptionLabel = [[NSTextField alloc] initWithFrame:descriptionFrame];
	[descriptionLabel setEditable:FALSE];
	[descriptionLabel setBordered:FALSE];
	[descriptionLabel setBackgroundColor:[NSColor clearColor]];
	[descriptionLabel setFont:[NSFont systemFontOfSize:13.0]];
	[descriptionLabel setAlignment:NSCenterTextAlignment];
	
	[contentView addSubview:descriptionLabel];
	self.descriptionLabel = descriptionLabel;
	
	
	// Insert the shortcut control
	NSRect shortcutControlFrame = descriptionFrame;
	shortcutControlFrame.origin.y -= descriptionFrame.size.height + 8.0;
	shortcutControlFrame.origin.x += 20.0;
	shortcutControlFrame.size.width -= 20.0 * 2;
	
	SRRecorderControl *shortcutControl = [[SRRecorderControl alloc] initWithFrame:shortcutControlFrame];
	shortcutControl.delegate = self;
	[shortcutControl setAllowedModifierFlags:(NSCommandKeyMask | NSAlternateKeyMask | NSShiftKeyMask) requiredModifierFlags:0 allowsEmptyModifierFlags:FALSE];
	self.shortcutControl = shortcutControl;

	[contentView addSubview:shortcutControl];
	self.shortcutControl = shortcutControl;


	// Insert the cancel button
	CGFloat cancelButtonWidth = 140.0;
	NSRect cancelFrame = NSInsetRect(contentView.frame, 20.0, 8.0);
	cancelFrame.size = NSMakeSize(cancelButtonWidth, 44.0);
	
	NSButton *cancelButton = [[NSButton alloc] initWithFrame:cancelFrame];
	[cancelButton setBezelStyle:NSRoundedBezelStyle];
	[cancelButton setKeyEquivalent:@"\E"];
	[cancelButton setKeyEquivalentModifierMask:0];
	[cancelButton setTarget:self];
	[contentView addSubview:cancelButton];
	self.cancelButton = cancelButton;
	
	
	// Insert the create button
	CGFloat createButtonWidth = 140.0;
	NSRect createFrame = NSInsetRect(contentView.bounds, 20.0, 8.0);
	createFrame.origin.x = createFrame.size.width - createButtonWidth;
	createFrame.size = NSMakeSize(createButtonWidth + 16.0, 44.0);
	
	NSButton *createButton = [[NSButton alloc] initWithFrame:createFrame];
	[createButton setKeyEquivalent:@"\r"];
	[createButton setKeyEquivalentModifierMask:0];
	[createButton.cell setControlSize:NSRegularControlSize];
	[createButton setBezelStyle:NSRoundedBezelStyle];
	[createButton setTarget:self];
	[contentView addSubview:createButton];
	self.createShortcutButton = createButton;
}


- (void)setMode:(AJKShortcutWindowMode)mode
{
	_mode = mode;
	
	if(self.mode == AJKShortcutWindowCreateMode) {
		self.window.title = NSLocalizedString(@"Create Shortcut", @"Create Shortcut window title");
		
		[self.cancelButton setAction:@selector(dismiss:)];
		self.cancelButton.title = NSLocalizedString(@"Cancel", @"Cancel button");
		
		[self.createShortcutButton setAction:@selector(createShortcut:)];
		self.createShortcutButton.title = NSLocalizedString(@"Create Shortcut", @"Create Menu Item button");
	} else {
		self.window.title = NSLocalizedString(@"Edit Shortcut", @"Edit Shortcut window title");
		
		[self.cancelButton setAction:@selector(updateShortcut:)];
		self.cancelButton.title = NSLocalizedString(@"Update Shortcut", @"Update button");;
		
		[self.createShortcutButton setAction:@selector(removeShortcut:)];
		self.createShortcutButton.title = NSLocalizedString(@"Remove Shortcut", @"Remove button");
	}
}


- (void)showWindow:(id)sender
{
	// Prepare the window
	if(self.mode == AJKShortcutWindowCreateMode) {
		NSString *title = NSLocalizedString(@"Create shortcut for %@", @"Create Shortcut window title");
		self.window.title = [NSString stringWithFormat:title, self.applicationName];
	} else {
		NSString *title = NSLocalizedString(@"Edit the 'Open With %@' Shortcut", @"Edit Shortcut window title");
		self.window.title = [NSString stringWithFormat:title, self.applicationName];
	}
	
	NSString *description = NSLocalizedString(@"Set a keyboard shortcut for the\n'Open with %@' menu item", @"");
	description = [NSString stringWithFormat:description, self.applicationName];
	[self.descriptionLabel setStringValue:description];
	
	self.shortcutControl.objectValue = self.shortcutDictionary;
	
	[self.window center];
	[super showWindow:sender];
}


#pragma mark - Handle actions


- (IBAction)createShortcut:(id)sender
{
	id <AJKShortcutWindowControllerDelegate> delegate = self.delegate;
	if([delegate respondsToSelector:@selector(addApplicationWithIdentifier:scope:shortcut:)]) {
		[delegate addApplicationWithIdentifier:self.applicationIdentifier scope:[self.scopeSegmentedControl selectedSegment] shortcut:self.shortcutControl.objectValue];
	}
	
	[self dismiss:nil];
}


- (IBAction)removeShortcut:(id)sender
{
	id <AJKShortcutWindowControllerDelegate> delegate = self.delegate;
	if([delegate respondsToSelector:@selector(removeApplicationWithIdentifier:)]) {
		[delegate removeApplicationWithIdentifier:self.applicationIdentifier];
	}
	
	[self dismiss:nil];
}


- (IBAction)updateShortcut:(id)sender
{
	id <AJKShortcutWindowControllerDelegate> delegate = self.delegate;
	if([delegate respondsToSelector:@selector(addApplicationWithIdentifier:scope:shortcut:)]) {
		[delegate addApplicationWithIdentifier:self.applicationIdentifier scope:[self.scopeSegmentedControl selectedSegment] shortcut:self.shortcutControl.objectValue];
	}
	
	[self dismiss:nil];
}



- (IBAction)dismiss:(id)sender
{
	[self.window close];
	
	id <AJKShortcutWindowControllerDelegate> delegate = self.delegate;
	if([delegate respondsToSelector:@selector(didDismissWindowController:)]) {
		[delegate didDismissWindowController:self];
	}
}


#pragma mark - Shortcut Recorder delegate methods


- (BOOL)shortcutRecorder:(SRRecorderControl *)aRecorder canRecordShortcut:(NSDictionary *)shortcut
{
	if(SRShortcutEqualToShortcut(shortcut, self.shortcutDictionary)) {
		// Allow the key combo to be set to the existing value
		return TRUE;
	}
	
	// Otherwise look for an existing key combo
	NSNumber *keyCode = shortcut[SRShortcutKeyCode];
	BOOL isValid = FALSE;
	
	if(keyCode) {
		NSError *error = nil;
		NSNumber *flags = shortcut[SRShortcutModifierFlagsKey];
		isValid = ![self.shortcutValidator isKeyCode:[keyCode shortValue] andFlagsTaken:[flags integerValue] error:&error];
		
		if(!isValid) {
			NSBeep();
		}
	}
	
	return isValid;
}



@end
