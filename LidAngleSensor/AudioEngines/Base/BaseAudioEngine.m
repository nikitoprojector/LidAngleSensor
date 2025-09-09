//
//  BaseAudioEngine.m
//  LidAngleSensor
//
//  Base class for all audio engines to eliminate code duplication
//

#import "BaseAudioEngine.h"

// Common audio parameter mapping constants
static const double kDeadzone = 1.0;          // deg/s - below this: treat as still
static const double kVelocityFull = 10.0;     // deg/s - max volume at/under this velocity
static const double kVelocityQuiet = 100.0;   // deg/s - silent by/over this velocity (fast movement)

// Pitch variation constants  
static const double kMinRate = 0.80;          // Minimum varispeed rate (lower pitch for slow movement)
static const double kMaxRate = 1.10;          // Maximum varispeed rate (higher pitch for fast movement)

// Smoothing and timing constants - optimized for faster response
static const double kAngleSmoothingFactor = 0.3;      // Reduced smoothing for faster response (30% new, 70% old)
static const double kVelocitySmoothingFactor = 0.5;   // Increased smoothing for velocity
static const double kMovementThreshold = 0.5;         // Minimum angle change to register as movement (degrees)
static const double kGainRampTimeMs = 30.0;           // Faster gain ramping (reduced from 50ms)
static const double kRateRampTimeMs = 50.0;           // Faster rate ramping (reduced from 80ms)
static const double kMovementTimeoutMs = 50.0;        // Time before aggressive velocity decay (milliseconds)
static const double kVelocityDecayFactor = 0.5;       // Decay rate when no movement detected
static const double kAdditionalDecayFactor = 0.8;     // Additional decay after timeout

@interface BaseAudioEngine ()

// State tracking for velocity calculation
@property (nonatomic, assign) double lastLidAngle;
@property (nonatomic, assign) double smoothedLidAngle;
@property (nonatomic, assign) double lastUpdateTime;
@property (nonatomic, assign) double smoothedVelocity;
@property (nonatomic, assign) double currentGain;
@property (nonatomic, assign) double currentRate;
@property (nonatomic, assign) BOOL isFirstUpdate;
@property (nonatomic, assign) NSTimeInterval lastMovementTime;

// Warmup period to prevent false triggers during initialization
@property (nonatomic, assign) NSTimeInterval initializationTime;
@property (nonatomic, assign) BOOL isInWarmupPeriod;

@end

@implementation BaseAudioEngine

- (instancetype)init {
    self = [super init];
    if (self) {
        _isFirstUpdate = YES;
        _lastUpdateTime = CACurrentMediaTime();
        _lastMovementTime = CACurrentMediaTime();
        _lastLidAngle = 0.0;
        _smoothedLidAngle = 0.0;
        _smoothedVelocity = 0.0;
        _targetGain = 0.0;
        _targetRate = 1.0;
        _currentGain = 0.0;
        _currentRate = 1.0;
        
        // Initialize warmup period to prevent false triggers
        _initializationTime = CACurrentMediaTime();
        _isInWarmupPeriod = YES;
        
        if (![self setupAudioEngine]) {
            NSLog(@"[%@] Failed to setup audio engine", NSStringFromClass([self class]));
            return nil;
        }
        
        if (![self loadAudioFiles]) {
            NSLog(@"[%@] Failed to load audio files", NSStringFromClass([self class]));
            return nil;
        }
    }
    return self;
}

- (void)dealloc {
    [self stopEngine];
}

#pragma mark - Engine Control

- (void)startEngine {
    if (self.isEngineRunning) {
        return;
    }
    
    NSError *error;
    if (![self.audioEngine startAndReturnError:&error]) {
        NSLog(@"[%@] Failed to start audio engine: %@", NSStringFromClass([self class]), error.localizedDescription);
        return;
    }
    
    [self startAudioPlayback];
    
    NSLog(@"[%@] Started audio engine", NSStringFromClass([self class]));
}

- (void)stopEngine {
    if (!self.isEngineRunning) {
        return;
    }
    
    [self.audioEngine stop];
    
    NSLog(@"[%@] Stopped audio engine", NSStringFromClass([self class]));
}

- (BOOL)isEngineRunning {
    return self.audioEngine.isRunning;
}

#pragma mark - Velocity Calculation and Parameter Mapping

