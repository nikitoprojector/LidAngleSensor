//
//  GachiAudioEngine.m
//  LidAngleSensor
//
//  Gachi sound mode with MP3 support and audio stretching.
//

#import "GachiAudioEngine.h"

// Movement session detection
static const double kMovementSessionTimeoutSec = 0.15; // Time without movement before considering it a new session
static const double kFadeOutDurationSec = 0.1; // Duration for smooth fade-out


// Gachi sound types - fixed set of 4 sounds
typedef NS_ENUM(NSInteger, GachiSoundType) {
    GachiSoundAUUUUUUUGH = 0,
    GachiSoundOOOOOOOOOO = 1,
    GachiSoundRIP_EARS = 2,
    GachiSoundVAN_DARKHOLME_WOO = 3,
    GachiSoundCount = 4
};

// Sound configuration structure
typedef struct {
    NSString *fileName;
    BOOL shouldLoop;        // YES for looping, NO for stretching
    BOOL shouldStretch;     // YES to stretch with varispeed
} GachiSoundConfig;

// Fixed configuration for all 4 gachi sounds
static const GachiSoundConfig kGachiSoundConfigs[GachiSoundCount] = {
    {@"AUUUUUUUGH", YES, NO},           // Loop, don't stretch
    {@"OOOOOOOOOOO", YES, NO},          // Loop, don't stretch  
    {@"RIP_EARS", YES, NO},             // Loop, don't stretch
    {@"VAN_DARKHOLME_WOO", YES, NO}     // Loop, don't stretch
};

@interface GachiAudioEngine ()

// Audio nodes - we need separate nodes for each format to avoid reconnection issues
@property (nonatomic, strong) NSMutableArray<AVAudioPlayerNode *> *playerNodes;
@property (nonatomic, strong) NSMutableArray<AVAudioUnitVarispeed *> *varispeadUnits;
@property (nonatomic, strong) AVAudioMixerNode *mixerNode;

// Audio files
@property (nonatomic, strong) NSArray<AVAudioFile *> *gachiFiles;
@property (nonatomic, assign) NSInteger currentSoundIndex;

// Track selection state
@property (nonatomic, assign) BOOL isManualTrackSelected; // Track if user manually selected a specific track

// Movement session tracking
@property (nonatomic, assign) BOOL isInMovementSession;
@property (nonatomic, assign) NSTimeInterval lastSignificantMovementTime;
@property (nonatomic, assign) NSTimeInterval lastSessionEndTime; // Track when last session ended
@property (nonatomic, assign) BOOL hasStartedPlaying; // Track if we've started playing at least once

// Movement trend detection
@property (nonatomic, strong) NSMutableArray<NSNumber *> *velocityBuffer; // Buffer of recent velocities
@property (nonatomic, assign) NSTimeInterval lastVelocityUpdateTime;
@property (nonatomic, assign) BOOL isDecelerating; // Track if movement is slowing down

// Fade-out state
@property (nonatomic, assign) BOOL isFadingOut; // Track if we're in fade-out mode
@property (nonatomic, assign) NSTimeInterval fadeOutStartTime; // When fade-out started
@property (nonatomic, assign) double fadeOutStartGain; // Gain level when fade-out started

@end

@implementation GachiAudioEngine

+ (void)initialize {
    // No longer needed - using fixed configuration structure
}

- (instancetype)init {
    // Initialize our arrays BEFORE calling super init
    // This is critical because BaseAudioEngine.init calls our overridden methods
    _playerNodes = [[NSMutableArray alloc] init];
    _varispeadUnits = [[NSMutableArray alloc] init];
    _currentSoundIndex = -1;
    _isManualTrackSelected = NO; // Initialize manual track selection state
    _isInMovementSession = NO;
    _hasStartedPlaying = NO;
    _lastSignificantMovementTime = CACurrentMediaTime();
    _lastSessionEndTime = 0.0;
    
    // Initialize velocity buffer for trend detection
    _velocityBuffer = [[NSMutableArray alloc] init];
    _lastVelocityUpdateTime = 0.0;
    _isDecelerating = NO;
    
    // Initialize fade-out state
    _isFadingOut = NO;
    _fadeOutStartTime = 0.0;
    _fadeOutStartGain = 0.0;
    
    self = [super init];
    if (self) {
        NSLog(@"[GachiAudioEngine] GachiAudioEngine initialized successfully");
    }
    return self;
}

#pragma mark - BaseAudioEngine Overrides

- (BOOL)setupAudioEngine {
    [super setupAudioEngine]; // This creates the basic audioEngine
    
    // Create mixer node
    self.mixerNode = self.audioEngine.mainMixerNode;
    
    return YES;
}

