//
//	AJKExtendedOpening.m
//	
//	Created by Harry Jordan on 18/08/12.
//	Released under the MIT license:	http://opensource.org/licenses/mit-license.php
//


#import "AJKExtendedOpening.h"

#import <objc/runtime.h>
#import <ScriptingBridge/ScriptingBridge.h>


NSString * const AJKExternalEditorBundleIdentifier = @"AJKExternalEditorBundleIdentifier";
NSString * const AJKPreferedTerminalBundleIdentifier = @"AJKPreferedTerminalBundleIdentifier";


@implementation AJKExtendedOpening


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
			NSMenuItem *selectExternalEditorApplicationMenuItem = [[[NSMenuItem alloc] initWithTitle:@"Set External Editor…" action:@selector(selectExternalEditor:) keyEquivalent:@"E"] autorelease];
			[selectExternalEditorApplicationMenuItem setTarget:self];
			[selectExternalEditorApplicationMenuItem setAlternate:TRUE];
			[selectExternalEditorApplicationMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask | NSAlternateKeyMask | NSShiftKeyMask | NSControlKeyMask];
			[fileMenu insertItem:selectExternalEditorApplicationMenuItem atIndex:desiredMenuItemIndex];
			
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
			
			desiredMenuItemIndex++;
			NSMenuItem *selectTerminalMenuItem = [[[NSMenuItem alloc] initWithTitle:@"Set Prefered Terminal" action:@selector(selectPreferedTerminal:) keyEquivalent:@"T"] autorelease];
			[selectTerminalMenuItem setTarget:self];
			[selectTerminalMenuItem setAlternate:TRUE];
			[selectTerminalMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask | NSAlternateKeyMask | NSShiftKeyMask | NSControlKeyMask];
			[fileMenu insertItem:selectTerminalMenuItem atIndex:desiredMenuItemIndex];
		} else if([NSApp mainMenu]) {
			NSLog(@"AJKExtendedOpening Xcode plugin: Couldn't find an 'Open with External Editor' item in the File menu");
		}
	}

	return self;
}



#pragma mark - Actions for Menu Items


- (void)openWithExternalEditor:(id)sender
{
	NSURL *currentFileURL = [self currentFileURL];
	
	if(currentFileURL) {
		NSString *applicationIdentifier = [[NSUserDefaults standardUserDefaults] objectForKey:AJKExternalEditorBundleIdentifier];
		if(!applicationIdentifier) {
			applicationIdentifier = [self selectExternalEditor:nil];
		}
		
		if([applicationIdentifier length]) {
			[[NSWorkspace sharedWorkspace] openURLs:@[currentFileURL]
							withAppBundleIdentifier:applicationIdentifier
											options:0
					 additionalEventParamDescriptor:nil
								  launchIdentifiers:nil];
		}
	}
}


- (NSString *)selectExternalEditor:(id)sender
{
	NSString *applicationIdentifier = [self requestApplicationIdentifierForTitle:@"Select Your Prefered External Editor"];
	[[NSUserDefaults standardUserDefaults] setObject:applicationIdentifier forKey:AJKExternalEditorBundleIdentifier];
	return applicationIdentifier;
}


- (void)showProjectInFinder:(id)sender
{
	NSString *projectDirectory = [self projectDirectoryPath];
	
	if([projectDirectory length])
		[[NSWorkspace sharedWorkspace] openFile:projectDirectory];
}


- (void)openProjectInTerminal:(id)sender
{
	NSString *projectDirectory = [self projectDirectoryPath];
	
	if([projectDirectory length]) {
		NSString *applicationIdentifier = [[NSUserDefaults standardUserDefaults] objectForKey:AJKPreferedTerminalBundleIdentifier];
		
		if(!applicationIdentifier || [applicationIdentifier isEqualToString:@"Terminal"]) {
			[[NSWorkspace sharedWorkspace] openFile:projectDirectory withApplication:@"Terminal"];
		} else if([applicationIdentifier isCaseInsensitiveLike:@"com.googlecode.iTerm2"]) {
			// iTerm support is based on cdto: http://code.google.com/p/cdto/
			@try {
				projectDirectory = [projectDirectory stringByReplacingOccurrencesOfString:@"'" withString:@"\'"];
				NSString *command = [NSString stringWithFormat:@"clear; pushd '%@'", projectDirectory];
				
				SBApplication *iTerm = [SBApplication applicationWithBundleIdentifier:@"com.googlecode.iTerm2"];
//				BOOL shouldCreateNewTerminal = [iTerm isRunning];	// Seems to always return TRUE?
				
				[iTerm activate];
				id currentTerminal = [iTerm valueForKey:@"currentTerminal"];
				
//				if(shouldCreateNewTerminal) {
//					currentTerminal = [[[[iTerm classForScriptingClass:@"terminal"] alloc] init] autorelease];
//					[[iTerm valueForKey:@"terminals"] addObject:currentTerminal];
//					[currentTerminal performSelector:@selector(launchSession:) withObject:@"Default Session"];
//				}
				
				id currentSession = [currentTerminal valueForKey:@"currentSession"];
				[currentSession performSelector:@selector(writeContentsOfFile:text:) withObject:nil withObject:command];
			}
			
			@catch (NSException *exception) {
			}
		} else {
			NSLog(@"Unrecognized terminal emulator: %@", applicationIdentifier);
		}
	}
}



