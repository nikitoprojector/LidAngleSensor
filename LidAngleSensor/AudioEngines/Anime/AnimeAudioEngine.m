//
//  AnimeAudioEngine.m
//  LidAngleSensor
//
//  Anime sound mode with MP3 support and random/manual selection.
//

#import "AnimeAudioEngine.h"

// Movement session detection
static const double kMovementSessionTimeoutSec = 0.15; // Time without movement before considering it a new session
static const double kFadeOutDurationSec = 0.1; // Duration for smooth fade-out

// Fast stop mode constants (like creak/theremin)
static const double kFastStopTimeoutMs = 50.0;        // Fast timeout for manual track selection
static const double kFastStopDecayFactor = 0.5;       // Fast decay rate
static const double kFastStopAdditionalDecay = 0.8;   // Additional fast decay

// Anime sound types - fixed set of 7 sounds
typedef NS_ENUM(NSInteger, AnimeSoundType) {
    AnimeSoundAAAAAA = 0,
    AnimeSoundARA_1 = 1,
    AnimeSoundARA_2 = 2,
    AnimeSoundARA_3 = 3,
    AnimeSoundNYA = 4,
    AnimeSoundSENPAI = 5,
    AnimeSoundYAMETE = 6,
    AnimeSoundCount = 7
};

// Sound configuration structure
typedef struct {
    NSString *fileName;
    BOOL shouldLoop;        // YES for looping, NO for stretching
    BOOL shouldStretch;     // YES to stretch with varispeed
} AnimeSoundConfig;

// Fixed configuration for all 7 anime sounds
static const AnimeSoundConfig kAnimeSoundConfigs[AnimeSoundCount] = {
    {@"aaaaaa", YES, NO},           // Loop, don't stretch
    {@"ara_1", YES, NO},            // Loop, don't stretch  
    {@"ara_2", YES, NO},            // Loop, don't stretch
    {@"ara_3", YES, NO},            // Loop, don't stretch
    {@"nya", YES, NO},              // Loop, don't stretch
    {@"senpai", YES, NO},           // Loop, don't stretch
    {@"yamete", YES, NO}            // Loop, don't stretch
};

@interface AnimeAudioEngine ()

// Audio nodes - we need separate nodes for each format to avoid reconnection issues
@property (nonatomic, strong) NSMutableArray<AVAudioPlayerNode *> *playerNodes;
@property (nonatomic, strong) NSMutableArray<AVAudioUnitVarispeed *> *varispeadUnits;
@property (nonatomic, strong) AVAudioMixerNode *mixerNode;

// Audio files
@property (nonatomic, strong) NSArray<AVAudioFile *> *animeFiles;
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

@implementation AnimeAudioEngine

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
        NSLog(@"[AnimeAudioEngine] AnimeAudioEngine initialized successfully");
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
    
    for (int i = 0; i < AnimeSoundCount; i++) {
        NSString *fileName = kAnimeSoundConfigs[i].fileName;
        
        // Try MP3 first (files are copied directly to Resources folder)
        NSString *filePath = [bundle pathForResource:fileName ofType:@"mp3"];
        if (!filePath) {
            // Fallback to WAV if MP3 not found
            filePath = [bundle pathForResource:fileName ofType:@"wav"];
        }
        
        if (!filePath) {
            NSLog(@"[AnimeAudioEngine] Could not find %@.mp3 or %@.wav in bundle resources", fileName, fileName);
            continue;
        }
        
        NSError *error;
        NSURL *fileURL = [NSURL fileURLWithPath:filePath];
        AVAudioFile *audioFile = [[AVAudioFile alloc] initForReading:fileURL error:&error];
        
        if (!audioFile) {
            NSLog(@"[AnimeAudioEngine] Failed to load %@: %@", fileName, error.localizedDescription);
            continue;
        }
        
        [files addObject:audioFile];
        NSLog(@"[AnimeAudioEngine] Successfully loaded %@ (length: %lld frames, format: %@)", 
              fileName, audioFile.length, audioFile.processingFormat);
    }
    
    if (files.count == 0) {
        NSLog(@"[AnimeAudioEngine] No anime sound files could be loaded");
        return NO;
    }
    
    self.animeFiles = [files copy];
    NSLog(@"[AnimeAudioEngine] Loaded %lu anime sound files", (unsigned long)self.animeFiles.count);
    
    // Create separate audio nodes for each file to avoid format switching issues
    [self setupAudioNodesForFiles];
    
    // Select initial random sound but don't start playing yet
    NSLog(@"[AnimeAudioEngine] About to select initial random sound, animeFiles.count: %lu", (unsigned long)self.animeFiles.count);
    [self selectNewRandomSound];
    NSLog(@"[AnimeAudioEngine] After selectNewRandomSound, currentSoundIndex: %ld", (long)self.currentSoundIndex);
    
    return YES;
}

