//
//  AJKAddApplicationWindowController.h
//  AJKExtendedOpening
//
//  Created by Harry Jordan on 24/08/2014.
//
//

#import <Cocoa/Cocoa.h>
#import <ShortcutRecorder/ShortcutRecorder.h>

typedef void (^AJKAddApplicationBlock)(NSString *applicationIdentifier, NSString *keyboardShortcut, NSNumber *modifierMask);


@interface AJKCreateShortcutWindowController : NSWindowController

@property (copy) NSString *applicationIdentifier, *applicationName;
@property (copy) AJKAddApplicationBlock completionBlock;

@property (unsafe_unretained) IBOutlet SRRecorderControl *shortcutRecorder;
@property (unsafe_unretained) IBOutlet NSButton *createMenuItemButton;

- (IBAction)createShortcut:(id)sender;
- (IBAction)dismiss:(id)sender;

@end
