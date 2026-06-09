import 'dart:convert';
import 'dart:io';

import '../models/discovered_device.dart';
import 'localsend_identity.dart';

class ManualDeviceConnector {
  ManualDeviceConnector({required this.identity});

  final LocalSendIdentity identity;

  Future<DiscoveredDevice> connect({
    required String host,
    required int port,
  }) async {
    final normalizedHost = host.trim();
    if (normalizedHost.isEmpty) {
      throw const ManualConnectException('请输入 IP 地址');
    }
    if (port < 1 || port > 65535) {
      throw const ManualConnectException('端口号必须在 1 到 65535 之间');
    }

    final attempts = [
      _ManualConnectAttempt('http', '/api/localsend/v2/info'),
      _ManualConnectAttempt('https', '/api/localsend/v2/info'),
      _ManualConnectAttempt('http', '/api/localsend/v1/info'),
      _ManualConnectAttempt('https', '/api/localsend/v1/info'),
    ];

    for (final attempt in attempts) {
      final device = await _tryInfo(
        host: normalizedHost,
        port: port,
        attempt: attempt,
      );
      if (device != null) {
        if (device.fingerprint == identity.fingerprint) {
          throw const ManualConnectException('不能连接当前设备自己');
        }
        return device;
      }
    }

    throw const ManualConnectException('未连接到 LocalSend 设备，请确认 IP、端口和防火墙设置');
  }

  Future<DiscoveredDevice?> _tryInfo({
    required String host,
    required int port,
    required _ManualConnectAttempt attempt,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    client.badCertificateCallback = (_, _, _) => true;

    try {
      final request = await client.getUrl(
        Uri(
          scheme: attempt.scheme,
          host: host,
          port: port,
          path: attempt.path,
          queryParameters: {'fingerprint': identity.fingerprint},
        ),
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close().timeout(
        const Duration(seconds: 3),
      );
      final body = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;
      return DiscoveredDevice.fromLocalSendJson(
        decoded,
        host,
        fallbackPort: port,
        fallbackHttps: attempt.scheme == 'https',
      );
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

class ManualConnectException implements Exception {
  const ManualConnectException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _ManualConnectAttempt {
  const _ManualConnectAttempt(this.scheme, this.path);

  final String scheme;
  final String path;
}
