# LidAngleSensor - Background Mode Modifications

This is a modified version of the original LidAngleSensor project that adds background operation with system tray support and multiple sound options.

## New Features

### 🔄 Background Operation
- The app now runs in the background without showing in the Dock
- Access all features through the system tray icon (📐)
- No main window - everything is controlled via the tray menu

### 🔊 Multiple Sound Options
The app now supports different sound modes

### 💾 Settings Persistence
- Your sound mode preference is automatically saved
- Audio enabled/disabled state is remembered between sessions
- Settings are stored in macOS user defaults

## How to Use

### System Tray Menu
Click on the 📐 icon in your system tray to access:

- **Current angle and status** - Real-time lid angle display
- **Enable/Disable Audio** - Toggle audio effects on/off
- **Sound Mode selection** - Choose from different sound options
- **About** - Information about the app
- **Quit** - Exit the application

### If the Tray Icon Disappears
If you can't see the 📐 icon in the system tray, you can still quit the app:

**Method 1 - Activity Monitor (Recommended):**
1. Open Spotlight (⌘ + Space)
2. Type "Activity Monitor" 
3. Search for "LidAngleSensor"
4. Select it and click "Force Quit" (red X button)

**Method 2 - Terminal:**
```bash
killall LidAngleSensor
```

**Method 3 - Force Quit Applications:**
1. Press ⌘ + Option + Esc
2. Find "LidAngleSensor" in the list
3. Select and click "Force Quit"

**Why the icon might disappear:**
- App crashed or froze
- Menu bar is too crowded (icon hidden on the right)
- System error (restart macOS)
- Code error (check Console.app for logs)

### Sound Modes Explained

**Continuous Sounds (Creak & Theremin):**
- Play continuously while audio is enabled
- Volume/pitch changes based on lid movement speed
- Original behavior from the base project

**Triggered Sounds (Click, Beep, Whoosh):**
- Play only when the lid moves at certain speeds
- Click: Gentle movements (>5°/s)
- Beep: Moderate movements (>10°/s) 
- Whoosh: Fast movements (>20°/s)

## Technical Changes

### Architecture
- Background agent (no Dock icon)
- System tray-based interface
- Persistent user preferences
- Modular sound system

## Building and Running

The project maintains the same build requirements as the original:
- macOS with Xcode
- MacBook with lid angle sensor (2019+ models)

```bash
# Build with Xcode
xcodebuild -project "LidAngleSensor.xcodeproj" -scheme "LidAngleSensor" -configuration Debug

# Or open in Xcode
open LidAngleSensor.xcodeproj
```

## Compatibility

- Maintains full compatibility with original sensor detection
- Works on the same MacBook models as the original
- All original audio engines (Creak, Theremin) preserved
- Added new sound options using existing audio file

## Credits

Based on the original LidAngleSensor project by Sam Gold.
Modified to add background operation and multiple sound options.
