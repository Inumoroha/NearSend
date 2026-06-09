import 'dart:convert';
import 'dart:io';

import '../models/discovered_device.dart';
import '../models/nearsend_message.dart';
import 'localsend_identity.dart';

class NearSendMessageClient {
  NearSendMessageClient({required this.identity});

  final LocalSendIdentity identity;

  Future<void> sendText({
    required DiscoveredDevice target,
    required String text,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client.postUrl(_messageUri(target));
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'senderFingerprint': identity.fingerprint,
          'senderAlias': identity.alias,
          'text': text,
        }),
      );
      await _expectOk(request);
    } finally {
      client.close(force: true);
    }
  }

  Future<void> sendAttachment({
    required DiscoveredDevice target,
    required NearSendAttachment attachment,
    String text = '',
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client.postUrl(_messageUri(target));
      final file = File(attachment.path);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'senderFingerprint': identity.fingerprint,
          'senderAlias': identity.alias,
          'text': text,
          'type': attachment.type.wireValue,
          'attachmentName': attachment.name,
          'attachmentBase64': base64Encode(await file.readAsBytes()),
        }),
      );

      await _expectOk(request);
    } finally {
      client.close(force: true);
    }
  }

  Uri _messageUri(DiscoveredDevice target) {
    return Uri(
      scheme: target.https ? 'https' : 'http',
      host: target.ip,
      port: target.port,
      path: '/api/nearsend/v1/message',
    );
  }

  Future<void> _expectOk(HttpClientRequest request) async {
    final response = await request.close().timeout(const Duration(seconds: 10));
    await response.drain<void>();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('NearSend message failed: ${response.statusCode}');
    }
  }
}
