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
    
    private fun ensureSingleLauncher() {
        val ctx = context ?: return
        val packageManager = ctx.packageManager
        val packageName = ctx.packageName
        val mainActivityComponent = ComponentName(packageName, "$packageName.MainActivity")
        
        try {
            val aliases = getActivityAliases()
            Log.d("MasterfabricAppIcon", "ensureSingleLauncher: Checking MainActivity and ${aliases.size} aliases")
            
            // Check MainActivity state
            val mainActivityState = packageManager.getComponentEnabledSetting(mainActivityComponent)
            val isMainActivityEnabled = mainActivityState == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
                                        mainActivityState == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
            Log.d("MasterfabricAppIcon", "ensureSingleLauncher: MainActivity state: $mainActivityState, enabled: $isMainActivityEnabled")
            
            // Check which aliases are enabled
            val enabledAliases = mutableListOf<String>()
            for (alias in aliases) {
                val aliasComponent = ComponentName(packageName, "$packageName.$alias")
                val aliasState = packageManager.getComponentEnabledSetting(aliasComponent)
                Log.d("MasterfabricAppIcon", "ensureSingleLauncher: Alias $alias state: $aliasState")
                if (aliasState == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                    enabledAliases.add(alias)
                }
            }
            
            Log.d("MasterfabricAppIcon", "ensureSingleLauncher: Found ${enabledAliases.size} enabled aliases: $enabledAliases")
            
            // If both MainActivity and some aliases are enabled, disable the aliases
            if (isMainActivityEnabled && enabledAliases.isNotEmpty()) {
                Log.w("MasterfabricAppIcon", "Both MainActivity and aliases enabled! Disabling all aliases.")
                for (alias in enabledAliases) {
                    val componentToDisable = ComponentName(packageName, "$packageName.$alias")
                    try {
                        packageManager.setComponentEnabledSetting(
                            componentToDisable,
                            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                            PackageManager.DONT_KILL_APP
                        )
                        Log.d("MasterfabricAppIcon", "Disabled alias: $alias")
                    } catch (e: Exception) {
                        Log.w("MasterfabricAppIcon", "Error disabling alias $alias: ${e.message}")
                    }
                }
                return
            }
            
            // If MainActivity is disabled but multiple aliases are enabled, keep only first one
            if (!isMainActivityEnabled && enabledAliases.size > 1) {
                Log.w("MasterfabricAppIcon", "Multiple aliases enabled! Disabling all except the first one.")
                for (i in 1 until enabledAliases.size) {
                    val aliasToDisable = enabledAliases[i]
                    val componentToDisable = ComponentName(packageName, "$packageName.$aliasToDisable")
                    try {
                        packageManager.setComponentEnabledSetting(
                            componentToDisable,
                            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                            PackageManager.DONT_KILL_APP
                        )
                        Log.d("MasterfabricAppIcon", "Disabled duplicate alias: $aliasToDisable")
                    } catch (e: Exception) {
                        Log.w("MasterfabricAppIcon", "Error disabling alias $aliasToDisable: ${e.message}")
                    }
                }
                return
            }
            
            // If nothing is enabled (shouldn't happen normally), enable MainActivity
            if (!isMainActivityEnabled && enabledAliases.isEmpty()) {
                Log.w("MasterfabricAppIcon", "Nothing enabled! Enabling MainActivity.")
                try {
                    packageManager.setComponentEnabledSetting(
                        mainActivityComponent,
                        PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                        PackageManager.DONT_KILL_APP
                    )
                    Log.d("MasterfabricAppIcon", "Enabled MainActivity as fallback")
                } catch (e: Exception) {
                    Log.w("MasterfabricAppIcon", "Error enabling MainActivity: ${e.message}")
                }
            }
        } catch (e: Exception) {
            Log.w("MasterfabricAppIcon", "Error ensuring single launcher: ${e.message}", e)
        }
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
        val mainActivityComponent = ComponentName(packageName, "$packageName.MainActivity")

        // First check if MainActivity is enabled (default state)
        val mainActivityState = packageManager.getComponentEnabledSetting(mainActivityComponent)
        Log.d("MasterfabricAppIcon", "getCurrentIcon: MainActivity state: $mainActivityState")
        
        if (mainActivityState == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
            mainActivityState == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT) {
            // MainActivity is enabled, this is the default icon
            Log.d("MasterfabricAppIcon", "getCurrentIcon: MainActivity enabled, returning 'default'")
            result.success("default")
            return
        }

        // MainActivity is disabled, check which activity-alias is enabled
        val aliases = getActivityAliases()
        Log.d("MasterfabricAppIcon", "getCurrentIcon: Checking ${aliases.size} aliases")
        
        for (alias in aliases) {
            val componentName = ComponentName(packageName, "$packageName.$alias")
            val state = packageManager.getComponentEnabledSetting(componentName)
            Log.d("MasterfabricAppIcon", "getCurrentIcon: Alias '$alias' state: $state")
            
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                // Extract icon name from alias (e.g., "MainActivityIcon1" -> "icon1")
                val iconName = alias.replace("MainActivity", "").lowercase()
                Log.d("MasterfabricAppIcon", "getCurrentIcon: Found enabled icon: $iconName")
                result.success(iconName)
                return
            }
        }

        // No alias enabled - return default
        Log.d("MasterfabricAppIcon", "getCurrentIcon: No enabled alias, returning 'default'")
        result.success("default")
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
            val mainActivityComponent = ComponentName(packageName, "$packageName.MainActivity")

            Log.d("MasterfabricAppIcon", "Setting icon to: $iconName")
            Log.d("MasterfabricAppIcon", "Found ${aliases.size} activity aliases: $aliases")

            // Handle "default" icon name - enable MainActivity and disable all aliases
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
                
                // Enable MainActivity (default launcher)
                packageManager.setComponentEnabledSetting(
                    mainActivityComponent,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
                Log.d("MasterfabricAppIcon", "Set default icon - enabled MainActivity")

                channel.invokeMethod("onIconChanged", "default")
                result.success(true)
                return
            }

            // Disable MainActivity launcher first
            try {
                packageManager.setComponentEnabledSetting(
                    mainActivityComponent,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
                Log.d("MasterfabricAppIcon", "Disabled MainActivity launcher")
            } catch (e: Exception) {
                Log.w("MasterfabricAppIcon", "Error disabling MainActivity: ${e.message}")
            }

            // Disable all aliases
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
                }
            }

            // Enable the selected alias
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
                
                val newState = packageManager.getComponentEnabledSetting(targetComponent)
                Log.d("MasterfabricAppIcon", "Icon set successfully. New state: $newState")
                
                channel.invokeMethod("onIconChanged", iconName)
                result.success(true)
            } catch (e: PackageManager.NameNotFoundException) {
                // Re-enable MainActivity if alias not found
                packageManager.setComponentEnabledSetting(
                    mainActivityComponent,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
                Log.e("MasterfabricAppIcon", "Icon alias '$targetAlias' not found in AndroidManifest.xml")
                result.error("ICON_NOT_FOUND", "Icon alias '$targetAlias' not found. Available: $aliases", null)
            } catch (e: Exception) {
                // Re-enable MainActivity on error
                packageManager.setComponentEnabledSetting(
                    mainActivityComponent,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
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
            val mainActivityComponent = ComponentName(packageName, "$packageName.MainActivity")

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
            
            // Enable MainActivity (default launcher)
            packageManager.setComponentEnabledSetting(
                mainActivityComponent,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
            Log.d("MasterfabricAppIcon", "Reset to default - enabled MainActivity")

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
        
        // MainActivity is enabled and has LAUNCHER intent-filter (for Flutter to launch)
        // But we need to ensure only activity-alias'lar are visible as launchers
        // We can't disable MainActivity because activity-alias'lar target it
        // Instead, we ensure only one activity-alias is enabled at a time
        scope.launch {
            delay(1000) // Wait for app to fully start
            ensureSingleLauncher()
        }
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
