import 'discovered_device.dart';

extension DiscoveredDeviceTypeLabel on DiscoveredDeviceType {
  String get label {
    return switch (this) {
      DiscoveredDeviceType.mobile => '移动设备',
      DiscoveredDeviceType.desktop => '桌面设备',
      DiscoveredDeviceType.web => '网页设备',
      DiscoveredDeviceType.headless => '无界面设备',
      DiscoveredDeviceType.server => '服务器',
    };
  }
}
