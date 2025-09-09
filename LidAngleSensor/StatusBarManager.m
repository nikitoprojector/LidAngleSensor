//
//  StatusBarManager.m
//  LidAngleSensor
//
//  Created by Modified for background operation.
//

#import "StatusBarManager.h"
#import "LidAngleSensor.h"
#import "SoundManager.h"
#import "AudioEngines/Gachi/GachiAudioEngine.h"
#import "AudioEngines/Anime/AnimeAudioEngine.h"
#import "AudioEngines/SystemSounds/SystemSoundsAudioEngine.h"

@implementation StatusBarManager

- (instancetype)init {
    NSLog(@"[StatusBarManager] Initializing StatusBarManager");
    self = [super init];
    if (self) {
        NSLog(@"[StatusBarManager] Setting up status bar");
        [self setupStatusBar];
        
        NSLog(@"[StatusBarManager] Setting up menu");
        [self setupMenu];
        
        NSLog(@"[StatusBarManager] Initializing sensors and audio");
        [self initializeSensorsAndAudio];
        
        NSLog(@"[StatusBarManager] Loading user preferences");
        [self loadUserPreferences];
        
        NSLog(@"[StatusBarManager] Starting updates");
        [self startUpdating];
        
        NSLog(@"[StatusBarManager] Initialization completed successfully");
    } else {
        NSLog(@"[StatusBarManager] ERROR: Failed to initialize super");
    }
    return self;
}

- (void)dealloc {
    [self stopUpdating];
    [self.soundManager stopAllAudio];
    [self.lidSensor stopLidAngleUpdates];
}

- (void)setupStatusBar {
    // Create status bar item with fixed length to avoid size issues
    @try {
        self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
        
        if (self.statusItem) {
            NSLog(@"[StatusBarManager] Status item created, setting up button");
            
            [self setupStatusBarIcon];
            
            [self.statusItem.button setToolTip:@"Lid Angle Sensor - Click to open menu"];
            
            // Make sure the status item is visible
            [self.statusItem setVisible:YES];
            
            NSLog(@"[StatusBarManager] Status bar item setup completed successfully");
        } else {
            NSLog(@"[StatusBarManager] ERROR: Failed to create status bar item");
        }
    } @catch (NSException *exception) {
        NSLog(@"[StatusBarManager] ERROR creating status bar item: %@", exception.reason);
    }
}

- (void)setupStatusBarIcon {
    // Use ruler/angle icon as selected by user
    [self.statusItem.button setTitle:@"📐"];
    NSLog(@"[StatusBarManager] Using ruler emoji icon");
}

- (void)setupMenu {
    self.statusMenu = [[NSMenu alloc] init];
    self.soundModeMenuItems = [[NSMutableArray alloc] init];
    
    // Angle display item (non-clickable)
    self.angleMenuItem = [[NSMenuItem alloc] initWithTitle:@"Angle: Initializing..." action:nil keyEquivalent:@""];
    [self.angleMenuItem setEnabled:NO];
    [self.statusMenu addItem:self.angleMenuItem];
    
    // Status display item (non-clickable)
    self.statusMenuItem = [[NSMenuItem alloc] initWithTitle:@"Status: Detecting sensor..." action:nil keyEquivalent:@""];
    [self.statusMenuItem setEnabled:NO];
    [self.statusMenu addItem:self.statusMenuItem];
    
    // Separator
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    
    // Audio toggle
    self.audioToggleMenuItem = [[NSMenuItem alloc] initWithTitle:@"Enable Audio" action:@selector(toggleAudio:) keyEquivalent:@""];
    [self.audioToggleMenuItem setTarget:self];
    [self.statusMenu addItem:self.audioToggleMenuItem];
    
    // Separator
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    
    // Audio mode selection header
    NSMenuItem *modeHeader = [[NSMenuItem alloc] initWithTitle:@"Sound Mode:" action:nil keyEquivalent:@""];
    [modeHeader setEnabled:NO];
    [self.statusMenu addItem:modeHeader];
    
    // Create menu items for each sound type
    [self createSoundModeMenuItems];
    
    // Separator
    [self.statusMenu addItem:[NSMenuItem separatorItem]];
    
    // About
    NSMenuItem *aboutItem = [[NSMenuItem alloc] initWithTitle:@"About" action:@selector(showAbout:) keyEquivalent:@""];
    [aboutItem setTarget:self];
    [self.statusMenu addItem:aboutItem];
    
    // Quit
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit" action:@selector(quitApplication:) keyEquivalent:@"q"];
    [quitItem setTarget:self];
    [self.statusMenu addItem:quitItem];
    
    // Set the menu - this should work properly now
    self.statusItem.menu = self.statusMenu;
}


