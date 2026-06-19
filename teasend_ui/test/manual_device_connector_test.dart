import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nearsend/services/localsend_identity.dart';
import 'package:nearsend/services/manual_device_connector.dart';

void main() {
  test('tries fallback ports when the requested port is closed', () async {
    final identity = LocalSendIdentity(alias: 'Manual Connector Test');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    server.listen((request) async {
      if (request.uri.path.endsWith('/info')) {
        request.response
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'alias': 'Peer',
              'version': LocalSendIdentity.protocolVersion,
              'deviceModel': 'Windows',
              'deviceType': 'desktop',
              'fingerprint': 'peer-fingerprint',
              'port': server.port,
              'protocol': 'http',
              'download': false,
            }),
          );
      } else {
        request.response.statusCode = HttpStatus.ok;
      }
      await request.response.close();
    });

    final connector = ManualDeviceConnector(
      identity: identity,
      fallbackPorts: [server.port],
    );
    try {
      final device = await connector.connect(
        host: '127.0.0.1',
        port: LocalSendIdentity.defaultPort,
      );

      expect(device.fingerprint, 'peer-fingerprint');
      expect(device.port, server.port);
    } finally {
      await server.close(force: true);
    }
  });
}
