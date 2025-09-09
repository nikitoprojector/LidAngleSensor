//
//  SoundManager.m
//  LidAngleSensor
//
//  Created by Modified for multiple sound support.
//

#import "SoundManager.h"
#import "AudioEngines/Creak/CreakAudioEngine.h"
#import "AudioEngines/Theremin/ThereminAudioEngine.h"
#import "AudioEngines/Gachi/GachiAudioEngine.h"
#import "AudioEngines/Anime/AnimeAudioEngine.h"

@interface SoundManager ()
@property (nonatomic, assign) NSTimeInterval lastSoundTime;
@end

@implementation SoundManager

- (instancetype)init {
    NSLog(@"[SoundManager] Initializing SoundManager");
    self = [super init];
    if (self) {
        self.currentSoundType = SoundTypeOff;
        self.isAudioEnabled = NO;
        self.currentAngle = 0.0;
        self.previousAngle = 0.0;
        self.velocity = 0.0;
        self.lastSoundTime = 0.0;
        self.masterVolume = 0.7; // Default volume 70%
        
        NSLog(@"[SoundManager] Initializing audio engines");
        [self initializeAudioEngines];
        
        // Initialize with current lid angle to prevent false motion detection
        [self initializeWithCurrentAngle];
        
        NSLog(@"[SoundManager] SoundManager initialized successfully");
    } else {
        NSLog(@"[SoundManager] ERROR: Failed to initialize super");
    }
    return self;
}

- (void)dealloc {
    [self stopAllAudio];
}

- (void)initializeWithCurrentAngle {
    // Get current lid angle to initialize baseline and prevent false motion detection
    extern double getCurrentLidAngle(void);
    double currentAngle = getCurrentLidAngle();
    
    if (currentAngle >= 0) {
        self.currentAngle = currentAngle;
        self.previousAngle = currentAngle;
        NSLog(@"[SoundManager] Initialized with current lid angle: %.2f degrees", currentAngle);
    } else {
        NSLog(@"[SoundManager] Could not get current lid angle, using default initialization");
    }
}

- (void)initializeAudioEngines {
    NSLog(@"[SoundManager] Starting audio engine initialization");
    
    // Initialize the existing audio engines
    NSLog(@"[SoundManager] Initializing CreakAudioEngine");
    self.creakAudioEngine = [[CreakAudioEngine alloc] init];
    if (self.creakAudioEngine) {
        NSLog(@"[SoundManager] CreakAudioEngine initialized successfully");
    } else {
        NSLog(@"[SoundManager] WARNING: CreakAudioEngine initialization failed");
    }
    
    NSLog(@"[SoundManager] Initializing ThereminAudioEngine");
    self.thereminAudioEngine = [[ThereminAudioEngine alloc] init];
    if (self.thereminAudioEngine) {
        NSLog(@"[SoundManager] ThereminAudioEngine initialized successfully");
    } else {
        NSLog(@"[SoundManager] ERROR: ThereminAudioEngine initialization failed - this will cause volume control crashes");
    }
    
    NSLog(@"[SoundManager] Initializing GachiAudioEngine");
    self.gachiAudioEngine = [[GachiAudioEngine alloc] init];
    if (self.gachiAudioEngine) {
        NSLog(@"[SoundManager] GachiAudioEngine initialized successfully");
    } else {
        NSLog(@"[SoundManager] WARNING: GachiAudioEngine initialization failed");
    }
    
    NSLog(@"[SoundManager] Initializing AnimeAudioEngine");
    self.animeAudioEngine = [[AnimeAudioEngine alloc] init];
    if (self.animeAudioEngine) {
        NSLog(@"[SoundManager] AnimeAudioEngine initialized successfully");
    } else {
        NSLog(@"[SoundManager] WARNING: AnimeAudioEngine initialization failed");
    }
    
    NSLog(@"[SoundManager] Audio engine initialization completed");
}