- (void)setupAudioNodesForFiles {
    NSLog(@"[AnimeAudioEngine] setupAudioNodesForFiles called - animeFiles.count: %lu, playerNodes.count: %lu, varispeadUnits.count: %lu", 
          (unsigned long)self.animeFiles.count, (unsigned long)self.playerNodes.count, (unsigned long)self.varispeadUnits.count);
    
    if (!self.audioEngine) {
        NSLog(@"[AnimeAudioEngine] ERROR: audioEngine is nil in setupAudioNodesForFiles");
        return;
    }
    
    if (!self.mixerNode) {
        NSLog(@"[AnimeAudioEngine] ERROR: mixerNode is nil in setupAudioNodesForFiles");
        return;
    }
    
    // Create a player node and varispeed unit for each audio file
    for (NSUInteger i = 0; i < self.animeFiles.count; i++) {
        AVAudioFile *file = self.animeFiles[i];
        
        // Create nodes
        AVAudioPlayerNode *playerNode = [[AVAudioPlayerNode alloc] init];
        AVAudioUnitVarispeed *varispeadUnit = [[AVAudioUnitVarispeed alloc] init];
        
        NSLog(@"[AnimeAudioEngine] Created nodes for file %lu: playerNode=%@, varispeadUnit=%@", i, playerNode, varispeadUnit);
        
        // Attach to engine
        [self.audioEngine attachNode:playerNode];
        [self.audioEngine attachNode:varispeadUnit];
        
        NSLog(@"[AnimeAudioEngine] Attached nodes to engine for file %lu", i);
        
        // Connect: Player -> Varispeed -> Mixer
        AVAudioFormat *fileFormat = file.processingFormat;
        [self.audioEngine connect:playerNode to:varispeadUnit format:fileFormat];
        [self.audioEngine connect:varispeadUnit to:self.mixerNode format:fileFormat];
        
        NSLog(@"[AnimeAudioEngine] Connected nodes for file %lu with format: %@", i, fileFormat);
        
        // Store nodes
        [self.playerNodes addObject:playerNode];
        [self.varispeadUnits addObject:varispeadUnit];
        
        NSLog(@"[AnimeAudioEngine] Added nodes to arrays for file %lu - playerNodes.count now: %lu, varispeadUnits.count now: %lu", 
              i, (unsigned long)self.playerNodes.count, (unsigned long)self.varispeadUnits.count);
    }
    
    NSLog(@"[AnimeAudioEngine] setupAudioNodesForFiles completed - final counts: playerNodes=%lu, varispeadUnits=%lu", 
          (unsigned long)self.playerNodes.count, (unsigned long)self.varispeadUnits.count);
}

- (void)startAudioPlayback {
    // DON'T start playing immediately - wait for movement
    NSLog(@"[AnimeAudioEngine] Started anime engine (waiting for movement)");
}

