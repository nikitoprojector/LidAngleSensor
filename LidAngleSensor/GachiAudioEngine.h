//
//  GachiAudioEngine.h
//  LidAngleSensor
//
//  Created for gachi sound mode with MP3 support.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GachiAudioEngine : NSObject

// Engine control
- (void)startEngine;
- (void)stopEngine;
- (BOOL)isEngineRunning;

// Audio parameter control
- (void)updateWithLidAngle:(double)lidAngle;
- (void)setAngularVelocity:(double)velocity;

// Properties
@property (nonatomic, readonly) double currentVelocity;
@property (nonatomic, readonly) double currentGain;
@property (nonatomic, readonly) double currentRate;

@end

NS_ASSUME_NONNULL_END
