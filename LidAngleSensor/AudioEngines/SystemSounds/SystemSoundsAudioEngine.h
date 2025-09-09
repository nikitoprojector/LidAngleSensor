//
//  SystemSoundsAudioEngine.h
//  LidAngleSensor
//
//  System sounds mode with macOS built-in sounds and track selection.
//

#import "../Base/BaseAudioEngine.h"

NS_ASSUME_NONNULL_BEGIN

@interface SystemSoundsAudioEngine : BaseAudioEngine

// Track selection for system sounds mode
- (void)selectSpecificTrack:(NSInteger)trackIndex;

// Reset to random mode (clears manual track selection)
- (void)resetToRandomMode;

// Get the name of the sound at the specified index
- (NSString *)soundNameAtIndex:(NSInteger)index;

// Get the total number of available system sounds
- (NSInteger)totalSoundCount;

@end

NS_ASSUME_NONNULL_END