- (void)updateAudioParametersWithVelocity:(double)velocity {
    double speed = velocity; // Velocity is already absolute
    
    // Use fast stop mode when manual track is selected (like creak/theremin)
    if (self.isManualTrackSelected) {
        [self updateAudioParametersWithVelocityFastMode:speed];
        return;
    }
    
    // Original session-based behavior for random mode
    // Update fade-out first
    [self updateFadeOut];
    
    // Update velocity buffer for trend detection
    [self updateVelocityBuffer:speed];
    
    // Check if this is significant movement (above deadzone)
    if (speed > 1.0) { // Using same deadzone as base class
        // Cancel fade-out only if movement is substantial (not just sensor noise)
        if (self.isFadingOut && speed > 5.0) { // Require stronger movement to cancel fade-out
            NSLog(@"[AnimeAudioEngine] Substantial movement detected (%.1f) - canceling fade-out", speed);
            self.isFadingOut = NO;
        }
        
        // Check if we're starting a new movement session
        if (!self.isInMovementSession) {
            // Check if enough time has passed since last session ended (dead time)
            double currentTime = CACurrentMediaTime();
            double timeSinceLastSessionEnd = currentTime - self.lastSessionEndTime;
            
            if (self.lastSessionEndTime == 0.0 || timeSinceLastSessionEnd > 0.3) { // Increased dead time to 0.3 seconds
                NSLog(@"[AnimeAudioEngine] Starting new movement session");
                self.isInMovementSession = YES;
                
                // Initialize lastSignificantMovementTime for new session
                self.lastSignificantMovementTime = currentTime;
                
                // Always switch to new random sound for new movement session
                [self switchToNewRandomSoundIfNeeded];
            } else {
                NSLog(@"[AnimeAudioEngine] Ignoring movement - too soon after last session (%.3f sec)", timeSinceLastSessionEnd);
            }
        }
    }
    
    // Check if movement session has ended
    double currentTime = CACurrentMediaTime();
    double timeSinceSignificantMovement = currentTime - self.lastSignificantMovementTime;
    if (self.isInMovementSession && timeSinceSignificantMovement > kMovementSessionTimeoutSec) {
        NSLog(@"[AnimeAudioEngine] Movement session ended - starting fade-out");
        self.isInMovementSession = NO;
        self.lastSessionEndTime = currentTime; // Record when session ended
        
        // Start fade-out instead of immediate stop
        [self startFadeOut];
    }
    
    // For anime mode: simple on/off based on deadzone, no volume modulation
    double gain;
    if (speed < 1.0) { // Below deadzone: no sound
        gain = 0.0;
    } else {
        gain = 1.0; // Above deadzone: full volume
        
        // Update lastSignificantMovementTime only when sound is actually playing
        self.lastSignificantMovementTime = CACurrentMediaTime();
    }
    
    // Calculate target pitch/tempo rate based on movement speed (keep this for variety)
    double normalizedVelocity = fmax(0.0, fmin(1.0, speed / 100.0));
    double rate = 0.80 + normalizedVelocity * (1.10 - 0.80);
    rate = fmax(0.80, fmin(1.10, rate));
    
    // Store targets for smooth ramping
    self.targetGain = gain;
    self.targetRate = rate;
    
    // Apply smooth parameter transitions
    [self rampToTargetParameters];
}

// Fast stop mode for manual track selection (similar to creak/theremin behavior)
- (void)updateAudioParametersWithVelocityFastMode:(double)velocity {
    double speed = velocity; // Velocity is already absolute
    double currentTime = CACurrentMediaTime();
    
    // Update velocity with fast decay (like creak/theremin)
    if (speed > 1.0) {
        // Real movement detected
        self.lastSignificantMovementTime = currentTime;
        
        // Start playing if not already started
        if (!self.hasStartedPlaying && self.isEngineRunning) {
            [self startAnimeLoop];
        }
    } else {
        // No movement - apply fast decay
        double timeSinceMovement = currentTime - self.lastSignificantMovementTime;
        if (timeSinceMovement > (kFastStopTimeoutMs / 1000.0)) {
            // Apply additional fast decay after timeout
            speed *= kFastStopAdditionalDecay;
        }
        speed *= kFastStopDecayFactor;
    }
    
    // For anime mode: simple on/off based on deadzone, no volume modulation
    double gain;
    if (speed < 1.0) { // Below deadzone: no sound
        gain = 0.0;
    } else {
        gain = 1.0; // Above deadzone: full volume
    }
    
    // Calculate target pitch/tempo rate based on movement speed
    double normalizedVelocity = fmax(0.0, fmin(1.0, speed / 100.0));
    double rate = 0.80 + normalizedVelocity * (1.10 - 0.80);
    rate = fmax(0.80, fmin(1.10, rate));
    
    // Store targets for smooth ramping
    self.targetGain = gain;
    self.targetRate = rate;
    
    // Apply smooth parameter transitions
    [self rampToTargetParameters];
}

