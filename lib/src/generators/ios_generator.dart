import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Generator for iOS platform icon configuration
class IosIconGenerator {
  final String projectPath;
  final List<IosIconDefinition> icons;
  final String appName;

  IosIconGenerator({
    required this.projectPath,
    required this.icons,
    required this.appName,
  });

  /// Generate iOS resources and update Info.plist
  Future<void> generate() async {
    await _copyIconAssets();
    await _updateInfoPlist();
  }

  /// Copy icon assets to iOS Assets.xcassets
  Future<void> _copyIconAssets() async {
    final assetsPath = '$projectPath/ios/Runner/Assets.xcassets';
    final assetsDir = Directory(assetsPath);
    
    // Clean up old icon sets (but keep AppIcon.appiconset for Xcode compatibility)
    if (assetsDir.existsSync()) {
      // Remove any icon sets that aren't in the current icon list
      // Note: We'll create AppIcon.appiconset from the default icon later
      final currentIconSets = icons.map((i) => '${i.assetCatalogName}.appiconset').toSet();
      final existingDirs = assetsDir.listSync();
      for (final entity in existingDirs) {
        if (entity is Directory) {
          final dirName = entity.path.split('/').last;
          // Remove if it's an AppIcon-*.appiconset that's not in our current list
          // But keep AppIcon.appiconset - we'll recreate it from default icon
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

      // iOS icon sizes with correct idiom
      // All required sizes: 29, 40, 48, 55, 57, 58, 60, 66, 80, 87, 88, 92, 100, 114, 120, 172, 180, 196, 216, 1024
      final iosSizes = [
        // Standard iOS sizes
        _IosIconSize(20, 1, 'iphone'), // 20
        _IosIconSize(20, 2, 'iphone'), // 40
        _IosIconSize(20, 3, 'iphone'), // 60
        _IosIconSize(29, 1, 'iphone'), // 29
        _IosIconSize(29, 2, 'iphone'), // 58
        _IosIconSize(29, 3, 'iphone'), // 87
        _IosIconSize(40, 1, 'iphone'), // 40
        _IosIconSize(40, 2, 'iphone'), // 80
        _IosIconSize(40, 3, 'iphone'), // 120
        _IosIconSize(60, 2, 'iphone'), // 120
        _IosIconSize(60, 3, 'iphone'), // 180
        // Additional custom sizes
        _IosIconSize(24, 2, 'iphone'), // 48
        _IosIconSize(27.5, 2, 'iphone'), // 55
        _IosIconSize(28.5, 2, 'iphone'), // 57
        _IosIconSize(30, 2, 'iphone'), // 60
        _IosIconSize(33, 2, 'iphone'), // 66
        _IosIconSize(44, 2, 'iphone'), // 88
        _IosIconSize(46, 2, 'iphone'), // 92
        _IosIconSize(50, 2, 'iphone'), // 100
        _IosIconSize(57, 2, 'iphone'), // 114
        _IosIconSize(86, 2, 'iphone'), // 172
        _IosIconSize(98, 2, 'iphone'), // 196
        _IosIconSize(108, 2, 'iphone'), // 216
        // iPad sizes
        _IosIconSize(20, 1, 'ipad'),
        _IosIconSize(20, 2, 'ipad'),
        _IosIconSize(29, 1, 'ipad'),
        _IosIconSize(29, 2, 'ipad'),
        _IosIconSize(40, 1, 'ipad'),
        _IosIconSize(40, 2, 'ipad'),
        _IosIconSize(76, 1, 'ipad'),
        _IosIconSize(76, 2, 'ipad'),
        _IosIconSize(83.5, 2, 'ipad'),
        // App Store
        _IosIconSize(1024, 1, 'ios-marketing'), // 1024
      ];

      // Generate Contents.json
      final contentsJson = _generateContentsJson(icon, iosSizes);
      await File('$iconSetPath/Contents.json').writeAsString(contentsJson);

      // Copy icons for each size
      for (final size in iosSizes) {
        await _resizeAndCopyIcon(
          icon.sourcePath,
          '$iconSetPath/${icon.name}_${size.size.toInt()}x${size.size.toInt()}@${size.scale}x.png',
          (size.size * size.scale).toInt(),
        );
      }
    }
    
    // Create default AppIcon.appiconset for Xcode compatibility
    // This is required by Xcode even though we use alternate icons
    final validIcons = icons.where((icon) {
      final sourceFile = File(icon.sourcePath);
      return sourceFile.existsSync();
    }).toList();
    
    if (validIcons.isNotEmpty) {
      final defaultIcon = validIcons.where((i) => i.isDefault).firstOrNull ?? validIcons.first;
      final defaultAppIconPath = '$assetsPath/AppIcon.appiconset';
      final defaultAppIconDir = Directory(defaultAppIconPath);
      
      // Remove existing AppIcon if it exists
      if (defaultAppIconDir.existsSync()) {
        defaultAppIconDir.deleteSync(recursive: true);
      }
      defaultAppIconDir.createSync(recursive: true);
      
      // Generate Contents.json with correct idioms for AppIcon
      final appIconSizes = [
        // iPhone - Notification (20pt)
        _IosIconSize(20, 1, 'iphone'),
        _IosIconSize(20, 2, 'iphone'),
        _IosIconSize(20, 3, 'iphone'),
        // iPhone - Settings (29pt)
        _IosIconSize(29, 1, 'iphone'),
        _IosIconSize(29, 2, 'iphone'),
        _IosIconSize(29, 3, 'iphone'),
        // iPhone - Spotlight (40pt)
        _IosIconSize(40, 1, 'iphone'),
        _IosIconSize(40, 2, 'iphone'),
        _IosIconSize(40, 3, 'iphone'),
        // iPhone - App (60pt)
        _IosIconSize(60, 2, 'iphone'),
        _IosIconSize(60, 3, 'iphone'),
        // iPad - Notification (20pt)
        _IosIconSize(20, 1, 'ipad'),
        _IosIconSize(20, 2, 'ipad'),
        // iPad - Settings (29pt)
        _IosIconSize(29, 1, 'ipad'),
        _IosIconSize(29, 2, 'ipad'),
        // iPad - Spotlight (40pt)
        _IosIconSize(40, 1, 'ipad'),
        _IosIconSize(40, 2, 'ipad'),
        // iPad - App (76pt)
        _IosIconSize(76, 1, 'ipad'),
        _IosIconSize(76, 2, 'ipad'),
        // iPad Pro - App (83.5pt)
        _IosIconSize(83.5, 2, 'ipad'),
        // App Store (1024pt)
        _IosIconSize(1024, 1, 'ios-marketing'),
      ];
      
      // Generate Contents.json for AppIcon
      final appIconContentsJson = _generateAppIconContentsJson(appIconSizes);
      await File('$defaultAppIconPath/Contents.json').writeAsString(appIconContentsJson);
      
      // Copy icon files from default icon set, renaming them to AppIcon_*
      final defaultIconSetPath = '$assetsPath/${defaultIcon.assetCatalogName}.appiconset';
      final defaultIconDir = Directory(defaultIconSetPath);
      if (defaultIconDir.existsSync()) {
        final iconFiles = defaultIconDir.listSync().whereType<File>().where((f) {
          return f.path.endsWith('.png') && f.path.contains(defaultIcon.name);
        });
        
        for (final iconFile in iconFiles) {
          final fileName = iconFile.path.split('/').last;
          final newFileName = fileName.replaceAll('${defaultIcon.name}_', 'AppIcon_');
          await iconFile.copy('$defaultAppIconPath/$newFileName');
        }
        
        print('  ✅ Created default AppIcon.appiconset from ${defaultIcon.name}');
      }
    }
  }

  /// Generate Contents.json for icon set
  String _generateContentsJson(
      IosIconDefinition icon, List<_IosIconSize> sizes) {
    final images = sizes.map((size) {
      return '''    {
      "filename": "${icon.name}_${size.size.toInt()}x${size.size.toInt()}@${size.scale}x.png",
      "idiom": "${size.idiom}",
      "scale": "${size.scale}x",
      "size": "${size.size.toInt()}x${size.size.toInt()}"
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

  /// Generate Contents.json for default AppIcon.appiconset
  String _generateAppIconContentsJson(List<_IosIconSize> sizes) {
    final images = sizes.map((size) {
      return '''    {
      "filename": "AppIcon_${size.size.toInt()}x${size.size.toInt()}@${size.scale}x.png",
      "idiom": "${size.idiom}",
      "scale": "${size.scale}x",
      "size": "${size.size.toInt()}x${size.size.toInt()}"
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

      // iOS icons MUST NOT have alpha channel (transparency)
      // Remove alpha channel by compositing onto white background
      img.Image processedImage = sourceImage;
      
      // If image has alpha channel, composite onto white background
      if (sourceImage.hasAlpha) {
        // Create white background
        final whiteBg = img.Image(
          width: sourceImage.width,
          height: sourceImage.height,
        );
        // Fill with white (255, 255, 255)
        img.fill(whiteBg, color: img.ColorRgb8(255, 255, 255));
        
        // Composite source image onto white background
        processedImage = img.compositeImage(whiteBg, sourceImage);
      }

      // Resize image to target size with high quality interpolation
      final resizedImage = img.copyResize(
        processedImage,
        width: size,
        height: size,
        interpolation: img.Interpolation.cubic,
        maintainAspect: false, // Force exact size
      );

      // Ensure final image has no alpha channel (iOS requirement)
      img.Image finalImage = resizedImage;
      if (resizedImage.hasAlpha) {
        // Create white background and composite
        final whiteBg = img.Image(
          width: resizedImage.width,
          height: resizedImage.height,
        );
        img.fill(whiteBg, color: img.ColorRgb8(255, 255, 255));
        finalImage = img.compositeImage(whiteBg, resizedImage);
      }

      // Encode as PNG with maximum compression quality
      final resizedBytes = Uint8List.fromList(
        img.encodePng(finalImage, level: 6), // Level 6 = good balance
      );
      
      // Write to destination
      final destFile = File(destPath);
      await destFile.writeAsBytes(resizedBytes);
      
      print('  ✅ Resized and saved icon: $destPath (${size}x$size, format: ${finalImage.format})');
    } catch (e) {
      print('  ⚠️  Error resizing icon: $e, falling back to copy');
      // Fallback to copy if resize fails
      await sourceFile.copy(destPath);
    }
  }

  /// Update Info.plist with alternate icon entries
  Future<void> _updateInfoPlist() async {
    final plistPath = '$projectPath/ios/Runner/Info.plist';
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

    // Remove existing CFBundleIcons configuration if it exists (with or without comments)
    // First remove commented sections
    content = content.replaceAll(
      RegExp(
        r'<!-- MASTERFABRIC_APP_ICON_START -->.*?<!-- MASTERFABRIC_APP_ICON_END -->',
        dotAll: true,
      ),
      '',
    );
    
    // Remove CFBundleIcons sections (properly nested)
    content = content.replaceAll(
      RegExp(
        r'\t<key>CFBundleIcons</key>\s*<dict>.*?</dict>\s*',
        dotAll: true,
      ),
      '',
    );
    
    // Remove CFBundleIcons~ipad sections (properly nested)
    content = content.replaceAll(
      RegExp(
        r'\t<key>CFBundleIcons~ipad</key>\s*<dict>.*?</dict>\s*',
        dotAll: true,
      ),
      '',
    );
    
    // Remove any standalone CFBundleAlternateIcons entries that might exist incorrectly
    // These appear at root level and incorrectly close the main dict
    // Match: <key>CFBundleAlternateIcons</key> followed by dict content and closing dict tags
    // Pattern matches any indentation level and handles multiple closing dict tags
    content = content.replaceAll(
      RegExp(
        r'[\t\s]*<key>CFBundleAlternateIcons</key>[\s\n]*<dict>.*?</dict>[\s\n]*</dict>',
        dotAll: true,
      ),
      '',
    );
    
    // Clean up any orphaned closing dict tags before the final </dict></plist>
    // Find the last </dict></plist> and remove any extra </dict> tags before it
    final lastDictPlistIndex = content.lastIndexOf('\t</dict>\n</plist>');
    if (lastDictPlistIndex != -1) {
      final beforeLast = content.substring(0, lastDictPlistIndex);
      final afterLast = content.substring(lastDictPlistIndex);
      // Remove ALL trailing </dict> tags (one or more, with tabs, whitespace, and newlines)
      // This handles multiple consecutive closing dict tags
      final cleanedBefore = beforeLast.replaceAll(
        RegExp(r'(\t</dict>\s*\n\s*)+$'),
        '',
      );
      content = cleanedBefore + afterLast;
    }

    // Find alternate icons (default icon uses AppIcon.appiconset)
    final alternateIcons = validIcons.where((i) => !i.isDefault).toList();

    // Generate plist entries
    final plistEntries = StringBuffer();
    plistEntries.writeln('\t<key>CFBundleIcons</key>');
    plistEntries.writeln('\t<dict>');
    plistEntries.writeln('\t\t<key>CFBundlePrimaryIcon</key>');
    plistEntries.writeln('\t\t<dict>');
    plistEntries.writeln('\t\t\t<key>CFBundleIconFiles</key>');
    plistEntries.writeln('\t\t\t<array>');
    // Use "AppIcon" as primary (the default AppIcon.appiconset we create)
    plistEntries.writeln('\t\t\t\t<string>AppIcon</string>');
    plistEntries.writeln('\t\t\t</array>');
    plistEntries.writeln('\t\t\t<key>UIPrerenderedIcon</key>');
    plistEntries.writeln('\t\t\t<false/>');
    plistEntries.writeln('\t\t</dict>');

    if (alternateIcons.isNotEmpty) {
      plistEntries.writeln('\t\t<key>CFBundleAlternateIcons</key>');
      plistEntries.writeln('\t\t<dict>');
      
      for (final icon in alternateIcons) {
        plistEntries.writeln('\t\t\t<key>${icon.name}</key>');
        plistEntries.writeln('\t\t\t<dict>');
        plistEntries.writeln('\t\t\t\t<key>CFBundleIconFiles</key>');
        plistEntries.writeln('\t\t\t\t<array>');
        plistEntries.writeln('\t\t\t\t\t<string>${icon.assetCatalogName}</string>');
        plistEntries.writeln('\t\t\t\t</array>');
        plistEntries.writeln('\t\t\t\t<key>UIPrerenderedIcon</key>');
        plistEntries.writeln('\t\t\t\t<false/>');
        plistEntries.writeln('\t\t\t</dict>');
      }
      
      plistEntries.writeln('\t\t</dict>');
    }

    plistEntries.writeln('\t</dict>');
    
    // Add iPad icons (CFBundleIcons~ipad)
    plistEntries.writeln('\t<key>CFBundleIcons~ipad</key>');
    plistEntries.writeln('\t<dict>');
    plistEntries.writeln('\t\t<key>CFBundlePrimaryIcon</key>');
    plistEntries.writeln('\t\t<dict>');
    plistEntries.writeln('\t\t\t<key>CFBundleIconFiles</key>');
    plistEntries.writeln('\t\t\t<array>');
    // Use "AppIcon" as primary (the default AppIcon.appiconset we create)
    plistEntries.writeln('\t\t\t\t<string>AppIcon</string>');
    plistEntries.writeln('\t\t\t</array>');
    plistEntries.writeln('\t\t\t<key>UIPrerenderedIcon</key>');
    plistEntries.writeln('\t\t\t<false/>');
    plistEntries.writeln('\t\t</dict>');

    if (alternateIcons.isNotEmpty) {
      plistEntries.writeln('\t\t<key>CFBundleAlternateIcons</key>');
      plistEntries.writeln('\t\t<dict>');
      
      for (final icon in alternateIcons) {
        plistEntries.writeln('\t\t\t<key>${icon.name}</key>');
        plistEntries.writeln('\t\t\t<dict>');
        plistEntries.writeln('\t\t\t\t<key>CFBundleIconFiles</key>');
        plistEntries.writeln('\t\t\t\t<array>');
        plistEntries.writeln('\t\t\t\t\t<string>${icon.assetCatalogName}</string>');
        plistEntries.writeln('\t\t\t\t</array>');
        plistEntries.writeln('\t\t\t\t<key>UIPrerenderedIcon</key>');
        plistEntries.writeln('\t\t\t\t<false/>');
        plistEntries.writeln('\t\t\t</dict>');
      }
      
      plistEntries.writeln('\t\t</dict>');
    }

    plistEntries.writeln('\t</dict>');

    // Find the correct insertion point - the last </dict> before </plist>
    // Remove any extra closing dict tags that might exist
    final lastDictIndex = content.lastIndexOf('\t</dict>\n</plist>');
    if (lastDictIndex != -1) {
      // Find the content before the last </dict></plist>
      final beforeLast = content.substring(0, lastDictIndex);
      // Remove any trailing </dict> tags (with tabs and newlines)
      final cleanedBefore = beforeLast.replaceAll(RegExp(r'\t</dict>\s*\n\s*$'), '');
      // Insert the new entries before the final </dict></plist>
      content = cleanedBefore + plistEntries.toString() + '\t</dict>\n</plist>';
    } else {
      // Fallback: try the original method
      content = content.replaceFirst(
        '</dict>\n</plist>',
        '${plistEntries.toString()}</dict>\n</plist>',
      );
    }

    await plistFile.writeAsString(content);
    print('Updated Info.plist with ${validIcons.length} icon(s)');
  }
}

/// iOS icon definition
class IosIconDefinition {
  final String name;
  final String sourcePath;
  final bool isDefault;

  IosIconDefinition({
    required this.name,
    required this.sourcePath,
    this.isDefault = false,
  });

  String get assetCatalogName => 'AppIcon-$name';
}

class _IosIconSize {
  final double size;
  final int scale;
  final String idiom;

  _IosIconSize(this.size, this.scale, [this.idiom = 'iphone']);
}
