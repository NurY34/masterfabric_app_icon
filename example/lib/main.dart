import 'package:flutter/material.dart';
import 'package:masterfabric_app_icon/masterfabric_app_icon.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the app icon system
  await MasterfabricAppIcon.initialize(
    settings: MasterfabricIconSettings(
      icons: [
        // Default icon
        const AppIconConfig(
          iconName: 'icon1',
          assetPath: 'assets/app_icons/icon1.png',
          isDefault: true,
        ),
        // Christmas icon - active from Dec 20-26
        AppIconConfig(
          iconName: 'icon2',
          assetPath: 'assets/app_icons/icon2.png',
          schedule: IconSchedule(
            startDate: DateTime(2024, 12, 20),
            endDate: DateTime(2024, 12, 26),
          ),
        ),
        // New Year icon - active from Dec 30 - Jan 2
        AppIconConfig(
          iconName: 'icon3',
          assetPath: 'assets/app_icons/icon3.png',
          schedule: IconSchedule(
            startDate: DateTime(2024, 12, 30),
            endDate: DateTime(2025, 1, 2),
          ),
        ),
        // Network triggered icon
        AppIconConfig(
          iconName: 'icon4',
          assetPath: 'assets/app_icons/icon4.png',
          schedule: IconSchedule(
            startDate: DateTime(2024, 1, 1),
            endDate: DateTime(2025, 12, 31),
            networkTriggered: true,
            triggerUrl: 'https://api.example.com/app-icon-config',
          ),
        ),
      ],
      checkOnForeground: true, // Check when app comes to foreground
      checkOnSplash: true, // Check during splash screen
      checkIntervalMinutes: 60, // Check every hour
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Icon Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const IconSwitcherPage(),
    );
  }
}

class IconSwitcherPage extends StatefulWidget {
  const IconSwitcherPage({super.key});

  @override
  State<IconSwitcherPage> createState() => _IconSwitcherPageState();
}

class _IconSwitcherPageState extends State<IconSwitcherPage> {
  String? _currentIcon;
  List<String> _availableIcons = [];
  bool _isSupported = false;

  @override
  void initState() {
    super.initState();
    _loadIconInfo();

    // Listen for icon changes
    MasterfabricAppIcon.onIconChanged((iconName) {
      setState(() => _currentIcon = iconName);
    });
  }

  Future<void> _loadIconInfo() async {
    final isSupported = await MasterfabricAppIcon.isSupported();
    final currentIcon = await MasterfabricAppIcon.getCurrentIcon();
    final availableIcons = await MasterfabricAppIcon.getAvailableIcons();

    setState(() {
      _isSupported = isSupported;
      _currentIcon = currentIcon;
      _availableIcons = availableIcons;
    });
  }

  Future<void> _setIcon(String iconName) async {
    try {
      await MasterfabricAppIcon.setIcon(iconName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Icon changed to $iconName'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      // Refresh icon info after successful change
      await _loadIconInfo();
    } catch (e) {
      // Extract clean error message
      String errorMessage;
      if (e is AppIconException) {
        errorMessage = e.message;
      } else {
        errorMessage = e.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), '');
      }
      
      final isSimulatorError = errorMessage.contains('iOS Simulator') || 
                               errorMessage.contains('Simulator') ||
                               errorMessage.contains('simulator');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Failed to change icon',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                errorMessage,
                style: const TextStyle(fontSize: 12),
              ),
              if (isSimulatorError) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'This is a known iOS Simulator limitation. Test on a real device for full functionality.',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  Future<void> _resetToDefault() async {
    try {
      await MasterfabricAppIcon.resetToDefault();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Icon reset to default')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reset icon: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Icon Switcher'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Icon: ${_currentIcon ?? 'Loading...'}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Alternate Icons Supported: ${_isSupported ? 'Yes' : 'No'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Available Icons:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _availableIcons.length,
                itemBuilder: (context, index) {
                  final iconName = _availableIcons[index];
                  final isSelected = iconName == _currentIcon;
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? Colors.green : null,
                    ),
                    title: Text(iconName),
                    subtitle: Text(isSelected ? 'Currently active' : 'Tap to activate'),
                    onTap: () => _setIcon(iconName),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _resetToDefault,
                icon: const Icon(Icons.restore),
                label: const Text('Reset to Default'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => MasterfabricAppIcon.checkSchedule(),
                icon: const Icon(Icons.schedule),
                label: const Text('Check Schedule Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
