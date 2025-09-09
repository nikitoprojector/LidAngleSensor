//
//  SystemSoundsAudioEngine.m
//  LidAngleSensor
//
//  System sounds mode with macOS built-in sounds and track selection.
//

#import "SystemSoundsAudioEngine.h"
#import <AppKit/AppKit.h>

// Movement session detection
static const double kMovementSessionTimeoutSec = 0.15; // Time without movement before considering it a new session

// System sound types - curated selection of fun macOS sounds
typedef NS_ENUM(NSInteger, SystemSoundType) {
    SystemSoundSosumi = 0,      // Classic Mac sound
    SystemSoundBasso = 1,       // Low error sound
    SystemSoundBlow = 2,        // Blow sound
    SystemSoundBottle = 3,      // Bottle sound
    SystemSoundFrog = 4,        // Frog sound
    SystemSoundFunk = 5,        // Funk sound
    SystemSoundGlass = 6,       // Glass sound
    SystemSoundHero = 7,        // Hero sound
    SystemSoundMorse = 8,       // Morse code sound
    SystemSoundPing = 9,        // Ping sound
    SystemSoundPop = 10,        // Pop sound
    SystemSoundPurr = 11,       // Purr sound
    SystemSoundSubmarine = 12,  // Submarine sound
    SystemSoundTink = 13,       // Tink sound
    SystemSoundCount = 14
};

// Sound configuration structure
typedef struct {
    NSString *soundName;        // NSSound name
    NSString *displayName;      // Human-readable name
    BOOL shouldLoop;            // YES for looping sounds
} SystemSoundConfig;

// Configuration for all system sounds
static const SystemSoundConfig kSystemSoundConfigs[SystemSoundCount] = {
    {@"Sosumi", @"Sosumi (Classic)", YES},
    {@"Basso", @"Basso (Error)", NO},
    {@"Blow", @"Blow", NO},
    {@"Bottle", @"Bottle", NO},
    {@"Frog", @"Frog", NO},
    {@"Funk", @"Funk", YES},
    {@"Glass", @"Glass", NO},
    {@"Hero", @"Hero", YES},
    {@"Morse", @"Morse", YES},
    {@"Ping", @"Ping", NO},
    {@"Pop", @"Pop", NO},
    {@"Purr", @"Purr", YES},
    {@"Submarine", @"Submarine", YES},
    {@"Tink", @"Tink", NO}
};

@interface SystemSoundsAudioEngine ()

// System sounds
@property (nonatomic, strong) NSMutableArray<NSSound *> *systemSounds;
@property (nonatomic, assign) NSInteger currentSoundIndex;

// Track selection state
@property (nonatomic, assign) BOOL isManualTrackSelected; // Track if user manually selected a specific track

// Movement session tracking
@property (nonatomic, assign) BOOL isInMovementSession;
@property (nonatomic, assign) NSTimeInterval lastSignificantMovementTime;
@property (nonatomic, assign) BOOL hasStartedPlaying; // Track if we've started playing at least once

// Current playing sound
@property (nonatomic, strong) NSSound *currentPlayingSound;

@end

@implementation SystemSoundsAudioEngine

- (instancetype)init {
    // Initialize our arrays BEFORE calling super init
    _systemSounds = [[NSMutableArray alloc] init];
    _currentSoundIndex = -1;
    _isManualTrackSelected = NO;
    _isInMovementSession = NO;
    _hasStartedPlaying = NO;
    _lastSignificantMovementTime = CACurrentMediaTime();
    _currentPlayingSound = nil;
    
    self = [super init];
    if (self) {
        NSLog(@"[SystemSoundsAudioEngine] SystemSoundsAudioEngine initialized successfully");
    }
    return self;
}

#pragma mark - BaseAudioEngine Overrides

- (BOOL)setupAudioEngine {
    // For system sounds, we don't need the complex AVAudioEngine setup
    // NSSound handles playback directly
    return YES;
}

- (BOOL)loadAudioFiles {
    // Load all available system sounds
    for (int i = 0; i < SystemSoundCount; i++) {
        NSString *soundName = kSystemSoundConfigs[i].soundName;
        NSSound *sound = [NSSound soundNamed:soundName];
        
        if (sound) {
            [self.systemSounds addObject:sound];
            NSLog(@"[SystemSoundsAudioEngine] Successfully loaded system sound: %@ (%@)", 
                  soundName, kSystemSoundConfigs[i].displayName);
        } else {
            // Create a placeholder to maintain index consistency
            [self.systemSounds addObject:[NSNull null]];
            NSLog(@"[SystemSoundsAudioEngine] System sound not available: %@", soundName);
        }
    }
    
    if (self.systemSounds.count == 0) {
        NSLog(@"[SystemSoundsAudioEngine] No system sounds could be loaded");
        return NO;
    }
    
    NSLog(@"[SystemSoundsAudioEngine] Loaded %lu system sounds", (unsigned long)self.systemSounds.count);
    
    // Select initial random sound but don't start playing yet
    [self selectNewRandomSound];
    
    return YES;
}

