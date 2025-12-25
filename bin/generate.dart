#!/usr/bin/env dart

import 'dart:io';
import 'package:args/args.dart';
import 'package:yaml/yaml.dart';

import '../lib/src/generators/android_generator.dart';
import '../lib/src/generators/ios_generator.dart';
import '../lib/src/generators/macos_generator.dart';

/// CLI command for generating app icons across platforms
void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'config',
      abbr: 'c',
      help: 'Path to configuration file (pubspec.yaml by default)',
      defaultsTo: 'pubspec.yaml',
    )
    ..addOption(
      'icons-path',
      abbr: 'i',
      help: 'Path to app icons folder',
      defaultsTo: 'assets/app_icons',
    )
    ..addMultiOption(
      'platforms',
      abbr: 'p',
      help: 'Target platforms (android, ios, macos)',
      defaultsTo: ['android', 'ios', 'macos'],
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage information',
    );

  try {
    final results = parser.parse(arguments);

    if (results['help'] as bool) {
      _printUsage(parser);
      return;
    }

    await _generateIcons(
      configPath: results['config'] as String,
      iconsPath: results['icons-path'] as String,
      platforms: results['platforms'] as List<String>,
    );
  } catch (e) {
    print('Error: $e');
    _printUsage(parser);
    exit(1);
  }
}

void _printUsage(ArgParser parser) {
  print('''
Masterfabric App Icon Generator

Usage: dart run masterfabric_app_icon:generate [options]

Options:
${parser.usage}

Configuration in pubspec.yaml:
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
''');
}

Future<void> _generateIcons({
  required String configPath,
  required String iconsPath,
  required List<String> platforms,
}) async {
  final projectPath = Directory.current.path;

  print('🎨 Masterfabric App Icon Generator');
  print('📁 Project path: $projectPath');
  print('📁 Icons path: $iconsPath');
  print('🎯 Platforms: ${platforms.join(', ')}');
  print('');

  // Read configuration
  final config = await _readConfig(configPath);
  final iconConfigs = _parseIconConfigs(config, iconsPath);

  if (iconConfigs.isEmpty) {
    print('⚠️  No icons configured. Please add icons to your pubspec.yaml');
    print('');
    print('Example configuration:');
    print('''
masterfabric_app_icon:
  icons_path: assets/app_icons
  icons:
    - name: icon1
      path: icon1.png
      default: true
    - name: icon2
      path: icon2.png
''');
    return;
  }

  if (iconConfigs.length > 4) {
    print('⚠️  Maximum 4 icons allowed. Using first 4 icons.');
    iconConfigs.removeRange(4, iconConfigs.length);
  }

  print('📦 Found ${iconConfigs.length} icon(s):');
  for (final icon in iconConfigs) {
    print('   - ${icon.name} (${icon.isDefault ? 'default' : 'alternate'})');
  }
  print('');

  // Generate for each platform
  for (final platform in platforms) {
    await _generateForPlatform(platform, projectPath, iconConfigs);
  }

  print('');
  print('✅ Icon generation complete!');
}

Future<Map<String, dynamic>> _readConfig(String configPath) async {
  final configFile = File(configPath);
  if (!configFile.existsSync()) {
    throw Exception('Configuration file not found: $configPath');
  }

  final content = await configFile.readAsString();
  final yaml = loadYaml(content) as YamlMap;

  final appIconConfig = yaml['masterfabric_app_icon'];
  if (appIconConfig == null) {
    return {};
  }

  return Map<String, dynamic>.from(appIconConfig as YamlMap);
}

