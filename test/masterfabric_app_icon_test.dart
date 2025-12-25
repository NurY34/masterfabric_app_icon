import 'package:flutter_test/flutter_test.dart';
import 'package:masterfabric_app_icon/masterfabric_app_icon.dart';

void main() {
  group('AppIconConfig', () {
    test('creates config with required parameters', () {
      const config = AppIconConfig(
        iconName: 'icon1',
        assetPath: 'assets/app_icons/icon1.png',
      );

      expect(config.iconName, 'icon1');
      expect(config.assetPath, 'assets/app_icons/icon1.png');
      expect(config.isDefault, false);
      expect(config.schedule, null);
    });

    test('creates config with all parameters', () {
      final config = AppIconConfig(
        iconName: 'icon2',
        assetPath: 'assets/app_icons/icon2.png',
        isDefault: true,
        schedule: IconSchedule(
          startDate: DateTime(2024, 12, 20),
          endDate: DateTime(2024, 12, 26),
        ),
      );

      expect(config.iconName, 'icon2');
      expect(config.isDefault, true);
      expect(config.schedule, isNotNull);
    });

    test('toJson and fromJson roundtrip', () {
      const config = AppIconConfig(
        iconName: 'icon1',
        assetPath: 'assets/app_icons/icon1.png',
        isDefault: true,
      );

      final json = config.toJson();
      final restored = AppIconConfig.fromJson(json);

      expect(restored.iconName, config.iconName);
      expect(restored.assetPath, config.assetPath);
      expect(restored.isDefault, config.isDefault);
    });
  });

  group('IconSchedule', () {
    test('isActiveNow returns true when within date range', () {
      final schedule = IconSchedule(
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 1)),
      );

      expect(schedule.isActiveNow(), true);
    });

    test('isActiveNow returns false when outside date range', () {
      final schedule = IconSchedule(
        startDate: DateTime.now().add(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 2)),
      );

      expect(schedule.isActiveNow(), false);
    });

    test('toJson and fromJson roundtrip', () {
      final schedule = IconSchedule(
        startDate: DateTime(2024, 12, 20),
        endDate: DateTime(2024, 12, 26),
        networkTriggered: true,
        triggerUrl: 'https://api.example.com',
      );

      final json = schedule.toJson();
      final restored = IconSchedule.fromJson(json);

      expect(restored.networkTriggered, schedule.networkTriggered);
      expect(restored.triggerUrl, schedule.triggerUrl);
    });
  });

  group('MasterfabricIconSettings', () {
    test('creates settings with icons', () {
      final settings = MasterfabricIconSettings(
        icons: const [
          AppIconConfig(
            iconName: 'icon1',
            assetPath: 'assets/app_icons/icon1.png',
            isDefault: true,
          ),
          AppIconConfig(
            iconName: 'icon2',
            assetPath: 'assets/app_icons/icon2.png',
          ),
        ],
      );

      expect(settings.icons.length, 2);
      expect(settings.checkOnForeground, true);
      expect(settings.checkOnSplash, true);
      expect(settings.checkIntervalMinutes, 60);
    });

    test('throws assertion error when more than 4 icons', () {
      expect(
        () => MasterfabricIconSettings(
          icons: List.generate(
            5,
            (i) => AppIconConfig(
              iconName: 'icon$i',
              assetPath: 'assets/app_icons/icon$i.png',
            ),
          ),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