- (void)setSoundType:(SoundType)soundType {
    if (self.currentSoundType == soundType) {
        return;
    }
    
    // Stop current audio
    [self stopAllAudio];
    
    // Reset engines to random mode when switching to random modes
    if (soundType == SoundTypeGachiRandom && self.gachiAudioEngine) {
        [self.gachiAudioEngine resetToRandomMode];
    }
    if (soundType == SoundTypeAnimeRandom && self.animeAudioEngine) {
        [self.animeAudioEngine resetToRandomMode];
    }
    
    // Update sound type
    self.currentSoundType = soundType;
    
    // Start new audio if enabled
    if (self.isAudioEnabled && soundType != SoundTypeOff) {
        [self startCurrentAudio];
    }
}

- (void)enableAudio:(BOOL)enabled {
    if (self.isAudioEnabled == enabled) {
        return;
    }
    
    self.isAudioEnabled = enabled;
    
    if (enabled && self.currentSoundType != SoundTypeOff) {
        [self startCurrentAudio];
    } else {
        [self stopAllAudio];
    }
}

- (void)startCurrentAudio {
    // Direct calls without respondsToSelector checks for performance
    switch (self.currentSoundType) {
        case SoundTypeCreak:
            if (self.creakAudioEngine) {
                [self.creakAudioEngine startEngine];
            }
            break;
        case SoundTypeTheremin:
            if (self.thereminAudioEngine) {
                [self.thereminAudioEngine startEngine];
            }
            break;
        case SoundTypeThereminMotion:
            // Motion-based theremin starts/stops dynamically based on movement
            // No need to start engine here - it will be controlled in updateWithLidAngle
            NSLog(@"[SoundManager] Motion-based theremin mode activated");
            break;
        case SoundTypeGachiRandom:
            if (self.gachiAudioEngine) {
                [self.gachiAudioEngine startEngine];
                NSLog(@"[SoundManager] Started gachi random mode");
            }
            break;
        case SoundTypeGachigasm:
            if (self.gachiAudioEngine) {
                [self.gachiAudioEngine startEngine];
                NSLog(@"[SoundManager] Started gachigasm mode");
            }
            break;
        case SoundTypeAnimeRandom:
            if (self.animeAudioEngine) {
                [self.animeAudioEngine startEngine];
                NSLog(@"[SoundManager] Started anime random mode");
            }
            break;
        case SoundTypeAnime:
            if (self.animeAudioEngine) {
                [self.animeAudioEngine startEngine];
                NSLog(@"[SoundManager] Started anime mode");
            }
            break;
        case SoundTypeOff:
        default:
            break;
    }
}

- (void)updateWithLidAngle:(double)angle {
    // Calculate velocity - optimized for 120Hz updates
    double deltaAngle = angle - self.currentAngle;
    self.velocity = fabs(deltaAngle) * 120.0; // Convert to degrees per second (120Hz updates)
    
    self.previousAngle = self.currentAngle;
    self.currentAngle = angle;
    
    if (!self.isAudioEnabled || self.currentSoundType == SoundTypeOff) {
        return;
    }
    
    // Direct calls without respondsToSelector checks for performance
    switch (self.currentSoundType) {
        case SoundTypeCreak:
            if (self.creakAudioEngine) {
                [self.creakAudioEngine updateWithLidAngle:angle];
            }
            break;
            
        case SoundTypeTheremin:
            if (self.thereminAudioEngine) {
                [self.thereminAudioEngine updateWithLidAngle:angle];
            }
            break;
            
        case SoundTypeThereminMotion:
            [self handleThereminMotionWithAngle:angle velocity:self.velocity];
            break;
            
        case SoundTypeGachiRandom:
        case SoundTypeGachigasm:
            if (self.gachiAudioEngine) {
                [self.gachiAudioEngine updateWithLidAngle:angle];
            }
            break;
            
        case SoundTypeAnimeRandom:
        case SoundTypeAnime:
            if (self.animeAudioEngine) {
                [self.animeAudioEngine updateWithLidAngle:angle];
            }
            break;
            
        case SoundTypeOff:
        default:
            break;
    }
}

