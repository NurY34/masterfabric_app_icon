import Flutter
import UIKit

public class MasterfabricAppIconPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.masterfabric/app_icon",
            binaryMessenger: registrar.messenger()
        )
        let instance = MasterfabricAppIconPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getCurrentIcon":
            getCurrentIcon(result: result)
        case "setIcon":
            if let args = call.arguments as? [String: Any],
               let iconName = args["iconName"] as? String {
                setIcon(iconName: iconName, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "iconName is required", details: nil))
            }
        case "resetToDefault":
            resetToDefault(result: result)
        case "getAvailableIcons":
            getAvailableIcons(result: result)
        case "isSupported":
            result(UIApplication.shared.supportsAlternateIcons)
        case "checkNetworkTrigger":
            if let args = call.arguments as? [String: Any],
               let url = args["url"] as? String,
               let iconName = args["iconName"] as? String {
                checkNetworkTrigger(url: url, iconName: iconName, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "url and iconName are required", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func getCurrentIcon(result: @escaping FlutterResult) {
        if let iconName = UIApplication.shared.alternateIconName {
            result(iconName)
        } else {
            result("default")
        }
    }
    
    private func setIcon(iconName: String, result: @escaping FlutterResult) {
        guard UIApplication.shared.supportsAlternateIcons else {
            result(FlutterError(code: "NOT_SUPPORTED", message: "Alternate icons not supported", details: nil))
            return
        }
        
        let targetIcon: String? = iconName == "default" ? nil : iconName
        
        // Ensure we're on the main thread and give it a moment
        DispatchQueue.main.async {
            // Small delay to ensure UI is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                #if targetEnvironment(simulator)
                // In simulator, use more aggressive retry (10 attempts)
                self._setIconWithRetry(iconName: targetIcon, result: result, retryCount: 0, maxRetries: 10, isSimulator: true)
                #else
                // On real device, use standard retry (5 attempts)
                self._setIconWithRetry(iconName: targetIcon, result: result, retryCount: 0, maxRetries: 5, isSimulator: false)
                #endif
            }
        }
    }
    
    private func _setIconWithRetry(iconName: String?, result: @escaping FlutterResult, retryCount: Int, maxRetries: Int, isSimulator: Bool) {
        // Ensure we're on main thread and app is active
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self._setIconWithRetry(iconName: iconName, result: result, retryCount: retryCount, maxRetries: maxRetries, isSimulator: isSimulator)
            }
            return
        }
        
        // Try to set icon with a small delay to avoid resource conflicts
        let attemptDelay = retryCount > 0 ? Double(retryCount) * 0.5 : 0.1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + attemptDelay) {
            // Verify app is in foreground
            guard UIApplication.shared.applicationState == .active else {
                // Wait a bit more if app is not active
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self._setIconWithRetry(iconName: iconName, result: result, retryCount: retryCount, maxRetries: maxRetries, isSimulator: isSimulator)
                }
                return
            }
            
            UIApplication.shared.setAlternateIconName(iconName) { [weak self] error in
                if let error = error {
                    let nsError = error as NSError
                    let errorCode = nsError.code
                    let errorDomain = nsError.domain
                    let errorDescription = error.localizedDescription
                    
                    // Check if it's a "Resource temporarily unavailable" error or similar
                    let isResourceUnavailable = errorCode == 11 || 
                                              errorDomain == NSPOSIXErrorDomain ||
                                              errorDescription.contains("Resource temporarily unavailable") ||
                                              errorDescription.contains("temporarily unavailable") ||
                                              errorDescription.contains("couldn't be completed")
                    
                    // Retry for recoverable errors
                    if isResourceUnavailable && retryCount < maxRetries {
                        // Progressive backoff: 0.5s, 1s, 1.5s, 2s, etc.
                        let delay = Double(retryCount + 1) * 0.5
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self?._setIconWithRetry(iconName: iconName, result: result, retryCount: retryCount + 1, maxRetries: maxRetries, isSimulator: isSimulator)
                        }
                        return
                    }
                    
                    // If we're in simulator and exhausted retries, try one more aggressive approach
                    #if targetEnvironment(simulator)
                    if isSimulator && retryCount >= maxRetries - 1 {
                        // Last attempt: wait longer and try once more with app activation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            // Force app to foreground if needed
                            if UIApplication.shared.applicationState != .active {
                                // Try to activate
                            }
                            
                            UIApplication.shared.setAlternateIconName(iconName) { [weak self] finalError in
                                if finalError == nil {
                                    // Success on last attempt
                                    let displayName = iconName ?? "default"
                                    self?.channel?.invokeMethod("onIconChanged", arguments: displayName)
                                    result(true)
                                } else {
                                    // Final failure - but in simulator we might still report success for testing
                                    // The icon won't actually change in simulator, but at least the API call succeeded
                                    let finalNsError = finalError as NSError
                                    let finalErrorDesc = finalError?.localizedDescription ?? "Unknown error"
                                    
                                    // In simulator, if it's a resource error, we'll report it but note the limitation
                                    result(FlutterError(
                                        code: "SET_ICON_ERROR", 
                                        message: "Failed after \(maxRetries + 1) attempts: \(finalErrorDesc)\n\n⚠️ iOS Simulator Limitation: Alternate icons do not work in iOS Simulator. This is a known iOS limitation. The icon change will work on a real iOS device.", 
                                        details: ["domain": finalNsError.domain, "code": finalNsError.code, "retryCount": retryCount + 1, "simulator": true]
                                    ))
                                }
                            }
                        }
                        return
                    }
                    #endif
                    
                    // Report error
                    result(FlutterError(
                        code: "SET_ICON_ERROR", 
                        message: errorDescription, 
                        details: ["domain": errorDomain, "code": errorCode, "retryCount": retryCount]
                    ))
                } else {
                    // Success - notify Flutter about the change
                    let displayName = iconName ?? "default"
                    self?.channel?.invokeMethod("onIconChanged", arguments: displayName)
                    result(true)
                }
            }
        }
    }
    
    private func resetToDefault(result: @escaping FlutterResult) {
        setIcon(iconName: "default", result: result)
    }
    
    private func getAvailableIcons(result: @escaping FlutterResult) {
        // Read from Info.plist CFBundleAlternateIcons
        if let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
           let alternateIcons = icons["CFBundleAlternateIcons"] as? [String: Any] {
            let iconNames = Array(alternateIcons.keys)
            result(iconNames)
        } else {
            result([String]())
        }
    }
    
    private func checkNetworkTrigger(url: String, iconName: String, result: @escaping FlutterResult) {
        guard let requestUrl = URL(string: url) else {
            result(false)
            return
        }
        
        let task = URLSession.shared.dataTask(with: requestUrl) { data, response, error in
            DispatchQueue.main.async {
                guard error == nil,
                      let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let isActive = json["isActive"] as? Bool,
                      let responseIconName = json["iconName"] as? String else {
                    result(false)
                    return
                }
                
                result(isActive && responseIconName == iconName)
            }
        }
        task.resume()
    }
}
