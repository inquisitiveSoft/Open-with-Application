//
//	AJKExtendedOpening.m
//	
//	Created by Harry Jordan on 18/08/12.
//	Released under the MIT license:	http://opensource.org/licenses/mit-license.php
//


#import "AJKExtendedOpening.h"

#import <objc/runtime.h>
#import <ScriptingBridge/ScriptingBridge.h>
#import "AJKCreateShortcutWindowController.h"
#import "AJKGlobalDefines.h"


NSString * const AJKExternalEditorBundleIdentifier = @"AJKExternalEditorBundleIdentifier";
NSString * const AJKPreferedTerminalBundleIdentifier = @"AJKPreferedTerminalBundleIdentifier";
NSString * const AJKOpenWithApplications = @"AJKOpenWithApplications";

NSString * const AJKApplicationIdentifier = @"AJKApplicationIdentifier";
NSString * const AJKApplicationName = @"AJKApplicationName";
NSString * const AJKShortcutScope = @"AJKShortcutScope";
NSString * const AJKShortcutDictionary = @"AJKShortcutDictionary";



@interface AJKExtendedOpening ()

@property (strong) NSMenuItem *openInApplicationMenuItem;

@property (strong) AJKCreateShortcutWindowController *shortcutWindowController;

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
			
			NSMenuItem *openWithExternalEditorMenuItem = [[NSMenuItem alloc] initWithTitle:@"Open with External Editor" action:@selector(openWithExternalEditor:) keyEquivalent:@"E"];
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
	NSURL *urlToOpen = nil;
	
	if(urlToOpen) {
		urlToOpen = [self currentFileURL];
	} else {
		NSString *projectDirectory = [self projectDirectoryPath];
		urlToOpen = [NSURL URLWithString:projectDirectory];
	}
	
	if(urlToOpen) {
		if([applicationIdentifier length]) {
			[[NSWorkspace sharedWorkspace] openURLs:@[urlToOpen]
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
				BOOL shouldCreateNewTerminal = [iTerm isRunning];	// Seems to always return TRUE?
				
				[iTerm activate];
				id currentTerminal = [iTerm valueForKey:@"currentTerminal"];
				
				if(shouldCreateNewTerminal) {
					currentTerminal = [[[iTerm classForScriptingClass:@"terminal"] alloc] init];
					[[iTerm valueForKey:@"terminals"] addObject:currentTerminal];
					[currentTerminal performSelector:@selector(launchSession:) withObject:@"Default Session"];
				}
				
				id currentSession = [currentTerminal valueForKey:@"currentSession"];
				[currentSession performSelector:@selector(writeContentsOfFile:text:) withObject:nil withObject:command];
			}
			
			@catch (NSException *exception) {
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



#pragma mark - The custom application menu


 - (void)registerOpenWithApplication:(id)sender
{
	NSString *applicationIdentifier = [self requestApplicationIdentifierForTitle:@"Select an Application"];
	
	if(applicationIdentifier) {
		AJKCreateShortcutWindowController *shortcutWindowController = [[AJKCreateShortcutWindowController alloc] init];
		shortcutWindowController.applicationIdentifier = applicationIdentifier;
		
		NSString *applicationName = [self applicationNameForIdentifier:applicationIdentifier];
		shortcutWindowController.applicationName = applicationName;
		
		__weak AJKExtendedOpening *weakSelf = self;
		shortcutWindowController.completionBlock = ^(NSString *applicationIdentifier, AJKOpenWithScope scope, NSDictionary *shortcut) {
			[weakSelf addApplicationWithIdentifier:applicationIdentifier name:applicationName scope:scope shortcut:shortcut];
		};
		
		[shortcutWindowController showWindow:nil];
		self.shortcutWindowController = shortcutWindowController;
	}
}


- (void)addApplicationWithIdentifier:(NSString *)applicationIdentifier name:(NSString *)applicationName scope:(AJKOpenWithScope)scope shortcut:(NSDictionary *)shortcut
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
		applicationDictionary[AJKShortcutDictionary] = shortcut;
		applicationDictionary[AJKApplicationName] = applicationName;
		
		[openWithApplicationsArray addObject:applicationDictionary];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:openWithApplicationsArray forKey:AJKOpenWithApplications];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[self updateOpenWithApplicationMenu];
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
	}
}


- (void)updateOpenWithApplicationMenu
{
	NSMenu *applicationMenu = [[NSMenu alloc] initWithTitle:@""];
	
	NSArray *openWithApplications = [[NSUserDefaults standardUserDefaults] objectForKey:AJKOpenWithApplications];
	NSInteger numberOfRegisteredApplication = openWithApplications.count;
	NSLog(@"openWithApplications: %@", openWithApplications);
	
	for(NSDictionary *applicationDictionary in openWithApplications) {
		NSString *applicationIdentifier = applicationDictionary[AJKApplicationIdentifier];

		if(applicationIdentifier.length) {
			NSString *name = applicationDictionary[AJKApplicationName] ?: [self applicationNameForIdentifier:applicationIdentifier];
			NSString *title = [NSString stringWithFormat:@"Open with %@", name];
			
			NSDictionary *shortcutDictionary = applicationDictionary[AJKShortcutDictionary];
			SRKeyEquivalentTransformer *keyEquivalentTransformer = [[SRKeyEquivalentTransformer alloc] init];
			NSString *keyEquivalent = [keyEquivalentTransformer transformedValue:shortcutDictionary];
			
			NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:title action:@selector(openApplicationForMenuItem:) keyEquivalent:keyEquivalent];
			menuItem.title = title;
			menuItem.tag = [applicationDictionary[AJKShortcutScope] integerValue];
			menuItem.target = self;
			menuItem.representedObject = applicationIdentifier;
			
			SRKeyEquivalentModifierMaskTransformer *keyEquivalentModifierMaskTransformer = [[SRKeyEquivalentModifierMaskTransformer alloc] init];
			NSNumber *keyEquivalentModifier = [keyEquivalentModifierMaskTransformer transformedValue:shortcutDictionary];
			
			if(keyEquivalentModifier) {
				[menuItem setKeyEquivalentModifierMask:[keyEquivalentModifier integerValue]];
			}
			
			[applicationMenu addItem:menuItem];
		}
	}
	
	if(numberOfRegisteredApplication > 0) {
		[applicationMenu addItem:[NSMenuItem separatorItem]];
	}
	
	NSMenuItem *addApplicationMenuItem = [[NSMenuItem alloc] initWithTitle:@"Add Application" action:@selector(registerOpenWithApplication:) keyEquivalent:@""];
	[addApplicationMenuItem setTarget:self];
	[applicationMenu addItem:addApplicationMenuItem];
	
	self.openInApplicationMenuItem.submenu = applicationMenu;
}


- (void)openApplicationForMenuItem:(id)sender
{
	NSLog(@"sender: %@", sender);
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
