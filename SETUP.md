# VocalHeat Xcode Project Setup

This guide will help you set up the VocalHeat iOS project in Xcode.

## Quick Start (Automatic - Recommended)

If you have [XcodeGen](https://github.com/yonaskolb/XcodeGen) installed:

```bash
cd claudevhstudio
xcodegen generate
open VocalHeat.xcodeproj
```

To install XcodeGen:
```bash
brew install xcodegen
```

## Manual Setup (Alternative)

If you don't have XcodeGen, follow these steps:

### Option 1: Let Xcode Create the Project

1. **Open Xcode**

2. **Create New Project**
   - File > New > Project
   - Choose **iOS** > **App**
   - Click **Next**

3. **Configure Project**
   - Product Name: `VocalHeat`
   - Team: (Select your team)
   - Organization Identifier: `com.krisenterprisesllc`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Click **Next**

4. **Save Location**
   - Navigate to the `claudevhstudio` directory
   - **IMPORTANT**: Name the folder `VocalHeat` (this will replace the existing VocalHeat folder)
   - Click **Create**

5. **Replace Files**
   - Xcode will create some default files
   - Delete the auto-generated `ContentView.swift` if it conflicts
   - The existing files should now be in your project

6. **Add Existing Files**
   - Right-click on the `VocalHeat` group in Project Navigator
   - Select **Add Files to "VocalHeat"...**
   - Navigate to `VocalHeat/VocalHeat/`
   - Select **all folders** (Models, Services, Views, Utilities)
   - Make sure **"Copy items if needed"** is **unchecked**
   - Make sure **"Create groups"** is selected
   - Click **Add**

7. **Configure Info.plist**
   - Select your project in Project Navigator
   - Select the `VocalHeat` target
   - Go to **Info** tab
   - Find the Info.plist file reference and ensure it points to `VocalHeat/VocalHeat/Info.plist`

8. **Configure Build Settings**
   - In the target's **Build Settings**
   - Search for "Info.plist"
   - Set **Info.plist File** to: `VocalHeat/VocalHeat/Info.plist`

### Option 2: Use the Setup Script

Run the provided setup script for guidance:

```bash
chmod +x setup-xcode-project.sh
./setup-xcode-project.sh
```

## Project Structure

After setup, your project should look like this:

```
VocalHeat/
├── VocalHeat/
│   ├── VocalHeatApp.swift          # Main app entry point
│   ├── Info.plist                  # App configuration
│   ├── Assets.xcassets/            # Images and colors
│   ├── Models/
│   │   ├── DuetSession.swift       # Session data models
│   │   ├── MusicGenre.swift        # Genre-specific rules
│   │   └── PitchPoint.swift        # Pitch analysis data
│   ├── Services/
│   │   └── AudioSessionManager.swift
│   ├── Views/
│   │   └── ContentView.swift       # Main UI
│   └── Utilities/
│       └── PersistenceManager.swift # Data persistence
└── VocalHeat.xcodeproj             # Xcode project (generated)
```

## Required Frameworks

The following frameworks should be linked automatically:
- **AVFoundation** - Audio recording and playback
- **Accelerate** - DSP and FFT operations
- **SwiftUI** - User interface
- **Combine** - Reactive programming

If they're not linked, add them manually:
1. Select your project target
2. Go to **General** > **Frameworks, Libraries, and Embedded Content**
3. Click **+** and add the frameworks listed above

## Permissions

The app requires microphone access. This is already configured in `Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>VocalHeat needs microphone access to record and analyze your singing voice.</string>
```

## Build and Run

1. Select a simulator or connected device from the scheme selector
2. Press **⌘R** or click the **Play** button
3. Grant microphone permissions when prompted

## Troubleshooting

### "No such module 'AVFoundation'"
- Make sure AVFoundation is linked in **General** > **Frameworks, Libraries, and Embedded Content**

### "Failed to load sessions"
- This is normal on first run - the app will create the sessions file automatically

### Build errors about missing files
- Make sure all files in `VocalHeat/VocalHeat/` are added to the project
- Check that they appear in the **Project Navigator**
- Verify they're included in the target's **Build Phases** > **Compile Sources**

### Asset catalog issues
- Make sure `Assets.xcassets` is included in the target
- Check **Build Phases** > **Copy Bundle Resources**

## Next Steps

Once the project builds successfully:

1. Add the remaining service files (AudioRecorder, PitchDetector, etc.)
2. Implement RecordingView and ResultsView
3. Connect the UI to the audio services
4. Test on a physical device for best results

## Support

For issues or questions:
- Check the main [README.md](README.md) for project overview
- Review the [project.yml](project.yml) for XcodeGen configuration
- Ensure you're using Xcode 14.0+ and iOS 15.0+ deployment target

---

**Copyright © 2026 Kris Enterprises LLC. All rights reserved.**