- (void)createSoundModeMenuItems {
    // We'll create this after soundManager is initialized
    // This method will be called from loadUserPreferences
}

- (void)initializeSensorsAndAudio {
    // Initialize lid sensor
    self.lidSensor = [[LidAngleSensor alloc] init];
    
    // Initialize sound manager
    self.soundManager = [[SoundManager alloc] init];
    
    // Now create the sound mode menu items
    [self createSoundModeMenuItemsWithSoundManager];
}

- (void)createSoundModeMenuItemsWithSoundManager {
    // Clear existing items
    [self.soundModeMenuItems removeAllObjects];
    
    // Get available sound types from sound manager
    NSArray<NSNumber *> *soundTypes = [self.soundManager availableSoundTypes];
    
    for (NSNumber *soundTypeNumber in soundTypes) {
        SoundType soundType = (SoundType)[soundTypeNumber integerValue];
        NSString *soundName = [self.soundManager nameForSoundType:soundType];
        
        NSMenuItem *menuItem;
        
        // Create submenus for gachigasm and anime modes
        if (soundType == SoundTypeGachigasm) {
            menuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"  %@", soundName]
                                                  action:nil
                                           keyEquivalent:@""];
            
            // Create submenu for gachigasm tracks
            self.gachigasmSubmenu = [[NSMenu alloc] init];
            
            // Add individual track options
            NSArray *gachiTrackNames = @[@"AUUUUUUUGH", @"OOOOOOOOOOO", @"RIP_EARS", @"VAN_DARKHOLME_WOO"];
            for (NSUInteger i = 0; i < gachiTrackNames.count; i++) {
                NSMenuItem *trackItem = [[NSMenuItem alloc] initWithTitle:gachiTrackNames[i]
                                                                   action:@selector(selectGachiTrack:)
                                                            keyEquivalent:@""];
                [trackItem setTarget:self];
                [trackItem setTag:i]; // Store track index in tag
                [self.gachigasmSubmenu addItem:trackItem];
            }
            
            [menuItem setSubmenu:self.gachigasmSubmenu];
            
        } else if (soundType == SoundTypeAnime) {
            menuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"  %@", soundName]
                                                  action:nil
                                           keyEquivalent:@""];
            
            // Create submenu for anime tracks
            self.animeSubmenu = [[NSMenu alloc] init];
            
            // Add individual track options
            NSArray *animeTrackNames = @[@"aaaaaa", @"ara_1", @"ara_2", @"ara_3", @"nya", @"senpai", @"yamete"];
            for (NSUInteger i = 0; i < animeTrackNames.count; i++) {
                NSMenuItem *trackItem = [[NSMenuItem alloc] initWithTitle:animeTrackNames[i]
                                                                   action:@selector(selectAnimeTrack:)
                                                            keyEquivalent:@""];
                [trackItem setTarget:self];
                [trackItem setTag:i]; // Store track index in tag
                [self.animeSubmenu addItem:trackItem];
            }
            
            [menuItem setSubmenu:self.animeSubmenu];
            
        } else if (soundType == SoundTypeSystemSounds) {
            menuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"  %@", soundName]
                                                  action:nil
                                           keyEquivalent:@""];
            
            // Create submenu for system sounds tracks
            self.systemSoundsSubmenu = [[NSMenu alloc] init];
            
            // Get track names from SystemSoundsAudioEngine
            if (self.soundManager.systemSoundsAudioEngine) {
                NSInteger totalSounds = [self.soundManager.systemSoundsAudioEngine totalSoundCount];
                for (NSInteger i = 0; i < totalSounds; i++) {
                    NSString *soundName = [self.soundManager.systemSoundsAudioEngine soundNameAtIndex:i];
                    NSMenuItem *trackItem = [[NSMenuItem alloc] initWithTitle:soundName
                                                                       action:@selector(selectSystemSoundsTrack:)
                                                                keyEquivalent:@""];
                    [trackItem setTarget:self];
                    [trackItem setTag:i]; // Store track index in tag
                    [self.systemSoundsSubmenu addItem:trackItem];
                }
            }
            
            [menuItem setSubmenu:self.systemSoundsSubmenu];
            
        } else {
            // Regular menu item for other sound types
            menuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"  %@", soundName]
                                                  action:@selector(selectSoundMode:)
                                           keyEquivalent:@""];
            [menuItem setTarget:self];
            [menuItem setTag:soundType]; // Store sound type in tag
        }
        
        // Set default selection (Off)
        if (soundType == SoundTypeOff) {
            [menuItem setState:NSControlStateValueOn];
        }
        
        [self.soundModeMenuItems addObject:menuItem];
        [self.statusMenu addItem:menuItem];
    }
}

