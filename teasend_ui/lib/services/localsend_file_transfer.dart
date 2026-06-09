import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../models/discovered_device.dart';
import '../models/nearsend_message.dart';
import 'localsend_identity.dart';

class LocalSendFileTransferService {
  LocalSendFileTransferService({required this.identity});

  final LocalSendIdentity identity;
  final _incomingController = StreamController<NearSendMessage>.broadcast();
  final _sessions = <String, _ReceiveSession>{};
  final _random = Random.secure();

  Stream<NearSendMessage> get incomingFiles => _incomingController.stream;

  Future<void> dispose() async {
    await _incomingController.close();
  }

  Future<Map<String, Object?>> handlePrepareUpload(HttpRequest request) async {
    final body = await utf8.decodeStream(request);
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Malformed prepare-upload request');
    }

    final filesJson = decoded['files'];
    if (filesJson is! Map<String, dynamic> || filesJson.isEmpty) {
      throw const FormatException('Missing files');
    }

    final sessionId = _token();
    final sender = decoded['info'];
    final senderAlias = sender is Map<String, dynamic>
        ? sender['alias']?.toString() ?? 'LocalSend'
        : 'LocalSend';
    final senderFingerprint = sender is Map<String, dynamic>
        ? sender['fingerprint']?.toString() ?? ''
        : '';
    final files = <String, _IncomingFile>{};
    final responseFiles = <String, String>{};

    for (final entry in filesJson.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      final name = value['fileName']?.toString() ?? entry.key;
      final size = value['size'] is int ? value['size'] as int : 0;
      final token = _token();
      files[entry.key] = _IncomingFile(
        id: entry.key,
        name: name,
        size: size,
        token: token,
      );
      responseFiles[entry.key] = token;
    }

    _sessions[sessionId] = _ReceiveSession(
      sessionId: sessionId,
      senderAlias: senderAlias,
      senderFingerprint: senderFingerprint,
      files: files,
    );

