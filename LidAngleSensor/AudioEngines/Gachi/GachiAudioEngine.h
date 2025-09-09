//
//  GachiAudioEngine.h
//  LidAngleSensor
//
//  Gachi sound mode with MP3 support and audio stretching.
//

#import "../Base/BaseAudioEngine.h"

NS_ASSUME_NONNULL_BEGIN

@interface GachiAudioEngine : BaseAudioEngine

// Track selection for gachigasm mode
- (void)selectSpecificTrack:(NSInteger)trackIndex;

// Reset to random mode (clears manual track selection)
- (void)resetToRandomMode;

@end

NS_ASSUME_NONNULL_END
