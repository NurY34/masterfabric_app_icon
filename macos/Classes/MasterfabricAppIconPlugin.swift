import Cocoa
import FlutterMacOS

public class MasterfabricAppIconPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?
    private var currentIconName: String = "default"
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.masterfabric/app_icon",
            binaryMessenger: registrar.messenger
        )
        let instance = MasterfabricAppIconPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getCurrentIcon":
            result(currentIconName)
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
            result(true) // macOS supports icon changes via NSApplication
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
    
    private func setIcon(iconName: String, result: @escaping FlutterResult) {
        // For macOS, we change the dock icon
        let assetName = "AppIcon-\(iconName)"
        
        if let image = NSImage(named: assetName) {
            NSApplication.shared.applicationIconImage = image
            currentIconName = iconName
            channel?.invokeMethod("onIconChanged", arguments: iconName)
            result(true)
        } else if iconName == "default" {
            // Reset to default icon
            NSApplication.shared.applicationIconImage = nil
            currentIconName = "default"
            channel?.invokeMethod("onIconChanged", arguments: iconName)
            result(true)
        } else {
            result(FlutterError(code: "ICON_NOT_FOUND", message: "Icon not found: \(assetName)", details: nil))
        }
    }
    
    private func resetToDefault(result: @escaping FlutterResult) {
        NSApplication.shared.applicationIconImage = nil
        currentIconName = "default"
        channel?.invokeMethod("onIconChanged", arguments: "default")
        result(true)
    }
    
    private func getAvailableIcons(result: @escaping FlutterResult) {
        // Return available icons from Assets.xcassets
        // This would typically be configured during build time
        result(["icon1", "icon2", "icon3", "icon4"])
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