    return {'sessionId': sessionId, 'files': responseFiles};
  }

  Future<void> handleUpload(HttpRequest request) async {
    final sessionId = request.uri.queryParameters['sessionId'];
    final fileId = request.uri.queryParameters['fileId'];
    final token = request.uri.queryParameters['token'];
    if (sessionId == null || fileId == null || token == null) {
      throw const FormatException('Missing upload parameters');
    }

    final session = _sessions[sessionId];
    final incoming = session?.files[fileId];
    if (session == null || incoming == null || incoming.token != token) {
      throw const FormatException('Invalid upload token');
    }

    final directory = await Directory.systemTemp.createTemp(
      'nearsend_localsend_',
    );
    final safeName = incoming.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${directory.path}${Platform.pathSeparator}$safeName');
    final sink = file.openWrite();
    await for (final chunk in request) {
      sink.add(chunk);
    }
    await sink.close();

    _incomingController.add(
      NearSendMessage(
        senderFingerprint: session.senderFingerprint,
        senderAlias: session.senderAlias,
        text: '',
        receivedAt: DateTime.now(),
        attachment: NearSendAttachment(
          path: file.path,
          name: incoming.name,
          size: await file.length(),
          type: NearSendPayloadTypeX.fromFileName(incoming.name),
        ),
      ),
    );
  }

  Future<void> sendFile({
    required DiscoveredDevice target,
    required String path,
  }) async {
    await sendFiles(target: target, paths: [path]);
  }

  Future<void> sendFiles({
    required DiscoveredDevice target,
    required List<String> paths,
  }) async {
    if (paths.isEmpty) return;
    final files = <_OutgoingFile>[];
    for (var index = 0; index < paths.length; index++) {
      final path = paths[index];
      final file = File(path);
      files.add(
        _OutgoingFile(
          id: 'file-${DateTime.now().microsecondsSinceEpoch}-$index',
          path: path,
          name: p.basename(path),
          size: await file.length(),
        ),
      );
    }

    final prepareResponse = await _prepareUpload(target: target, files: files);
    final remoteSessionId = prepareResponse.sessionId;
    var uploadedAny = false;

    for (final file in files) {
      final token = prepareResponse.files[file.id];
      if (token == null) continue;
      uploadedAny = true;
      await _upload(
        target: target,
        path: file.path,
        fileId: file.id,
        token: token,
        sessionId: remoteSessionId,
      );
    }
    if (!uploadedAny) {
      throw const HttpException('LocalSend receiver did not accept any files');
    }
  }

  Future<_PrepareUploadResponse> _prepareUpload({
    required DiscoveredDevice target,
    required List<_OutgoingFile> files,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final request = await client.postUrl(
        Uri(
          scheme: target.https ? 'https' : 'http',
          host: target.ip,
          port: target.port,
          path: target.version == '1.0'
              ? '/api/localsend/v1/send-request'
              : '/api/localsend/v2/prepare-upload',
        ),
      );
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'info': identity.registerJson(),
          'files': {
            for (final file in files)
              file.id: {
                'id': file.id,
                'fileName': file.name,
                'size': file.size,
                'fileType': _mimeFor(file.name),
              },
          },
        }),
      );

      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      final body = await utf8.decodeStream(response);
      if (response.statusCode == HttpStatus.noContent) {
        return const _PrepareUploadResponse(sessionId: null, files: {});
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('prepare-upload failed: ${response.statusCode}');
      }

      final decoded = jsonDecode(body);
      if (target.version == '1.0') {
        return _PrepareUploadResponse(
          sessionId: null,
          files: (decoded as Map<String, dynamic>).cast<String, String>(),
        );
      }

      final map = decoded as Map<String, dynamic>;
      return _PrepareUploadResponse(
        sessionId: map['sessionId']?.toString(),
        files: (map['files'] as Map<String, dynamic>).cast<String, String>(),
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _upload({
    required DiscoveredDevice target,
    required String path,
    required String fileId,
    required String token,
    required String? sessionId,
  }) async {
    final file = File(path);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final query = {
        // ignore: use_null_aware_elements
        if (sessionId != null) 'sessionId': sessionId,
        'fileId': fileId,
        'token': token,
      };
      final request = await client.postUrl(
        Uri(
          scheme: target.https ? 'https' : 'http',
          host: target.ip,
          port: target.port,
          path: target.version == '1.0'
              ? '/api/localsend/v1/send'
              : '/api/localsend/v2/upload',
          queryParameters: query,
        ),
      );
      request.headers.contentType = ContentType.parse(_mimeFor(path));
      request.headers.contentLength = await file.length();
      await request.addStream(file.openRead());
      final response = await request.close().timeout(
        const Duration(minutes: 5),
      );
      await response.drain<void>();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('upload failed: ${response.statusCode}');
      }
    } finally {
      client.close(force: true);
    }
  }

  String _mimeFor(String fileName) {
    final extension = p.extension(fileName).toLowerCase();
    return switch (extension) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.pdf' => 'application/pdf',
      '.txt' || '.md' => 'text/plain',
      _ => 'application/octet-stream',
    };
  }

  String _token() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

class _ReceiveSession {
  const _ReceiveSession({
    required this.sessionId,
    required this.senderAlias,
    required this.senderFingerprint,
    required this.files,
  });

  final String sessionId;
  final String senderAlias;
  final String senderFingerprint;
  final Map<String, _IncomingFile> files;
}

class _IncomingFile {
  const _IncomingFile({
    required this.id,
    required this.name,
    required this.size,
    required this.token,
  });

  final String id;
  final String name;
  final int size;
  final String token;
}

class _OutgoingFile {
  const _OutgoingFile({
    required this.id,
    required this.path,
    required this.name,
    required this.size,
  });

  final String id;
  final String path;
  final String name;
  final int size;
}

class _PrepareUploadResponse {
  const _PrepareUploadResponse({required this.sessionId, required this.files});

  final String? sessionId;
  final Map<String, String> files;
}
