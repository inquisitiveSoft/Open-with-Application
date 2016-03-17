//
//	AJKOpenWithPlugin.m
//	
//	Created by Harry Jordan on 18/08/12.
//	Released under the MIT license:	http://opensource.org/licenses/mit-license.php
//


#import "AJKOpenWithPlugin.h"

#import <objc/runtime.h>
#import <ScriptingBridge/ScriptingBridge.h>

#import "AJKShortcutWindowController.h"
#import "AJKScriptWindowController.h"

#import "AJKDefines.h"
#import "LogClient.h"


NSString * const AJKExternalEditorBundleIdentifier = @"AJKExternalEditorBundleIdentifier";
NSString * const AJKPreferedTerminalBundleIdentifier = @"AJKPreferedTerminalBundleIdentifier";
NSString * const AJKOpenWithApplications = @"AJKOpenWithApplications";
NSString * const AJKOpenWithScripts = @"AJKOpenWithScripts";

NSString * const AJKShortcutIdentifier = @"AJKShortcutIdentifier";
NSString * const AJKScriptName = @"AJKScriptName";
NSString * const AJKShortcutScopeKey = @"AJKShortcutScopeKey";
NSString * const AJKShortcutDictionary = @"AJKShortcutDictionary";
NSString * const AJKScript = @"AJKScript";



@interface AJKOpenWithPlugin () <AJKShortcutWindowControllerDelegate, AJKScriptWindowControllerDelegate>

@property (copy) NSString *pluginName;
@property (strong, nonatomic, readonly) NSUserDefaults *userDefaults;

@property (strong) NSMenuItem *openInApplicationMenuItem;
@property (strong) AJKShortcutWindowController *shortcutWindowController;
@property (strong) AJKScriptWindowController *scriptWindowController;

@end


@implementation AJKOpenWithPlugin
@synthesize userDefaults = _userDefaults;


+ (void)pluginDidLoad:(NSBundle *)plugin
{
	static id __openWithAdditionsPlugin = nil;
	static dispatch_once_t createXcodeAdditionsPlugin;
	dispatch_once(&createXcodeAdditionsPlugin, ^{
		__openWithAdditionsPlugin = [[self alloc] init];
	});
}


- (id)init
{
	self = [super init];

	if(self) {
		NSBundle *pluginBundle = [NSBundle bundleForClass:self.class];
		self.pluginName = [pluginBundle infoDictionary][@"CFBundleName"];
	
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(applicationDidFinishLaunching:)
         name:NSApplicationDidFinishLaunchingNotification
         object:nil];
        
	}

	return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    
    [self insertMenuItems];
}

- (void)insertMenuItems
{
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
		NSMenuItem *editPodfileMenuItem = [[NSMenuItem alloc] initWithTitle:@"Edit Podfile" action:@selector(editPodfile:) keyEquivalent:@"P"];
		[editPodfileMenuItem setTarget:self];
		[editPodfileMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask | NSAlternateKeyMask | NSShiftKeyMask];
		[fileMenu insertItem:editPodfileMenuItem atIndex:desiredMenuItemIndex];
		
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
		PluginLogWithName(self.pluginName, @"Couldn't find an 'Open with External Editor' item in the File menu");
	}
}


#pragma mark - Validating Menu Items


- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if([menuItem action] == @selector(openWithExternalEditor:)) {
		return [[self currentFileURL] isFileURL];
	} else if([menuItem action] == @selector(showProjectInFinder:) || [menuItem action] == @selector(openProjectInTerminal:)) {
		return [self projectDirectoryURL].path.length > 0;
	} else if([menuItem action] == @selector(openApplicationForMenuItem:)) {
		if(menuItem.tag == AJKShortcutScopeDocument) {
			return [[self currentFileURL] isFileURL];
		} else {
			return [self projectDirectoryURL].path.length > 0;
		}
	} else if([menuItem action] == @selector(editPodfile:)) {
		return [[self userDefaults] objectForKey:AJKExternalEditorBundleIdentifier] && [self projectDirectoryURL].path.length > 0;
	}
	
	return TRUE;
}


#pragma mark - Actions for Menu Items