- (BOOL)loadAudioFiles {
    NSBundle *bundle = [NSBundle mainBundle];
    NSMutableArray<AVAudioFile *> *files = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < GachiSoundCount; i++) {
        NSString *fileName = kGachiSoundConfigs[i].fileName;
        
        // Try MP3 first (files are copied directly to Resources folder)
        NSString *filePath = [bundle pathForResource:fileName ofType:@"mp3"];
        if (!filePath) {
            // Fallback to WAV if MP3 not found
            filePath = [bundle pathForResource:fileName ofType:@"wav"];
        }
        
        if (!filePath) {
            NSLog(@"[GachiAudioEngine] Could not find %@.mp3 or %@.wav in bundle resources", fileName, fileName);
            continue;
        }
        
        NSError *error;
        NSURL *fileURL = [NSURL fileURLWithPath:filePath];
        AVAudioFile *audioFile = [[AVAudioFile alloc] initForReading:fileURL error:&error];
        
        if (!audioFile) {
            NSLog(@"[GachiAudioEngine] Failed to load %@: %@", fileName, error.localizedDescription);
            continue;
        }
        
        [files addObject:audioFile];
        NSLog(@"[GachiAudioEngine] Successfully loaded %@ (length: %lld frames, format: %@)", 
              fileName, audioFile.length, audioFile.processingFormat);
    }
    
    if (files.count == 0) {
        NSLog(@"[GachiAudioEngine] No gachi sound files could be loaded");
        return NO;
    }
    
    self.gachiFiles = [files copy];
    NSLog(@"[GachiAudioEngine] Loaded %lu gachi sound files", (unsigned long)self.gachiFiles.count);
    
    // Create separate audio nodes for each file to avoid format switching issues
    [self setupAudioNodesForFiles];
    
    // Select initial random sound but don't start playing yet
    NSLog(@"[GachiAudioEngine] About to select initial random sound, gachiFiles.count: %lu", (unsigned long)self.gachiFiles.count);
    [self selectNewRandomSound];
    NSLog(@"[GachiAudioEngine] After selectNewRandomSound, currentSoundIndex: %ld", (long)self.currentSoundIndex);
    
    return YES;
}

- (void)setupAudioNodesForFiles {
    NSLog(@"[GachiAudioEngine] setupAudioNodesForFiles called - gachiFiles.count: %lu, playerNodes.count: %lu, varispeadUnits.count: %lu", 
          (unsigned long)self.gachiFiles.count, (unsigned long)self.playerNodes.count, (unsigned long)self.varispeadUnits.count);
    
    if (!self.audioEngine) {
        NSLog(@"[GachiAudioEngine] ERROR: audioEngine is nil in setupAudioNodesForFiles");
        return;
    }
    
    if (!self.mixerNode) {
        NSLog(@"[GachiAudioEngine] ERROR: mixerNode is nil in setupAudioNodesForFiles");
        return;
    }
    
    // Create a player node and varispeed unit for each audio file
    for (NSUInteger i = 0; i < self.gachiFiles.count; i++) {
        AVAudioFile *file = self.gachiFiles[i];
        
        // Create nodes
        AVAudioPlayerNode *playerNode = [[AVAudioPlayerNode alloc] init];
        AVAudioUnitVarispeed *varispeadUnit = [[AVAudioUnitVarispeed alloc] init];
        
        NSLog(@"[GachiAudioEngine] Created nodes for file %lu: playerNode=%@, varispeadUnit=%@", i, playerNode, varispeadUnit);
        
        // Attach to engine
        [self.audioEngine attachNode:playerNode];
        [self.audioEngine attachNode:varispeadUnit];
        
        NSLog(@"[GachiAudioEngine] Attached nodes to engine for file %lu", i);
        
        // Connect: Player -> Varispeed -> Mixer
        AVAudioFormat *fileFormat = file.processingFormat;
        [self.audioEngine connect:playerNode to:varispeadUnit format:fileFormat];
        [self.audioEngine connect:varispeadUnit to:self.mixerNode format:fileFormat];
        
        NSLog(@"[GachiAudioEngine] Connected nodes for file %lu with format: %@", i, fileFormat);
        
        // Store nodes
        [self.playerNodes addObject:playerNode];
        [self.varispeadUnits addObject:varispeadUnit];
        
        NSLog(@"[GachiAudioEngine] Added nodes to arrays for file %lu - playerNodes.count now: %lu, varispeadUnits.count now: %lu", 
              i, (unsigned long)self.playerNodes.count, (unsigned long)self.varispeadUnits.count);
    }
    
    NSLog(@"[GachiAudioEngine] setupAudioNodesForFiles completed - final counts: playerNodes=%lu, varispeadUnits=%lu", 
          (unsigned long)self.playerNodes.count, (unsigned long)self.varispeadUnits.count);
}

