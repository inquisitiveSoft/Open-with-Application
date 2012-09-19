//
//	AJKXcodeAdditions.m
//	
//	Created by Harry Jordan on 18/08/12.
//	Released under the MIT license:	http://opensource.org/licenses/mit-license.php
//


#import "AJKXcodeAdditions.h"


NSString * const AJKExternalEditorBundleIdentifier = @"AJKExternalEditorBundleIdentifier";



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
		NSMenu *fileMenu = [[[NSApp mainMenu] itemWithTitle:@"File"] submenu];
		NSInteger desiredMenuItemIndex = [fileMenu indexOfItemWithTitle:@"Open with External Editor"];
		
		if(fileMenu && (desiredMenuItemIndex >= 0)) {
			[fileMenu removeItemAtIndex:desiredMenuItemIndex];
			
			NSMenuItem *openWithExternalEditorMenuItem = [[[NSMenuItem alloc] initWithTitle:@"Open with External Editor" action:@selector(openWithExternalEditor:) keyEquivalent:@"E"] autorelease];
			[openWithExternalEditorMenuItem setTarget:self];
			[openWithExternalEditorMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask | NSAlternateKeyMask | NSShiftKeyMask];
			[fileMenu insertItem:openWithExternalEditorMenuItem atIndex:desiredMenuItemIndex];
			
			desiredMenuItemIndex++;
			NSMenuItem *setExternalEditorApplicationMenuItem = [[[NSMenuItem alloc] initWithTitle:@"Set External Editor…" action:@selector(setExternalEditor:) keyEquivalent:@"E"] autorelease];
			[setExternalEditorApplicationMenuItem setTarget:self];
			[setExternalEditorApplicationMenuItem setAlternate:TRUE];
			[setExternalEditorApplicationMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask | NSAlternateKeyMask | NSShiftKeyMask | NSControlKeyMask];
			[fileMenu insertItem:setExternalEditorApplicationMenuItem atIndex:desiredMenuItemIndex];
			
			desiredMenuItemIndex++;
			NSMenuItem *showProjectInFinderMenuItem = [[[NSMenuItem alloc] initWithTitle:@"Show Project in Finder" action:@selector(showProjectInFinder:) keyEquivalent:@"R"] autorelease];
			[showProjectInFinderMenuItem setTarget:self];
			[showProjectInFinderMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask | NSAlternateKeyMask | NSShiftKeyMask];
			[fileMenu insertItem:showProjectInFinderMenuItem atIndex:desiredMenuItemIndex];
			
			desiredMenuItemIndex++;
			NSMenuItem *openInTerminalMenuItem = [[[NSMenuItem alloc] initWithTitle:@"Open Project in Terminal" action:@selector(openProjectInTerminal:) keyEquivalent:@"T"] autorelease];
			[openInTerminalMenuItem setTarget:self];
			[openInTerminalMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask | NSAlternateKeyMask | NSShiftKeyMask];
			[fileMenu insertItem:openInTerminalMenuItem atIndex:desiredMenuItemIndex];
		} else
			NSLog(@"AJKXcodeAdditions couldn't find an 'Open with External Editor' item in the File ment");
	}

	return self;
}



#pragma mark - Actions for Menu Items


- (void)openWithExternalEditor:(id)sender
{
	NSURL *currentFileURL = [self currentFileURL];
	
	if(currentFileURL) {
		NSString *applicationIdentifier = [[NSUserDefaults standardUserDefaults] objectForKey:AJKExternalEditorBundleIdentifier];
		if(!applicationIdentifier)
			applicationIdentifier = [self requestExternalEditor];
		
		if([applicationIdentifier length]) {
			[[NSWorkspace sharedWorkspace] openURLs:@[currentFileURL]
							withAppBundleIdentifier:applicationIdentifier
											options:0
					 additionalEventParamDescriptor:nil
								  launchIdentifiers:nil];
		}
	}
}


- (void)setExternalEditor:(id)sender
{
	(void)[self requestExternalEditor];
}


- (NSString *)requestExternalEditor
{
	// Allow the user to choose which application they use as their external editor
	NSURL *applicationsFolderURL = [NSURL URLWithString:@"/Applications"];
	NSArray *applicationDirectoryURLs = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationDirectory inDomains:NSLocalDomainMask];
	if([applicationDirectoryURLs count])
		applicationsFolderURL = [applicationDirectoryURLs objectAtIndex:0];
	
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setDirectoryURL:applicationsFolderURL];
	[openPanel setAllowedFileTypes:@[@"app"]];
	[openPanel setAllowsMultipleSelection:FALSE];
	[openPanel setTitle:@"Select Your Prefered External Editor"];
	
	if([openPanel runModal] == NSOKButton) {
		NSArray *applicationURLs = [openPanel URLs];
		
		if([applicationURLs count]) {
			NSURL *applicationURL = [applicationURLs objectAtIndex:0];
			NSString *applicationIdentifier = [[NSBundle bundleWithURL:applicationURL] bundleIdentifier];
			
			[[NSUserDefaults standardUserDefaults] setObject:applicationIdentifier forKey:AJKExternalEditorBundleIdentifier];
			return applicationIdentifier;
		}
	}

	return nil;
}


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
	if([menuItem action] == @selector(openWithExternalEditor:)) {
		return [[self currentFileURL] isFileURL];
	} else if([menuItem action] == @selector(showProjectInFinder:) || [menuItem action] == @selector(openProjectInTerminal:)) {
		return [[self projectDirectory] length] > 0;
	}
	
	return YES;
}



#pragma mark - Actions for Menu Items


- (NSURL *)currentFileURL
{
	@try {
		NSDocument *document = [[[NSApp keyWindow] windowController] document];
		NSArray *recentEditorDocumentURLs = [document valueForKey:@"recentEditorDocumentURLs"];
		
		if([recentEditorDocumentURLs count]) {
			NSURL *recentEditorDocumentURL = [recentEditorDocumentURLs objectAtIndex:0];
			
			// Test that the current document isn't
			NSString *pathExtension = [recentEditorDocumentURL pathExtension];
			NSArray *fileExtensionsToExclude = @[@"nib", @"xib", @"xcdatamodeld", @"jpeg", @"jpg", @"png", @"gif", @"pdf"];
			
			for (NSString *extensionToExclude in fileExtensionsToExclude) {
				if([pathExtension isEqualToString:extensionToExclude]) {
					pathExtension = nil;
					break;
				}
			}
			
			if(pathExtension)
				return recentEditorDocumentURL;
		}
	}
	
	
	@catch (NSException *exception) {
		NSLog(@"AJKXcodeAdditions. Raised an exception while asking for the documents 'recentEditorDocumentURLs' value: %@", exception);
	}
	
	return nil;
}


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