- (void)openWithDefaultExternalEditor:(id)sender
{
	NSString *applicationIdentifier = [[self userDefaults] objectForKey:AJKExternalEditorBundleIdentifier];
	
	if(!applicationIdentifier) {
		applicationIdentifier = [self selectExternalEditor:nil];
	}
	
	[self openScope:AJKShortcutScopeDocument inExternalEditorForIdentifier:applicationIdentifier];
}


- (void)openScope:(AJKShortcutScope)scope inExternalEditorForIdentifier:(NSString *)applicationIdentifier
{
	NSURL *urlToOpen = nil;
	
	if(scope == AJKShortcutScopeProject) {
		urlToOpen = [self projectDirectoryURL];
	} else if(scope == AJKShortcutScopePodfile) {
		urlToOpen = [[self projectDirectoryURL] URLByAppendingPathComponent:@"Podfile"];
	} else {
		urlToOpen = [self currentFileURL];
	}
	
	if(urlToOpen && [applicationIdentifier length]) {
		// Handle special cases
		@try {
			if([applicationIdentifier isEqualToString:@"com.fournova.Tower2"]) {
				// Tower (at least the second version) doesn't seem to handle NSWorkspace…openURLs in the way that you'd hope
				NSTask *task = [[NSTask alloc] init];
				[task setCurrentDirectoryPath:urlToOpen.path];
				[task setLaunchPath:@"/usr/bin/open"];
				[task setArguments:@[@".", @"-a", @"Tower"]];
				[task launch];
			} else if([applicationIdentifier isEqualToString:@"com.github.GitHub"]) {
				// Ditto for the GitHub app
				NSTask *task = [[NSTask alloc] init];
				[task setCurrentDirectoryPath:urlToOpen.path];
				[task setLaunchPath:@"/usr/bin/open"];
				[task setArguments:@[@".", @"-a", @"GitHub"]];
				[task launch];
			} else {
				[[NSWorkspace sharedWorkspace] openURLs:@[urlToOpen]
								withAppBundleIdentifier:applicationIdentifier
												options:NSWorkspaceLaunchDefault
						 additionalEventParamDescriptor:nil
									  launchIdentifiers:nil];
			}
		}
		
		@catch (NSException *exception) {
			PluginLogWithName(self.pluginName, @"Encountered an exception: %@ in openScope:%ld inExternalEditorForIdentifier:%@", exception, scope, applicationIdentifier);
		}
	}
}


- (void)performScriptForIdentifier:(NSString *)scriptIdentifier
{
	NSURL *fileURL = [self currentFileURL];
	NSURL *projectURL = [self projectDirectoryURL];
	
	if(projectURL && [scriptIdentifier length]) {
        NSDictionary *scriptDictionary = [self scriptDictionaryForIdentifier:scriptIdentifier];
        
        // Handle special cases
        @try {
            NSMutableString *shellScript = [scriptDictionary[AJKScript] mutableCopy];
            
            if(!(shellScript.length > 0)) {
                return;
            }
            
            
            // Substitute variables
            [shellScript replaceOccurrencesOfString:@"$CURSOR_LINE" withString:@"0" options:0 range:NSMakeRange(0, shellScript.length)];
            [shellScript replaceOccurrencesOfString:@"$CURSOR_COLUMN" withString:@"0" options:0 range:NSMakeRange(0, shellScript.length)];
            [shellScript replaceOccurrencesOfString:@"$PATH_TO_FILE" withString:[fileURL path] ?: @"" options:0 range:NSMakeRange(0, shellScript.length)];
            [shellScript replaceOccurrencesOfString:@"$PATH_TO_PROJECT" withString:[projectURL path] ?: @"" options:0 range:NSMakeRange(0, shellScript.length)];
            
            
            // Save the shell script to a temporary file
            NSString *scriptPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
            scriptPath = [scriptPath stringByAppendingPathExtension:@"sh"];
            
            NSError *error = nil;
            if(![shellScript writeToFile:scriptPath atomically:TRUE encoding:NSUTF8StringEncoding error:&error]) {
                PluginLogWithName(self.pluginName, @"Couldn't save shell script: %@", error);
                return;
            }
            
            // Mark it as executable
            NSNumber *permissions = [NSNumber numberWithUnsignedLong: 493];
            NSDictionary *attributes = [NSDictionary dictionaryWithObject:permissions forKey:NSFilePosixPermissions];
            
            if(![[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:scriptPath error:&error]) {
                PluginLogWithName(self.pluginName, @"Couldn't set the shell script '%@' to be executable %@", scriptPath, error);
                return;
            }
            
            
            // Use Applescript to invoke the shell script in Terminal
            NSBundle *pluginBundle = [NSBundle bundleForClass:self.class];
            NSURL *appleScriptURL = [pluginBundle URLForResource:@"Run Script in Terminal" withExtension:@"scpt"];
            
            NSString *appleScriptString = [NSString stringWithContentsOfURL:appleScriptURL encoding:NSUTF8StringEncoding error:&error];
            
            if (appleScriptString.length > 0) {
                appleScriptString = [appleScriptString stringByReplacingOccurrencesOfString:@"SHELL_SCRIPT_PATH" withString:scriptPath];
                
                NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:appleScriptString];
                
                NSDictionary *errorDictionary = nil;
                NSAppleEventDescriptor *returnDescriptor = [appleScript executeAndReturnError:&errorDictionary];
                PluginLogWithName(self.pluginName, @">> %@, errorDictionary: %@", returnDescriptor, errorDictionary);
            }
        }
        
        
        @catch (NSException *exception) {
            PluginLogWithName(self.pluginName, @"Encountered an exception: %@ in performScriptForIdentifier:%@", exception, scriptIdentifier);
        }
	}
}