- (void)startAudioPlayback {
    // DON'T start playing immediately - wait for movement
    NSLog(@"[GachiAudioEngine] Started gachi engine (waiting for movement)");
}

- (void)updateAudioParametersWithVelocity:(double)velocity currentTime:(double)currentTime {
    double speed = velocity; // Velocity is already absolute
    
    // Unified logic for all modes - no more fast mode distinction
    
    // Check if this is significant movement (above deadzone) - increased threshold to prevent false triggers
    if (speed > 5.0) { // Increased from 1.0 to prevent phantom movement detection
        // Start playing if not already started
        if (!self.hasStartedPlaying && self.isEngineRunning) {
            NSLog(@"[GachiAudioEngine] Movement detected (%.1f deg/s) - starting gachi playback", speed);
            [self switchToNewRandomSoundIfNeeded];
        }
        
        // Update last movement time
        self.lastSignificantMovementTime = currentTime;
        self.isInMovementSession = YES;
    }
    
    // Check if movement has stopped for too long
    double timeSinceSignificantMovement = currentTime - self.lastSignificantMovementTime;
    if (self.isInMovementSession && timeSinceSignificantMovement > kMovementSessionTimeoutSec) {
        NSLog(@"[GachiAudioEngine] Movement stopped for %.3f seconds - stopping gachi playback", timeSinceSignificantMovement);
        self.isInMovementSession = NO;
        [self stopAllAudioPlayback];
    }
    
    // For gachi mode: simple on/off based on deadzone, no volume modulation
    double gain;
    if (speed < 1.0 || !self.isInMovementSession) { // Below deadzone or no movement session: no sound
        gain = 0.0;
    } else {
        gain = 1.0; // Above deadzone and in movement session: full volume
    }
    
    // Calculate target pitch/tempo rate based on movement speed (keep this for variety)
    double normalizedVelocity = fmax(0.0, fmin(1.0, speed / 100.0));
    double rate = 0.80 + normalizedVelocity * (1.10 - 0.80);
    rate = fmax(0.80, fmin(1.10, rate));
    
    // Store targets for smooth ramping
    self.targetGain = gain;
    self.targetRate = rate;
    
    // Apply smooth parameter transitions
    [self rampToTargetParametersWithCurrentTime:currentTime];
}

// Keep the old method for compatibility
- (void)updateAudioParametersWithVelocity:(double)velocity {
    [self updateAudioParametersWithVelocity:velocity currentTime:CACurrentMediaTime()];
}


- (void)rampToTargetParameters {
    [super rampToTargetParameters]; // This updates currentGain and currentRate
    
    if (!self.isEngineRunning || !self.hasStartedPlaying || self.currentSoundIndex < 0) {
        return;
    }
    
    // Apply ramped values to current audio nodes
    AVAudioPlayerNode *currentPlayerNode = self.playerNodes[self.currentSoundIndex];
    AVAudioUnitVarispeed *currentVarispeadUnit = self.varispeadUnits[self.currentSoundIndex];
    
    // For manual track selection, keep constant volume to avoid oscillations
    if (self.isManualTrackSelected) {
        currentPlayerNode.volume = 1.0; // Constant volume for track selection
    } else {
        currentPlayerNode.volume = (float)self.currentGain; // Variable volume for random mode
    }
    
    currentVarispeadUnit.rate = (float)self.currentRate;
}

#pragma mark - Sound Selection and Playback

- (void)selectNewRandomSound {
    if (self.gachiFiles.count == 0) {
        return;
    }
    
    // Select a random sound
    NSInteger newIndex = arc4random_uniform((uint32_t)self.gachiFiles.count);
    self.currentSoundIndex = newIndex;
    
    NSString *fileName = kGachiSoundConfigs[newIndex].fileName;
    NSLog(@"[GachiAudioEngine] Selected random sound: %@ (index %ld)", fileName, (long)newIndex);
}

