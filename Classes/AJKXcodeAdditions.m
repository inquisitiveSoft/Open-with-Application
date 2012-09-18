//
//	AJKXcodeAdditions.m
//	
//	Created by Harry Jordan on 18/08/12.
//	Released under the MIT license:	http://opensource.org/licenses/mit-license.php
//


#import "AJKXcodeAdditions.h"


@interface AJKXcodeAdditions () {
	NSString *lastPathComponent;
}

@end



@implementation AJKXcodeAdditions


+ (void)pluginDidLoad:(NSBundle *)plugin
{
	static id AJKXcodeAdditionsPlugin__ = nil;
	static dispatch_once_t createXcodeAdditionsPlugin;
	dispatch_once(&createXcodeAdditionsPlugin, ^{
		AJKXcodeAdditionsPlugin__ = [[self alloc] init];
	});
}


- (id)init
{
	self = [super init]
	
	if(self) {
		// Register for notifications
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeKey:) name:NSWindowDidBecomeKeyNotification object:nil];
		
		
		// Add menu bar items for the 'Show Project in Finder' and 'Open Project in Terminal' actions
		NSMenuItem *fileMenuItem = [[NSApp mainMenu] itemWithTitle:@"File"];
		NSInteger desiredMenuItemIndex = [[fileMenuItem submenu] indexOfItemWithTitle:@"Open with External Editor"];
		
		if(fileMenuItem && (desiredMenuItemIndex >= 0)) {
			desiredMenuItemIndex++;
			
			NSMenuItem *showProjectInFinderMenuItem = [[[NSMenuItem alloc] initWithTitle:@"Show Project in Finder" action:@selector(showProjectInFinder:) keyEquivalent:@"R"] autorelease];
			[showProjectInFinderMenuItem setTarget:self];
			[showProjectInFinderMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask | NSAlternateKeyMask | NSShiftKeyMask];
			[[fileMenuItem submenu] insertItem:showProjectInFinderMenuItem atIndex:desiredMenuItemIndex];
			
			desiredMenuItemIndex++;
			NSMenuItem *openInTerminalMenuItem = [[[NSMenuItem alloc] initWithTitle:@"Open Project in Terminal" action:@selector(openProjectInTerminal:) keyEquivalent:@"T"] autorelease];
			[openInTerminalMenuItem setTarget:self];
			[openInTerminalMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask | NSAlternateKeyMask | NSShiftKeyMask];
			[[fileMenuItem submenu] insertItem:openInTerminalMenuItem atIndex:desiredMenuItemIndex];
		} else
			NSLog(@"AJKXcodeAdditions couldn't find an 'Open with External Editor' item in the File ment");
	}

	return self;
}


#pragma mark - Menu Item Actions


- (void)showProjectInFinder:(id)sender
{
	NSString *projectDirectory = [self projectDirectory] ? : lastProjectDirectory;
	
	if([projectDirectory length]) {
		[[NSWorkspace sharedWorkspace] selectFile:projectDirectory inFileViewerRootedAtPath:@""];
		lastProjectDirectory = projectDirectory;
	}
}


- (void)openProjectInTerminal:(id)sender
{
	NSString *projectDirectory = [self projectDirectory] ? : lastProjectDirectory;
	
	if([projectDirectory length]) {
		[[NSWorkspace sharedWorkspace] openFile:projectDirectory withApplication:@"Terminal"];
		lastProjectDirectory = projectDirectory;
	}
}


- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([menuItem action] == @selector(showProjectInFinder:) || [menuItem action] == @selector(openProjectInTerminal:)) {
		return [[[[NSApp keyWindow] windowController] window] isVisible]
				&& (([lastProjectDirectory length] > 0) || ([[self projectDirectory] length] > 0));
	}
	
	return YES;
}



#pragma mark - Notifications


- (void)windowDidBecomeKey:(NSNotification *)notification
{
	// Store the current projects directory so that it can be referenced while anciliary windows are front most
	NSString *projectDirectory = [self projectDirectory];
	
	if([projectDirectory length])
		lastProjectDirectory = projectDirectory;
}



- (NSString *)projectDirectory
{
	@try {
		id workspace = [[[NSApp keyWindow] windowController] valueForKeyPath:@"_workspace"];
		return [[workspace valueForKeyPath:@"representingFilePath.relativePathOnVolume"] stringByDeletingLastPathComponent];
	}
	
	@catch (NSException *exception) {
//		NSLog(@"AJKXcodeAdditions encountered an exception while asking for the current projects directory: %@", exception);
	}
	
	return nil;
}


@end
