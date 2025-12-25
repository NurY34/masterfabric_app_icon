import 'package:flutter/widgets.dart';
import 'src/models/app_icon_config.dart';
import 'src/platform_channels/app_icon_method_channel.dart';
import 'src/utils/schedule_manager.dart';

export 'src/models/app_icon_config.dart';
export 'src/platform_channels/app_icon_method_channel.dart';
export 'src/utils/schedule_manager.dart';

/// Main class for managing alternative app icons
/// 
/// Example usage:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   
///   await MasterfabricAppIcon.initialize(
///     settings: MasterfabricIconSettings(
///       icons: [
///         AppIconConfig(
///           iconName: 'icon1',
///           assetPath: 'assets/app_icons/icon1.png',
///           isDefault: true,
///         ),
///         AppIconConfig(
///           iconName: 'icon2',
///           assetPath: 'assets/app_icons/icon2.png',
///           schedule: IconSchedule(
///             startDate: DateTime(2024, 12, 20),
///             endDate: DateTime(2024, 12, 26),
///           ),
///         ),
///       ],
///       checkOnForeground: true,
///       checkOnSplash: true,
///     ),
///   );
///   
///   runApp(MyApp());
/// }
/// ```
class MasterfabricAppIcon {
  static MasterfabricAppIcon? _instance;
  static IconScheduleManager? _scheduleManager;

  final MasterfabricIconSettings settings;

  MasterfabricAppIcon._(this.settings);

  /// Initialize the app icon system
  /// 
  /// Call this in your main() function before runApp()
  static Future<MasterfabricAppIcon> initialize({
    required MasterfabricIconSettings settings,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();

    _instance = MasterfabricAppIcon._(settings);
    _scheduleManager = IconScheduleManager(settings);
    
    await _scheduleManager!.initialize();

    return _instance!;
  }

  /// Get the singleton instance
  static MasterfabricAppIcon get instance {
    if (_instance == null) {
      throw StateError(
        'MasterfabricAppIcon not initialized. Call MasterfabricAppIcon.initialize() first.',
      );
    }
    return _instance!;
  }

  /// Check if alternate icons are supported on this platform
  static Future<bool> isSupported() => AppIconMethodChannel.isSupported();

  /// Get the current active icon name
  static Future<String?> getCurrentIcon() =>
      AppIconMethodChannel.getCurrentIcon();

  /// Set the app icon to the specified icon name
  static Future<bool> setIcon(String iconName) =>
      AppIconMethodChannel.setIcon(iconName);

  /// Reset to the default/primary icon
  static Future<bool> resetToDefault() =>
      AppIconMethodChannel.resetToDefault();

  /// Get list of available icon names
  static Future<List<String>> getAvailableIcons() =>
      AppIconMethodChannel.getAvailableIcons();

  /// Manually trigger a schedule check
  static Future<void> checkSchedule() async {
    await _scheduleManager?.checkAndUpdateIcon();
  }

  /// Set a listener for icon change events
  static void onIconChanged(Function(String iconName) listener) {
    AppIconMethodChannel.setIconChangeListener(listener);
  }

  /// Dispose the app icon system
  static void dispose() {
    _scheduleManager?.dispose();
    _instance = null;
    _scheduleManager = null;
  }
}