- (NSDictionary *)scriptDictionaryForIdentifier:(NSString *)scriptIdentifier
{
    if(!scriptIdentifier) {
        return nil;
    }
    
    NSArray *scriptsArray = [[self userDefaults] objectForKey:AJKOpenWithScripts];

    for(NSDictionary *script in scriptsArray) {
        if([script[AJKShortcutIdentifier] isEqualToString:scriptIdentifier]) {
            return script;
        }
    }
    
    return nil;
}



- (NSString *)selectExternalEditor:(id)sender
{
	NSString *applicationIdentifier = [self requestApplicationIdentifierForTitle:@"Select Your Prefered External Editor"];
	[[self userDefaults] setObject:applicationIdentifier forKey:AJKExternalEditorBundleIdentifier];
	return applicationIdentifier;
}


- (void)showProjectInFinder:(id)sender
{
	NSURL *projectDirectoryURL = [self projectDirectoryURL];
	
	if(projectDirectoryURL) {
		[[NSWorkspace sharedWorkspace] openURL:projectDirectoryURL];
	}
}


- (void)openProjectInTerminal:(id)sender
{
	NSString *projectDirectory = [self projectDirectoryURL].path;
	
	if([projectDirectory length]) {
		NSString *applicationIdentifier = [[self userDefaults] objectForKey:AJKPreferedTerminalBundleIdentifier];
		
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
				PluginLogWithName(self.pluginName, @"Encountered an exception while launching iTerm: %@", exception);
			}
		} else {
			PluginLogWithName(self.pluginName, @"Unrecognized terminal emulator: '%@'", applicationIdentifier);
		}
	}
}


- (void)selectPreferedTerminal:(id)sender
{
	NSString *applicationIdentifier = [self requestApplicationIdentifierForTitle:@"Select Your Terminal Emulator of Choice"];
	[[self userDefaults] setObject:applicationIdentifier forKey:AJKPreferedTerminalBundleIdentifier];
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
	AJKShortcutScope scope = (AJKShortcutScope)menuItem.tag;
	
	if(applicationIdentifier) {
		[self openScope:scope inExternalEditorForIdentifier:applicationIdentifier];
	} else {
		PluginLogWithName(self.pluginName, @"Couldn't find application identifier for menu item: %@", menuItem.title);
	}
}


- (void)editApplicationShortcutForMenuItem:(NSMenuItem *)menuItem
{
	NSString *applicationIdentifier = menuItem.representedObject;
	
	if(!applicationIdentifier) {
		return;
	}
	
	
	NSArray *openWithApplications = [[self userDefaults] objectForKey:AJKOpenWithApplications];
	
	for(NSDictionary *applicationDictionary in openWithApplications) {
		if([applicationDictionary[AJKShortcutIdentifier] isEqualToString:applicationIdentifier]) {
			[self presentShortcutWindowForApplicationIdentifier:applicationIdentifier mode:AJKShortcutWindowEditMode shortcut:applicationDictionary[AJKShortcutDictionary]];
			break;
		}
	}
	
	[self removeApplicationWithIdentifier:applicationIdentifier];
}


