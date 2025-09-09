//
//  AnimeAudioEngine.h
//  LidAngleSensor
//
//  Anime sound mode with MP3 support and random/manual selection.
//

#import <Foundation/Foundation.h>
#import "../Base/BaseAudioEngine.h"

@interface AnimeAudioEngine : BaseAudioEngine

// Track selection for anime mode
- (void)selectSpecificTrack:(NSInteger)trackIndex;

// Reset to random mode (clears manual track selection)
- (void)resetToRandomMode;

@end
