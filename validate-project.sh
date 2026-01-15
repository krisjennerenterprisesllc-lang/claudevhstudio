#!/bin/bash

# VocalHeat Project Validation Script
echo "🎤 VocalHeat Project Validation"
echo "================================"
echo ""

# Check file count
SWIFT_FILES=$(find VocalHeat/VocalHeat -name "*.swift" | wc -l)
echo "✅ Found $SWIFT_FILES Swift files"

# List all Swift files
echo ""
echo "📄 Swift Files:"
find VocalHeat/VocalHeat -name "*.swift" -type f | sort | while read file; do
    echo "   - ${file#VocalHeat/VocalHeat/}"
done

# Check project structure
echo ""
echo "📁 Project Structure:"
echo "   Models: $(ls VocalHeat/VocalHeat/Models/*.swift 2>/dev/null | wc -l) files"
echo "   Services: $(ls VocalHeat/VocalHeat/Services/*.swift 2>/dev/null | wc -l) files"
echo "   Views: $(ls VocalHeat/VocalHeat/Views/*.swift 2>/dev/null | wc -l) files"
echo "   Utilities: $(ls VocalHeat/VocalHeat/Utilities/*.swift 2>/dev/null | wc -l) files"

# Check for Xcode project
echo ""
if [ -f "VocalHeat.xcodeproj/project.pbxproj" ]; then
    echo "✅ Xcode project exists"
else
    echo "⚠️  Xcode project NOT found"
    echo ""
    echo "To generate it, run:"
    echo "   brew install xcodegen"
    echo "   xcodegen generate"
    echo ""
    echo "Or create manually in Xcode following SETUP.md"
fi

# Check for required files
echo ""
echo "🔍 Required Files:"
[ -f "project.yml" ] && echo "   ✅ project.yml" || echo "   ❌ project.yml"
[ -f "SETUP.md" ] && echo "   ✅ SETUP.md" || echo "   ❌ SETUP.md"
[ -f "README.md" ] && echo "   ✅ README.md" || echo "   ❌ README.md"
[ -f "VocalHeat/VocalHeat/Info.plist" ] && echo "   ✅ Info.plist" || echo "   ❌ Info.plist"
[ -f "VocalHeat/VocalHeat/VocalHeatApp.swift" ] && echo "   ✅ VocalHeatApp.swift" || echo "   ❌ VocalHeatApp.swift"

# Line count
echo ""
TOTAL_LINES=$(find VocalHeat/VocalHeat -name "*.swift" -type f -exec wc -l {} + | tail -1 | awk '{print $1}')
echo "📊 Total Lines of Code: $TOTAL_LINES"

echo ""
echo "✅ Project validation complete!"
echo ""
echo "Next steps:"
echo "1. Generate Xcode project: xcodegen generate"
echo "2. Open project: open VocalHeat.xcodeproj"
echo "3. Build and run in Xcode"
