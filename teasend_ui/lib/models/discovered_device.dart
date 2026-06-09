enum DiscoveredDeviceType { mobile, desktop, web, headless, server }

extension DiscoveredDeviceTypeParsing on DiscoveredDeviceType {
  static DiscoveredDeviceType fromLocalSend(Object? value) {
    final normalized = value?.toString().toLowerCase();
    return switch (normalized) {
      'mobile' => DiscoveredDeviceType.mobile,
      'web' => DiscoveredDeviceType.web,
      'headless' => DiscoveredDeviceType.headless,
      'server' => DiscoveredDeviceType.server,
      _ => DiscoveredDeviceType.desktop,
    };
  }
}

class DiscoveredDevice {
  const DiscoveredDevice({
    required this.alias,
    required this.ip,
    required this.version,
    required this.port,
    required this.https,
    required this.fingerprint,
    required this.deviceType,
    required this.download,
    required this.lastSeen,
    this.deviceModel,
  });

  final String alias;
  final String ip;
  final String version;
  final int port;
  final bool https;
  final String fingerprint;
  final DiscoveredDeviceType deviceType;
  final bool download;
  final DateTime lastSeen;
  final String? deviceModel;

  static DiscoveredDevice? fromLocalSendJson(
    Map<String, dynamic> data,
    String ip, {
    required int fallbackPort,
    required bool fallbackHttps,
  }) {
    final alias = data['alias'];
    final fingerprint = data['fingerprint'];
    if (alias is! String || fingerprint is! String) return null;

    final protocol = data['protocol'];

    return DiscoveredDevice(
      alias: alias,
      ip: ip,
      version: data['version'] is String ? data['version'] as String : '1.0',
      port: data['port'] is int ? data['port'] as int : fallbackPort,
      https: protocol is String
          ? protocol.toLowerCase() == 'https'
          : fallbackHttps,
      fingerprint: fingerprint,
      deviceType: DiscoveredDeviceTypeParsing.fromLocalSend(data['deviceType']),
      download: data['download'] == true,
      lastSeen: DateTime.now(),
      deviceModel: data['deviceModel'] is String
          ? data['deviceModel'] as String
          : null,
    );
  }

  String get endpoint => '${https ? 'https' : 'http'}://$ip:$port';

  String get displayModel {
    final model = deviceModel?.trim();
    if (model != null && model.isNotEmpty) {
      return model;
    }

    return switch (deviceType) {
      DiscoveredDeviceType.mobile => 'Mobile',
      DiscoveredDeviceType.desktop => 'Desktop',
      DiscoveredDeviceType.web => 'Web',
      DiscoveredDeviceType.headless => 'Headless',
      DiscoveredDeviceType.server => 'Server',
    };
  }

  String get initials {
    final trimmed = alias.trim();
    if (trimmed.isEmpty) return '?';
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  DiscoveredDevice copyWith({DateTime? lastSeen}) {
    return DiscoveredDevice(
      alias: alias,
      ip: ip,
      version: version,
      port: port,
      https: https,
      fingerprint: fingerprint,
      deviceType: deviceType,
      download: download,
      lastSeen: lastSeen ?? this.lastSeen,
      deviceModel: deviceModel,
    );
  }
}
