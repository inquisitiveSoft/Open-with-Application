//
//  AJKAddApplicationWindowController.m
//  AJKExtendedOpening
//
//  Created by Harry Jordan on 24/08/2014.
//
//

#import "AJKCreateShortcutWindowController.h"
#import <ShortcutRecorder/ShortcutRecorder.h>


@interface AJKCreateShortcutWindowController () <SRRecorderControlDelegate>

@property (strong) NSTextField *descriptionLabel;
@property (strong) SRRecorderControl *shortcutControl;

@end


@implementation AJKCreateShortcutWindowController

- (instancetype)init
{
	self = [super init];
	
	if(self) {
		[self loadWindow];
	}
	
	return self;
}


- (void)loadWindow
{
	NSInteger styleMask = NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask;
	NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0.0, 0.0, 320.0, 272.0) styleMask:styleMask backing:NSBackingStoreBuffered defer:TRUE];
	window.title = NSLocalizedString(@"Create Shortcut", @"Create Shortcut window title");
	self.window = window;
	NSView *contentView = window.contentView;
	
	CGFloat scopeLabelHeight = 20.0;
	NSRect scopeLabelFrame = NSInsetRect(contentView.bounds, 12.0, 30.0);
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
	[scopeSegmentedControl setLabel:NSLocalizedString(@"Active Project", @"") forSegment:0];
	[scopeSegmentedControl setLabel:NSLocalizedString(@"Current Document", @"") forSegment:1];
	[scopeSegmentedControl setSelectedSegment:0];
	
	[scopeSegmentedControl sizeToFit];
	scopeFrame.origin.x += (scopeFrame.size.width - scopeSegmentedControl.frame.size.width) / 2;
	scopeSegmentedControl.frame = scopeFrame;
	
	[contentView addSubview:scopeSegmentedControl];
	
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
	[shortcutControl setAllowedModifierFlags:SRCocoaModifierFlagsMask requiredModifierFlags:0 allowsEmptyModifierFlags:FALSE];
	self.shortcutControl = shortcutControl;

	[contentView addSubview:shortcutControl];
	self.shortcutControl = shortcutControl;


	// Insert the cancel button
	NSRect cancelFrame = NSInsetRect(contentView.frame, 20.0, 8.0);
	cancelFrame.size = NSMakeSize(100.0, 44.0);
	
	NSButton *cancelButton = [[NSButton alloc] initWithFrame:cancelFrame];
	[cancelButton setBezelStyle:NSRoundedBezelStyle];
	[cancelButton setTitle:NSLocalizedString(@"Cancel", @"Cancel button")];
	[cancelButton setKeyEquivalent:@"\E"];
	[cancelButton setKeyEquivalentModifierMask:0];
	[cancelButton setTarget:self];
	[cancelButton setAction:@selector(dismiss:)];
	[contentView addSubview:cancelButton];


	// Insert the create button
	NSRect createFrame = NSInsetRect(contentView.bounds, 20.0, 8.0);
	createFrame.origin.x = createFrame.size.width - 120.0;
	createFrame.size = NSMakeSize(136.0, 44.0);
	
	NSButton *createButton = [[NSButton alloc] initWithFrame:createFrame];
	[createButton setTitle:NSLocalizedString(@"Create Shortcut", @"Create Menu Item button")];
	[createButton setKeyEquivalent:@"\r"];
	[createButton setKeyEquivalentModifierMask:0];
	[createButton.cell setControlSize:NSRegularControlSize];
	[createButton setBezelStyle:NSRoundedBezelStyle];
	[createButton setTarget:self];
	[createButton setAction:@selector(createShortcut:)];
	[contentView addSubview:createButton];
}


- (void)showWindow:(id)sender
{
	// Prepare the window
	NSString *description = NSLocalizedString(@"Set a keyboard shortcut for the\n'Open with %@' menu item", @"");
	description = [NSString stringWithFormat:description, self.applicationName];
	[self.descriptionLabel setStringValue:description];
	
	[self.window center];
	[super showWindow:sender];
}


- (IBAction)createShortcut:(id)sender {
	AJKAddApplicationBlock addApplicationBlock = self.completionBlock;
	
	if(addApplicationBlock) {
		NSDictionary *shortcut = self.shortcutRecorder.objectValue;
		NSLog(@"shortcut: %@", shortcut);
		
//		addApplicationBlock(self.applicationIdentifier, , self.modifierMask);
	}
}


- (IBAction)dismiss:(id)sender
{
	[self.window close];
}



#pragma mark - SRRecorderControlDelegate methods






@end
