import 'dart:async';
import 'package:flutter/widgets.dart';
import '../models/app_icon_config.dart';
import '../platform_channels/app_icon_method_channel.dart';
import 'package:flutter/services.dart';

/// Manages automatic icon switching based on schedules and network triggers
class IconScheduleManager {
  final MasterfabricIconSettings settings;
  Timer? _periodicTimer;
  bool _isInitialized = false;

  IconScheduleManager(this.settings);

  /// Initialize the schedule manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isInitialized = true;

    // Set up periodic checks
    if (settings.checkIntervalMinutes > 0) {
      _periodicTimer = Timer.periodic(
        Duration(minutes: settings.checkIntervalMinutes),
        (_) => checkAndUpdateIcon(),
      );
    }

    // Set up foreground listener
    if (settings.checkOnForeground) {
      WidgetsBinding.instance.addObserver(_AppLifecycleObserver(this));
    }

    // Check on initialization - but don't block if checkOnSplash is false
    // If checkOnSplash is true, still run it but make network calls non-blocking
    if (settings.checkOnSplash) {
      // Run check in background to avoid blocking app startup
      checkAndUpdateIcon().catchError((e) {
        debugPrint('Icon check during initialization failed: $e');
      });
    }
  }

  /// Check schedule and network triggers, update icon if needed
  Future<void> checkAndUpdateIcon() async {
    // Check if alternate icons are supported
    final isSupported = await AppIconMethodChannel.isSupported();
    if (!isSupported) {
      debugPrint('Alternate icons not supported on this platform');
      return;
    }

    final availableIcons = await AppIconMethodChannel.getAvailableIcons();

    // First check network triggers
    for (final icon in settings.icons) {
      if (icon.schedule?.networkTriggered == true &&
          icon.schedule?.triggerUrl != null) {
        final shouldActivate = await _checkNetworkTrigger(icon);
        if (shouldActivate) {
          // Only set icon if it's available (skip if missing from Info.plist)
          if (availableIcons.contains(icon.iconName)) {
            await AppIconMethodChannel.setIcon(icon.iconName);
          } else {
            debugPrint('Skipping icon "${icon.iconName}": not available on this platform');
          }
          return;
        }
      }
    }

    // Then check date-based schedules
    for (final icon in settings.icons) {
      if (icon.schedule?.isActiveNow() == true) {
        final currentIcon = await AppIconMethodChannel.getCurrentIcon();
        if (currentIcon != icon.iconName) {
          // Only set icon if it's available (skip if missing from Info.plist)
          if (availableIcons.contains(icon.iconName)) {
            await AppIconMethodChannel.setIcon(icon.iconName);
          } else {
            debugPrint('Skipping icon "${icon.iconName}": not available on this platform');
          }
        }
        return;
      }
    }

    // If no schedule is active, reset to default
    final defaultIcon = settings.icons.where((i) => i.isDefault).firstOrNull;
    if (defaultIcon != null) {
      final currentIcon = await AppIconMethodChannel.getCurrentIcon();
      // Check if we need to switch to default icon
      if (currentIcon != defaultIcon.iconName && currentIcon != 'default') {
        // If default icon is in available icons (e.g., icon1), use setIcon
        // Otherwise use resetToDefault() for main activity icon
        if (availableIcons.contains(defaultIcon.iconName)) {
          await AppIconMethodChannel.setIcon(defaultIcon.iconName);
        } else {
          await AppIconMethodChannel.resetToDefault();
        }
      }
    }
  }

  /// Check network trigger for an icon
  Future<bool> _checkNetworkTrigger(AppIconConfig icon) async {
    if (icon.schedule?.triggerUrl == null) return false;

    try {
      // Use platform channel to make network request with timeout
      final result = await const MethodChannel('com.masterfabric/app_icon')
          .invokeMethod<bool>('checkNetworkTrigger', {
        'url': icon.schedule!.triggerUrl,
        'iconName': icon.iconName,
      }).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('Network trigger check timed out');
          return false;
        },
      );
      return result ?? false;
    } catch (e) {
      debugPrint('Network trigger check failed: $e');
      return false;
    }
  }

  /// Dispose the schedule manager
  void dispose() {
    _periodicTimer?.cancel();
    _isInitialized = false;
  }
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  final IconScheduleManager manager;

  _AppLifecycleObserver(this.manager);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      manager.checkAndUpdateIcon();
    }
  }
}

/// Network trigger response model
class NetworkTriggerResponse {
  final String iconName;
  final DateTime? activeFrom;
  final DateTime? activeTo;
  final bool isActive;

  NetworkTriggerResponse({
    required this.iconName,
    this.activeFrom,
    this.activeTo,
    required this.isActive,
  });

  factory NetworkTriggerResponse.fromJson(Map<String, dynamic> json) {
    return NetworkTriggerResponse(
      iconName: json['iconName'] as String,
      activeFrom: json['activeFrom'] != null
          ? DateTime.parse(json['activeFrom'] as String)
          : null,
      activeTo: json['activeTo'] != null
          ? DateTime.parse(json['activeTo'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? false,
    );
  }
}