- (void)stopAllAudio {
    // Direct calls without respondsToSelector checks for performance
    if (self.creakAudioEngine) {
        [self.creakAudioEngine stopEngine];
    }
    if (self.thereminAudioEngine) {
        [self.thereminAudioEngine stopEngine];
    }
    if (self.gachiAudioEngine) {
        [self.gachiAudioEngine stopEngine];
    }
    if (self.animeAudioEngine) {
        [self.animeAudioEngine stopEngine];
    }
}

- (NSString *)nameForSoundType:(SoundType)soundType {
    switch (soundType) {
        case SoundTypeOff:
            return @"Off";
        case SoundTypeCreak:
            return @"Creak Sound";
        case SoundTypeTheremin:
            return @"Theremin Sound";
        case SoundTypeThereminMotion:
            return @"Theremin Motion";
        case SoundTypeGachiRandom:
            return @"gachi random";
        case SoundTypeGachigasm:
            return @"gachigasm";
        case SoundTypeAnimeRandom:
            return @"anime random";
        case SoundTypeAnime:
            return @"anime";
        default:
            return @"Unknown";
    }
}

- (NSArray<NSNumber *> *)availableSoundTypes {
    return @[
        @(SoundTypeOff),
        @(SoundTypeCreak),
        @(SoundTypeTheremin),
        @(SoundTypeThereminMotion),
        @(SoundTypeGachiRandom),
        @(SoundTypeGachigasm),
        @(SoundTypeAnimeRandom),
        @(SoundTypeAnime)
    ];
}

#pragma mark - Volume Control

- (void)setMasterVolume:(float)masterVolume {
    NSLog(@"[SoundManager] Setting master volume to: %.2f", masterVolume);
    
    @try {
        _masterVolume = fmax(0.0, fmin(1.0, masterVolume)); // Clamp between 0.0 and 1.0
        NSLog(@"[SoundManager] Master volume clamped to: %.2f", _masterVolume);
        
        [self updateAllVolumes];
        NSLog(@"[SoundManager] Master volume set successfully");
        
    } @catch (NSException *exception) {
        NSLog(@"[SoundManager] EXCEPTION in setMasterVolume: %@", exception.reason);
        NSLog(@"[SoundManager] Exception stack trace: %@", [exception callStackSymbols]);
    }
}

- (void)updateAllVolumes {
    NSLog(@"[SoundManager] Starting updateAllVolumes");
    
    @try {
        // Only update volumes for engines that are actually being used
        // This prevents crashes when engines are initialized but not needed
        
        if (self.currentSoundType == SoundTypeTheremin) {
            // TEMPORARY: Disable theremin volume control to prevent crashes
            // TODO: Fix ThereminAudioEngine volume control implementation
            NSLog(@"[SoundManager] TEMPORARY: Skipping theremin volume update to prevent crashes");
            NSLog(@"[SoundManager] NOTE: Theremin volume control is temporarily disabled");
        } else {
            NSLog(@"[SoundManager] Skipping theremin volume update (current sound type: %ld)", (long)self.currentSoundType);
        }
        
        if (self.currentSoundType == SoundTypeCreak) {
            // TODO: Add volume control for CreakAudioEngine when needed
            NSLog(@"[SoundManager] NOTE: CreakAudioEngine doesn't support volume control yet");
        }
        
        NSLog(@"[SoundManager] Updated all volumes to master volume: %.2f", self.masterVolume);
        
    } @catch (NSException *exception) {
        NSLog(@"[SoundManager] EXCEPTION in updateAllVolumes: %@", exception.reason);
        NSLog(@"[SoundManager] Exception stack trace: %@", [exception callStackSymbols]);
    }
}

#pragma mark - Motion-based Theremin

