package com.masterfabric.app_icon

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.*
import org.json.JSONObject

class MasterfabricAppIconPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activity: Activity? = null
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.masterfabric/app_icon")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getCurrentIcon" -> getCurrentIcon(result)
            "setIcon" -> {
                val iconName = call.argument<String>("iconName")
                if (iconName != null) {
                    setIcon(iconName, result)
                } else {
                    result.error("INVALID_ARGUMENT", "iconName is required", null)
                }
            }
            "resetToDefault" -> resetToDefault(result)
            "getAvailableIcons" -> getAvailableIcons(result)
            "isSupported" -> result.success(true)
            "checkNetworkTrigger" -> {
                val url = call.argument<String>("url")
                val iconName = call.argument<String>("iconName")
                if (url != null && iconName != null) {
                    checkNetworkTrigger(url, iconName, result)
                } else {
                    result.error("INVALID_ARGUMENT", "url and iconName are required", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun getCurrentIcon(result: Result) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "Context not available", null)
            return
        }

        val packageManager = ctx.packageManager
        val packageName = ctx.packageName

        // First check if main activity is enabled (default icon)
        val mainActivityComponent = ComponentName(packageName, "$packageName.MainActivity")
        val mainState = packageManager.getComponentEnabledSetting(mainActivityComponent)
        Log.d("MasterfabricAppIcon", "getCurrentIcon: MainActivity state: $mainState")
        
        if (mainState == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
            mainState == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT) {
            // Main activity is enabled, check if icon1 alias exists and is also enabled
            // If icon1 is the default, it might be enabled too
            val aliases = getActivityAliases()
            val icon1Alias = aliases.find { it == "MainActivityIcon1" }
            if (icon1Alias != null) {
                val icon1Component = ComponentName(packageName, "$packageName.$icon1Alias")
                val icon1State = packageManager.getComponentEnabledSetting(icon1Component)
                if (icon1State == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
                    icon1State == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT) {
                    Log.d("MasterfabricAppIcon", "getCurrentIcon: icon1 alias is enabled")
                    result.success("icon1")
                    return
                }
            }
            // Main activity enabled but no icon1 alias, return default
            Log.d("MasterfabricAppIcon", "getCurrentIcon: MainActivity enabled, returning 'default'")
            result.success("default")
            return
        }

        // Get all activity aliases and check which one is enabled
        val aliases = getActivityAliases()
        Log.d("MasterfabricAppIcon", "getCurrentIcon: Checking ${aliases.size} aliases")
        
        for (alias in aliases) {
            val componentName = ComponentName(packageName, "$packageName.$alias")
            val state = packageManager.getComponentEnabledSetting(componentName)
            Log.d("MasterfabricAppIcon", "getCurrentIcon: Alias '$alias' state: $state")
            
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
                state == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT) {
                // Extract icon name from alias (e.g., "MainActivityIcon1" -> "icon1")
                val iconName = alias.replace("MainActivity", "").lowercase()
                Log.d("MasterfabricAppIcon", "getCurrentIcon: Found enabled icon: $iconName")
                result.success(iconName)
                return
            }
        }

        // No alias or main activity enabled - return icon1 as fallback if available
        if (aliases.isNotEmpty()) {
            val defaultIconName = aliases[0].replace("MainActivity", "").lowercase()
            Log.d("MasterfabricAppIcon", "getCurrentIcon: No enabled component, returning first alias: $defaultIconName")
            result.success(defaultIconName)
        } else {
            Log.w("MasterfabricAppIcon", "getCurrentIcon: No aliases found, returning 'default'")
            result.success("default")
        }
    }

    private fun setIcon(iconName: String, result: Result) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "Context not available", null)
            return
        }

        try {
            val packageManager = ctx.packageManager
            val packageName = ctx.packageName
            val aliases = getActivityAliases()

            Log.d("MasterfabricAppIcon", "Setting icon to: $iconName")
            Log.d("MasterfabricAppIcon", "Found ${aliases.size} activity aliases: $aliases")

            // Handle "default" icon name - enable main activity and disable all aliases
            if (iconName == "default") {
                // Disable all aliases
                for (alias in aliases) {
                    val componentName = ComponentName(packageName, "$packageName.$alias")
                    try {
                        packageManager.setComponentEnabledSetting(
                            componentName,
                            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                            PackageManager.DONT_KILL_APP
                        )
                    } catch (e: Exception) {
                        // Ignore errors
                    }
                }

                // Enable main activity
                val mainActivityComponent = ComponentName(packageName, "$packageName.MainActivity")
                packageManager.setComponentEnabledSetting(
                    mainActivityComponent,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )

                channel.invokeMethod("onIconChanged", "default")
                result.success(true)
                return
            }

            // Disable main activity's launcher (if using activity-alias, we want only alias to be launcher)
            val mainActivityComponent = ComponentName(packageName, "$packageName.MainActivity")
            try {
                packageManager.setComponentEnabledSetting(
                    mainActivityComponent,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
                Log.d("MasterfabricAppIcon", "Disabled main activity launcher")
            } catch (e: Exception) {
                Log.w("MasterfabricAppIcon", "Error disabling main activity: ${e.message}")
            }

            // Disable all aliases first
            for (alias in aliases) {
                val componentName = ComponentName(packageName, "$packageName.$alias")
                try {
                    val currentState = packageManager.getComponentEnabledSetting(componentName)
                    Log.d("MasterfabricAppIcon", "Disabling alias: $alias (current state: $currentState)")
                    packageManager.setComponentEnabledSetting(
                        componentName,
                        PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                        PackageManager.DONT_KILL_APP
                    )
                } catch (e: Exception) {
                    Log.w("MasterfabricAppIcon", "Error disabling alias $alias: ${e.message}")
                    // Ignore errors for non-existent components
                }
            }

            // Enable the selected alias
            // Convert "icon1" -> "MainActivityIcon1"
            // Capitalize first letter: "icon1" -> "Icon1"
            val capitalizedIconName = iconName.replaceFirstChar { 
                if (it.isLowerCase()) it.uppercaseChar() else it 
            }
            val targetAlias = "MainActivity$capitalizedIconName"
            val targetComponent = ComponentName(packageName, "$packageName.$targetAlias")
            
            Log.d("MasterfabricAppIcon", "Enabling alias: $targetAlias")
            
            try {
                packageManager.setComponentEnabledSetting(
                    targetComponent,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
                
                // Verify the change
                val newState = packageManager.getComponentEnabledSetting(targetComponent)
                Log.d("MasterfabricAppIcon", "Icon set successfully. New state: $newState")
                
                // Notify Flutter about the change
                channel.invokeMethod("onIconChanged", iconName)
                
                result.success(true)
            } catch (e: PackageManager.NameNotFoundException) {
                Log.e("MasterfabricAppIcon", "Icon alias '$targetAlias' not found in AndroidManifest.xml")
                result.error("ICON_NOT_FOUND", "Icon alias '$targetAlias' not found in AndroidManifest.xml. Available aliases: $aliases", null)
            } catch (e: Exception) {
                Log.e("MasterfabricAppIcon", "Failed to set icon: ${e.message}", e)
                result.error("SET_ICON_ERROR", "Failed to set icon: ${e.message}", null)
            }
        } catch (e: Exception) {
            Log.e("MasterfabricAppIcon", "Error in setIcon: ${e.message}", e)
            result.error("SET_ICON_ERROR", e.message, null)
        }
    }

    private fun resetToDefault(result: Result) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "Context not available", null)
            return
        }

        try {
            val packageManager = ctx.packageManager
            val packageName = ctx.packageName
            val aliases = getActivityAliases()

            // Disable all aliases
            for (alias in aliases) {
                val componentName = ComponentName(packageName, "$packageName.$alias")
                try {
                    packageManager.setComponentEnabledSetting(
                        componentName,
                        PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                        PackageManager.DONT_KILL_APP
                    )
                } catch (e: Exception) {
                    // Ignore errors
                }
            }

            // Enable main activity (default icon)
            val mainActivityComponent = ComponentName(packageName, "$packageName.MainActivity")
            packageManager.setComponentEnabledSetting(
                mainActivityComponent,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )

            channel.invokeMethod("onIconChanged", "default")
            result.success(true)
        } catch (e: Exception) {
            result.error("RESET_ERROR", e.message, null)
        }
    }

    private fun getAvailableIcons(result: Result) {
        val aliases = getActivityAliases()
        Log.d("MasterfabricAppIcon", "getAvailableIcons: Found ${aliases.size} aliases: $aliases")
        val icons = aliases.map { alias ->
            // Convert "MainActivityIcon1" -> "icon1"
            val iconName = alias.replace("MainActivity", "").lowercase()
            Log.d("MasterfabricAppIcon", "Converting alias '$alias' to icon name '$iconName'")
            iconName
        }.sorted()
        Log.d("MasterfabricAppIcon", "getAvailableIcons: Returning icons: $icons")
        result.success(icons)
    }

    private fun getActivityAliases(): List<String> {
        val ctx = context ?: return emptyList()
        val packageManager = ctx.packageManager
        val packageName = ctx.packageName
        
        val aliases = mutableListOf<String>()
        
        Log.d("MasterfabricAppIcon", "getActivityAliases: Package name: $packageName")
        
        // Method 1: Try to get all activities from package info (including disabled components)
        // This should include activity-alias entries
        try {
            val packageInfo = packageManager.getPackageInfo(
                packageName, 
                PackageManager.GET_ACTIVITIES or PackageManager.GET_DISABLED_COMPONENTS
            )
            Log.d("MasterfabricAppIcon", "Package info activities count: ${packageInfo.activities?.size ?: 0}")
            
            packageInfo.activities?.forEach { activityInfo ->
                val activityName = activityInfo.name
                Log.d("MasterfabricAppIcon", "Checking activity: $activityName")
                
                // Remove package name prefix if present
                val shortName = if (activityName.contains(".")) {
                    activityName.substringAfterLast(".")
                } else {
                    activityName
                }
                
                // Check if it's an activity alias that starts with "MainActivityIcon"
                // but is NOT "MainActivity" itself
                if (shortName.startsWith("MainActivityIcon") && 
                    shortName != "MainActivity" &&
                    !aliases.contains(shortName)) {
                    aliases.add(shortName)
                    Log.d("MasterfabricAppIcon", "Found activity alias from package info: $shortName (full: $activityName)")
                }
            }
        } catch (e: Exception) {
            Log.w("MasterfabricAppIcon", "Error getting package info: ${e.message}", e)
        }
        
        // Method 2: Direct component check - fallback if package info doesn't work
        if (aliases.isEmpty()) {
            Log.d("MasterfabricAppIcon", "Package info found nothing, trying direct component check")
            for (i in 1..10) {
                val aliasName = "MainActivityIcon$i"
                try {
                    // Try both with and without package name prefix
                    val componentName1 = ComponentName(packageName, "$packageName.$aliasName")
                    val componentName2 = ComponentName(packageName, aliasName)
                    
                    try {
                        packageManager.getActivityInfo(componentName1, PackageManager.GET_META_DATA)
                        aliases.add(aliasName)
                        Log.d("MasterfabricAppIcon", "Found activity alias via direct check (with package): $aliasName")
                        continue
                    } catch (e1: Exception) {
                        // Try without package prefix
                        try {
                            packageManager.getActivityInfo(componentName2, PackageManager.GET_META_DATA)
                            aliases.add(aliasName)
                            Log.d("MasterfabricAppIcon", "Found activity alias via direct check (without package): $aliasName")
                            continue
                        } catch (e2: Exception) {
                            // Both failed, skip
                        }
                    }
                } catch (e: Exception) {
                    Log.w("MasterfabricAppIcon", "Error checking alias $aliasName: ${e.message}")
                    continue
                }
            }
        }
        
        Log.d("MasterfabricAppIcon", "Total aliases found: ${aliases.size} - $aliases")
        return aliases.sorted()
    }

    private fun checkNetworkTrigger(url: String, iconName: String, result: Result) {
        scope.launch {
            try {
                val response = withContext(Dispatchers.IO) {
                    try {
                        val connection = URL(url).openConnection() as HttpURLConnection
                        connection.requestMethod = "GET"
                        connection.connectTimeout = 3000  // Reduced timeout to 3 seconds
                        connection.readTimeout = 3000
                        
                        val responseCode = connection.responseCode
                        if (responseCode == HttpURLConnection.HTTP_OK) {
                            val response = connection.inputStream.bufferedReader().readText()
                            val json = JSONObject(response)
                            json.optBoolean("isActive", false) &&
                                json.optString("iconName", "") == iconName
                        } else {
                            false
                        }
                    } catch (e: java.net.SocketTimeoutException) {
                        false  // Timeout - return false instead of throwing
                    } catch (e: java.net.UnknownHostException) {
                        false  // Unknown host - return false instead of throwing
                    } catch (e: Exception) {
                        false  // Any other error - return false
                    }
                }
                result.success(response)
            } catch (e: Exception) {
                result.success(false)
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scope.cancel()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}
