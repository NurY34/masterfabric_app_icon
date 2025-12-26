import 'package:flutter/services.dart';

/// Platform channel for communicating with native code
class AppIconMethodChannel {
  static const MethodChannel _channel =
      MethodChannel('com.masterfabric/app_icon');

  /// Get the current active icon name
  static Future<String?> getCurrentIcon() async {
    try {
      final String? iconName = await _channel.invokeMethod('getCurrentIcon');
      return iconName;
    } on PlatformException catch (e) {
      throw AppIconException('Failed to get current icon: ${e.message}');
    }
  }

  /// Set the app icon to the specified icon name
  static Future<bool> setIcon(String iconName) async {
    try {
      final bool result = await _channel.invokeMethod('setIcon', {
        'iconName': iconName,
      });
      return result;
    } on PlatformException catch (e) {
      String errorMessage = e.message ?? e.code;
      
      // Extract retry count from details if available
      final retryCount = e.details is Map 
          ? (e.details as Map)['retryCount'] as int? 
          : null;
      
      if (retryCount != null && retryCount > 0) {
        errorMessage += ' (Retried $retryCount time${retryCount > 1 ? 's' : ''})';
      }
      
      // Provide helpful context for common errors
      if (errorMessage.contains('Resource temporarily unavailable') ||
          errorMessage.contains('temporarily unavailable') ||
          errorMessage.contains('iOS Simulator')) {
        // The Swift code already includes helpful simulator messages
        // Just pass it through
      }
      
      throw AppIconException(errorMessage);
    }
  }

  /// Reset to the default/primary icon
  static Future<bool> resetToDefault() async {
    try {
      final bool result = await _channel.invokeMethod('resetToDefault');
      return result;
    } on PlatformException catch (e) {
      throw AppIconException('Failed to reset icon: ${e.message}');
    }
  }

  /// Get list of available icon names
  static Future<List<String>> getAvailableIcons() async {
    try {
      final List<dynamic> icons =
          await _channel.invokeMethod('getAvailableIcons');
      return icons.cast<String>();
    } on PlatformException catch (e) {
      throw AppIconException('Failed to get available icons: ${e.message}');
    }
  }

  /// Check if alternate icons are supported on this platform
  static Future<bool> isSupported() async {
    try {
      final bool supported = await _channel.invokeMethod('isSupported');
      return supported;
    } on PlatformException {
      return false;
    }
  }

  /// Set up listener for icon change events
  static void setIconChangeListener(Function(String iconName) onIconChanged) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onIconChanged') {
        final iconName = call.arguments as String;
        onIconChanged(iconName);
      }
    });
  }
}

/// Exception for app icon operations
class AppIconException implements Exception {
  final String message;
  AppIconException(this.message);

  @override
  String toString() => 'AppIconException: $message';
}
