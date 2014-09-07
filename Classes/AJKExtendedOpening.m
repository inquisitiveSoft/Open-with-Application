//
//	AJKExtendedOpening.m
//	
//	Created by Harry Jordan on 18/08/12.
//	Released under the MIT license:	http://opensource.org/licenses/mit-license.php
//


#import "AJKExtendedOpening.h"

#import <objc/runtime.h>
#import <ScriptingBridge/ScriptingBridge.h>
#import "AJKShortcutWindowController.h"
#import "AJKGlobalDefines.h"


NSString * const AJKExternalEditorBundleIdentifier = @"AJKExternalEditorBundleIdentifier";
NSString * const AJKPreferedTerminalBundleIdentifier = @"AJKPreferedTerminalBundleIdentifier";
NSString * const AJKOpenWithApplications = @"AJKOpenWithApplications";

NSString * const AJKApplicationIdentifier = @"AJKApplicationIdentifier";
NSString * const AJKShortcutScope = @"AJKShortcutScope";
NSString * const AJKShortcutDictionary = @"AJKShortcutDictionary";



@interface AJKExtendedOpening () <AJKShortcutWindowControllerDelegate>

@property (strong) NSMenuItem *openInApplicationMenuItem;

@property (strong) AJKShortcutWindowController *shortcutWindowController;

@end


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
			
			NSMenuItem *openWithExternalEditorMenuItem = [[NSMenuItem alloc] initWithTitle:@"Open with External Editor" action:@selector(openWithDefaultExternalEditor:) keyEquivalent:@"E"];
			[openWithExternalEditorMenuItem setTarget:self];
			[openWithExternalEditorMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask | NSAlternateKeyMask | NSShiftKeyMask];
			[fileMenu insertItem:openWithExternalEditorMenuItem atIndex:desiredMenuItemIndex];
			
			desiredMenuItemIndex++;
			NSMenuItem *selectExternalEditorApplicationMenuItem = [[NSMenuItem alloc] initWithTitle:@"Set External Editor…" action:@selector(selectExternalEditor:) keyEquivalent:@"E"];
			[selectExternalEditorApplicationMenuItem setTarget:self];
			[selectExternalEditorApplicationMenuItem setAlternate:TRUE];
			[selectExternalEditorApplicationMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask | NSAlternateKeyMask | NSShiftKeyMask | NSControlKeyMask];
			[fileMenu insertItem:selectExternalEditorApplicationMenuItem atIndex:desiredMenuItemIndex];
			
			desiredMenuItemIndex++;
			NSMenuItem *showProjectInFinderMenuItem = [[NSMenuItem alloc] initWithTitle:@"Show Project in Finder" action:@selector(showProjectInFinder:) keyEquivalent:@"R"];
			[showProjectInFinderMenuItem setTarget:self];
			[showProjectInFinderMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask | NSAlternateKeyMask | NSShiftKeyMask];
			[fileMenu insertItem:showProjectInFinderMenuItem atIndex:desiredMenuItemIndex];
			
			desiredMenuItemIndex++;
			NSMenuItem *openInTerminalMenuItem = [[NSMenuItem alloc] initWithTitle:@"Open Project in Terminal" action:@selector(openProjectInTerminal:) keyEquivalent:@"T"];
			[openInTerminalMenuItem setTarget:self];
			[openInTerminalMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask | NSAlternateKeyMask | NSShiftKeyMask];
			[fileMenu insertItem:openInTerminalMenuItem atIndex:desiredMenuItemIndex];
			
			desiredMenuItemIndex++;
			NSMenuItem *selectTerminalMenuItem = [[NSMenuItem alloc] initWithTitle:@"Set Prefered Terminal" action:@selector(selectPreferedTerminal:) keyEquivalent:@"T"];
			[selectTerminalMenuItem setTarget:self];
			[selectTerminalMenuItem setAlternate:TRUE];
			[selectTerminalMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask | NSAlternateKeyMask | NSShiftKeyMask | NSControlKeyMask];
			[fileMenu insertItem:selectTerminalMenuItem atIndex:desiredMenuItemIndex];
			
			desiredMenuItemIndex++;
			NSMenuItem *separatorItem = [NSMenuItem separatorItem];
			[fileMenu insertItem:separatorItem atIndex:desiredMenuItemIndex];
			
			desiredMenuItemIndex++;
			NSMenuItem *openInApplicationMenuItem = [[NSMenuItem alloc] initWithTitle:@"Open In Application" action:nil keyEquivalent:@""];
			[openInApplicationMenuItem setTarget:self];
			[fileMenu insertItem:openInApplicationMenuItem atIndex:desiredMenuItemIndex];
			self.openInApplicationMenuItem = openInApplicationMenuItem;
			
			[self updateOpenWithApplicationMenu];
		} else if([NSApp mainMenu]) {
			NSLog(@"AJKExtendedOpening Xcode plugin: Couldn't find an 'Open with External Editor' item in the File menu");
		}
	}

	return self;
}