- (void)startUpdating {
    // Update every 8ms (120Hz) for maximum responsiveness
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.008
                                                        target:self
                                                      selector:@selector(updateDisplay)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)stopUpdating {
    [self.updateTimer invalidate];
    self.updateTimer = nil;
}

- (void)updateDisplay {
    if (!self.lidSensor.isAvailable) {
        [self.angleMenuItem setTitle:@"Angle: Not Available"];
        [self.statusMenuItem setTitle:@"Status: Sensor not found"];
        return;
    }
    
    double angle = [self.lidSensor lidAngle];
    
    if (angle == -2.0) {
        [self.angleMenuItem setTitle:@"Angle: Read Error"];
        [self.statusMenuItem setTitle:@"Status: Failed to read sensor"];
    } else {
        [self.angleMenuItem setTitle:[NSString stringWithFormat:@"Angle: %.1f°", angle]];
        
        // Update status based on angle
        NSString *status;
        if (angle < 5.0) {
            status = @"Status: Lid is closed";
        } else if (angle < 45.0) {
            status = @"Status: Lid slightly open";
        } else if (angle < 90.0) {
            status = @"Status: Lid partially open";
        } else if (angle < 120.0) {
            status = @"Status: Lid mostly open";
        } else {
            status = @"Status: Lid fully open";
        }
        [self.statusMenuItem setTitle:status];
        
        // Update sound manager with new angle
        [self.soundManager updateWithLidAngle:angle];
    }
}

- (void)updateMenuStates {
    if (!self.soundManager) {
        NSLog(@"[StatusBarManager] WARNING: soundManager is nil in updateMenuStates");
        return;
    }
    
    // Update sound mode checkmarks
    SoundType currentSoundType = self.soundManager.currentSoundType;
    
    if (self.soundModeMenuItems) {
        for (NSMenuItem *menuItem in self.soundModeMenuItems) {
            if (menuItem) {
                SoundType itemSoundType = (SoundType)menuItem.tag;
                [menuItem setState:(itemSoundType == currentSoundType) ? NSControlStateValueOn : NSControlStateValueOff];
            }
        }
    }
    
    // Update audio toggle button
    if (self.audioToggleMenuItem) {
        if (self.soundManager.isAudioEnabled) {
            [self.audioToggleMenuItem setTitle:@"Disable Audio"];
        } else {
            [self.audioToggleMenuItem setTitle:@"Enable Audio"];
        }
        
        // Enable/disable audio toggle based on mode
        [self.audioToggleMenuItem setEnabled:(currentSoundType != SoundTypeOff)];
    }
}

