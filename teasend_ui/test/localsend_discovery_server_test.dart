import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nearsend/services/localsend_discovery_server.dart';
import 'package:nearsend/services/localsend_identity.dart';

void main() {
  test('serves LocalSend v2 info and register endpoints', () async {
    final identity = LocalSendIdentity(alias: 'NearSend Test', port: 0);
    final server = LocalSendDiscoveryServer(identity: identity);
    await server.start();
    final port = server.boundPort;

    try {
      final client = HttpClient();
      addTearDown(() => client.close(force: true));

      final infoRequest = await client.getUrl(
        Uri.http('127.0.0.1:$port', '/api/localsend/v2/info'),
      );
      final infoResponse = await infoRequest.close();
      final infoBody = jsonDecode(await utf8.decodeStream(infoResponse));

      expect(infoResponse.statusCode, HttpStatus.ok);
      expect(infoBody['alias'], 'NearSend Test');
      expect(infoBody['version'], LocalSendIdentity.protocolVersion);
      expect(infoBody['fingerprint'], identity.fingerprint);

      final registerRequest = await client.postUrl(
        Uri.http('127.0.0.1:$port', '/api/localsend/v2/register'),
      );
      registerRequest.headers.contentType = ContentType.json;
      registerRequest.write(
        jsonEncode({
          'alias': 'Peer',
          'version': '2.1',
          'deviceModel': 'Windows',
          'deviceType': 'desktop',
          'fingerprint': 'peer-fingerprint',
          'port': 53317,
          'protocol': 'http',
          'download': false,
        }),
      );
      final registerResponse = await registerRequest.close();
      final registerBody = jsonDecode(
        await utf8.decodeStream(registerResponse),
      );

      expect(registerResponse.statusCode, HttpStatus.ok);
      expect(registerBody['alias'], 'NearSend Test');
      expect(registerBody['fingerprint'], identity.fingerprint);
    } finally {
      await server.dispose();
    }
  });

  test('receives NearSend text and attachment messages', () async {
    final identity = LocalSendIdentity(alias: 'NearSend Test', port: 0);
    final server = LocalSendDiscoveryServer(identity: identity);
    await server.start();
    final port = server.boundPort;

    try {
      final client = HttpClient();
      addTearDown(() => client.close(force: true));

      final textFuture = server.messages.first;
      final textRequest = await client.postUrl(
        Uri.http('127.0.0.1:$port', '/api/nearsend/v1/message'),
      );
      textRequest.headers.contentType = ContentType.json;
      textRequest.write(
        jsonEncode({
          'senderFingerprint': 'peer-fingerprint',
          'senderAlias': 'Peer',
          'text': 'hello',
        }),
      );
      final textResponse = await textRequest.close();
      await textResponse.drain<void>();
      final textMessage = await textFuture;

      expect(textResponse.statusCode, HttpStatus.ok);
      expect(textMessage.text, 'hello');
      expect(textMessage.senderAlias, 'Peer');

      final attachmentFuture = server.messages.first;
      final attachmentRequest = await client.postUrl(
        Uri.http('127.0.0.1:$port', '/api/nearsend/v1/message'),
      );
      attachmentRequest.headers.contentType = ContentType.json;
      attachmentRequest.write(
        jsonEncode({
          'senderFingerprint': 'peer-fingerprint',
          'senderAlias': 'Peer',
          'text': '',
          'attachmentName': 'note.txt',
          'attachmentBase64': base64Encode(utf8.encode('file body')),
        }),
      );
      final attachmentResponse = await attachmentRequest.close();
      await attachmentResponse.drain<void>();
      final attachmentMessage = await attachmentFuture;

      expect(attachmentResponse.statusCode, HttpStatus.ok);
      expect(attachmentMessage.attachment?.name, 'note.txt');
      expect(
        await File(attachmentMessage.attachment!.path).readAsString(),
        'file body',
      );
    } finally {
      await server.dispose();
    }
  });

  test('receives LocalSend v2 file upload', () async {
    final identity = LocalSendIdentity(alias: 'NearSend Test', port: 0);
    final server = LocalSendDiscoveryServer(identity: identity);
    await server.start();
    final port = server.boundPort;

    try {
      final client = HttpClient();
      addTearDown(() => client.close(force: true));

      const fileId = 'file-1';
      final prepareRequest = await client.postUrl(
        Uri.http('127.0.0.1:$port', '/api/localsend/v2/prepare-upload'),
      );
      prepareRequest.headers.contentType = ContentType.json;
      prepareRequest.write(
        jsonEncode({
          'info': {
            'alias': 'LocalSend Peer',
            'version': '2.1',
            'deviceModel': 'Windows',
            'deviceType': 'desktop',
            'fingerprint': 'peer-fingerprint',
            'port': 53317,
            'protocol': 'http',
            'download': false,
          },
          'files': {
            fileId: {
              'id': fileId,
              'fileName': 'hello.txt',
              'size': 11,
              'fileType': 'text/plain',
            },
          },
        }),
      );
      final prepareResponse = await prepareRequest.close();
      final prepareBody = jsonDecode(await utf8.decodeStream(prepareResponse));
      final token = prepareBody['files'][fileId] as String;
      final sessionId = prepareBody['sessionId'] as String;

      expect(prepareResponse.statusCode, HttpStatus.ok);
      expect(token, isNotEmpty);
      expect(sessionId, isNotEmpty);

      final uploadFuture = server.messages.first;
      final uploadRequest = await client.postUrl(
        Uri.http('127.0.0.1:$port', '/api/localsend/v2/upload', {
          'sessionId': sessionId,
          'fileId': fileId,
          'token': token,
        }),
      );
      uploadRequest.headers.contentType = ContentType.text;
      uploadRequest.headers.contentLength = 11;
      uploadRequest.write('hello world');
      final uploadResponse = await uploadRequest.close();
      await uploadResponse.drain<void>();
      final message = await uploadFuture;

      expect(uploadResponse.statusCode, HttpStatus.ok);
      expect(message.senderAlias, 'LocalSend Peer');
      expect(message.attachment?.name, 'hello.txt');
      expect(
        await File(message.attachment!.path).readAsString(),
        'hello world',
      );
    } finally {
      await server.dispose();
    }
  });

  test('receives multiple LocalSend v2 file uploads in one session', () async {
    final identity = LocalSendIdentity(alias: 'NearSend Test', port: 0);
    final server = LocalSendDiscoveryServer(identity: identity);
    await server.start();
    final port = server.boundPort;

    try {
      final client = HttpClient();
      addTearDown(() => client.close(force: true));

      final prepareRequest = await client.postUrl(
        Uri.http('127.0.0.1:$port', '/api/localsend/v2/prepare-upload'),
      );
      prepareRequest.headers.contentType = ContentType.json;
      prepareRequest.write(
        jsonEncode({
          'info': {
            'alias': 'LocalSend Peer',
            'version': '2.1',
            'fingerprint': 'peer-fingerprint',
            'port': 53317,
            'protocol': 'http',
          },
          'files': {
            'file-1': {
              'id': 'file-1',
              'fileName': 'one.txt',
              'size': 3,
              'fileType': 'text/plain',
            },
            'file-2': {
              'id': 'file-2',
              'fileName': 'two.txt',
              'size': 3,
              'fileType': 'text/plain',
            },
          },
        }),
      );
      final prepareResponse = await prepareRequest.close();
      final prepareBody = jsonDecode(await utf8.decodeStream(prepareResponse));
      final sessionId = prepareBody['sessionId'] as String;
      final files = prepareBody['files'] as Map<String, dynamic>;

      expect(prepareResponse.statusCode, HttpStatus.ok);
      expect(files.keys, containsAll(['file-1', 'file-2']));

      final messagesFuture = server.messages.take(2).toList();
      for (final entry in {'file-1': 'one', 'file-2': 'two'}.entries) {
        final uploadRequest = await client.postUrl(
          Uri.http('127.0.0.1:$port', '/api/localsend/v2/upload', {
            'sessionId': sessionId,
            'fileId': entry.key,
            'token': files[entry.key] as String,
          }),
        );
        uploadRequest.headers.contentType = ContentType.text;
        uploadRequest.headers.contentLength = entry.value.length;
        uploadRequest.write(entry.value);
        final uploadResponse = await uploadRequest.close();
        await uploadResponse.drain<void>();
        expect(uploadResponse.statusCode, HttpStatus.ok);
      }

      final messages = await messagesFuture;
      expect(
        messages.map((message) => message.attachment?.name),
        containsAll(['one.txt', 'two.txt']),
      );
    } finally {
      await server.dispose();
    }
  });
}