List<_IconConfig> _parseIconConfigs(
    Map<String, dynamic> config, String defaultIconsPath) {
  final iconsPath = config['icons_path'] as String? ?? defaultIconsPath;
  final iconsList = config['icons'] as YamlList?;

  if (iconsList == null || iconsList.isEmpty) {
    // Auto-detect icons from folder
    return _autoDetectIcons(iconsPath);
  }

  final icons = <_IconConfig>[];
  for (final iconYaml in iconsList) {
    final iconMap = Map<String, dynamic>.from(iconYaml as YamlMap);
    icons.add(_IconConfig(
      name: iconMap['name'] as String,
      sourcePath: '$iconsPath/${iconMap['path']}',
      isDefault: iconMap['default'] as bool? ?? false,
    ));
  }

  // Ensure at least one default icon
  if (!icons.any((i) => i.isDefault) && icons.isNotEmpty) {
    icons[0] = _IconConfig(
      name: icons[0].name,
      sourcePath: icons[0].sourcePath,
      isDefault: true,
    );
  }

  return icons;
}

List<_IconConfig> _autoDetectIcons(String iconsPath) {
  final dir = Directory(iconsPath);
  if (!dir.existsSync()) {
    print('⚠️  Icons directory not found: $iconsPath');
    return [];
  }

  final icons = <_IconConfig>[];
  final files = dir.listSync().whereType<File>().where((f) {
    final name = f.path.toLowerCase();
    return name.endsWith('.png') || name.endsWith('.jpg');
  }).toList();

  // Sort to ensure consistent ordering
  files.sort((a, b) => a.path.compareTo(b.path));

  for (var i = 0; i < files.length && i < 4; i++) {
    final file = files[i];
    final name = file.uri.pathSegments.last.replaceAll(RegExp(r'\.(png|jpg)$'), '');
    icons.add(_IconConfig(
      name: name,
      sourcePath: file.path,
      isDefault: i == 0,
    ));
  }

  return icons;
}

Future<void> _generateForPlatform(
  String platform,
  String projectPath,
  List<_IconConfig> icons,
) async {
  print('📱 Generating for $platform...');

  switch (platform.toLowerCase()) {
    case 'android':
      await _generateAndroid(projectPath, icons);
      break;
    case 'ios':
      await _generateIos(projectPath, icons);
      break;
    case 'macos':
      await _generateMacos(projectPath, icons);
      break;
    default:
      print('   ⚠️  Unknown platform: $platform');
  }
}

Future<void> _generateAndroid(String projectPath, List<_IconConfig> icons) async {
  final androidDir = Directory('$projectPath/android');
  if (!androidDir.existsSync()) {
    print('   ⚠️  Android directory not found, skipping...');
    return;
  }

  final generator = AndroidIconGenerator(
    projectPath: projectPath,
    icons: icons.map((i) => IconDefinition(
      name: i.name,
      sourcePath: i.sourcePath,
      isDefault: i.isDefault,
    )).toList(),
  );

  await generator.generate();
  print('   ✅ Android icons generated');
}

Future<void> _generateIos(String projectPath, List<_IconConfig> icons) async {
  final iosDir = Directory('$projectPath/ios');
  if (!iosDir.existsSync()) {
    print('   ⚠️  iOS directory not found, skipping...');
    return;
  }

  final generator = IosIconGenerator(
    projectPath: projectPath,
    appName: 'Runner',
    icons: icons.map((i) => IosIconDefinition(
      name: i.name,
      sourcePath: i.sourcePath,
      isDefault: i.isDefault,
    )).toList(),
  );

  await generator.generate();
  print('   ✅ iOS icons generated');
}

Future<void> _generateMacos(String projectPath, List<_IconConfig> icons) async {
  final macosDir = Directory('$projectPath/macos');
  if (!macosDir.existsSync()) {
    print('   ⚠️  macOS directory not found, skipping...');
    return;
  }

  final generator = MacosIconGenerator(
    projectPath: projectPath,
    appName: 'Runner',
    icons: icons.map((i) => MacosIconDefinition(
      name: i.name,
      sourcePath: i.sourcePath,
      isDefault: i.isDefault,
    )).toList(),
  );

  await generator.generate();
  print('   ✅ macOS icons generated');
}

class _IconConfig {
  final String name;
  final String sourcePath;
  final bool isDefault;

  _IconConfig({
    required this.name,
    required this.sourcePath,
    this.isDefault = false,
  });
}
