# Masterfabric App Icon

A Flutter package for dynamic app icon switching with scheduling, network triggers, and multi-platform support (Android, iOS, iPad, macOS).

## Features

- 🎨 **Up to 4 alternative app icons** - Switch between different app icons at runtime
- 📅 **Date-based scheduling** - Automatically switch icons based on date ranges
- 🌐 **Network triggers** - Change icons based on remote server configuration
- 🔄 **Auto-check on foreground** - Automatically check and update icons when app comes to foreground
- 📱 **Multi-platform support** - Android, iOS, iPad, and macOS
- ⚡ **Build-time icon generation** - CLI command to generate platform-specific icon assets

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  masterfabric_app_icon: ^0.0.1
```

## Setup

### 1. Add Icon Assets

Create an `assets/app_icons` folder in your project and add your icon images (PNG, max 1024x1024):

```
assets/
  app_icons/
    icon1.png  (default icon)
    icon2.png
    icon3.png
    icon4.png
```

### 2. Configure in pubspec.yaml

```yaml
flutter:
  assets:
    - assets/app_icons/

masterfabric_app_icon:
  icons_path: assets/app_icons
  icons:
    - name: icon1
      path: icon1.png
      default: true
    - name: icon2
      path: icon2.png
    - name: icon3
      path: icon3.png
    - name: icon4
      path: icon4.png
```

### 3. Generate Platform Icons

Run the CLI command to generate icons for all platforms:

```bash
# Generate for all platforms
dart run masterfabric_app_icon:generate

# Generate for specific platforms
dart run masterfabric_app_icon:generate -p android,ios

# Show help
dart run masterfabric_app_icon:generate --help
```

This command will:
- **Android**: Generate mipmap resources and update `AndroidManifest.xml` with activity-alias entries
- **iOS/iPad**: Generate Assets.xcassets icon sets and update `Info.plist` with CFBundleAlternateIcons
- **macOS**: Generate Assets.xcassets icon sets and update `Info.plist`

## Usage

### Initialize in main()

```dart
import 'package:flutter/material.dart';
import 'package:masterfabric_app_icon/masterfabric_app_icon.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await MasterfabricAppIcon.initialize(
    settings: MasterfabricIconSettings(
      icons: [
        // Default icon
        const AppIconConfig(
          iconName: 'icon1',
          assetPath: 'assets/app_icons/icon1.png',
          isDefault: true,
        ),
        // Christmas icon - active from Dec 20-26
        AppIconConfig(
          iconName: 'icon2',
          assetPath: 'assets/app_icons/icon2.png',
          schedule: IconSchedule(
            startDate: DateTime(2024, 12, 20),
            endDate: DateTime(2024, 12, 26),
          ),
        ),
        // Network-triggered icon
        const AppIconConfig(
          iconName: 'icon3',
          assetPath: 'assets/app_icons/icon3.png',
          schedule: IconSchedule(
            startDate: DateTime(2024, 1, 1),
            endDate: DateTime(2025, 12, 31),
            networkTriggered: true,
            triggerUrl: 'https://api.example.com/app-icon-config',
          ),
        ),
      ],
      checkOnForeground: true,  // Check when app comes to foreground
      checkOnSplash: true,       // Check during splash screen
      checkIntervalMinutes: 60,  // Check every hour
    ),
  );

  runApp(MyApp());
}
```

### Manual Icon Switching

```dart
// Check if alternate icons are supported
final isSupported = await MasterfabricAppIcon.isSupported();

// Get current icon
final currentIcon = await MasterfabricAppIcon.getCurrentIcon();

// Set specific icon
await MasterfabricAppIcon.setIcon('icon2');

// Reset to default
await MasterfabricAppIcon.resetToDefault();

// Get available icons
final icons = await MasterfabricAppIcon.getAvailableIcons();

// Listen for icon changes
MasterfabricAppIcon.onIconChanged((iconName) {
  print('Icon changed to: $iconName');
});

// Manually trigger schedule check
await MasterfabricAppIcon.checkSchedule();
```

## Network Trigger API

When using network triggers, your API should return JSON in this format:

```json
{
  "iconName": "icon2",
  "isActive": true,
  "activeFrom": "2024-12-20T00:00:00Z",
  "activeTo": "2024-12-26T23:59:59Z"
}
```

## Platform-Specific Notes

### Android

The package uses activity-alias in AndroidManifest.xml to enable icon switching. This is a standard Android approach that:
- Works on Android 7.0+ (API 25+)
- May briefly show "App loading" when switching icons
- Icon change persists across app restarts

### iOS/iPad

Uses Apple's `setAlternateIconName` API:
- Requires iOS 10.3+
- Shows a system alert when icon changes
- Limited to icons declared in Info.plist

### macOS

Changes the dock icon at runtime using `NSApplication.shared.applicationIconImage`:
- Icon change is temporary (resets on app restart)
- No system alert shown

## CLI Options

```
dart run masterfabric_app_icon:generate [options]

Options:
  -c, --config       Path to configuration file (default: pubspec.yaml)
  -i, --icons-path   Path to app icons folder (default: assets/app_icons)
  -p, --platforms    Target platforms (default: android,ios,macos)
  -h, --help         Show usage information
```

## Example

See the [example](example/) folder for a complete implementation.

## License

MIT License - see [LICENSE](LICENSE) for details.
