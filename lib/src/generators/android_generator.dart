import 'dart:io';
import 'package:image/image.dart' as img;

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
    await _updateMainActivityIcon();
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

    // Find default icon
    final defaultIcon = icons.where((icon) => icon.isDefault).firstOrNull;

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

        // For default icon, also create ic_launcher.png files (replace Flutter's default)
        if (icon.isDefault) {
          // Delete existing ic_launcher.png if it exists
          final launcherFile = File('${destDir.path}/ic_launcher.png');
          if (launcherFile.existsSync()) {
            launcherFile.deleteSync();
          }
          
          // Create ic_launcher.png from default icon
          await _resizeAndCopyIcon(
            icon.sourcePath,
            launcherFile.path,
            entry.value,
          );

          // Delete existing ic_launcher_round.png if it exists
          final launcherRoundFile = File('${destDir.path}/ic_launcher_round.png');
          if (launcherRoundFile.existsSync()) {
            launcherRoundFile.deleteSync();
          }
          
          // Create ic_launcher_round.png from default icon
          await _resizeAndCopyIcon(
            icon.sourcePath,
            launcherRoundFile.path,
            entry.value,
          );
        }
      }

      // Generate adaptive icon XML if needed (Android 8.0+)
      await _generateAdaptiveIconXml(icon);
    }

    // Generate adaptive icon XML for ic_launcher (default icon)
    if (defaultIcon != null) {
      await _generateDefaultAdaptiveIconXml(defaultIcon);
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
      print('  ⚠️  Source icon not found: $sourcePath');
      return;
    }

    try {
      // Read the source image
      final sourceBytes = await sourceFile.readAsBytes();
      final sourceImage = img.decodeImage(sourceBytes);
      
      if (sourceImage == null) {
        print('  ⚠️  Could not decode image: $sourcePath');
        // Fallback: just copy the file
        await sourceFile.copy(destPath);
        return;
      }

      // For foreground icons (adaptive icons), we need to create a 108x108dp canvas
      // with the icon centered in a 72x72dp safe zone
      final isForeground = destPath.contains('_foreground');
      
      if (isForeground) {
        // Adaptive icon foreground: 108x108dp canvas, icon centered in 72x72dp safe zone
        // 108dp = size * 2.25 (since size is for 48dp base)
        final canvasSize = (size * 2.25).round(); // 108dp in pixels
        final safeZoneSize = (size * 1.5).round(); // 72dp in pixels (72/48 = 1.5)
        
        // Resize source image to fit in safe zone while maintaining aspect ratio
        final sourceWidth = sourceImage.width;
        final sourceHeight = sourceImage.height;
        final sourceAspect = sourceWidth / sourceHeight;
        
        int targetWidth, targetHeight;
        if (sourceAspect > 1) {
          // Wider than tall
          targetWidth = safeZoneSize;
          targetHeight = (safeZoneSize / sourceAspect).round();
        } else {
          // Taller than wide or square
          targetHeight = safeZoneSize;
          targetWidth = (safeZoneSize * sourceAspect).round();
        }
        
        // Resize the icon
        final resizedIcon = img.copyResize(
          sourceImage,
          width: targetWidth,
          height: targetHeight,
          interpolation: img.Interpolation.cubic,
        );
        
        // Create a transparent canvas
        final canvas = img.Image(width: canvasSize, height: canvasSize);
        
        // Center the icon on the canvas
        final offsetX = (canvasSize - targetWidth) ~/ 2;
        final offsetY = (canvasSize - targetHeight) ~/ 2;
        
        img.compositeImage(canvas, resizedIcon, dstX: offsetX, dstY: offsetY);
        
        // Save the result
        final destFile = File(destPath);
        await destFile.writeAsBytes(img.encodePng(canvas));
        print('  Created adaptive foreground icon: $destPath (${canvasSize}x${canvasSize})');
      } else {
        // Regular icon or round icon: resize to target size
        final resizedImage = img.copyResize(
          sourceImage,
          width: size,
          height: size,
          interpolation: img.Interpolation.cubic,
        );
        
        final destFile = File(destPath);
        await destFile.writeAsBytes(img.encodePng(resizedImage));
        print('  Resized icon to: $destPath (${size}x${size})');
      }
    } catch (e) {
      print('  ⚠️  Error processing icon: $e');
      // Fallback: just copy the file
      await sourceFile.copy(destPath);
    }
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

  /// Generate adaptive icon XML for default ic_launcher
  Future<void> _generateDefaultAdaptiveIconXml(IconDefinition defaultIcon) async {
    final xmlDir = Directory(
        '$projectPath/android/app/src/main/res/mipmap-anydpi-v26');
    if (!xmlDir.existsSync()) {
      xmlDir.createSync(recursive: true);
    }

    final xmlContent = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/${defaultIcon.resourceName}_foreground"/>
</adaptive-icon>
''';

    final xmlFile = File('${xmlDir.path}/ic_launcher.xml');
    await xmlFile.writeAsString(xmlContent);
    print('  Created adaptive icon XML for ic_launcher');
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

    // Remove MainActivity's LAUNCHER intent-filter to prevent duplicate icons
    // Only activity-alias'lar will have LAUNCHER intent-filter
    // MainActivity must always be enabled (for Flutter), but won't show as launcher
    final mainActivityMatch = mainActivityRegex.firstMatch(content);
    if (mainActivityMatch != null) {
      final activityStart = mainActivityMatch.start;
      final activityEnd = content.indexOf('</activity>', activityStart);
      if (activityEnd != -1) {
        final activityContent = content.substring(activityStart, activityEnd);
        if (activityContent.contains('android.intent.category.LAUNCHER') &&
            !activityContent.contains('MASTERFABRIC_APP_ICON')) {
          // Remove LAUNCHER intent-filter from MainActivity
          content = content.replaceRange(
            activityStart,
            activityEnd,
            activityContent.replaceAll(
              RegExp(
                r'\s*<intent-filter>\s*<action android:name="android\.intent\.action\.MAIN"/>\s*<category android:name="android\.intent\.category\.LAUNCHER"/>\s*</intent-filter>\s*',
                multiLine: true,
                dotAll: true,
              ),
              '\n            <!-- LAUNCHER intent-filter removed - only activity-alias\'lar have LAUNCHER -->\n',
            ),
          );
          print('  Removed LAUNCHER intent-filter from MainActivity');
        }
      }
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
      // Default icon's alias is enabled, others are disabled
      // MainActivity doesn't have LAUNCHER intent-filter, so Flutter launches via enabled alias
      final isEnabled = icon.isDefault;
      aliasesBuffer.writeln('''
        <activity-alias
            android:name=".${icon.aliasName}"
            android:enabled="$isEnabled"
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

  /// Update MainActivity to use default icon's adaptive icon
  Future<void> _updateMainActivityIcon() async {
    // Find default icon
    final defaultIcon = icons.where((icon) => icon.isDefault).firstOrNull;
    if (defaultIcon == null) {
      print('  ⚠️  No default icon found, skipping MainActivity icon update');
      return;
    }

    final manifestPath =
        '$projectPath/android/app/src/main/AndroidManifest.xml';
    final manifestFile = File(manifestPath);

    if (!manifestFile.existsSync()) {
      return;
    }

    var content = await manifestFile.readAsString();

    // Update MainActivity's icon to use default icon
    final mainActivityRegex = RegExp(
      r'<activity\s+android:name="\.MainActivity"[^>]*>',
      multiLine: true,
    );

    final match = mainActivityRegex.firstMatch(content);
    if (match == null) {
      return;
    }

    final activityStart = match.start;
    final activityEnd = content.indexOf('</activity>', activityStart);
    if (activityEnd == -1) {
      return;
    }

    final activityContent = content.substring(activityStart, activityEnd);
    
    // Replace icon and roundIcon attributes
    final updatedActivity = activityContent
        .replaceAll(
          RegExp(r'android:icon="[^"]*"'),
          'android:icon="@mipmap/${defaultIcon.resourceName}"',
        )
        .replaceAll(
          RegExp(r'android:roundIcon="[^"]*"'),
          'android:roundIcon="@mipmap/${defaultIcon.resourceName}_round"',
        );

    // If icon attributes don't exist, add them
    if (!updatedActivity.contains('android:icon=')) {
      final insertPos = updatedActivity.indexOf('android:exported=');
      if (insertPos != -1) {
        final beforeExport = updatedActivity.substring(0, insertPos);
        final afterExport = updatedActivity.substring(insertPos);
        content = content.replaceRange(
          activityStart,
          activityEnd,
          '$beforeExport            android:icon="@mipmap/${defaultIcon.resourceName}"\n            android:roundIcon="@mipmap/${defaultIcon.resourceName}_round"\n            $afterExport',
        );
      }
    } else {
      content = content.replaceRange(
        activityStart,
        activityEnd,
        updatedActivity,
      );
    }

    await manifestFile.writeAsString(content);
    print('  Updated MainActivity to use default icon: ${defaultIcon.resourceName}');
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