- (void)startAudioPlayback {
    // DON'T start playing immediately - wait for movement
    NSLog(@"[SystemSoundsAudioEngine] Started system sounds engine (waiting for movement)");
}

- (void)updateAudioParametersWithVelocity:(double)velocity currentTime:(double)currentTime {
    // Check warmup period first (inherited from BaseAudioEngine)
    [super updateAudioParametersWithVelocity:velocity currentTime:currentTime];
    
    // If we're in warmup period, the parent method will have returned early
    if (self.isInWarmupPeriod) {
        return;
    }
    
    double speed = velocity; // Velocity is already absolute
    
    // Check if this is significant movement (above deadzone) - increased threshold to prevent false triggers
    if (speed > 5.0) { // Increased from 1.0 to prevent phantom movement detection
        // Start playing if not already started
        if (!self.hasStartedPlaying) {
            NSLog(@"[SystemSoundsAudioEngine] Movement detected (%.1f deg/s) - starting system sound playback", speed);
            [self switchToNewRandomSoundIfNeeded];
        }
        
        // Update last movement time
        self.lastSignificantMovementTime = currentTime;
        self.isInMovementSession = YES;
    }
    
    // Check if movement has stopped for too long
    double timeSinceSignificantMovement = currentTime - self.lastSignificantMovementTime;
    if (self.isInMovementSession && timeSinceSignificantMovement > kMovementSessionTimeoutSec) {
        NSLog(@"[SystemSoundsAudioEngine] Movement stopped for %.3f seconds - stopping system sound playback", timeSinceSignificantMovement);
        self.isInMovementSession = NO;
        [self stopAllAudioPlayback];
    }
    
    // For system sounds: simple on/off based on deadzone
    double gain;
    if (speed < 1.0 || !self.isInMovementSession) { // Below deadzone or no movement session: no sound
        gain = 0.0;
    } else {
        gain = 1.0; // Above deadzone and in movement session: full volume
    }
    
    // Store targets for smooth ramping (though we don't use complex ramping for system sounds)
    self.targetGain = gain;
    self.targetRate = 1.0; // System sounds don't support rate changes
}

// Keep the old method for compatibility
- (void)updateAudioParametersWithVelocity:(double)velocity {
    [self updateAudioParametersWithVelocity:velocity currentTime:CACurrentMediaTime()];
}

#pragma mark - Sound Selection and Playback

- (void)selectNewRandomSound {
    if (self.systemSounds.count == 0) {
        return;
    }
    
    // Find a valid sound (not NSNull)
    NSInteger attempts = 0;
    NSInteger newIndex;
    do {
        newIndex = arc4random_uniform((uint32_t)self.systemSounds.count);
        attempts++;
    } while ([self.systemSounds[newIndex] isKindOfClass:[NSNull class]] && attempts < 20);
    
    if ([self.systemSounds[newIndex] isKindOfClass:[NSNull class]]) {
        NSLog(@"[SystemSoundsAudioEngine] Could not find valid system sound after %ld attempts", (long)attempts);
        return;
    }
    
    self.currentSoundIndex = newIndex;
    
    NSString *displayName = kSystemSoundConfigs[newIndex].displayName;
    NSLog(@"[SystemSoundsAudioEngine] Selected random sound: %@ (index %ld)", displayName, (long)newIndex);
}

- (void)startSystemSoundPlayback {
    NSLog(@"[SystemSoundsAudioEngine] startSystemSoundPlayback called - currentSoundIndex: %ld, systemSounds.count: %lu", 
          (long)self.currentSoundIndex, (unsigned long)self.systemSounds.count);
    
    if (self.currentSoundIndex < 0 || self.currentSoundIndex >= (NSInteger)self.systemSounds.count) {
        NSLog(@"[SystemSoundsAudioEngine] Invalid currentSoundIndex: %ld", (long)self.currentSoundIndex);
        
        // Try to fix by selecting a new random sound
        [self selectNewRandomSound];
        if (self.currentSoundIndex < 0) {
            return;
        }
    }
    
    NSSound *sound = self.systemSounds[self.currentSoundIndex];
    if ([sound isKindOfClass:[NSNull class]]) {
        NSLog(@"[SystemSoundsAudioEngine] Sound at index %ld is not available", (long)self.currentSoundIndex);
        return;
    }
    
    // Stop any current playback
    [self stopAllAudioPlayback];
    
    // Get sound configuration
    SystemSoundConfig config = kSystemSoundConfigs[self.currentSoundIndex];
    
    // Set up the sound
    sound.volume = 1.0;
    sound.loops = config.shouldLoop;
    
    // Set ourselves as delegate to handle completion
    sound.delegate = self;
    
    NSLog(@"[SystemSoundsAudioEngine] Starting playback of %@ (loops: %@)", 
          config.displayName, config.shouldLoop ? @"YES" : @"NO");
    
    // Play the sound
    [sound play];
    self.currentPlayingSound = sound;
    self.hasStartedPlaying = YES;
    
    // For non-looping sounds, we need to handle repetition manually during movement
    if (!config.shouldLoop && self.isInMovementSession) {
        // Schedule next play after a short delay
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.isInMovementSession && self.currentPlayingSound == sound) {
                [self startSystemSoundPlayback]; // Replay the same sound
            }
        });
    }
}