- (void)rampToTargetParameters {
    [super rampToTargetParameters]; // This updates currentGain and currentRate
    
    if (!self.isEngineRunning || !self.hasStartedPlaying || self.currentSoundIndex < 0) {
        return;
    }
    
    // Apply ramped values to current audio nodes (no volume multiplier for anime mode)
    AVAudioPlayerNode *currentPlayerNode = self.playerNodes[self.currentSoundIndex];
    AVAudioUnitVarispeed *currentVarispeadUnit = self.varispeadUnits[self.currentSoundIndex];
    
    currentPlayerNode.volume = (float)self.currentGain;
    currentVarispeadUnit.rate = (float)self.currentRate;
}

#pragma mark - Sound Selection and Playback

- (void)selectNewRandomSound {
    if (self.animeFiles.count == 0) {
        return;
    }
    
    // Select a random sound
    NSInteger newIndex = arc4random_uniform((uint32_t)self.animeFiles.count);
    self.currentSoundIndex = newIndex;
    
    NSString *fileName = kAnimeSoundConfigs[newIndex].fileName;
    NSLog(@"[AnimeAudioEngine] Selected random sound: %@ (index %ld)", fileName, (long)newIndex);
}

- (void)startAnimeLoop {
    NSLog(@"[AnimeAudioEngine] startAnimeLoop called - currentSoundIndex: %ld, engineRunning: %d, animeFiles.count: %lu", 
          (long)self.currentSoundIndex, self.isEngineRunning, (unsigned long)self.animeFiles.count);
    
    if (self.currentSoundIndex < 0 || !self.isEngineRunning) {
        NSLog(@"[AnimeAudioEngine] Cannot start loop - currentSoundIndex: %ld, engineRunning: %d", 
              (long)self.currentSoundIndex, self.isEngineRunning);
        
        // Try to fix the issue by selecting a new random sound if we have files
        if (self.animeFiles.count > 0 && self.currentSoundIndex < 0) {
            NSLog(@"[AnimeAudioEngine] Attempting to fix currentSoundIndex by selecting new random sound");
            [self selectNewRandomSound];
            NSLog(@"[AnimeAudioEngine] After fix attempt, currentSoundIndex: %ld", (long)self.currentSoundIndex);
        }
        
        if (self.currentSoundIndex < 0 || !self.isEngineRunning) {
            return;
        }
    }
    
    // Additional safety checks
    if (self.currentSoundIndex >= (NSInteger)self.animeFiles.count || 
        self.currentSoundIndex >= (NSInteger)self.playerNodes.count ||
        self.currentSoundIndex >= (NSInteger)self.varispeadUnits.count) {
        NSLog(@"[AnimeAudioEngine] Invalid currentSoundIndex: %ld, arrays sizes: animeFiles=%lu, playerNodes=%lu, varispeadUnits=%lu", 
              (long)self.currentSoundIndex, (unsigned long)self.animeFiles.count, 
              (unsigned long)self.playerNodes.count, (unsigned long)self.varispeadUnits.count);
        return;
    }
    
    AVAudioFile *currentFile = self.animeFiles[self.currentSoundIndex];
    AVAudioPlayerNode *currentPlayerNode = self.playerNodes[self.currentSoundIndex];
    
    // Get sound configuration for current sound
    AnimeSoundConfig config = kAnimeSoundConfigs[self.currentSoundIndex];
    
    // Stop any current playback from all nodes
    for (AVAudioPlayerNode *node in self.playerNodes) {
        [node stop];
    }
    
    // Reset file position to beginning
    currentFile.framePosition = 0;
    
    // Schedule the anime sound based on its configuration
    AVAudioFrameCount frameCount = (AVAudioFrameCount)currentFile.length;
    AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:currentFile.processingFormat
                                                             frameCapacity:frameCount];
    
    if (!buffer) {
        NSLog(@"[AnimeAudioEngine] Failed to create buffer for %@ frames", @(frameCount));
        return;
    }
    
    NSError *error;
    if (![currentFile readIntoBuffer:buffer error:&error]) {
        NSLog(@"[AnimeAudioEngine] Failed to read anime sound into buffer: %@", error.localizedDescription);
        return;
    }
    
    NSLog(@"[AnimeAudioEngine] Buffer created successfully: %@ frames", @(buffer.frameLength));
    
    // All sounds now use simple looping behavior
    NSLog(@"[AnimeAudioEngine] Starting looping playback for %@", config.fileName);
    [currentPlayerNode scheduleBuffer:buffer atTime:nil options:AVAudioPlayerNodeBufferLoops completionHandler:nil];
    
    [currentPlayerNode play];
    
    // Set initial volume to 0 (will be controlled by gain)
    currentPlayerNode.volume = 0.0;
    self.hasStartedPlaying = YES;
    
    NSLog(@"[AnimeAudioEngine] Started playing anime sound loop");
}

