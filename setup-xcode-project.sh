#!/bin/bash

# VocalHeat Xcode Project Setup Script
# Run this on macOS with Xcode installed to create the Xcode project

echo "🎤 VocalHeat Xcode Project Setup"
echo "================================"
echo ""

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "⚠️  Warning: This script should be run on macOS with Xcode installed"
    echo "   You can still proceed, but some steps may fail"
    echo ""
fi

# Check if xcodegen is installed
if command -v xcodegen &> /dev/null; then
    echo "✅ xcodegen found - using it to generate project"
    cd "$(dirname "$0")"
    xcodegen generate
    exit 0
fi

# If xcodegen not found, provide instructions
echo "📋 Manual Setup Instructions:"
echo ""
echo "1. Open Xcode"
echo "2. File > New > Project"
echo "3. Choose 'iOS' > 'App'"
echo "4. Use these settings:"
echo "   - Product Name: VocalHeat"
echo "   - Organization Identifier: com.krisenterprisesllc"
echo "   - Interface: SwiftUI"
echo "   - Language: Swift"
echo "   - Save location: $(pwd)/VocalHeat"
echo ""
echo "5. Delete the default ContentView.swift if created"
echo "6. Add existing files:"
echo "   - Right-click project > Add Files to 'VocalHeat'"
echo "   - Select all .swift files in VocalHeat/VocalHeat/"
echo ""
echo "7. The project structure should be:"
echo "   VocalHeat/"
echo "   ├── Models/"
echo "   │   ├── DuetSession.swift"
echo "   │   ├── MusicGenre.swift"
echo "   │   └── PitchPoint.swift"
echo "   ├── VocalHeatApp.swift"
echo "   └── Info.plist"
echo ""
echo "8. Build and run!"
echo ""
echo "💡 Tip: Install xcodegen for automatic project generation:"
echo "   brew install xcodegen"
echo ""