- (void)presentShortcutWindowForApplicationIdentifier:(NSString *)applicationIdentifier mode:(AJKShortcutWindowMode)mode shortcut:(NSDictionary *)shortcutDictionary
{
	if(!applicationIdentifier) {
		return;
	}
	
	AJKShortcutWindowController *shortcutWindowController = [[AJKShortcutWindowController alloc] init];
	shortcutWindowController.delegate = self;
	
	shortcutWindowController.applicationIdentifier = applicationIdentifier;
	shortcutWindowController.applicationName = [self applicationNameForIdentifier:applicationIdentifier];
	shortcutWindowController.shortcutDictionary = shortcutDictionary;
    [shortcutWindowController showWindow:nil];
    
    shortcutWindowController.mode = mode;
	self.shortcutWindowController = shortcutWindowController;
}



#pragma mark - AJKShortcutWindowControllerDelegate methods


- (void)addApplicationWithIdentifier:(NSString *)applicationIdentifier scope:(AJKShortcutScope)scope shortcut:(NSDictionary *)shortcut
{
	// A brute force way to avoid duplicates
	[self removeApplicationWithIdentifier:applicationIdentifier];
	
	NSMutableArray *openWithApplicationsArray = [[[self userDefaults] objectForKey:AJKOpenWithApplications] mutableCopy];
	
	if(!openWithApplicationsArray) {
		openWithApplicationsArray = [[NSMutableArray alloc] initWithCapacity:1];
	}
	
	if(applicationIdentifier.length) {
		NSMutableDictionary *applicationDictionary = [[NSMutableDictionary alloc] init];
		applicationDictionary[AJKShortcutIdentifier] = applicationIdentifier;
		applicationDictionary[AJKShortcutScopeKey] = @(scope);
		
		if(shortcut) {
			applicationDictionary[AJKShortcutDictionary] = shortcut;
		}
		
		[openWithApplicationsArray addObject:applicationDictionary];
	}
	
	[[self userDefaults] setObject:openWithApplicationsArray forKey:AJKOpenWithApplications];
	[[self userDefaults] synchronize];
}


- (void)removeApplicationWithIdentifier:(NSString *)applicationIdentifier
{
	if(!applicationIdentifier) {
		return;
	}
	
	NSArray *openWithApplicationsArray = [[self userDefaults] objectForKey:AJKOpenWithApplications];
	NSIndexSet *indexesToKeep = [openWithApplicationsArray indexesOfObjectsPassingTest:^BOOL(NSDictionary *applicationDictionary, NSUInteger idx, BOOL *stop) {
		return ![applicationDictionary[AJKShortcutIdentifier] isEqualToString:applicationIdentifier];
	}];
	
	if(indexesToKeep.count < openWithApplicationsArray.count) {
		NSArray *objectsToKeep = [openWithApplicationsArray objectsAtIndexes:indexesToKeep];
		[[self userDefaults] setObject:objectsToKeep forKey:AJKOpenWithApplications];
		[[self userDefaults] synchronize];
	}
}


- (void)editPodfile:(id)sender
{
	NSString *applicationIdentifier = [[self userDefaults] objectForKey:AJKExternalEditorBundleIdentifier];
	[self openScope:AJKShortcutScopePodfile inExternalEditorForIdentifier:applicationIdentifier];
}



#pragma mark - Managing the Script section


- (void)registerScriptWithApplicationShortcut:(id)sender
{
	NSString *scriptIdentifier = [[NSProcessInfo processInfo] globallyUniqueString];
    [self presentScriptWindowForIdentifier:scriptIdentifier scriptName:nil scriptText:nil mode:AJKShortcutWindowCreateMode shortcut:nil];
}


- (void)performScriptForMenuItem:(NSMenuItem *)menuItem
{
	NSString *scriptIdentifier = menuItem.representedObject;
	
	if(scriptIdentifier) {
		[self performScriptForIdentifier:scriptIdentifier];
	} else {
		PluginLogWithName(self.pluginName, @"Couldn't find script identifier for menu item: %@", menuItem.title);
	}
}


