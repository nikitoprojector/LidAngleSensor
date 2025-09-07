//
//  SoundManager.h
//  LidAngleSensor
//
//  Created by Modified for multiple sound support.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class CreakAudioEngine;
@class ThereminAudioEngine;
@class GachiAudioEngine;

typedef NS_ENUM(NSInteger, SoundType) {
    SoundTypeOff = 0,
    SoundTypeCreak,
    SoundTypeTheremin,
    SoundTypeThereminMotion,
    SoundTypeGachi
};

@interface SoundManager : NSObject

@property (nonatomic, assign) SoundType currentSoundType;
@property (nonatomic, assign) BOOL isAudioEnabled;
@property (nonatomic, assign) double currentAngle;
@property (nonatomic, assign) double previousAngle;
@property (nonatomic, assign) double velocity;
@property (nonatomic, assign) float masterVolume; // 0.0 to 1.0

// Audio engines
@property (strong, nonatomic) CreakAudioEngine *creakAudioEngine;
@property (strong, nonatomic) ThereminAudioEngine *thereminAudioEngine;
@property (strong, nonatomic) GachiAudioEngine *gachiAudioEngine;

- (instancetype)init;
- (void)initializeAudioEngines;

// Sound control
- (void)setSoundType:(SoundType)soundType;
- (void)enableAudio:(BOOL)enabled;
- (void)updateWithLidAngle:(double)angle;
- (void)setMasterVolume:(float)masterVolume;

// Sound type information
- (NSString *)nameForSoundType:(SoundType)soundType;
- (NSArray<NSNumber *> *)availableSoundTypes;

// Cleanup
- (void)stopAllAudio;
- (void)dealloc;

@end
