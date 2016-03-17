//
//  AJKScriptWindowController.m
//  AJKOpenWithPlugin
//
//  Created by Harry Jordan on 24/08/2014.
//
//

#import <Cocoa/Cocoa.h>

#import "AJKScriptWindowController.h"
#import <ShortcutRecorder/ShortcutRecorder.h>
#import "LogClient.h"


NSString * const AJKSuggestedScripts = @"AJKSuggestedScripts";
NSString * const AJKSuggestedScriptName = @"name";
NSString * const AJKSuggestedScriptText = @"script";
NSString * const AJKSuggestedScriptRequiresSave = @"AJKSuggestedScriptRequiresSave";


@interface AJKScriptWindowController () <SRRecorderControlDelegate, NSTextFieldDelegate, NSTextViewDelegate>

@property (strong) SRValidator *shortcutValidator;

@property (unsafe_unretained, nonatomic) NSTextField *scriptNameField;
@property (unsafe_unretained, nonatomic) NSTextView *scriptTextView;

@property (unsafe_unretained, nonatomic) NSTextField *descriptionLabel;
@property (unsafe_unretained, nonatomic) SRRecorderControl *shortcutControl;
@property (unsafe_unretained, nonatomic) NSSegmentedControl *scopeSegmentedControl;

@property (unsafe_unretained, nonatomic) NSButton *suggestedScriptsButton;
@property (unsafe_unretained, nonatomic) NSButton *createShortcutButton;
@property (unsafe_unretained, nonatomic) NSButton *cancelButton;

@end


@implementation AJKScriptWindowController

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
	NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0.0, 0.0, 460.0, 480.0) styleMask:NSTitledWindowMask backing:NSBackingStoreBuffered defer:TRUE];
	self.window = window;
	NSView *contentView = window.contentView;
	
	
	CGFloat scriptNameLabelHeight = 26.0;
	NSRect scriptNameFrame = NSInsetRect(contentView.bounds, 12.0, 12.0);
	scriptNameFrame.origin.y += scriptNameFrame.size.height - scriptNameLabelHeight;
	scriptNameFrame.size.height = scriptNameLabelHeight;
	
	CGRect scriptTextViewFrame = scriptNameFrame;
	scriptNameFrame.size.width -= 42.0;
	
	NSTextField *scriptNameField = [[NSTextField alloc] initWithFrame:scriptNameFrame];
    scriptNameField.delegate = self;
	scriptNameField.placeholderString = NSLocalizedString(@"Script Name", @"Script Name placeholder text");
	[contentView addSubview:scriptNameField];
	self.scriptNameField = scriptNameField;
	
	CGRect arrowFrame = scriptTextViewFrame;
	arrowFrame.origin.x += scriptNameFrame.size.width;
	arrowFrame.size.width = 42.0;
	
	
	NSButton *suggestedScriptsButton = [[NSButton alloc] initWithFrame:arrowFrame];
	[suggestedScriptsButton setTarget:self];
	[suggestedScriptsButton setAction:@selector(presentSuggestedScriptsMenu:)];
	[suggestedScriptsButton setTitle:@""];
	[suggestedScriptsButton setBezelStyle:NSRoundedDisclosureBezelStyle];
	[suggestedScriptsButton setBordered:TRUE];
	[contentView addSubview:suggestedScriptsButton];
	self.suggestedScriptsButton = suggestedScriptsButton;

	
	scriptTextViewFrame.size.height = 268.0;
	scriptTextViewFrame.origin.y -= 12.0 + scriptTextViewFrame.size.height;
	
	NSTextView *scriptTextView = [[NSTextView alloc] initWithFrame:scriptTextViewFrame];
    scriptTextView.delegate = self;
	scriptTextView.font = [NSFont fontWithName:@"Menlo-Regular" size:12.0];
	[contentView addSubview:scriptTextView];
	self.scriptTextView = scriptTextView;

	
	// Insert the description label
	NSRect descriptionFrame = scriptTextViewFrame;
	descriptionFrame.size.height = 26.0;
	descriptionFrame.size.width -= 10.0 * 2;
	descriptionFrame.origin.y = scriptTextViewFrame.origin.y - descriptionFrame.size.height - 24.0;
	descriptionFrame.origin.x += 10.0;
	
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
	shortcutControlFrame.origin.x += 100.0;
	shortcutControlFrame.size.width -= 100.0 * 2;
	
	SRRecorderControl *shortcutControl = [[SRRecorderControl alloc] initWithFrame:shortcutControlFrame];
	shortcutControl.delegate = self;
	[shortcutControl setAllowedModifierFlags:(NSCommandKeyMask | NSAlternateKeyMask | NSShiftKeyMask) requiredModifierFlags:0 allowsEmptyModifierFlags:FALSE];
	self.shortcutControl = shortcutControl;

	[contentView addSubview:shortcutControl];
	self.shortcutControl = shortcutControl;


	// Insert the cancel button
	CGFloat cancelButtonWidth = 132.0;
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
	CGFloat createButtonWidth = 110.0;
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
		self.window.title = NSLocalizedString(@"Create Script", @"Create Script window title");
        
        self.scriptIdentifier = [[NSProcessInfo processInfo] globallyUniqueString];
		self.scriptText = @"#!/bin/sh";
        
		[self.cancelButton setAction:@selector(dismiss:)];
		self.cancelButton.title = NSLocalizedString(@"Cancel", @"Cancel button");
		
		[self.createShortcutButton setAction:@selector(createScript:)];
		self.createShortcutButton.title = NSLocalizedString(@"Create Script", @"Create Menu Item button");
	} else {
		self.window.title = NSLocalizedString(@"Edit Script", @"Edit Script window title");
		
		[self.cancelButton setAction:@selector(updateScript:)];
		self.cancelButton.title = NSLocalizedString(@"Update Script", @"Update button");;
		
		[self.createShortcutButton setAction:@selector(removeScript:)];
		self.createShortcutButton.title = NSLocalizedString(@"Remove Script", @"Remove button");
	}
}