- (void)saveUserPreferences {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:self.soundManager.currentSoundType forKey:@"SoundType"];
    [defaults setBool:self.soundManager.isAudioEnabled forKey:@"AudioEnabled"];
    [defaults setFloat:self.soundManager.masterVolume forKey:@"MasterVolume"];
    [defaults synchronize];
}

- (void)loadUserPreferences {
    NSLog(@"[StatusBarManager] Starting loadUserPreferences");
    
    @try {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSLog(@"[StatusBarManager] Got NSUserDefaults instance");
        
        // Load sound type (default to Off)
        NSInteger savedSoundType = [defaults integerForKey:@"SoundType"];
        NSLog(@"[StatusBarManager] Loaded sound type: %ld", (long)savedSoundType);
        
        // Validate sound type and default to Off if invalid
        if (savedSoundType < SoundTypeOff || savedSoundType > SoundTypeAnime) {
            NSLog(@"[StatusBarManager] Invalid sound type %ld, defaulting to SoundTypeOff", (long)savedSoundType);
            savedSoundType = SoundTypeOff;
        }
        
        if (self.soundManager) {
            NSLog(@"[StatusBarManager] Setting sound type to: %ld", (long)savedSoundType);
            [self.soundManager setSoundType:(SoundType)savedSoundType];
            NSLog(@"[StatusBarManager] Sound type set successfully");
        }
        
        // Load audio enabled state
        BOOL audioEnabled = [defaults boolForKey:@"AudioEnabled"];
        NSLog(@"[StatusBarManager] Loaded audio enabled: %d", audioEnabled);
        
        if (self.soundManager) {
            NSLog(@"[StatusBarManager] Enabling audio: %d", audioEnabled);
            [self.soundManager enableAudio:audioEnabled];
            NSLog(@"[StatusBarManager] Audio enabled successfully");
        }
        
        // Load volume (default to 0.7 if not set)
        float savedVolume = [defaults floatForKey:@"MasterVolume"];
        if (savedVolume == 0.0) {
            savedVolume = 0.7; // Default volume
        }
        NSLog(@"[StatusBarManager] Using volume: %.2f", savedVolume);
        
        if (self.soundManager) {
            NSLog(@"[StatusBarManager] Setting master volume");
            [self.soundManager setMasterVolume:savedVolume];
            NSLog(@"[StatusBarManager] Master volume set successfully");
        }
        
        
        NSLog(@"[StatusBarManager] About to call updateMenuStates");
        [self updateMenuStates];
        NSLog(@"[StatusBarManager] updateMenuStates completed successfully");
        
    } @catch (NSException *exception) {
        NSLog(@"[StatusBarManager] EXCEPTION in loadUserPreferences: %@", exception.reason);
        NSLog(@"[StatusBarManager] Exception stack trace: %@", [exception callStackSymbols]);
    }
    
    NSLog(@"[StatusBarManager] loadUserPreferences completed");
}

#pragma mark - Menu Actions

- (void)statusBarClicked:(id)sender {
    // Manually show the menu at the status bar button location
    NSRect buttonRect = self.statusItem.button.frame;
    NSPoint menuOrigin = NSMakePoint(NSMinX(buttonRect), NSMaxY(buttonRect));
    
    // Convert to screen coordinates
    menuOrigin = [self.statusItem.button.window convertPointToScreen:menuOrigin];
    
    // Show the menu
    [self.statusMenu popUpMenuPositioningItem:nil atLocation:menuOrigin inView:nil];
}

- (void)toggleAudio:(id)sender {
    BOOL newState = !self.soundManager.isAudioEnabled;
    [self.soundManager enableAudio:newState];
    [self updateMenuStates];
    [self saveUserPreferences];
}