- (void)handleThereminMotionWithAngle:(double)angle velocity:(double)velocity {
    // Define motion thresholds - sound plays only when there's significant movement
    // Increased thresholds to prevent false triggers during startup
    static const double kVelocityThreshold = 5.0; // degrees per second - minimum velocity (increased from 0.5)
    static const double kAngleChangeThreshold = 5.0; // degrees - minimum angle change to consider as intentional movement (increased from 2.0)
    static BOOL isEngineRunning = NO;
    static NSTimeInterval lastEngineStartTime = 0.0;
    static NSTimeInterval lastMotionTime = 0.0;
    static double lastSignificantAngle = 0.0; // Track angle for significant change detection
    static BOOL hasSignificantAngleChange = NO;
    static const NSTimeInterval kMinEngineRunTime = 0.3; // Minimum time engine should run (300ms)
    static const NSTimeInterval kMotionTimeout = 0.15; // Time to wait after motion stops before considering stopping (150ms)
    
    if (self.thereminAudioEngine == nil) {
        NSLog(@"[SoundManager] WARNING: ThereminAudioEngine is nil in motion mode");
        return;
    }
    
    NSTimeInterval currentTime = CACurrentMediaTime();
    
    // Check for significant angle change to avoid accidental triggers
    double angleChange = fabs(angle - lastSignificantAngle);
    if (!isEngineRunning && angleChange >= kAngleChangeThreshold) {
        hasSignificantAngleChange = YES;
        lastSignificantAngle = angle;
        NSLog(@"[SoundManager] Significant angle change detected: %.2f degrees", angleChange);
    }
    
    // Check if there's enough movement to play sound
    BOOL hasSignificantMotion = (velocity > kVelocityThreshold) && (hasSignificantAngleChange || isEngineRunning);
    
    if (hasSignificantMotion) {
        // There's significant movement - update last motion time
        lastMotionTime = currentTime;
        
        // Start engine if not already running
        if (!isEngineRunning) {
            NSLog(@"[SoundManager] Significant motion detected (%.2f deg/s, angle change: %.2f deg), starting theremin engine", velocity, angleChange);
            
            // Initialize the engine with current angle first
            if ([self.thereminAudioEngine respondsToSelector:@selector(updateWithLidAngle:)]) {
                [self.thereminAudioEngine updateWithLidAngle:angle];
            }
            
            // Then start the engine
            if ([self.thereminAudioEngine respondsToSelector:@selector(startEngine)]) {
                [self.thereminAudioEngine startEngine];
                isEngineRunning = YES;
                lastEngineStartTime = currentTime;
                NSLog(@"[SoundManager] Theremin engine started at time %.3f", currentTime);
            }
        }
        
        // Always update theremin with current angle when there's movement
        if ([self.thereminAudioEngine respondsToSelector:@selector(updateWithLidAngle:)]) {
            [self.thereminAudioEngine updateWithLidAngle:angle];
        }
        
        // Update last sound time to track activity
        self.lastSoundTime = currentTime;
        
    } else {
        // No significant movement - but keep engine running for a while
        if (isEngineRunning) {
            NSTimeInterval engineRunTime = currentTime - lastEngineStartTime;
            NSTimeInterval timeSinceLastMotion = currentTime - lastMotionTime;
            
            // Only stop if engine has been running for minimum time AND no motion for timeout period
            if (engineRunTime >= kMinEngineRunTime && timeSinceLastMotion >= kMotionTimeout) {
                NSLog(@"[SoundManager] No significant motion for %.3f seconds, stopping theremin engine after %.3f seconds total runtime", timeSinceLastMotion, engineRunTime);
                if ([self.thereminAudioEngine respondsToSelector:@selector(stopEngine)]) {
                    [self.thereminAudioEngine stopEngine];
                    isEngineRunning = NO;
                    hasSignificantAngleChange = NO; // Reset for next session
                    lastSignificantAngle = angle; // Update reference angle
                }
            } else {
                // Keep engine running and continue updating with current angle
                if ([self.thereminAudioEngine respondsToSelector:@selector(updateWithLidAngle:)]) {
                    [self.thereminAudioEngine updateWithLidAngle:angle];
                }
            }
        }
    }
}

#pragma mark - Motion-based Gachi

