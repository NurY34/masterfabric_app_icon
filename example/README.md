# example

A new Flutter project with flavor support (dev and prod).

## Getting Started

This project is a starting point for a Flutter application with Android flavor support.

## Flavor Structure

This project includes two flavors:
- **dev**: Development environment
  - Application ID: `com.example.example.dev`
  - App Name: "Example Dev"
  - Main file: `lib/main-dev.dart`
  - Primary color: Blue
  
- **prod**: Production environment
  - Application ID: `com.example.example`
  - App Name: "Example"
  - Main file: `lib/main-prod.dart`
  - Primary color: Deep Purple

## Running the App

### Development Flavor
```bash
flutter run --flavor dev -t lib/main-dev.dart
```

### Production Flavor
```bash
flutter run --flavor prod -t lib/main-prod.dart
```

### Building APK/AAB

#### Development APK
```bash
flutter build apk --flavor dev -t lib/main-dev.dart
```

#### Production APK
```bash
flutter build apk --flavor prod -t lib/main-prod.dart
```

#### Production AAB (for Play Store)
```bash
flutter build appbundle --flavor prod -t lib/main-prod.dart --release
```

## Project Structure

- `lib/main.dart` - Default main file (uses prod config)
- `lib/main-dev.dart` - Development flavor entry point
- `lib/main-prod.dart` - Production flavor entry point
- `lib/app.dart` - Shared app configuration and UI code

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