- (void)switchToNewRandomSoundIfNeeded {
    // Only select a new random sound if no manual track selection has been made
    if (!self.isManualTrackSelected) {
        NSLog(@"[SystemSoundsAudioEngine] Switching to new random sound for new movement session");
        [self selectNewRandomSound];
    } else {
        NSLog(@"[SystemSoundsAudioEngine] Using manually selected track %ld for new movement session", (long)self.currentSoundIndex);
    }
    
    // Start the playback with current sound (either random or manually selected)
    [self startSystemSoundPlayback];
}

- (void)stopAllAudioPlayback {
    NSLog(@"[SystemSoundsAudioEngine] Stopping all audio playback");
    
    // Stop current playing sound
    if (self.currentPlayingSound) {
        [self.currentPlayingSound stop];
        self.currentPlayingSound = nil;
    }
    
    // Stop all sounds just in case
    for (NSSound *sound in self.systemSounds) {
        if (![sound isKindOfClass:[NSNull class]] && [sound isPlaying]) {
            [sound stop];
        }
    }
    
    // Reset playback state
    self.hasStartedPlaying = NO;
    
    NSLog(@"[SystemSoundsAudioEngine] All audio playback stopped");
}

#pragma mark - NSSound Delegate

- (void)sound:(NSSound *)sound didFinishPlaying:(BOOL)finishedPlaying {
    if (finishedPlaying && sound == self.currentPlayingSound) {
        NSLog(@"[SystemSoundsAudioEngine] Sound finished playing: %@", sound.name);
        
        // If we're still in a movement session and this was a non-looping sound, play it again
        SystemSoundConfig config = kSystemSoundConfigs[self.currentSoundIndex];
        if (self.isInMovementSession && !config.shouldLoop) {
            // Small delay before replaying
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (self.isInMovementSession) {
                    [self startSystemSoundPlayback];
                }
            });
        }
    }
}

#pragma mark - Track Selection

- (void)selectSpecificTrack:(NSInteger)trackIndex {
    if (trackIndex < 0 || trackIndex >= SystemSoundCount) {
        NSLog(@"[SystemSoundsAudioEngine] Invalid track index: %ld", (long)trackIndex);
        return;
    }
    
    // Check if the sound is available
    if ([self.systemSounds[trackIndex] isKindOfClass:[NSNull class]]) {
        NSLog(@"[SystemSoundsAudioEngine] Sound at index %ld is not available", (long)trackIndex);
        return;
    }
    
    NSLog(@"[SystemSoundsAudioEngine] Selecting specific track: %ld (%@)", 
          (long)trackIndex, kSystemSoundConfigs[trackIndex].displayName);
    
    // Set the current sound index to the specified track
    self.currentSoundIndex = trackIndex;
    
    // Mark that a manual track selection has been made
    self.isManualTrackSelected = YES;
    
    // If we're currently playing, switch to the new track immediately
    if (self.hasStartedPlaying) {
        [self startSystemSoundPlayback];
    }
}

- (void)resetToRandomMode {
    NSLog(@"[SystemSoundsAudioEngine] Resetting to random mode");
    
    // Clear manual track selection flag
    self.isManualTrackSelected = NO;
    
    // Select a new random sound
    [self selectNewRandomSound];
    
    NSLog(@"[SystemSoundsAudioEngine] Reset to random mode complete, new sound index: %ld", (long)self.currentSoundIndex);
}

- (NSString *)soundNameAtIndex:(NSInteger)index {
    if (index < 0 || index >= SystemSoundCount) {
        return @"Unknown";
    }
    
    return kSystemSoundConfigs[index].displayName;
}

- (NSInteger)totalSoundCount {
    return SystemSoundCount;
}

#pragma mark - Engine Control Overrides

- (void)startEngine {
    // System sounds don't need complex engine startup
    NSLog(@"[SystemSoundsAudioEngine] Started system sounds engine");
}

- (void)stopEngine {
    [self stopAllAudioPlayback];
    NSLog(@"[SystemSoundsAudioEngine] Stopped system sounds engine");
}

- (BOOL)isEngineRunning {
    // System sounds are always "running" if initialized
    return YES;
}

@end