- (void)showWindow:(id)sender
{
	// Prepare the window
	if(self.mode == AJKShortcutWindowCreateMode) {
		NSString *title = NSLocalizedString(@"Create script", @"Create Shortcut window title");
		self.window.title = title;
	} else {
		NSString *title = NSLocalizedString(@"Edit the '%@' Script", @"Edit Shortcut window title");
		self.window.title = [NSString stringWithFormat:title, self.scriptName];
	}
    
    [self.scriptNameField setStringValue: self.scriptName ?: NSLocalizedString(@"Script name", @"")];
	[self.descriptionLabel setStringValue: NSLocalizedString(@"Set a keyboard shortcut to trigger this script", @"")];
    
    self.scriptTextView.string = self.scriptText ?: @"";
	self.shortcutControl.objectValue = self.shortcutDictionary;
    
	[self.window center];
	[super showWindow:sender];
}


#pragma mark - Handle actions


- (IBAction)createScript:(id)sender
{
    self.scriptName = [self.scriptNameField stringValue];
    self.scriptText = [self.scriptTextView string];
    
	id <AJKScriptWindowControllerDelegate> delegate = self.delegate;
	if([delegate respondsToSelector:@selector(addScriptWithIdentifier:scriptName:script:shortcut:)]) {
		[delegate addScriptWithIdentifier:self.scriptIdentifier scriptName:self.scriptName script:self.scriptText shortcut:self.shortcutControl.objectValue];
	}
	
	[self dismiss:nil];
}


- (IBAction)removeScript:(id)sender
{
	id <AJKScriptWindowControllerDelegate> delegate = self.delegate;
	if([delegate respondsToSelector:@selector(removeScriptWithIdentifier:)]) {
        PluginLog(@"removeScriptWithIdentifier: %@ delegate: %@", self.scriptIdentifier, delegate);
		[delegate removeScriptWithIdentifier:self.scriptIdentifier];
	}
	
	[self dismiss:nil];
}


- (IBAction)updateScript:(id)sender
{
	[self createScript:nil];
}



- (IBAction)dismiss:(id)sender
{
	[self.window close];
	
	id <AJKScriptWindowControllerDelegate> delegate = self.delegate;
	if([delegate respondsToSelector:@selector(didDismissWindowController:)]) {
		[delegate didDismissWindowController:self];
	}
}


#pragma mark - Shortcut Recorder delegate methods


- (void)presentSuggestedScriptsMenu:(NSButton *)suggestedScriptsButton
{
	NSMenu *suggestedScriptsMenu = [[NSMenu alloc] init];
	NSDictionary *infoDictionary = [[NSBundle bundleForClass:self.class] infoDictionary];
	
	for(NSDictionary *scriptDictionary in infoDictionary[AJKSuggestedScripts]) {
		NSString *name = scriptDictionary[AJKSuggestedScriptName];
		
		if(name.length > 0) {
			NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:name action:@selector(fillSuggestedScriptFields:) keyEquivalent:@""];
			menuItem.representedObject = scriptDictionary;
			[suggestedScriptsMenu addItem:menuItem];
		}
	}
	
	NSEvent *event = [[NSApplication sharedApplication] currentEvent];
	[NSMenu popUpContextMenu:suggestedScriptsMenu withEvent:event forView:suggestedScriptsButton];
}


- (void)fillSuggestedScriptFields:(NSMenuItem *)menuItem
{
	NSDictionary *scriptDictionary = menuItem.representedObject;
	NSString *name = scriptDictionary[AJKSuggestedScriptName];
	NSString *script = scriptDictionary[AJKSuggestedScriptText];
	
	if(name && script) {
		[self.scriptNameField setStringValue:name];
		[self.scriptTextView setString:script];
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
