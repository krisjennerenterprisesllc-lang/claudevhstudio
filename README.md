# VocalHeat Studio

An iOS vocal analysis and recording application with AI-powered coaching.

## Overview

VocalHeat is a sophisticated iOS app that helps singers improve their vocal performance through:
- Real-time pitch detection and analysis
- Duet and solo recording capabilities
- Genre-aware scoring (Pop, Mariachi, Ranchera, Bolero)
- AI-powered coaching feedback
- Vibrato analysis and measurement
- Comprehensive vocal metrics

## Project Structure

```
VocalHeat/
├── VocalHeat/
│   ├── Models/
│   │   ├── DuetSession.swift      # Session management models
│   │   ├── MusicGenre.swift       # Genre-aware scoring rules
│   │   └── PitchPoint.swift       # Pitch detection data structures
│   ├── Services/
│   │   ├── AudioRecorder.swift
│   │   ├── PitchDetector.swift
│   │   ├── VibratoDetector.swift
│   │   └── CoachingService.swift
│   ├── Views/
│   │   ├── ContentView.swift
│   │   ├── RecordingView.swift
│   │   └── ResultsView.swift
│   └── Utilities/
│       └── PersistenceManager.swift
```

## Features

### Genre-Aware Analysis
- **Pop**: Controlled technique with moderate vibrato
- **Mariachi**: Wide dramatic vibrato with gritos technique
- **Ranchera**: Emotional delivery with cry technique
- **Bolero**: Romantic style with rubato

### Vocal Metrics
- **Pitch Accuracy**: Frequency deviation from expected notes
- **Vibrato Analysis**: Rate, extent, and consistency measurement
- **Tone Consistency**: Stability across vocal range
- **Expression Score**: Emotional delivery and technique

### Technical Highlights
- Real-time FFT-based pitch detection
- Autocorrelation for vibrato analysis
- Accelerate framework for DSP optimization
- AVFoundation for audio recording/playback
- SwiftUI + Combine for reactive UI

## Requirements

- iOS 15.0+
- Xcode 14.0+
- Swift 5.7+

## Getting Started

1. Clone this repository
2. Open `VocalHeat/VocalHeat.xcodeproj` in Xcode
3. Build and run on your iOS device or simulator

## Copyright

Copyright © 2026 Kris Enterprises LLC. All rights reserved.