- (void)editScriptForMenuItem:(NSMenuItem *)menuItem
{
	NSString *scriptIdentifier = menuItem.representedObject;
	
	if(!scriptIdentifier) {
		return;
	}
	
	
	NSArray *scripts = [[self userDefaults] objectForKey:AJKOpenWithScripts];
	
	for(NSDictionary *applicationDictionary in scripts) {
		if([applicationDictionary[AJKShortcutIdentifier] isEqualToString:scriptIdentifier]) {
            [self presentScriptWindowForIdentifier:scriptIdentifier scriptName:applicationDictionary[AJKScriptName] scriptText:applicationDictionary[AJKScript] mode:AJKShortcutWindowEditMode shortcut:applicationDictionary[AJKShortcutDictionary]];
			break;
		}
	}
	
	[self removeApplicationWithIdentifier:scriptIdentifier];
}


- (void)presentScriptWindowForIdentifier:(NSString *)scriptIdentifier scriptName:(NSString *)scriptName scriptText:(NSString *)scriptText mode:(AJKShortcutWindowMode)mode shortcut:(NSDictionary *)shortcutDictionary
{
	if(!scriptIdentifier) {
		return;
	}
	
	AJKScriptWindowController *scriptWindowController = [[AJKScriptWindowController alloc] init];
	scriptWindowController.delegate = self;
	
	scriptWindowController.scriptIdentifier = scriptIdentifier;
	scriptWindowController.shortcutDictionary = shortcutDictionary;
    scriptWindowController.scriptName = scriptName;
    scriptWindowController.scriptText = scriptText;
    scriptWindowController.mode = mode;
	
    PluginLog(@"scriptText: '%@'", scriptText);
    
	[scriptWindowController showWindow:nil];
	self.scriptWindowController = scriptWindowController;
}



#pragma mark - AJKScriptWindowControllerDelegate methods


- (void)addScriptWithIdentifier:(NSString *)scriptIdentifier scriptName:(NSString *)scriptName script:(NSString *)script shortcut:(NSDictionary *)shortcut
{
	// A brute force way to avoid duplicates
	[self removeScriptWithIdentifier:scriptIdentifier];
	
	NSMutableArray *openWithScriptsArray = [[[self userDefaults] objectForKey:AJKOpenWithScripts] mutableCopy];
	
	if(!openWithScriptsArray) {
		openWithScriptsArray = [[NSMutableArray alloc] initWithCapacity:1];
	}
	
	if(scriptIdentifier.length > 0 && script.length > 0) {
		NSMutableDictionary *scriptDictionary = [[NSMutableDictionary alloc] init];
		scriptDictionary[AJKShortcutIdentifier] = scriptIdentifier;
        scriptDictionary[AJKScriptName] = scriptName ? : @"Untitled Script";
        scriptDictionary[AJKScript] = script;
        PluginLogWithName(self.pluginName, @"script: %@", script);
        
		if(shortcut) {
			scriptDictionary[AJKShortcutDictionary] = shortcut;
		}
        
		
		[openWithScriptsArray addObject:scriptDictionary];
        PluginLog(@"scriptDictionary: %@", scriptDictionary);
	}
	
	[[self userDefaults] setObject:openWithScriptsArray forKey:AJKOpenWithScripts];
	[[self userDefaults] synchronize];
}


- (void)removeScriptWithIdentifier:(NSString *)scriptIdentifier
{
    PluginLog(@"removeScriptWithIdentifier: %@", scriptIdentifier);
    
	if(!scriptIdentifier) {
		return;
	}
	
	NSArray *openWithScriptsArray = [[self userDefaults] objectForKey:AJKOpenWithScripts];
	NSIndexSet *indexesToKeep = [openWithScriptsArray indexesOfObjectsPassingTest:^BOOL(NSDictionary *applicationDictionary, NSUInteger idx, BOOL *stop) {
		return ![applicationDictionary[AJKShortcutIdentifier] isEqualToString:scriptIdentifier];
	}];
	
    NSArray *objectsToKeep = [openWithScriptsArray objectsAtIndexes:indexesToKeep];
    PluginLog(@"removeScriptWithIdentifier: %@ - %@", scriptIdentifier, objectsToKeep);
    [[self userDefaults] setObject:objectsToKeep forKey:AJKOpenWithScripts];
    [[self userDefaults] synchronize];
}