- (void)startGachiLoop {
    NSLog(@"[GachiAudioEngine] startGachiLoop called - currentSoundIndex: %ld, engineRunning: %d, gachiFiles.count: %lu", 
          (long)self.currentSoundIndex, self.isEngineRunning, (unsigned long)self.gachiFiles.count);
    
    if (self.currentSoundIndex < 0 || !self.isEngineRunning) {
        NSLog(@"[GachiAudioEngine] Cannot start loop - currentSoundIndex: %ld, engineRunning: %d", 
              (long)self.currentSoundIndex, self.isEngineRunning);
        
        // Try to fix the issue by selecting a new random sound if we have files
        if (self.gachiFiles.count > 0 && self.currentSoundIndex < 0) {
            NSLog(@"[GachiAudioEngine] Attempting to fix currentSoundIndex by selecting new random sound");
            [self selectNewRandomSound];
            NSLog(@"[GachiAudioEngine] After fix attempt, currentSoundIndex: %ld", (long)self.currentSoundIndex);
        }
        
        if (self.currentSoundIndex < 0 || !self.isEngineRunning) {
            return;
        }
    }
    
    // Additional safety checks
    if (self.currentSoundIndex >= (NSInteger)self.gachiFiles.count || 
        self.currentSoundIndex >= (NSInteger)self.playerNodes.count ||
        self.currentSoundIndex >= (NSInteger)self.varispeadUnits.count) {
        NSLog(@"[GachiAudioEngine] Invalid currentSoundIndex: %ld, arrays sizes: gachiFiles=%lu, playerNodes=%lu, varispeadUnits=%lu", 
              (long)self.currentSoundIndex, (unsigned long)self.gachiFiles.count, 
              (unsigned long)self.playerNodes.count, (unsigned long)self.varispeadUnits.count);
        return;
    }
    
    AVAudioFile *currentFile = self.gachiFiles[self.currentSoundIndex];
    AVAudioPlayerNode *currentPlayerNode = self.playerNodes[self.currentSoundIndex];
    
    // Get sound configuration for current sound
    GachiSoundConfig config = kGachiSoundConfigs[self.currentSoundIndex];
    
    // Stop any current playback from all nodes
    for (AVAudioPlayerNode *node in self.playerNodes) {
        [node stop];
    }
    
    // Reset file position to beginning
    currentFile.framePosition = 0;

    AVAudioFrameCount frameCount = (AVAudioFrameCount)currentFile.length;
    AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:currentFile.processingFormat
                                                             frameCapacity:frameCount];
    
    if (!buffer) {
        NSLog(@"[GachiAudioEngine] Failed to create buffer for %@ frames", @(frameCount));
        return;
    }
    
    NSError *error;
    if (![currentFile readIntoBuffer:buffer error:&error]) {
        NSLog(@"[GachiAudioEngine] Failed to read gachi sound into buffer: %@", error.localizedDescription);
        return;
    }
    
    NSLog(@"[GachiAudioEngine] Buffer created successfully: %@ frames", @(buffer.frameLength));
    
    // All sounds now use simple looping behavior
    NSLog(@"[GachiAudioEngine] Starting looping playback for %@", config.fileName);
    [currentPlayerNode scheduleBuffer:buffer atTime:nil options:AVAudioPlayerNodeBufferLoops completionHandler:nil];
    
    [currentPlayerNode play];
    
    // Set constant volume for gachi mode (not controlled by gain/movement speed)
    currentPlayerNode.volume = 1.0;
    self.hasStartedPlaying = YES;
    
    NSLog(@"[GachiAudioEngine] Started playing gachi sound loop with constant volume: 1.0");
}


- (void)switchToNewRandomSoundIfNeeded {
    // This method switches to a new random sound
    // Only call this when starting a new movement session
    
    if (!self.isEngineRunning) {
        return;
    }
    
    // Only select a new random sound if no manual track selection has been made
    if (!self.isManualTrackSelected) {
        NSLog(@"[GachiAudioEngine] Switching to new random sound for new movement session");
        
        // Select new random sound
        [self selectNewRandomSound];
    } else {
        NSLog(@"[GachiAudioEngine] Using manually selected track %ld for new movement session", (long)self.currentSoundIndex);
    }
    
    // Start the loop with current sound (either random or manually selected)
    [self startGachiLoop];
}

- (void)stopAllAudioPlayback {
    NSLog(@"[GachiAudioEngine] Stopping all audio playback");
    
    // Stop all player nodes
    for (AVAudioPlayerNode *node in self.playerNodes) {
        if (node.isPlaying) {
            [node stop];
        }
    }
    
    // Reset playback state
    self.hasStartedPlaying = NO;
    
    // Reset fade-out state
    self.isFadingOut = NO;
    self.fadeOutStartTime = 0.0;
    self.fadeOutStartGain = 0.0;
    
    NSLog(@"[GachiAudioEngine] All audio playback stopped");
}

#pragma mark - Fade-out Management

