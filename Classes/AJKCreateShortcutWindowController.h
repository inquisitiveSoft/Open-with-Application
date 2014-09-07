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


typedef void (^AJKAddApplicationBlock)(NSString *applicationIdentifier, AJKOpenWithScope scope, NSDictionary *shortcutDictionary);


@interface AJKCreateShortcutWindowController : NSWindowController

@property (copy) NSString *applicationIdentifier, *applicationName;
@property (copy) AJKAddApplicationBlock completionBlock;

- (IBAction)createShortcut:(id)sender;
- (IBAction)dismiss:(id)sender;

@end
