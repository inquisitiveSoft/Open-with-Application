//
//	AJKXcodeAdditions.m
//	
//	Created by Harry Jordan on 18/08/12.
//	Released under the MIT license:	http://opensource.org/licenses/mit-license.php
//


#import "AJKXcodeAdditions.h"



@implementation AJKXcodeAdditions


+ (void)pluginDidLoad:(NSBundle *)plugin
{
	static id __xcodeAdditionsPlugin = nil;
	static dispatch_once_t createXcodeAdditionsPlugin;
	dispatch_once(&createXcodeAdditionsPlugin, ^{
		__xcodeAdditionsPlugin = [[self alloc] init];
	});
}


- (id)init
{
	self = [super init];
	
	if(self) {
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



#pragma mark - Actions for Menu Items


- (void)showProjectInFinder:(id)sender
{
	NSString *projectDirectory = [self projectDirectory];
	
	if([projectDirectory length])
		[[NSWorkspace sharedWorkspace] openFile:projectDirectory];
}


- (void)openProjectInTerminal:(id)sender
{
	NSString *projectDirectory = [self projectDirectory];
	
	if([projectDirectory length])
		[[NSWorkspace sharedWorkspace] openFile:projectDirectory withApplication:@"Terminal"];
}


- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([menuItem action] == @selector(showProjectInFinder:) || [menuItem action] == @selector(openProjectInTerminal:)) {
		return [[self projectDirectory] length] > 0;
	}
	
	return YES;
}



#pragma mark - Actions for Menu Items


- (NSString *)projectDirectory
{
	for (NSDocument *document in [NSApp orderedDocuments]) {
		@try {
			//	_workspace(IDEWorkspace) -> representingFilePath(DVTFilePath) -> relativePathOnVolume(NSString)
			NSString *workspacePath = [document valueForKeyPath:@"_workspace.representingFilePath.relativePathOnVolume"];
			
			if([workspacePath length])
				return [workspacePath stringByDeletingLastPathComponent];
		}
		
		@catch (NSException *exception) {
			NSLog(@"AJKXcodeAdditions. Raised an exception while asking for the documents '_workspace.representingFilePath.relativePathOnVolume' key path: %@", exception);
		}
	}
	
	return nil;
}


@end
