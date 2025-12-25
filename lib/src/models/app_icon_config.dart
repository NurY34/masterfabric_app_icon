/// Configuration for alternative app icons
class AppIconConfig {
  /// Unique identifier for the icon (e.g., 'icon1', 'icon2')
  final String iconName;

  /// Path to the icon asset (e.g., 'assets/app_icons/icon1.png')
  final String assetPath;

  /// Whether this is the default/primary icon
  final bool isDefault;

  /// Optional schedule for automatic icon switching
  final IconSchedule? schedule;

  const AppIconConfig({
    required this.iconName,
    required this.assetPath,
    this.isDefault = false,
    this.schedule,
  });

  Map<String, dynamic> toJson() => {
        'iconName': iconName,
        'assetPath': assetPath,
        'isDefault': isDefault,
        'schedule': schedule?.toJson(),
      };

  factory AppIconConfig.fromJson(Map<String, dynamic> json) => AppIconConfig(
        iconName: json['iconName'] as String,
        assetPath: json['assetPath'] as String,
        isDefault: json['isDefault'] as bool? ?? false,
        schedule: json['schedule'] != null
            ? IconSchedule.fromJson(json['schedule'] as Map<String, dynamic>)
            : null,
      );
}

/// Schedule configuration for automatic icon switching
class IconSchedule {
  /// Start date for this icon to be active
  final DateTime startDate;

  /// End date for this icon to be active
  final DateTime endDate;

  /// Whether to trigger from network
  final bool networkTriggered;

  /// Remote URL for network trigger check
  final String? triggerUrl;

  const IconSchedule({
    required this.startDate,
    required this.endDate,
    this.networkTriggered = false,
    this.triggerUrl,
  });

  /// Check if the icon should be active based on current date
  bool isActiveNow() {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  Map<String, dynamic> toJson() => {
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'networkTriggered': networkTriggered,
        'triggerUrl': triggerUrl,
      };

  factory IconSchedule.fromJson(Map<String, dynamic> json) => IconSchedule(
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: DateTime.parse(json['endDate'] as String),
        networkTriggered: json['networkTriggered'] as bool? ?? false,
        triggerUrl: json['triggerUrl'] as String?,
      );
}

/// Configuration for the entire app icon system
class MasterfabricIconSettings {
  /// List of alternative icons (max 4)
  final List<AppIconConfig> icons;

  /// Whether to check schedule on app foreground
  final bool checkOnForeground;

  /// Whether to check schedule on splash screen
  final bool checkOnSplash;

  /// Interval in minutes for periodic checks
  final int checkIntervalMinutes;

  const MasterfabricIconSettings({
    required this.icons,
    this.checkOnForeground = true,
    this.checkOnSplash = true,
    this.checkIntervalMinutes = 60,
  }) : assert(icons.length <= 4, 'Maximum 4 alternative icons allowed');

  Map<String, dynamic> toJson() => {
        'icons': icons.map((e) => e.toJson()).toList(),
        'checkOnForeground': checkOnForeground,
        'checkOnSplash': checkOnSplash,
        'checkIntervalMinutes': checkIntervalMinutes,
      };
}
