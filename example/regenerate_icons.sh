#!/bin/bash

# Icon generator script
echo "🔄 Regenerating app icons..."

cd "$(dirname "$0")"

# Run the generator
dart run masterfabric_app_icon:generate --platforms android

echo ""
echo "✅ Icon generation complete!"
echo ""
echo "📱 Next steps:"
echo "1. Run: flutter clean"
echo "2. Run: flutter pub get"
echo "3. Run: flutter run"

