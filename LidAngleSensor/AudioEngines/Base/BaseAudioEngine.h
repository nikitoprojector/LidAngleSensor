//
//  BaseAudioEngine.h
//  LidAngleSensor
//
//  Base class for all audio engines to eliminate code duplication
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BaseAudioEngine : NSObject

// Common properties for all engines
@property (nonatomic, readonly) BOOL isEngineRunning;
@property (nonatomic, readonly) double currentVelocity;
@property (nonatomic, readonly) double currentGain;
@property (nonatomic, readonly) double currentRate;

// Protected properties for subclasses
@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, assign) double targetGain;
@property (nonatomic, assign) double targetRate;

// Common methods
- (void)startEngine;
- (void)stopEngine;
- (void)updateWithLidAngle:(double)lidAngle;
- (void)setAngularVelocity:(double)velocity;

// Abstract methods for subclasses to override
- (BOOL)setupAudioEngine;
- (BOOL)loadAudioFiles;
- (void)startAudioPlayback;
- (void)updateAudioParametersWithVelocity:(double)velocity;
- (void)updateAudioParametersWithVelocity:(double)velocity currentTime:(double)currentTime;

// Helper methods available to subclasses
- (double)rampValue:(double)current toward:(double)target withDeltaTime:(double)dt timeConstantMs:(double)tauMs;
- (void)rampToTargetParameters;
- (void)rampToTargetParametersWithCurrentTime:(double)currentTime;

@end

NS_ASSUME_NONNULL_END