#pragma mark - AJKShortcutWindowControllerDelegate & AJKScriptWindowControllerDelegate shared methods


- (void)didDismissWindowController:(NSWindowController *)windowController
{
	if(self.shortcutWindowController == windowController) {
		self.shortcutWindowController = nil;
	}
	
	[self updateOpenWithApplicationMenu];
}



#pragma mark - Managing the Script


- (void)updateOpenWithApplicationMenu
{
	NSMenu *applicationMenu = [[NSMenu alloc] initWithTitle:@""];
	
	NSArray *openWithApplications = [[self userDefaults] objectForKey:AJKOpenWithApplications];
	NSInteger numberOfRegisteredApplication = openWithApplications.count;
	
	for(NSDictionary *applicationDictionary in openWithApplications) {
		NSString *applicationIdentifier = applicationDictionary[AJKShortcutIdentifier];
		
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
			menuItem.tag = [applicationDictionary[AJKShortcutScopeKey] integerValue];
			[menuItem setKeyEquivalentModifierMask:[keyEquivalentModifier integerValue]];
			[applicationMenu addItem:menuItem];
			
			
			// Add the Edit application shortcut menu item
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

	
	NSArray *scripts = [[self userDefaults] objectForKey:AJKOpenWithScripts];
	NSInteger numberOfScripts = scripts.count;
	
	for(NSDictionary *applicationDictionary in scripts) {
		NSString *scriptIdentifier = applicationDictionary[AJKShortcutIdentifier];
		
		if(scriptIdentifier.length) {
			NSString *name = applicationDictionary[AJKScriptName] ?: @"Untitled Script";
			
			// Gather the shortcut paramaters
			NSDictionary *shortcutDictionary = applicationDictionary[AJKShortcutDictionary];
			SRKeyEquivalentTransformer *keyEquivalentTransformer = [[SRKeyEquivalentTransformer alloc] init];
			NSString *keyEquivalent = [keyEquivalentTransformer transformedValue:shortcutDictionary];
			
			SRKeyEquivalentModifierMaskTransformer *keyEquivalentModifierMaskTransformer = [[SRKeyEquivalentModifierMaskTransformer alloc] init];
			NSNumber *keyEquivalentModifier = [keyEquivalentModifierMaskTransformer transformedValue:shortcutDictionary];
			
			
			// Add the Script menu item
			NSString *title = [NSString stringWithFormat:@"%@", name];
			NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:title action:@selector(performScriptForMenuItem:) keyEquivalent:keyEquivalent];
			menuItem.target = self;
			menuItem.representedObject = scriptIdentifier;
			menuItem.tag = [applicationDictionary[AJKShortcutScopeKey] integerValue];
			[menuItem setKeyEquivalentModifierMask:[keyEquivalentModifier integerValue]];
			[applicationMenu addItem:menuItem];
			
			
			// Add the Edit Script menu item
			title = [NSString stringWithFormat:@"Edit '%@' Script", name];
			NSMenuItem *editMenuItem = [[NSMenuItem alloc] initWithTitle:title action:@selector(editScriptForMenuItem:) keyEquivalent:keyEquivalent];
			editMenuItem.target = self;
			editMenuItem.representedObject = scriptIdentifier;
			[editMenuItem setKeyEquivalentModifierMask:[keyEquivalentModifier integerValue] | NSControlKeyMask];
			[editMenuItem setAlternate:TRUE];
			[applicationMenu addItem:editMenuItem];
		}
	}
	
	if(numberOfScripts > 0) {
		[applicationMenu addItem:[NSMenuItem separatorItem]];
	}
	
	
	NSString *title = NSLocalizedString(@"Add Shortcut for Application…", @"Shortcut menu item");
	NSMenuItem *addApplicationMenuItem = [[NSMenuItem alloc] initWithTitle:title action:@selector(registerOpenWithApplicationShortcut:) keyEquivalent:@""];
	[addApplicationMenuItem setTarget:self];
	[applicationMenu addItem:addApplicationMenuItem];
	
	title = NSLocalizedString(@"Add Script…", @"Add Script shortcut menu item");
	NSMenuItem *addScriptMenuItem = [[NSMenuItem alloc] initWithTitle:title action:@selector(registerScriptWithApplicationShortcut:) keyEquivalent:@""];
	[addScriptMenuItem setTarget:self];
	[applicationMenu addItem:addScriptMenuItem];
	
	self.openInApplicationMenuItem.submenu = applicationMenu;
}