- (void)startFadeOut {
    if (self.isFadingOut || !self.hasStartedPlaying) {
        return; // Already fading out or not playing
    }
    
    double currentTime = CACurrentMediaTime();
    self.isFadingOut = YES;
    self.fadeOutStartTime = currentTime;
    self.fadeOutStartGain = self.currentGain; // Store current gain level
    
    NSLog(@"[GachiAudioEngine] Started fade-out from gain %.2f", self.fadeOutStartGain);
}

- (void)updateFadeOut {
    if (!self.isFadingOut) {
        return;
    }
    
    double currentTime = CACurrentMediaTime();
    double fadeProgress = (currentTime - self.fadeOutStartTime) / kFadeOutDurationSec;
    
    if (fadeProgress >= 1.0) {
        // Fade-out complete
        NSLog(@"[GachiAudioEngine] Fade-out complete - stopping playback");
        [self stopAllAudioPlayback];
        self.isFadingOut = NO;
        return;
    }
    
    // Calculate fade-out gain (linear fade from fadeOutStartGain to 0)
    double fadeGain = self.fadeOutStartGain * (1.0 - fadeProgress);
    
    // Override targetGain during fade-out
    self.targetGain = fadeGain;
}

#pragma mark - Movement Trend Detection

- (void)updateVelocityBuffer:(double)velocity {
    double currentTime = CACurrentMediaTime();
    
    // Only update buffer every 50ms to avoid too frequent updates
    if (currentTime - self.lastVelocityUpdateTime < 0.05) {
        return;
    }
    
    self.lastVelocityUpdateTime = currentTime;
    
    // Add current velocity to buffer
    [self.velocityBuffer addObject:@(velocity)];
    
    // Keep buffer size limited to last 5 measurements (250ms of data)
    if (self.velocityBuffer.count > 5) {
        [self.velocityBuffer removeObjectAtIndex:0];
    }
    
    // Detect deceleration trend if we have enough data
    if (self.velocityBuffer.count >= 3) {
        [self detectDecelerationTrend];
    }
}

- (void)detectDecelerationTrend {
    if (self.velocityBuffer.count < 3) {
        return;
    }
    
    // Get recent velocities
    double recent = [self.velocityBuffer.lastObject doubleValue];
    double middle = [self.velocityBuffer[self.velocityBuffer.count - 2] doubleValue];
    double older = [self.velocityBuffer[self.velocityBuffer.count - 3] doubleValue];
    
    // Check if there's a consistent downward trend
    BOOL wasDecelerating = self.isDecelerating;
    self.isDecelerating = (recent < middle) && (middle < older) && (older - recent > 2.0);
    
    if (self.isDecelerating && !wasDecelerating) {
        NSLog(@"[GachiAudioEngine] Deceleration detected: %.1f -> %.1f -> %.1f", older, middle, recent);
        
        // Start early countdown when deceleration is detected
        if (self.isInMovementSession && recent > 1.0) {
            // Reduce the effective timeout when decelerating
            double earlyTimeout = kMovementSessionTimeoutSec * 0.5; // Use half the normal timeout
            double currentTime = CACurrentMediaTime();
            double adjustedLastMovementTime = currentTime - earlyTimeout;
            
            // Only adjust if it would make the timeout shorter
            if (adjustedLastMovementTime > self.lastSignificantMovementTime) {
                self.lastSignificantMovementTime = adjustedLastMovementTime;
                NSLog(@"[GachiAudioEngine] Applied early timeout due to deceleration");
            }
        }
    }
}

#pragma mark - Track Selection

- (void)selectSpecificTrack:(NSInteger)trackIndex {
    if (trackIndex < 0 || trackIndex >= GachiSoundCount) {
        NSLog(@"[GachiAudioEngine] Invalid track index: %ld", (long)trackIndex);
        return;
    }
    
    NSLog(@"[GachiAudioEngine] Selecting specific track: %ld (%@)", (long)trackIndex, kGachiSoundConfigs[trackIndex].fileName);
    
    // Set the current sound index to the specified track
    self.currentSoundIndex = trackIndex;
    
    // Mark that a manual track selection has been made
    self.isManualTrackSelected = YES;
    
    // If we're currently playing, switch to the new track immediately
    if (self.hasStartedPlaying && self.isEngineRunning) {
        [self startGachiLoop];
    }
}

- (void)resetToRandomMode {
    NSLog(@"[GachiAudioEngine] Resetting to random mode");
    
    // Clear manual track selection flag
    self.isManualTrackSelected = NO;
    
    // Select a new random sound
    [self selectNewRandomSound];
    
    NSLog(@"[GachiAudioEngine] Reset to random mode complete, new sound index: %ld", (long)self.currentSoundIndex);
}

@end
