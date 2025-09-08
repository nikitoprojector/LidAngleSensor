//
//  StatusBarManager.h
//  LidAngleSensor
//
//  Created by Modified for background operation.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@class LidAngleSensor;
@class SoundManager;

@interface StatusBarManager : NSObject

@property (strong, nonatomic) NSStatusItem *statusItem;
@property (strong, nonatomic) NSMenu *statusMenu;
@property (strong, nonatomic) LidAngleSensor *lidSensor;
@property (strong, nonatomic) SoundManager *soundManager;
@property (strong, nonatomic) NSTimer *updateTimer;

// Menu items
@property (strong, nonatomic) NSMenuItem *angleMenuItem;
@property (strong, nonatomic) NSMenuItem *statusMenuItem;
@property (strong, nonatomic) NSMenuItem *audioToggleMenuItem;
@property (strong, nonatomic) NSMutableArray<NSMenuItem *> *soundModeMenuItems;

- (instancetype)init;
- (void)setupStatusBar;
- (void)setupMenu;
- (void)initializeSensorsAndAudio;
- (void)startUpdating;
- (void)stopUpdating;

// Menu actions
- (void)toggleAudio:(id)sender;
- (void)selectCreakMode:(id)sender;
- (void)selectThereminMode:(id)sender;
- (void)selectOffMode:(id)sender;
- (void)showAbout:(id)sender;
- (void)quitApplication:(id)sender;

@end