- (void)selectPreferedTerminal:(id)sender
{
	NSString *applicationIdentifier = [self requestApplicationIdentifierForTitle:@"Select Your Terminal Emulator of Choice"];
	[[NSUserDefaults standardUserDefaults] setObject:applicationIdentifier forKey:AJKPreferedTerminalBundleIdentifier];
}


- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if([menuItem action] == @selector(openWithExternalEditor:)) {
		return [[self currentFileURL] isFileURL];
	} else if([menuItem action] == @selector(showProjectInFinder:) || [menuItem action] == @selector(openProjectInTerminal:)) {
		return [[self projectDirectoryPath] length] > 0;
	}
	
	return YES;
}



#pragma mark - Actions for Menu Items



- (NSURL *)currentFileURL
{
	@try {
		NSWindowController *currentWindowController = [[NSApp keyWindow] windowController];
		
		if([currentWindowController isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")]) {
			id editor = [currentWindowController valueForKeyPath:@"editorArea.lastActiveEditorContext.editor"];
			if(!editor)
				return nil;
			
			id document = nil;;
			
			if([editor isKindOfClass:NSClassFromString(@"IDESourceCodeEditor")]) {
				document = [editor valueForKey:@"sourceCodeDocument"];
			} else if([editor isKindOfClass:NSClassFromString(@"IDESourceCodeComparisonEditor")]) {
				id primaryDocument = [editor valueForKey:@"primaryDocument"];
				
				if([primaryDocument isKindOfClass:NSClassFromString(@"IDESourceCodeDocument")]) {
					document = primaryDocument;
				}
			} else if([editor isKindOfClass:NSClassFromString(@"IDEPlistEditor")]) {
				// Could handle other types of document
				// [self printAllMethodsForObject:editor];
			}
			
			if(document) {
				NSArray *knownFileReferences = [document valueForKey:@"knownFileReferences"];
				
				for(id fileReference in knownFileReferences) {
					return [fileReference valueForKeyPath:@"resolvedFilePath.fileURL"];
				}
			}
		}
	}
	
	@catch (NSException *exception) {
		NSLog(@"AJKExtendedOpening Xcode plugin: Raised an exception while looking for the URL of the sourceCodeDocument: %@", exception);
	}
	
	return nil;
}


- (NSString *)projectDirectoryPath
{
	for (NSDocument *document in [NSApp orderedDocuments]) {
		@try {
			//	_workspace(IDEWorkspace) -> representingFilePath(DVTFilePath) -> relativePathOnVolume(NSString)
			NSURL *workspaceDirectoryURL = [[[document valueForKeyPath:@"_workspace.representingFilePath.fileURL"] URLByDeletingLastPathComponent] filePathURL];
			
			if(workspaceDirectoryURL) {
				return [workspaceDirectoryURL path];
			}
		}
		
		@catch (NSException *exception) {
			NSLog(@"AJKExtendedOpening Xcode plugin: Raised an exception while asking for the documents '_workspace.representingFilePath.relativePathOnVolume' key path: %@", exception);
		}
	}
	
	return nil;
}


- (NSString *)requestApplicationIdentifierForTitle:(NSString *)title
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
	[openPanel setTitle:title];
	
	if([openPanel runModal] == NSOKButton) {
		NSArray *applicationURLs = [openPanel URLs];
		
		if([applicationURLs count]) {
			NSURL *applicationURL = [applicationURLs objectAtIndex:0];
			NSString *applicationIdentifier = [[NSBundle bundleWithURL:applicationURL] bundleIdentifier];
			return applicationIdentifier;
		}
	}

	return nil;
}




#pragma mark - A helper method to use in developing


- (void)printAllMethodsForObject:(id)objectToInspect
{
	NSLog(@"%@", objectToInspect);
	
	int unsigned numberOfMethods;
	Method *methods = class_copyMethodList([objectToInspect class], &numberOfMethods);
	
	for(int i = 0; i < numberOfMethods; i++) {
		NSLog(@"%@: %@", NSStringFromClass([objectToInspect class]), NSStringFromSelector(method_getName(methods[i])));
	}
}




@end