#pragma mark -


- (NSUserDefaults *)userDefaults
{
	if(!_userDefaults) {
		_userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.inquisitiveSoftware.AJKOpenWith"];
	}
	
	return _userDefaults;
}


- (NSURL *)currentFileURL
{
	@try {
		NSWindowController *currentWindowController = [[NSApp keyWindow] windowController];
		
		if([currentWindowController isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")]) {
			id editor = [currentWindowController valueForKeyPath:@"editorArea.lastActiveEditorContext.editor"];
			if(!editor)
				return nil;
			
			id document = nil;
			
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
				// Get the files URL
				NSArray *knownFileReferences = [document valueForKey:@"knownFileReferences"];
				
				for(id fileReference in knownFileReferences) {
					return [fileReference valueForKeyPath:@"resolvedFilePath.fileURL"];
				}
			}
		}
	}
	
	@catch (NSException *exception) {
		PluginLogWithName(self.pluginName, @"Raised an exception while looking for the URL of the sourceCodeDocument: %@", exception);
	}
	
	return nil;
}


- (NSRange)currentSelection
{
	@try {
		NSWindowController *currentWindowController = [[NSApp keyWindow] windowController];
		
		if([currentWindowController isKindOfClass:NSClassFromString(@"IDEWorkspaceWindowController")]) {
			id editor = [currentWindowController valueForKeyPath:@"editorArea.lastActiveEditorContext.editor"];
			
			// Get current selection
			if(editor && [[NSApp keyWindow] firstResponder] == [editor textView]) {
				return [[editor textView] selectedRange];
			}
		}
	}
	
	@catch (NSException *exception) {
		PluginLogWithName(self.pluginName, @"Raised an exception while looking for the current documents selection: %@", exception);
	}
	
	return NSMakeRange(NSNotFound, 0);
}


- (NSURL *)projectDirectoryURL
{
	for (NSDocument *document in [NSApp orderedDocuments]) {
		@try {
			//	_workspace(IDEWorkspace) -> representingFilePath(DVTFilePath) -> relativePathOnVolume(NSString)
			NSURL *workspaceDirectoryURL = [[[document valueForKeyPath:@"_workspace.representingFilePath.fileURL"] URLByDeletingLastPathComponent] filePathURL];
			
			if(workspaceDirectoryURL) {
				return workspaceDirectoryURL;
			}
		}
		
		@catch (NSException *exception) {
			PluginLogWithName(self.pluginName, @"Raised an exception while asking for the documents '_workspace.representingFilePath.relativePathOnVolume' key path: %@", exception);
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
			
			if(applicationURL) {
				NSString *applicationIdentifier = [[NSBundle bundleWithURL:applicationURL] bundleIdentifier];
				return applicationIdentifier;
			}
		}
	}

	return nil;
}


- (NSString *)applicationNameForIdentifier:(NSString *)applicationIdentifier
{
	NSString *appName = nil;
	
	if(applicationIdentifier && applicationIdentifier.length > 0) {
		NSURL *applicationURL = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:applicationIdentifier];
		
		if(applicationURL) {
			NSBundle *bundle = [NSBundle bundleWithURL:applicationURL];
			appName = [bundle objectForInfoDictionaryKey:@"CFBundleName"];
		}
	}
	
	return appName;
}



#pragma mark - A helper method to use in developing


- (void)printAllMethodsForObject:(id)objectToInspect
{
	PluginLog(@"%@", objectToInspect);
	
	int unsigned numberOfMethods;
	Method *methods = class_copyMethodList([objectToInspect class], &numberOfMethods);
	
	for(int i = 0; i < numberOfMethods; i++) {
		PluginLog(@"%@: %@", NSStringFromClass([objectToInspect class]), NSStringFromSelector(method_getName(methods[i])));
	}
}




@end
