import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

// #region agent log
void _debugLog(String location, String message, Map<String, dynamic> data) {
  try {
    final logEntry = jsonEncode({
      'location': 'app_icon_method_channel.dart:$location',
      'message': message,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'sessionId': 'debug-session',
    });
    final file = File('/Users/ticimax/Documents/ticimax/masterfabric_app_icon/.cursor/debug.log');
    file.writeAsStringSync('$logEntry\n', mode: FileMode.append);
  } catch (e) {
    // Ignore logging errors
  }
}
// #endregion

/// Platform channel for communicating with native code
class AppIconMethodChannel {
  static const MethodChannel _channel =
      MethodChannel('com.masterfabric/app_icon');

  /// Get the current active icon name
  static Future<String?> getCurrentIcon() async {
    try {
      final String? iconName = await _channel.invokeMethod('getCurrentIcon');
      // #region agent log
      _debugLog('getCurrentIcon', 'Got current icon', {'iconName': iconName, 'hypothesisId': 'B'});
      // #endregion
      return iconName;
    } on PlatformException catch (e) {
      // #region agent log
      _debugLog('getCurrentIcon', 'Error getting current icon', {'error': e.message, 'hypothesisId': 'B'});
      // #endregion
      throw AppIconException('Failed to get current icon: ${e.message}');
    }
  }

  /// Set the app icon to the specified icon name
  static Future<bool> setIcon(String iconName) async {
    // #region agent log
    _debugLog('setIcon', 'Starting setIcon', {'iconName': iconName, 'hypothesisId': 'A'});
    // #endregion
    try {
      final bool result = await _channel.invokeMethod('setIcon', {
        'iconName': iconName,
      });
      // #region agent log
      _debugLog('setIcon', 'setIcon completed', {'iconName': iconName, 'result': result, 'hypothesisId': 'A'});
      // #endregion
      return result;
    } on PlatformException catch (e) {
      // #region agent log
      _debugLog('setIcon', 'setIcon FAILED', {'iconName': iconName, 'error': e.message, 'code': e.code, 'hypothesisId': 'A'});
      // #endregion
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
      final result = icons.cast<String>();
      // #region agent log
      _debugLog('getAvailableIcons', 'Got available icons', {'icons': result, 'count': result.length, 'hypothesisId': 'C'});
      // #endregion
      return result;
    } on PlatformException catch (e) {
      // #region agent log
      _debugLog('getAvailableIcons', 'Error getting icons', {'error': e.message, 'hypothesisId': 'C'});
      // #endregion
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
