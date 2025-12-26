import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Generator for macOS platform icon configuration
class MacosIconGenerator {
  final String projectPath;
  final List<MacosIconDefinition> icons;
  final String appName;

  MacosIconGenerator({
    required this.projectPath,
    required this.icons,
    required this.appName,
  });

  /// Generate macOS resources and update configuration
  Future<void> generate() async {
    await _copyIconAssets();
    await _updateInfoPlist();
  }

  /// Copy icon assets to macOS Assets.xcassets
  Future<void> _copyIconAssets() async {
    final assetsPath = '$projectPath/macos/Runner/Assets.xcassets';
    final assetsDir = Directory(assetsPath);
    
    // Clean up old/default icon sets
    if (assetsDir.existsSync()) {
      // Remove default AppIcon.appiconset if it exists
      final defaultAppIcon = Directory('$assetsPath/AppIcon.appiconset');
      if (defaultAppIcon.existsSync()) {
        defaultAppIcon.deleteSync(recursive: true);
        print('  🗑️  Removed default AppIcon.appiconset');
      }
      
      // Remove any icon sets that aren't in the current icon list
      final currentIconSets = icons.map((i) => '${i.assetCatalogName}.appiconset').toSet();
      final existingDirs = assetsDir.listSync();
      for (final entity in existingDirs) {
        if (entity is Directory) {
          final dirName = entity.path.split('/').last;
          // Remove if it's an AppIcon-*.appiconset that's not in our current list
          if (dirName.startsWith('AppIcon-') && dirName.endsWith('.appiconset')) {
            if (!currentIconSets.contains(dirName)) {
              entity.deleteSync(recursive: true);
              print('  🗑️  Removed old icon set: $dirName');
            }
          }
        }
      }
    }

    for (final icon in icons) {
      // Check if source file exists
      final sourceFile = File(icon.sourcePath);
      if (!sourceFile.existsSync()) {
        print('  ⚠️  Skipping ${icon.name}: source file not found at ${icon.sourcePath}');
        continue;
      }

      final iconSetPath = '$assetsPath/${icon.assetCatalogName}.appiconset';
      final iconSetDir = Directory(iconSetPath);

      if (!iconSetDir.existsSync()) {
        iconSetDir.createSync(recursive: true);
      }

      // macOS icon sizes
      final macosSizes = [
        _MacosIconSize(16, 1),
        _MacosIconSize(16, 2),
        _MacosIconSize(32, 1),
        _MacosIconSize(32, 2),
        _MacosIconSize(128, 1),
        _MacosIconSize(128, 2),
        _MacosIconSize(256, 1),
        _MacosIconSize(256, 2),
        _MacosIconSize(512, 1),
        _MacosIconSize(512, 2),
      ];

      // Generate Contents.json
      final contentsJson = _generateContentsJson(icon, macosSizes);
      await File('$iconSetPath/Contents.json').writeAsString(contentsJson);

      // Copy icons for each size
      for (final size in macosSizes) {
        await _resizeAndCopyIcon(
          icon.sourcePath,
          '$iconSetPath/${icon.name}_${size.size}x${size.size}@${size.scale}x.png',
          size.size * size.scale,
        );
      }
    }
  }

  /// Generate Contents.json for icon set
  String _generateContentsJson(
      MacosIconDefinition icon, List<_MacosIconSize> sizes) {
    final images = sizes.map((size) {
      return '''    {
      "filename": "${icon.name}_${size.size}x${size.size}@${size.scale}x.png",
      "idiom": "mac",
      "scale": "${size.scale}x",
      "size": "${size.size}x${size.size}"
    }''';
    }).join(',\n');

    return '''{
  "images": [
$images
  ],
  "info": {
    "author": "masterfabric_app_icon",
    "version": 1
  }
}
''';
  }

  /// Resize and copy icon
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

    try {
      // Read source image
      final sourceBytes = await sourceFile.readAsBytes();
      final sourceImage = img.decodeImage(sourceBytes);
      
      if (sourceImage == null) {
        print('  ⚠️  Failed to decode image: $sourcePath');
        // Fallback to copy if decode fails
        await sourceFile.copy(destPath);
        return;
      }

      // Resize image to target size
      final resizedImage = img.copyResize(
        sourceImage,
        width: size,
        height: size,
        interpolation: img.Interpolation.cubic,
      );

      // Encode as PNG
      final resizedBytes = Uint8List.fromList(img.encodePng(resizedImage));
      
      // Write to destination
      final destFile = File(destPath);
      await destFile.writeAsBytes(resizedBytes);
      
      print('  ✅ Resized and saved icon: $destPath (${size}x$size)');
    } catch (e) {
      print('  ⚠️  Error resizing icon: $e, falling back to copy');
      // Fallback to copy if resize fails
      await sourceFile.copy(destPath);
    }
  }

  /// Update Info.plist for macOS
  Future<void> _updateInfoPlist() async {
    final plistPath = '$projectPath/macos/Runner/Info.plist';
    final plistFile = File(plistPath);

    if (!plistFile.existsSync()) {
      throw Exception('Info.plist not found at: $plistPath');
    }

    var content = await plistFile.readAsString();

    // Filter out icons with missing source files
    final validIcons = icons.where((icon) {
      final sourceFile = File(icon.sourcePath);
      return sourceFile.existsSync();
    }).toList();

    if (validIcons.isEmpty) {
      print('  ⚠️  No valid icons found, skipping Info.plist update');
      return;
    }

    // Find the default icon
    final defaultIcon = validIcons.where((i) => i.isDefault).firstOrNull ?? validIcons.first;

    // Check if icon configuration already exists
    if (content.contains('<!-- MASTERFABRIC_APP_ICON_START -->')) {
      content = content.replaceAll(
        RegExp(
          r'<!-- MASTERFABRIC_APP_ICON_START -->.*<!-- MASTERFABRIC_APP_ICON_END -->',
          dotAll: true,
        ),
        '',
      );
    }

    // Generate plist entry for CFBundleIconFile
    final plistEntry = '''    <!-- MASTERFABRIC_APP_ICON_START -->
    <key>CFBundleIconFile</key>
    <string>${defaultIcon.assetCatalogName}</string>
    <!-- MASTERFABRIC_APP_ICON_END -->
''';

    // Insert before </dict></plist>
    content = content.replaceFirst(
      '</dict>\n</plist>',
      '$plistEntry</dict>\n</plist>',
    );

    await plistFile.writeAsString(content);
    print('Updated macOS Info.plist with icon configuration');
  }
}

/// macOS icon definition
class MacosIconDefinition {
  final String name;
  final String sourcePath;
  final bool isDefault;

  MacosIconDefinition({
    required this.name,
    required this.sourcePath,
    this.isDefault = false,
  });

  String get assetCatalogName => 'AppIcon-$name';
}

class _MacosIconSize {
  final int size;
  final int scale;

  _MacosIconSize(this.size, this.scale);
}
