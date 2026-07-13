import 'dart:convert';
import 'dart:io';

import '../models/discovered_device.dart';
import '../models/nearsend_message.dart';
import 'localsend_discovery_server.dart';
import 'localsend_identity.dart';
import 'localsend_security.dart';

class NearSendMessageClient {
  NearSendMessageClient({required this.identity, required this.boundPort});

  final LocalSendIdentity identity;
  final int Function() boundPort;

  Future<void> sendText({
    required DiscoveredDevice target,
    required String text,
  }) async {
    await _sendJsonWithFallback(
      target: target,
      body: {..._senderInfo(), 'text': text},
    );
  }

  Future<void> sendAttachment({
    required DiscoveredDevice target,
    required NearSendAttachment attachment,
    String text = '',
  }) async {
    final file = File(attachment.path);
    await _sendJsonWithFallback(
      target: target,
      body: {
        ..._senderInfo(),
        'text': text,
        'type': attachment.type.wireValue,
        'attachmentName': attachment.name,
        'attachmentBase64': base64Encode(await file.readAsBytes()),
      },
    );
  }

  Future<void> _sendJsonWithFallback({
    required DiscoveredDevice target,
    required Map<String, Object?> body,
  }) async {
    Object? lastError;
    for (final port in _candidatePorts(target.port)) {
      final client = createLocalSendHttpClient(
        trustedFingerprint: target.https ? target.fingerprint : null,
        connectionTimeout: const Duration(milliseconds: 1200),
      );
      try {
        final uri = _messageUri(target, port);
        final request = await client.postUrl(uri);
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
        await _expectOk(request, uri, target);
        return;
      } catch (error) {
        lastError = error;
      } finally {
        client.close(force: true);
      }
    }
    final error = lastError;
    if (error is Exception) throw error;
    throw HttpException('NearSend message failed: $error');
  }

  Iterable<int> _candidatePorts(int preferredPort) {
    return {preferredPort, ...LocalSendDiscoveryServer.fallbackPorts};
  }

  Uri _messageUri(DiscoveredDevice target, int port) {
    return Uri(
      scheme: target.https ? 'https' : 'http',
      host: target.ip,
      port: port,
      path: '/api/nearsend/v1/message',
    );
  }

  Future<void> _expectOk(
    HttpClientRequest request,
    Uri uri,
    DiscoveredDevice target,
  ) async {
    final response = await request.close().timeout(const Duration(seconds: 10));
    ensureResponseCertificateMatches(
      uri: uri,
      expectedFingerprint: target.https ? target.fingerprint : null,
      response: response,
    );
    await response.drain<void>();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('NearSend message failed: ${response.statusCode}');
    }
  }

  Map<String, Object?> _senderInfo() {
    return {
      'senderFingerprint': identity.fingerprint,
      'senderAlias': identity.alias,
      'senderDevice': {
        ...identity.infoJson(),
        'port': boundPort(),
        'protocol': identity.protocol,
      },
    };
  }
}