#pragma mark - Validating Menu Items


- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if([menuItem action] == @selector(openWithExternalEditor:)) {
		return [[self currentFileURL] isFileURL];
	} else if([menuItem action] == @selector(showProjectInFinder:) || [menuItem action] == @selector(openProjectInTerminal:)) {
		return [[self projectDirectoryPath] length] > 0;
	} else if([menuItem action] == @selector(openApplicationForMenuItem:)) {
		if(menuItem.tag == AJKOpenWithDocumentScope) {
			return [[self currentFileURL] isFileURL];
		} else {
			return [[self projectDirectoryPath] length] > 0;
		}
	}
	
	return TRUE;
}


#pragma mark - Actions for Menu Items


- (void)openWithDefaultExternalEditor:(id)sender
{
	NSString *applicationIdentifier = [[NSUserDefaults standardUserDefaults] objectForKey:AJKExternalEditorBundleIdentifier];
	
	if(!applicationIdentifier) {
		applicationIdentifier = [self selectExternalEditor:nil];
	}
	
	[self openScope:AJKOpenWithDocumentScope inExternalEditorForIdentifier:applicationIdentifier];
}


- (void)openScope:(AJKOpenWithScope)scope inExternalEditorForIdentifier:(NSString *)applicationIdentifier
{
	NSURL *urlToOpen = [self currentFileURL];
	
	if(scope == AJKOpenWithProjectScope) {
		NSString *projectDirectory = [self projectDirectoryPath];
		NSURL *projectURL = [NSURL URLWithString:projectDirectory];
		
		if(projectURL) {
			urlToOpen = projectURL;
		}
	}
	
	NSLog(@"AJKExtendedOpening urlToOpen: %@", urlToOpen);
	if(urlToOpen && [applicationIdentifier length]) {
		// Handle special cases
		if([applicationIdentifier isEqualToString:@"com.fournova.Tower2"]) {
			// Tower (at least the second version) doesn't seem to handle NSWorkspace…openURLs
			NSTask *task = [[NSTask alloc] init];
			[task setCurrentDirectoryPath:urlToOpen.path];
			[task setLaunchPath:@"/usr/bin/open"];
			[task setArguments:@[@".", @"-a", @"Tower"]];
			[task launch];
		} else {
			[[NSWorkspace sharedWorkspace] openURLs:@[urlToOpen]
							withAppBundleIdentifier:applicationIdentifier
											options:NSWorkspaceLaunchDefault
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
		
		if(!applicationIdentifier
			|| [applicationIdentifier compare:@"com.apple.Terminal" options:NSCaseInsensitiveSearch] == NSOrderedSame
			|| [applicationIdentifier compare:@"Terminal" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
			//
			[[NSWorkspace sharedWorkspace] openFile:projectDirectory withApplication:@"Terminal"];
		} else if([applicationIdentifier isCaseInsensitiveLike:@"com.googlecode.iTerm2"]) {
			// iTerm support is based on cdto: http://code.google.com/p/cdto/
			@try {
				projectDirectory = [projectDirectory stringByReplacingOccurrencesOfString:@"'" withString:@"\'"];
				NSString *command = [NSString stringWithFormat:@"clear; pushd '%@'", projectDirectory];
				
				SBApplication *iTerm = [SBApplication applicationWithBundleIdentifier:@"com.googlecode.iTerm2"];
				[iTerm activate];
				
				id currentTerminal = [[[iTerm classForScriptingClass:@"terminal"] alloc] init];
				[[iTerm valueForKey:@"terminals"] addObject:currentTerminal];
				[currentTerminal performSelector:@selector(launchSession:) withObject:@"Default Session"];
				
				id currentSession = [currentTerminal valueForKey:@"currentSession"];
				[currentSession performSelector:@selector(writeContentsOfFile:text:) withObject:nil withObject:command];
			}
			
			@catch (NSException *exception) {
				NSLog(@"AJKExtendeddOpening: Encountered an exception while launching iTerm: %@", exception);
			}
		} else {
			NSLog(@"Unrecognized terminal emulator: '%@'", applicationIdentifier);
		}
	}
}


- (void)selectPreferedTerminal:(id)sender
{
	NSString *applicationIdentifier = [self requestApplicationIdentifierForTitle:@"Select Your Terminal Emulator of Choice"];
	[[NSUserDefaults standardUserDefaults] setObject:applicationIdentifier forKey:AJKPreferedTerminalBundleIdentifier];
}



#pragma mark - Managing the Open with… menu


- (void)registerOpenWithApplicationShortcut:(id)sender
{
	NSString *applicationIdentifier = [self requestApplicationIdentifierForTitle:@"Select an Application"];
	[self presentShortcutWindowForApplicationIdentifier:applicationIdentifier mode:AJKShortcutWindowCreateMode shortcut:nil];
}


- (void)openApplicationForMenuItem:(NSMenuItem *)menuItem
{
	NSString *applicationIdentifier = menuItem.representedObject;
	AJKOpenWithScope scope = (AJKOpenWithScope)menuItem.tag;
	
	if(applicationIdentifier) {
		[self openScope:scope inExternalEditorForIdentifier:applicationIdentifier];
	} else {
		NSLog(@"AJKExtendedOpening: Couldn't find application identifier for nemu item: %@", menuItem.title);
	}
}


- (void)editApplicationShortcutForMenuItem:(NSMenuItem *)menuItem
{
	NSString *applicationIdentifier = menuItem.representedObject;
	
	if(!applicationIdentifier) {
		return;
	}
	
	
	NSArray *openWithApplications = [[NSUserDefaults standardUserDefaults] objectForKey:AJKOpenWithApplications];
	
	for(NSDictionary *applicationDictionary in openWithApplications) {
		if([applicationDictionary[AJKApplicationIdentifier] isEqualToString:applicationIdentifier]) {
			[self presentShortcutWindowForApplicationIdentifier:applicationIdentifier mode:AJKShortcutWindowEditMode shortcut:applicationDictionary[AJKShortcutDictionary]];
			break;
		}
	}
}




- (void)presentShortcutWindowForApplicationIdentifier:(NSString *)applicationIdentifier mode:(AJKShortcutWindowMode)mode shortcut:(NSDictionary *)shortcutDictionary
{
	if(!applicationIdentifier) {
		return;
	}
	
	AJKShortcutWindowController *shortcutWindowController = [[AJKShortcutWindowController alloc] init];
	shortcutWindowController.delegate = self;
	shortcutWindowController.mode = mode;
	
	shortcutWindowController.applicationIdentifier = applicationIdentifier;
	shortcutWindowController.applicationName = [self applicationNameForIdentifier:applicationIdentifier];
	shortcutWindowController.shortcutDictionary = shortcutDictionary;
	
	[shortcutWindowController showWindow:nil];
	self.shortcutWindowController = shortcutWindowController;
}



- (void)updateOpenWithApplicationMenu
{
	NSMenu *applicationMenu = [[NSMenu alloc] initWithTitle:@""];
	
	NSArray *openWithApplications = [[NSUserDefaults standardUserDefaults] objectForKey:AJKOpenWithApplications];
	NSInteger numberOfRegisteredApplication = openWithApplications.count;
	
	for(NSDictionary *applicationDictionary in openWithApplications) {
		NSString *applicationIdentifier = applicationDictionary[AJKApplicationIdentifier];
		
		if(applicationIdentifier.length) {
			NSString *name = [self applicationNameForIdentifier:applicationIdentifier] ?: applicationIdentifier;
			
			
			// Gather the shortcut paramaters
			NSDictionary *shortcutDictionary = applicationDictionary[AJKShortcutDictionary];
			SRKeyEquivalentTransformer *keyEquivalentTransformer = [[SRKeyEquivalentTransformer alloc] init];
			NSString *keyEquivalent = [keyEquivalentTransformer transformedValue:shortcutDictionary];
			
			SRKeyEquivalentModifierMaskTransformer *keyEquivalentModifierMaskTransformer = [[SRKeyEquivalentModifierMaskTransformer alloc] init];
			NSNumber *keyEquivalentModifier = [keyEquivalentModifierMaskTransformer transformedValue:shortcutDictionary];
			
			
			// Add the Open With… menu item
			NSString *title = [NSString stringWithFormat:@"Open With %@", name];
			NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:title action:@selector(openApplicationForMenuItem:) keyEquivalent:keyEquivalent];
			menuItem.target = self;
			menuItem.representedObject = applicationIdentifier;
			menuItem.tag = [applicationDictionary[AJKShortcutScope] integerValue];
			[menuItem setKeyEquivalentModifierMask:[keyEquivalentModifier integerValue]];
			[applicationMenu addItem:menuItem];
			
			
			// Add the Edit menu item
			title = [NSString stringWithFormat:@"Edit Shortcut for %@", name];
			NSMenuItem *editMenuItem = [[NSMenuItem alloc] initWithTitle:title action:@selector(editApplicationShortcutForMenuItem:) keyEquivalent:keyEquivalent];
			editMenuItem.target = self;
			editMenuItem.representedObject = applicationIdentifier;
			[editMenuItem setKeyEquivalentModifierMask:[keyEquivalentModifier integerValue] | NSControlKeyMask];
			[editMenuItem setAlternate:TRUE];
			[applicationMenu addItem:editMenuItem];
		}
	}
	
	if(numberOfRegisteredApplication > 0) {
		[applicationMenu addItem:[NSMenuItem separatorItem]];
	}
	
	NSString *title = NSLocalizedString(@"Add Shortcut for Application…", @"Shortcut menu item");
	NSMenuItem *addApplicationMenuItem = [[NSMenuItem alloc] initWithTitle:title action:@selector(registerOpenWithApplicationShortcut:) keyEquivalent:@""];
	[addApplicationMenuItem setTarget:self];
	[applicationMenu addItem:addApplicationMenuItem];
	
	self.openInApplicationMenuItem.submenu = applicationMenu;
}


#pragma mark - AJKCreateShortcutWindowControllerDelegate methods


- (void)addApplicationWithIdentifier:(NSString *)applicationIdentifier scope:(AJKOpenWithScope)scope shortcut:(NSDictionary *)shortcut
{
	// A brute force way to avoid duplicates
	[self removeApplicationWithIdentifier:applicationIdentifier];
	
	NSMutableArray *openWithApplicationsArray = [[[NSUserDefaults standardUserDefaults] objectForKey:AJKOpenWithApplications] mutableCopy];
	
	if(!openWithApplicationsArray) {
		openWithApplicationsArray = [[NSMutableArray alloc] initWithCapacity:1];
	}
	
	if(applicationIdentifier.length) {
		NSMutableDictionary *applicationDictionary = [[NSMutableDictionary alloc] init];
		applicationDictionary[AJKApplicationIdentifier] = applicationIdentifier;
		applicationDictionary[AJKShortcutScope] = @(scope);
		
		if(shortcut) {
			applicationDictionary[AJKShortcutDictionary] = shortcut;
		}
		
		[openWithApplicationsArray addObject:applicationDictionary];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:openWithApplicationsArray forKey:AJKOpenWithApplications];
	[[NSUserDefaults standardUserDefaults] synchronize];
}


- (void)removeApplicationWithIdentifier:(NSString *)applicationIdentifier
{
	if(!applicationIdentifier) {
		return;
	}
	
	NSArray *openWithApplicationsArray = [[NSUserDefaults standardUserDefaults] objectForKey:AJKOpenWithApplications];
	NSIndexSet *indexesToKeep = [openWithApplicationsArray indexesOfObjectsPassingTest:^BOOL(NSDictionary *applicationDictionary, NSUInteger idx, BOOL *stop) {
		return ![applicationDictionary[AJKApplicationIdentifier] isEqualToString:applicationIdentifier];
	}];
	
	if(indexesToKeep.count < openWithApplicationsArray.count) {
		NSArray *objectsToKeep = [openWithApplicationsArray objectsAtIndexes:indexesToKeep];
		[[NSUserDefaults standardUserDefaults] setObject:objectsToKeep forKey:AJKOpenWithApplications];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
}


- (void)didDismissWindowController:(NSWindowController *)windowController
{
	if(self.shortcutWindowController == windowController) {
		self.shortcutWindowController = nil;
	}
	
	[self updateOpenWithApplicationMenu];
}



#pragma mark -


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
	// Allow the user to select an application
	NSURL *applicationsFolderURL = [NSURL URLWithString:@"/Applications"];
	NSArray *applicationDirectoryURLs = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationDirectory inDomains:NSLocalDomainMask];
	if([applicationDirectoryURLs count]) {
		applicationsFolderURL = [applicationDirectoryURLs objectAtIndex:0];
	}
	
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


- (NSString *)applicationNameForIdentifier:(NSString *)applicationIdentifier
{
	NSString *appName = nil;
	
	if(applicationIdentifier) {
		NSURL *applicationURL = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:applicationIdentifier];
		NSBundle *bundle = [NSBundle bundleWithURL:applicationURL];
		appName = [bundle objectForInfoDictionaryKey:@"CFBundleName"];
	}
	
	return appName;
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
