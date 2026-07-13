import 'dart:convert';
import 'dart:io';

import '../models/discovered_device.dart';
import 'localsend_discovery_server.dart';
import 'localsend_identity.dart';
import 'localsend_security.dart';

class ManualDeviceConnector {
  ManualDeviceConnector({
    required this.identity,
    int Function()? boundPort,
    Iterable<int>? fallbackPorts,
  }) : boundPort = boundPort ?? (() => identity.port),
       fallbackPorts = fallbackPorts ?? LocalSendDiscoveryServer.fallbackPorts;

  final LocalSendIdentity identity;
  final int Function() boundPort;
  final Iterable<int> fallbackPorts;

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

    ManualConnectException? selfConnectError;
    final candidatePorts = _candidatePorts(port);
    for (final attempt in _attempts) {
      for (final candidatePort in candidatePorts) {
        final device = await _tryInfo(
          host: normalizedHost,
          port: candidatePort,
          attempt: attempt,
        );
        if (device == null) continue;
        if (device.fingerprint == identity.fingerprint) {
          selfConnectError = const ManualConnectException('不能连接当前设备自己');
          continue;
        }
        await _registerSelf(device, attempt.path);
        return device;
      }
    }

    if (selfConnectError != null) throw selfConnectError;
    throw const ManualConnectException('未连接到 LocalSend 设备，请确认 IP、端口和防火墙设置');
  }

  List<int> _candidatePorts(int preferredPort) {
    return {preferredPort, ...fallbackPorts}.toList(growable: false);
  }

  static const _attempts = [
    _ManualConnectAttempt('https', '/api/localsend/v2/info'),
    _ManualConnectAttempt('https', '/api/localsend/v1/info'),
    _ManualConnectAttempt('http', '/api/localsend/v2/info'),
    _ManualConnectAttempt('http', '/api/localsend/v1/info'),
  ];

  Future<DiscoveredDevice?> _tryInfo({
    required String host,
    required int port,
    required _ManualConnectAttempt attempt,
  }) async {
    final client = createLocalSendHttpClient(
      trustedFingerprint: null,
      connectionTimeout: const Duration(milliseconds: 900),
    );

    try {
      final uri = Uri(
        scheme: attempt.scheme,
        host: host,
        port: port,
        path: attempt.path,
        queryParameters: {'fingerprint': identity.fingerprint},
      );
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close().timeout(
        const Duration(seconds: 2),
      );
      final body = await utf8
          .decodeStream(response)
          .timeout(const Duration(seconds: 2));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;
      final device = DiscoveredDevice.fromLocalSendJson(
        decoded,
        host,
        fallbackPort: port,
        fallbackHttps: attempt.scheme == 'https',
      );
      if (device == null) return null;
      ensureResponseCertificateMatches(
        uri: uri,
        expectedFingerprint: device.https ? device.fingerprint : null,
        response: response,
      );
      return device;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _registerSelf(DiscoveredDevice device, String infoPath) async {
    final client = createLocalSendHttpClient(
      trustedFingerprint: device.https ? device.fingerprint : null,
      connectionTimeout: const Duration(seconds: 2),
    );
    final registerPath = infoPath.contains('/v1/')
        ? '/api/localsend/v1/register'
        : '/api/localsend/v2/register';

    try {
      final uri = Uri(
        scheme: device.https ? 'https' : 'http',
        host: device.ip,
        port: device.port,
        path: registerPath,
      );
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(_registerMessage()));
      final response = await request.close().timeout(
        const Duration(seconds: 3),
      );
      ensureResponseCertificateMatches(
        uri: uri,
        expectedFingerprint: device.https ? device.fingerprint : null,
        response: response,
      );
      await response.drain<void>();
    } catch (_) {
      // A manual connect can still be useful if the peer refuses register; the
      // user can send directly with the device info we already fetched.
    } finally {
      client.close(force: true);
    }
  }

  Map<String, Object?> _registerMessage() {
    return {
      ...identity.infoJson(),
      'port': boundPort(),
      'protocol': identity.protocol,
    };
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
