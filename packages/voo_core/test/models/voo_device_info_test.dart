import 'package:flutter_test/flutter_test.dart';
import 'package:voo_core/voo_core.dart';

void main() {
  group('VooDeviceInfo', () {
    VooDeviceInfo createTestDeviceInfo({
      String deviceId = 'test-device-id',
      String deviceModel = 'Test Model',
      String manufacturer = 'Test Manufacturer',
      String osName = 'TestOS',
      String osVersion = '1.0.0',
      String locale = 'en_US',
      String timezone = 'America/New_York',
      String appVersion = '1.0.0',
      String buildNumber = '1',
      String packageName = 'com.test.app',
      bool isPhysicalDevice = true,
    }) {
      return VooDeviceInfo(
        deviceId: deviceId,
        deviceModel: deviceModel,
        manufacturer: manufacturer,
        osName: osName,
        osVersion: osVersion,
        locale: locale,
        timezone: timezone,
        appVersion: appVersion,
        buildNumber: buildNumber,
        packageName: packageName,
        isPhysicalDevice: isPhysicalDevice,
      );
    }

    test('should create device info with required fields', () {
      final info = createTestDeviceInfo();

      expect(info.deviceId, 'test-device-id');
      expect(info.deviceModel, 'Test Model');
      expect(info.manufacturer, 'Test Manufacturer');
      expect(info.osName, 'TestOS');
      expect(info.osVersion, '1.0.0');
      expect(info.locale, 'en_US');
      expect(info.timezone, 'America/New_York');
      expect(info.appVersion, '1.0.0');
      expect(info.buildNumber, '1');
      expect(info.packageName, 'com.test.app');
      expect(info.isPhysicalDevice, true);
    });

    test('should create device info with optional web fields', () {
      final info = VooDeviceInfo(
        deviceId: 'web-device-id',
        deviceModel: 'Web',
        manufacturer: 'Google',
        osName: 'Web',
        osVersion: 'Chrome 120',
        locale: 'en_US',
        timezone: 'UTC',
        appVersion: '1.0.0',
        buildNumber: '1',
        packageName: 'com.test.app',
        isPhysicalDevice: true,
        userAgent: 'Mozilla/5.0 ...',
        browserName: 'Chrome',
        browserVersion: '120.0',
      );

      expect(info.userAgent, 'Mozilla/5.0 ...');
      expect(info.browserName, 'Chrome');
      expect(info.browserVersion, '120.0');
    });

    test('should create device info with additional info', () {
      final info = VooDeviceInfo(
        deviceId: 'test-device-id',
        deviceModel: 'Test Model',
        manufacturer: 'Test',
        osName: 'Android',
        osVersion: '14',
        locale: 'en_US',
        timezone: 'UTC',
        appVersion: '1.0.0',
        buildNumber: '1',
        packageName: 'com.test.app',
        isPhysicalDevice: true,
        additionalInfo: {
          'androidSdkInt': 34,
          'androidBrand': 'Google',
        },
      );

      expect(info.additionalInfo['androidSdkInt'], 34);
      expect(info.additionalInfo['androidBrand'], 'Google');
    });

    test('should convert to JSON correctly', () {
      final info = createTestDeviceInfo();
      final json = info.toJson();

      expect(json['deviceId'], 'test-device-id');
      expect(json['deviceModel'], 'Test Model');
      expect(json['manufacturer'], 'Test Manufacturer');
      expect(json['osName'], 'TestOS');
      expect(json['osVersion'], '1.0.0');
      expect(json['locale'], 'en_US');
      expect(json['timezone'], 'America/New_York');
      expect(json['appVersion'], '1.0.0');
      expect(json['buildNumber'], '1');
      expect(json['packageName'], 'com.test.app');
      expect(json['isPhysicalDevice'], true);
    });

    test('should exclude null optional fields from JSON', () {
      final info = createTestDeviceInfo();
      final json = info.toJson();

      expect(json.containsKey('screenWidth'), false);
      expect(json.containsKey('screenHeight'), false);
      expect(json.containsKey('userAgent'), false);
      expect(json.containsKey('browserName'), false);
    });

    test('should include optional fields in JSON when present', () {
      final info = VooDeviceInfo(
        deviceId: 'test-device-id',
        deviceModel: 'Test Model',
        manufacturer: 'Test',
        osName: 'TestOS',
        osVersion: '1.0.0',
        screenWidth: '1920',
        screenHeight: '1080',
        locale: 'en_US',
        timezone: 'UTC',
        appVersion: '1.0.0',
        buildNumber: '1',
        packageName: 'com.test.app',
        isPhysicalDevice: true,
      );

      final json = info.toJson();

      expect(json['screenWidth'], '1920');
      expect(json['screenHeight'], '1080');
    });

    test('should generate sync payload with essential fields', () {
      final info = createTestDeviceInfo();
      final payload = info.toSyncPayload();

      expect(payload['deviceId'], 'test-device-id');
      expect(payload['deviceModel'], 'Test Model');
      expect(payload['platform'], 'TestOS');
      expect(payload['osVersion'], '1.0.0');
      expect(payload['appVersion'], '1.0.0');
      expect(payload['buildNumber'], '1');
      expect(payload['locale'], 'en_US');
      expect(payload['timezone'], 'America/New_York');
      expect(payload['isPhysicalDevice'], true);
    });

    test('should generate analytics tags in snake_case', () {
      final info = createTestDeviceInfo();
      final tags = info.toAnalyticsTags();

      expect(tags['device_id'], 'test-device-id');
      expect(tags['device_model'], 'Test Model');
      expect(tags['manufacturer'], 'Test Manufacturer');
      expect(tags['os_name'], 'TestOS');
      expect(tags['os_version'], '1.0.0');
      expect(tags['locale'], 'en_US');
      expect(tags['timezone'], 'America/New_York');
      expect(tags['app_version'], '1.0.0');
      expect(tags['build_number'], '1');
      expect(tags['is_physical_device'], 'true');
    });

    test('should restore from JSON correctly', () {
      final original = createTestDeviceInfo();
      final json = original.toJson();
      final restored = VooDeviceInfo.fromJson(json);

      expect(restored.deviceId, original.deviceId);
      expect(restored.deviceModel, original.deviceModel);
      expect(restored.manufacturer, original.manufacturer);
      expect(restored.osName, original.osName);
      expect(restored.osVersion, original.osVersion);
      expect(restored.locale, original.locale);
      expect(restored.timezone, original.timezone);
      expect(restored.appVersion, original.appVersion);
      expect(restored.buildNumber, original.buildNumber);
      expect(restored.packageName, original.packageName);
      expect(restored.isPhysicalDevice, original.isPhysicalDevice);
    });

    test('should handle missing fields in fromJson with defaults', () {
      final info = VooDeviceInfo.fromJson({});

      expect(info.deviceId, 'unknown');
      expect(info.deviceModel, 'unknown');
      expect(info.manufacturer, 'unknown');
      expect(info.osName, 'unknown');
      expect(info.osVersion, 'unknown');
      expect(info.locale, 'en');
      expect(info.timezone, 'UTC');
      expect(info.appVersion, '1.0.0');
      expect(info.buildNumber, '1');
      expect(info.packageName, 'unknown');
      expect(info.isPhysicalDevice, true);
    });

    test('should support copyWith', () {
      final original = createTestDeviceInfo();
      final modified = original.copyWith(
        osVersion: '2.0.0',
        appVersion: '2.0.0',
      );

      expect(modified.deviceId, original.deviceId);
      expect(modified.deviceModel, original.deviceModel);
      expect(modified.osVersion, '2.0.0');
      expect(modified.appVersion, '2.0.0');
    });

    test('should implement equality correctly', () {
      final info1 = createTestDeviceInfo();
      final info2 = createTestDeviceInfo();
      final info3 = createTestDeviceInfo(deviceId: 'different-id');

      expect(info1, equals(info2));
      expect(info1, isNot(equals(info3)));
      expect(info1.hashCode, equals(info2.hashCode));
    });

    test('should have meaningful toString', () {
      final info = createTestDeviceInfo();
      final str = info.toString();

      expect(str, contains('VooDeviceInfo'));
      expect(str, contains('test-device-id'));
      expect(str, contains('Test Model'));
      expect(str, contains('TestOS'));
    });
  });
}
