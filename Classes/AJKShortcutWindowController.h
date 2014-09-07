//
//  AJKAddApplicationWindowController.h
//  AJKExtendedOpening
//
//  Created by Harry Jordan on 24/08/2014.
//
//

#import <Cocoa/Cocoa.h>
#import <ShortcutRecorder/ShortcutRecorder.h>

#import "AJKGlobalDefines.h"


typedef NS_ENUM(NSInteger, AJKShortcutWindowMode) {
	AJKShortcutWindowCreateMode,
	AJKShortcutWindowEditMode
};


@protocol AJKShortcutWindowControllerDelegate <NSObject>

- (void)addApplicationWithIdentifier:(NSString *)applicationIdentifier scope:(AJKShortcutScope)scope shortcut:(NSDictionary *)shortcut;
- (void)removeApplicationWithIdentifier:(NSString *)applicationIdentifier;

- (void)didDismissWindowController:(NSWindowController *)windowController;

@end


@interface AJKShortcutWindowController : NSWindowController

@property (weak) id <AJKShortcutWindowControllerDelegate> delegate;
@property (assign, nonatomic) AJKShortcutWindowMode mode;

@property (copy) NSString *applicationIdentifier, *applicationName;
@property (copy) NSDictionary *shortcutDictionary;

@end