- (void)updateWithLidAngle:(double)lidAngle {
    double currentTime = CACurrentMediaTime();
    
    if (self.isFirstUpdate) {
        self.lastLidAngle = lidAngle;
        self.smoothedLidAngle = lidAngle;
        self.lastUpdateTime = currentTime;
        self.lastMovementTime = currentTime;
        self.isFirstUpdate = NO;
        return;
    }
    
    // Calculate time delta
    double deltaTime = currentTime - self.lastUpdateTime;
    if (deltaTime <= 0 || deltaTime > 1.0) {
        // Skip if time delta is invalid or too large (likely app was backgrounded)
        self.lastUpdateTime = currentTime;
        return;
    }
    
    // Stage 1: Smooth the raw angle input to eliminate sensor jitter
    self.smoothedLidAngle = (kAngleSmoothingFactor * lidAngle) + 
                           ((1.0 - kAngleSmoothingFactor) * self.smoothedLidAngle);
    
    // Stage 2: Calculate velocity from smoothed angle data
    double deltaAngle = self.smoothedLidAngle - self.lastLidAngle;
    double instantVelocity;
    
    // Apply movement threshold to eliminate remaining noise
    if (fabs(deltaAngle) < kMovementThreshold) {
        instantVelocity = 0.0;
    } else {
        instantVelocity = fabs(deltaAngle / deltaTime);
        self.lastLidAngle = self.smoothedLidAngle;
    }
    
    // Stage 3: Apply velocity smoothing and decay
    if (instantVelocity > 0.0) {
        // Real movement detected - apply moderate smoothing
        self.smoothedVelocity = (kVelocitySmoothingFactor * instantVelocity) + 
                               ((1.0 - kVelocitySmoothingFactor) * self.smoothedVelocity);
        self.lastMovementTime = currentTime;
    } else {
        // No movement detected - apply fast decay
        self.smoothedVelocity *= kVelocityDecayFactor;
    }
    
    // Additional decay if no movement for extended period
    double timeSinceMovement = currentTime - self.lastMovementTime;
    if (timeSinceMovement > (kMovementTimeoutMs / 1000.0)) {
        self.smoothedVelocity *= kAdditionalDecayFactor;
    }
    
    // Update state for next iteration
    self.lastUpdateTime = currentTime;
    
    // Apply velocity-based parameter mapping (pass currentTime to avoid recalculating)
    [self updateAudioParametersWithVelocity:self.smoothedVelocity currentTime:currentTime];
}

- (void)setAngularVelocity:(double)velocity {
    self.smoothedVelocity = velocity;
    [self updateAudioParametersWithVelocity:velocity];
}

#pragma mark - Helper Methods

- (double)rampValue:(double)current toward:(double)target withDeltaTime:(double)dt timeConstantMs:(double)tauMs {
    double alpha = fmin(1.0, dt / (tauMs / 1000.0)); // linear ramp coefficient
    return current + (target - current) * alpha;
}

- (void)rampToTargetParameters {
    [self rampToTargetParametersWithCurrentTime:CACurrentMediaTime()];
}

- (void)rampToTargetParametersWithCurrentTime:(double)currentTime {
    if (!self.isEngineRunning) {
        return;
    }
    
    // Calculate delta time for ramping
    static double lastRampTime = 0;
    if (lastRampTime == 0) lastRampTime = currentTime;
    double deltaTime = currentTime - lastRampTime;
    lastRampTime = currentTime;
    
    // Ramp current values toward targets for smooth transitions
    self.currentGain = [self rampValue:self.currentGain toward:self.targetGain withDeltaTime:deltaTime timeConstantMs:kGainRampTimeMs];
    self.currentRate = [self rampValue:self.currentRate toward:self.targetRate withDeltaTime:deltaTime timeConstantMs:kRateRampTimeMs];
}

#pragma mark - Abstract Methods (to be overridden by subclasses)

- (BOOL)setupAudioEngine {
    // Default implementation - subclasses should override
    self.audioEngine = [[AVAudioEngine alloc] init];
    return YES;
}

- (BOOL)loadAudioFiles {
    // Default implementation - subclasses should override
    return YES;
}

- (void)startAudioPlayback {
    // Default implementation - subclasses should override
}

- (void)updateAudioParametersWithVelocity:(double)velocity {
    [self updateAudioParametersWithVelocity:velocity currentTime:CACurrentMediaTime()];
}

- (void)updateAudioParametersWithVelocity:(double)velocity currentTime:(double)currentTime {
    // Check warmup period to prevent false triggers during initialization
    static const NSTimeInterval kWarmupPeriodSeconds = 1.5; // 1.5 second warmup period
    
    if (self.isInWarmupPeriod) {
        NSTimeInterval timeSinceInit = currentTime - self.initializationTime;
        if (timeSinceInit >= kWarmupPeriodSeconds) {
            self.isInWarmupPeriod = NO;
            NSLog(@"[%@] Warmup period completed after %.2f seconds", NSStringFromClass([self class]), timeSinceInit);
        } else {
            // During warmup period, suppress all audio to prevent false triggers
            self.targetGain = 0.0;
            self.targetRate = 1.0;
            [self rampToTargetParametersWithCurrentTime:currentTime];
            return;
        }
    }
    
    // Default implementation - subclasses should override
    double speed = velocity; // Velocity is already absolute
    
    // Calculate target gain: slow movement = loud, fast movement = quiet/silent
    double gain;
    if (speed < kDeadzone) {
        gain = 0.0; // Below deadzone: no sound
    } else {
        // Use simplified linear interpolation instead of smoothstep for performance
        double t = fmin(1.0, fmax(0.0, (speed - kVelocityFull) / (kVelocityQuiet - kVelocityFull)));
        gain = 1.0 - t; // invert: slow = loud, fast = quiet
        gain = fmax(0.0, fmin(1.0, gain));
    }
    
    // Calculate target pitch/tempo rate based on movement speed
    double normalizedVelocity = fmax(0.0, fmin(1.0, speed / kVelocityQuiet));
    double rate = kMinRate + normalizedVelocity * (kMaxRate - kMinRate);
    rate = fmax(kMinRate, fmin(kMaxRate, rate));
    
    // Store targets for smooth ramping
    self.targetGain = gain;
    self.targetRate = rate;
    
    // Apply smooth parameter transitions (pass currentTime to avoid recalculating)
    [self rampToTargetParametersWithCurrentTime:currentTime];
}

#pragma mark - Property Accessors

- (double)currentVelocity {
    return self.smoothedVelocity;
}

- (double)currentGain {
    return _currentGain;
}

- (double)currentRate {
    return _currentRate;
}

@end