- (void)selectSoundMode:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    SoundType soundType = (SoundType)menuItem.tag;
    
    [self.soundManager setSoundType:soundType];
    [self updateMenuStates];
    [self saveUserPreferences];
}

- (void)selectCreakMode:(id)sender {
    [self.soundManager setSoundType:SoundTypeCreak];
    [self updateMenuStates];
    [self saveUserPreferences];
}

- (void)selectThereminMode:(id)sender {
    [self.soundManager setSoundType:SoundTypeTheremin];
    [self updateMenuStates];
    [self saveUserPreferences];
}

- (void)selectOffMode:(id)sender {
    [self.soundManager setSoundType:SoundTypeOff];
    [self updateMenuStates];
    [self saveUserPreferences];
}


- (void)showAbout:(id)sender {
    @try {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Lid Angle Sensor"];
        [alert setInformativeText:@"A utility that shows the angle from your MacBook's lid sensor and can play various audio effects.\n\nModified by vtornikita for background operation with system tray support and multiple sound options."];
        [alert addButtonWithTitle:@"OK"];
        [alert setAlertStyle:NSAlertStyleInformational];
        
        // Store reference to status item to prevent it from disappearing
        NSStatusItem *statusItemRef = self.statusItem;
        
        // Run the alert on the main thread to prevent crashes
        dispatch_async(dispatch_get_main_queue(), ^{
            [alert runModal];
            
            // Ensure status item remains visible after alert is dismissed
            if (statusItemRef) {
                [statusItemRef setVisible:YES];
                NSLog(@"[StatusBarManager] Status item visibility restored after About dialog");
            }
        });
    } @catch (NSException *exception) {
        NSLog(@"[StatusBarManager] Exception in showAbout: %@", exception.reason);
    }
}

- (void)quitApplication:(id)sender {
    [self stopUpdating];
    [self.soundManager stopAllAudio];
    [self.lidSensor stopLidAngleUpdates];
    [[NSApplication sharedApplication] terminate:nil];
}

#pragma mark - Track Selection Actions

- (void)selectGachiTrack:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    NSInteger trackIndex = menuItem.tag;
    
    NSLog(@"[StatusBarManager] Selected gachi track %ld", (long)trackIndex);
    
    // Set to gachigasm mode and specify the track
    [self.soundManager setSoundType:SoundTypeGachigasm];
    
    // Tell the gachi audio engine to use the specific track
    if (self.soundManager.gachiAudioEngine) {
        [self.soundManager.gachiAudioEngine selectSpecificTrack:trackIndex];
    }
    
    [self updateMenuStates];
    [self saveUserPreferences];
}

- (void)selectAnimeTrack:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    NSInteger trackIndex = menuItem.tag;
    
    NSLog(@"[StatusBarManager] Selected anime track %ld", (long)trackIndex);
    
    // Set to anime mode and specify the track
    [self.soundManager setSoundType:SoundTypeAnime];
    
    // Tell the anime audio engine to use the specific track
    if (self.soundManager.animeAudioEngine) {
        [self.soundManager.animeAudioEngine selectSpecificTrack:trackIndex];
    }
    
    [self updateMenuStates];
    [self saveUserPreferences];
}

- (void)selectSystemSoundsTrack:(id)sender {
    NSMenuItem *menuItem = (NSMenuItem *)sender;
    NSInteger trackIndex = menuItem.tag;
    
    NSLog(@"[StatusBarManager] Selected system sounds track %ld", (long)trackIndex);
    
    // Set to system sounds mode and specify the track
    [self.soundManager setSoundType:SoundTypeSystemSounds];
    
    // Tell the system sounds audio engine to use the specific track
    if (self.soundManager.systemSoundsAudioEngine) {
        [self.soundManager.systemSoundsAudioEngine selectSpecificTrack:trackIndex];
    }
    
    [self updateMenuStates];
    [self saveUserPreferences];
}

@end