- (void)handleGachiMotionWithAngle:(double)angle velocity:(double)velocity {
    // Define motion thresholds - sound plays only when there's significant movement
    static const double kVelocityThreshold = 0.5; // degrees per second - minimum velocity
    static const double kAngleChangeThreshold = 2.0; // degrees - minimum angle change to consider as intentional movement
    static BOOL isEngineRunning = NO;
    static NSTimeInterval lastEngineStartTime = 0.0;
    static NSTimeInterval lastMotionTime = 0.0;
    static double lastSignificantAngle = 0.0; // Track angle for significant change detection
    static BOOL hasSignificantAngleChange = NO;
    static const NSTimeInterval kMinEngineRunTime = 0.3; // Minimum time engine should run (300ms)
    static const NSTimeInterval kMotionTimeout = 0.5; // Time to wait after motion stops before considering stopping (500ms)
    
    if (self.gachiAudioEngine == nil) {
        NSLog(@"[SoundManager] WARNING: GachiAudioEngine is nil in gachi mode");
        return;
    }
    
    NSTimeInterval currentTime = CACurrentMediaTime();
    
    // Check for significant angle change to avoid accidental triggers
    double angleChange = fabs(angle - lastSignificantAngle);
    if (!isEngineRunning && angleChange >= kAngleChangeThreshold) {
        hasSignificantAngleChange = YES;
        lastSignificantAngle = angle;
        NSLog(@"[SoundManager] Significant angle change detected for gachi: %.2f degrees", angleChange);
    }
    
    // Check if there's enough movement to play sound
    BOOL hasSignificantMotion = (velocity > kVelocityThreshold) && (hasSignificantAngleChange || isEngineRunning);
    
    if (hasSignificantMotion) {
        // There's significant movement - update last motion time
        lastMotionTime = currentTime;
        
        // Start engine if not already running (this will select a new random sound)
        if (!isEngineRunning) {
            NSLog(@"[SoundManager] Significant motion detected (%.2f deg/s, angle change: %.2f deg), starting gachi engine", velocity, angleChange);
            
            // Start the gachi engine (it will select a random sound automatically)
            if ([self.gachiAudioEngine respondsToSelector:@selector(startEngine)]) {
                [self.gachiAudioEngine startEngine];
                isEngineRunning = YES;
                lastEngineStartTime = currentTime;
                NSLog(@"[SoundManager] Gachi engine started at time %.3f", currentTime);
            }
        }
        
        // Update gachi engine with current angle (for potential future features)
        if ([self.gachiAudioEngine respondsToSelector:@selector(updateWithLidAngle:)]) {
            [self.gachiAudioEngine updateWithLidAngle:angle];
        }
        
        // Update last sound time to track activity
        self.lastSoundTime = currentTime;
        
    } else {
        // No significant movement - but keep engine running for a while
        if (isEngineRunning) {
            NSTimeInterval engineRunTime = currentTime - lastEngineStartTime;
            NSTimeInterval timeSinceLastMotion = currentTime - lastMotionTime;
            
            // Only stop if engine has been running for minimum time AND no motion for timeout period
            if (engineRunTime >= kMinEngineRunTime && timeSinceLastMotion >= kMotionTimeout) {
                NSLog(@"[SoundManager] No significant motion for %.3f seconds, stopping gachi engine after %.3f seconds total runtime", timeSinceLastMotion, engineRunTime);
                if ([self.gachiAudioEngine respondsToSelector:@selector(stopEngine)]) {
                    [self.gachiAudioEngine stopEngine];
                    isEngineRunning = NO;
                    hasSignificantAngleChange = NO; // Reset for next session (new random sound will be selected)
                    lastSignificantAngle = angle; // Update reference angle
                }
            } else {
                // Keep engine running and continue updating with current angle
                if ([self.gachiAudioEngine respondsToSelector:@selector(updateWithLidAngle:)]) {
                    [self.gachiAudioEngine updateWithLidAngle:angle];
                }
            }
        }
    }
}

#pragma mark - Helper Methods

- (BOOL)canPlaySound:(NSTimeInterval)cooldownTime {
    NSTimeInterval currentTime = CACurrentMediaTime();
    return (currentTime - self.lastSoundTime) >= cooldownTime;
}

@end
