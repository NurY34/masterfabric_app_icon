package com.masterfabric.app_icon

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
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

        // Get all activity aliases
        val aliases = getActivityAliases()
        
        for (alias in aliases) {
            val componentName = ComponentName(packageName, "$packageName.$alias")
            val state = packageManager.getComponentEnabledSetting(componentName)
            
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
                state == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT) {
                // Extract icon name from alias (e.g., "MainActivityIcon1" -> "icon1")
                val iconName = alias.replace("MainActivity", "").lowercase()
                result.success(iconName)
                return
            }
        }

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

            // Disable all aliases first
            for (alias in aliases) {
                val componentName = ComponentName(packageName, "$packageName.$alias")
                packageManager.setComponentEnabledSetting(
                    componentName,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
            }

            // Enable the selected alias
            val targetAlias = "MainActivity${iconName.replaceFirstChar { it.uppercase() }}"
            val targetComponent = ComponentName(packageName, "$packageName.$targetAlias")
            
            packageManager.setComponentEnabledSetting(
                targetComponent,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )

            // Notify Flutter about the change
            channel.invokeMethod("onIconChanged", iconName)
            
            result.success(true)
        } catch (e: Exception) {
            result.error("SET_ICON_ERROR", e.message, null)
        }
    }

    private fun resetToDefault(result: Result) {
        setIcon("icon1", result) // Assuming icon1 is the default
    }

    private fun getAvailableIcons(result: Result) {
        val aliases = getActivityAliases()
        val icons = aliases.map { alias ->
            alias.replace("MainActivity", "").lowercase()
        }
        result.success(icons)
    }

    private fun getActivityAliases(): List<String> {
        // These should match the activity-alias names in AndroidManifest.xml
        return listOf(
            "MainActivityIcon1",
            "MainActivityIcon2",
            "MainActivityIcon3",
            "MainActivityIcon4"
        )
    }

    private fun checkNetworkTrigger(url: String, iconName: String, result: Result) {
        scope.launch {
            try {
                val response = withContext(Dispatchers.IO) {
                    val connection = URL(url).openConnection() as HttpURLConnection
                    connection.requestMethod = "GET"
                    connection.connectTimeout = 10000
                    connection.readTimeout = 10000
                    
                    val responseCode = connection.responseCode
                    if (responseCode == HttpURLConnection.HTTP_OK) {
                        val response = connection.inputStream.bufferedReader().readText()
                        val json = JSONObject(response)
                        json.optBoolean("isActive", false) &&
                            json.optString("iconName", "") == iconName
                    } else {
                        false
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
