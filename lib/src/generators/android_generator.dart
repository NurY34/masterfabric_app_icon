import 'dart:io';

/// Generator for Android platform icon configuration
class AndroidIconGenerator {
  final String projectPath;
  final List<IconDefinition> icons;

  AndroidIconGenerator({
    required this.projectPath,
    required this.icons,
  });

  /// Generate Android resources and update AndroidManifest.xml
  Future<void> generate() async {
    await _ensureColorResource();
    await _copyIconResources();
    await _updateAndroidManifest();
  }

  /// Copy icon assets to Android res folders
  Future<void> _copyIconResources() async {
    final resPath = '$projectPath/android/app/src/main/res';

    // Android icon sizes for different densities
    final densities = {
      'mipmap-mdpi': 48,
      'mipmap-hdpi': 72,
      'mipmap-xhdpi': 96,
      'mipmap-xxhdpi': 144,
      'mipmap-xxxhdpi': 192,
    };

    for (final icon in icons) {
      // Check if source file exists
      final sourceFile = File(icon.sourcePath);
      if (!sourceFile.existsSync()) {
        print('  ⚠️  Skipping ${icon.name}: source file not found at ${icon.sourcePath}');
        continue;
      }

      for (final entry in densities.entries) {
        final destDir = Directory('$resPath/${entry.key}');
        if (!destDir.existsSync()) {
          destDir.createSync(recursive: true);
        }

        final destFile = File('${destDir.path}/${icon.resourceName}.png');
        
        // Copy and resize the icon
        await _resizeAndCopyIcon(
          icon.sourcePath,
          destFile.path,
          entry.value,
        );

        // Also create round icon version (same icon, different name)
        final roundDestFile = File('${destDir.path}/${icon.resourceName}_round.png');
        await _resizeAndCopyIcon(
          icon.sourcePath,
          roundDestFile.path,
          entry.value,
        );

        // Create foreground drawable for adaptive icon
        final foregroundDestFile = File('${destDir.path}/${icon.resourceName}_foreground.png');
        await _resizeAndCopyIcon(
          icon.sourcePath,
          foregroundDestFile.path,
          entry.value,
        );
      }

      // Generate adaptive icon XML if needed (Android 8.0+)
      await _generateAdaptiveIconXml(icon);
    }
  }

  /// Resize and copy icon to destination
  Future<void> _resizeAndCopyIcon(
    String sourcePath,
    String destPath,
    int size,
  ) async {
    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync()) {
      // This should not happen as we check before calling, but handle gracefully
      print('  ⚠️  Source icon not found: $sourcePath');
      return;
    }

    // For now, just copy the file - in production, use image package to resize
    await sourceFile.copy(destPath);
    print('  Copied icon to: $destPath');
  }

  /// Ensure color resource exists for adaptive icons
  Future<void> _ensureColorResource() async {
    final valuesDir = Directory('$projectPath/android/app/src/main/res/values');
    if (!valuesDir.existsSync()) {
      valuesDir.createSync(recursive: true);
    }

    final colorsFile = File('${valuesDir.path}/colors.xml');
    if (!colorsFile.existsSync()) {
      // Create colors.xml with launcher background color
      final colorsContent = '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#FFFFFF</color>
</resources>
''';
      await colorsFile.writeAsString(colorsContent);
      print('  Created colors.xml with ic_launcher_background');
    } else {
      // Check if ic_launcher_background exists, if not add it
      var content = await colorsFile.readAsString();
      if (!content.contains('ic_launcher_background')) {
        // Add the color before </resources>
        content = content.replaceFirst(
          '</resources>',
          '    <color name="ic_launcher_background">#FFFFFF</color>\n</resources>',
        );
        await colorsFile.writeAsString(content);
        print('  Added ic_launcher_background to colors.xml');
      }
    }
  }

  /// Generate adaptive icon XML for Android 8.0+
  Future<void> _generateAdaptiveIconXml(IconDefinition icon) async {
    final xmlDir = Directory(
        '$projectPath/android/app/src/main/res/mipmap-anydpi-v26');
    if (!xmlDir.existsSync()) {
      xmlDir.createSync(recursive: true);
    }

    final xmlContent = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/${icon.resourceName}_foreground"/>
</adaptive-icon>
''';

    final xmlFile = File('${xmlDir.path}/${icon.resourceName}.xml');
    await xmlFile.writeAsString(xmlContent);
  }

  /// Update AndroidManifest.xml with activity-alias entries
  Future<void> _updateAndroidManifest() async {
    final manifestPath =
        '$projectPath/android/app/src/main/AndroidManifest.xml';
    final manifestFile = File(manifestPath);

    if (!manifestFile.existsSync()) {
      throw Exception('AndroidManifest.xml not found at: $manifestPath');
    }

    var content = await manifestFile.readAsString();

    // Find the main activity
    final mainActivityRegex = RegExp(
      r'<activity\s+android:name="\.MainActivity"[^>]*>',
      multiLine: true,
    );

    if (!mainActivityRegex.hasMatch(content)) {
      print('Warning: MainActivity not found in AndroidManifest.xml');
      return;
    }

    // Check if aliases already exist
    if (content.contains('<!-- MASTERFABRIC_APP_ICON_ALIASES_START -->')) {
      // Remove existing aliases
      content = content.replaceAll(
        RegExp(
          r'<!-- MASTERFABRIC_APP_ICON_ALIASES_START -->.*<!-- MASTERFABRIC_APP_ICON_ALIASES_END -->',
          dotAll: true,
        ),
        '',
      );
    }

    // Filter out icons with missing source files
    final validIcons = icons.where((icon) {
      final sourceFile = File(icon.sourcePath);
      return sourceFile.existsSync();
    }).toList();

    if (validIcons.isEmpty) {
      print('  ⚠️  No valid icons found, skipping AndroidManifest.xml update');
      return;
    }

    // Generate activity-alias entries
    final aliasesBuffer = StringBuffer();
    aliasesBuffer.writeln('        <!-- MASTERFABRIC_APP_ICON_ALIASES_START -->');

    for (final icon in validIcons) {
      final isDefault = icon.isDefault;
      aliasesBuffer.writeln('''
        <activity-alias
            android:name=".${icon.aliasName}"
            android:enabled="${isDefault}"
            android:exported="true"
            android:icon="@mipmap/${icon.resourceName}"
            android:roundIcon="@mipmap/${icon.resourceName}_round"
            android:targetActivity=".MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity-alias>
''');
    }
    aliasesBuffer.writeln('        <!-- MASTERFABRIC_APP_ICON_ALIASES_END -->');

    // Insert aliases before </application>
    content = content.replaceFirst(
      '</application>',
      '${aliasesBuffer.toString()}    </application>',
    );

    await manifestFile.writeAsString(content);
    print('Updated AndroidManifest.xml with ${validIcons.length} icon aliases');
  }
}

/// Icon definition for generation
class IconDefinition {
  final String name;
  final String sourcePath;
  final bool isDefault;

  IconDefinition({
    required this.name,
    required this.sourcePath,
    this.isDefault = false,
  });

  String get resourceName => 'ic_launcher_$name';
  String get aliasName => 'MainActivity${_capitalize(name)}';

  String _capitalize(String s) =>
      s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;
}
