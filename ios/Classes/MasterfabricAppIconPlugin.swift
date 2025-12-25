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
        
        UIApplication.shared.setAlternateIconName(targetIcon) { [weak self] error in
            if let error = error {
                result(FlutterError(code: "SET_ICON_ERROR", message: error.localizedDescription, details: nil))
            } else {
                // Notify Flutter about the change
                self?.channel?.invokeMethod("onIconChanged", arguments: iconName)
                result(true)
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
