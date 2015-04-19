//
//  AJKScriptWindowController.h
//  AJKOpenWithPlugin
//
//  Created by Harry Jordan on 24/08/2014.
//
//

#import <Cocoa/Cocoa.h>
#import <ShortcutRecorder/ShortcutRecorder.h>

#import "AJKShortcutWindowController.h"
#import "AJKDefines.h"


@protocol AJKScriptWindowControllerDelegate <NSObject>

- (void)addScriptWithIdentifier:(NSString *)scriptIdentifier scriptName:(NSString *)scriptName script:(NSString *)script shortcut:(NSDictionary *)shortcut;
- (void)removeScriptWithIdentifier:(NSString *)scriptIdentifier;

- (void)didDismissWindowController:(NSWindowController *)windowController;

@end


@interface AJKScriptWindowController : NSWindowController

@property (weak) id <AJKScriptWindowControllerDelegate> delegate;
@property (assign, nonatomic) AJKShortcutWindowMode mode;

@property (copy) NSString *scriptIdentifier, *scriptName, *scriptText;
@property (copy) NSDictionary *shortcutDictionary;

@end