- (void)switchToNewRandomSoundIfNeeded {
    // This method switches to a new random sound
    // Only call this when starting a new movement session
    
    if (!self.isEngineRunning) {
        return;
    }
    
    // Only select a new random sound if no manual track selection has been made
    if (!self.isManualTrackSelected) {
        NSLog(@"[AnimeAudioEngine] Switching to new random sound for new movement session");
        
        // Select new random sound
        [self selectNewRandomSound];
    } else {
        NSLog(@"[AnimeAudioEngine] Using manually selected track %ld for new movement session", (long)self.currentSoundIndex);
    }
    
    // Start the loop with current sound (either random or manually selected)
    [self startAnimeLoop];
}

- (void)stopAllAudioPlayback {
    NSLog(@"[AnimeAudioEngine] Stopping all audio playback");
    
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
    
    NSLog(@"[AnimeAudioEngine] All audio playback stopped");
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
    
    NSLog(@"[AnimeAudioEngine] Started fade-out from gain %.2f", self.fadeOutStartGain);
}

- (void)updateFadeOut {
    if (!self.isFadingOut) {
        return;
    }
    
    double currentTime = CACurrentMediaTime();
    double fadeProgress = (currentTime - self.fadeOutStartTime) / kFadeOutDurationSec;
    
    if (fadeProgress >= 1.0) {
        // Fade-out complete
        NSLog(@"[AnimeAudioEngine] Fade-out complete - stopping playback");
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
        NSLog(@"[AnimeAudioEngine] Deceleration detected: %.1f -> %.1f -> %.1f", older, middle, recent);
        
        // Start early countdown when deceleration is detected
        if (self.isInMovementSession && recent > 1.0) {
            // Reduce the effective timeout when decelerating
            double earlyTimeout = kMovementSessionTimeoutSec * 0.5; // Use half the normal timeout
            double currentTime = CACurrentMediaTime();
            double adjustedLastMovementTime = currentTime - earlyTimeout;
            
            // Only adjust if it would make the timeout shorter
            if (adjustedLastMovementTime > self.lastSignificantMovementTime) {
                self.lastSignificantMovementTime = adjustedLastMovementTime;
                NSLog(@"[AnimeAudioEngine] Applied early timeout due to deceleration");
            }
        }
    }
}

#pragma mark - Track Selection

- (void)selectSpecificTrack:(NSInteger)trackIndex {
    if (trackIndex < 0 || trackIndex >= AnimeSoundCount) {
        NSLog(@"[AnimeAudioEngine] Invalid track index: %ld", (long)trackIndex);
        return;
    }
    
    NSLog(@"[AnimeAudioEngine] Selecting specific track: %ld (%@)", (long)trackIndex, kAnimeSoundConfigs[trackIndex].fileName);
    
    // Set the current sound index to the specified track
    self.currentSoundIndex = trackIndex;
    
    // Mark that a manual track selection has been made
    self.isManualTrackSelected = YES;
    
    // If we're currently playing, switch to the new track immediately
    if (self.hasStartedPlaying && self.isEngineRunning) {
        [self startAnimeLoop];
    }
}

@end
