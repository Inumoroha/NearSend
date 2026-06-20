import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../models/discovered_device.dart';
import '../models/nearsend_message.dart';
import 'localsend_discovery_server.dart';
import 'localsend_identity.dart';

/// Thrown when an in-flight upload is aborted via [TransferHandle.cancel].
class TransferCancelledException implements Exception {
  const TransferCancelledException();

  @override
  String toString() => 'TransferCancelledException';
}

/// Per-transfer cancel handle. The UI holds one per outgoing message and calls
/// [cancel] to abort the upload; the bound [HttpClient] is force-closed so the
/// connection drops immediately rather than after the current chunk.
class TransferHandle {
  bool _cancelled = false;
  HttpClient? _client;
  DiscoveredDevice? _target;
  String? _sessionId;

  bool get isCancelled => _cancelled;

  void _bind(HttpClient client) => _client = client;
  void _bindRemote(DiscoveredDevice target, String? sessionId) {
    _target = target;
    _sessionId = sessionId;
  }

  DiscoveredDevice? get target => _target;
  String? get sessionId => _sessionId;

  void cancel() {
    _cancelled = true;
    _client?.close(force: true);
  }
}

class LocalSendFileTransferService {
  LocalSendFileTransferService({
    required this.identity,
    int Function()? boundPort,
    this.requireReceiveConfirmation = false,
    this.shouldConfirmIncoming,
  }) : boundPort = boundPort ?? (() => identity.port);

  final LocalSendIdentity identity;
  final int Function() boundPort;
  final bool requireReceiveConfirmation;
  final bool Function(String senderFingerprint)? shouldConfirmIncoming;
  final _incomingController = StreamController<NearSendMessage>.broadcast();
  final _requestController =
      StreamController<IncomingTransferRequest>.broadcast();
  final _sessions = <String, _ReceiveSession>{};
  final _random = Random.secure();

  Stream<NearSendMessage> get incomingFiles => _incomingController.stream;
  Stream<IncomingTransferRequest> get incomingRequests =>
      _requestController.stream;

  Future<void> dispose() async {
    await _incomingController.close();
    await _requestController.close();
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
    final senderDevice = sender is Map<String, dynamic>
        ? DiscoveredDevice.fromLocalSendJson(
            sender,
            request.connectionInfo?.remoteAddress.address ?? '',
            fallbackPort: identity.port,
            fallbackHttps: identity.https,
          )
        : null;
    final files = <String, _IncomingFile>{};
    final responseFiles = <String, String>{};

    for (final entry in filesJson.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      final name = value['fileName']?.toString() ?? entry.key;
      final size = _parseSize(value['size']);
      final fileType = value['fileType']?.toString();
      final token = _token();
      files[entry.key] = _IncomingFile(
        id: entry.key,
        name: name,
        size: size,
        fileType: fileType,
        token: token,
      );
      responseFiles[entry.key] = token;
    }

    _sessions[sessionId] = _ReceiveSession(
      sessionId: sessionId,
      senderAlias: senderAlias,
      senderFingerprint: senderFingerprint,
      files: files,
      senderDevice: senderDevice,
    );

    final requiresConfirmation =
        shouldConfirmIncoming?.call(senderFingerprint) ??
        requireReceiveConfirmation;

    final incomingRequest = IncomingTransferRequest(
      sessionId: sessionId,
      senderAlias: senderAlias,
      senderFingerprint: senderFingerprint,
      senderDevice: senderDevice,
      files: files.values
          .map(
            (file) => IncomingTransferFile(
              id: file.id,
              name: file.name,
              size: file.size,
            ),
          )
          .toList(),
      autoAccepted: !requiresConfirmation,
    );

    if (requiresConfirmation) {
      _requestController.add(incomingRequest);
      final accepted = await _sessions[sessionId]!.decision.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => false,
      );
      if (!accepted) {
        _sessions.remove(sessionId);
        throw const TransferDeclinedException();
      }
    } else {
      _requestController.add(incomingRequest);
    }

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
    if (session.cancelled) {
      throw const TransferCancelledException();
    }

    final directory = await Directory.systemTemp.createTemp(
      'nearsend_localsend_',
    );
    final safeName = incoming.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${directory.path}${Platform.pathSeparator}$safeName');
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in request) {
        if (session.cancelled) {
          throw const TransferCancelledException();
        }
        received += chunk.length;
        incoming.received = received;
        sink.add(chunk);
      }
    } finally {
      await sink.close();
    }
    if (session.cancelled) {
      throw const TransferCancelledException();
    }

    _incomingController.add(
      NearSendMessage(
        senderFingerprint: session.senderFingerprint,
        senderAlias: session.senderAlias,
        text: '',
        receivedAt: DateTime.now(),
        sessionId: session.sessionId,
        fileId: incoming.id,
        senderDevice: session.senderDevice,
        attachment: NearSendAttachment(
          path: file.path,
          name: incoming.name,
          size: await file.length(),
          type: _payloadTypeFor(incoming.name, incoming.fileType),
        ),
      ),
    );

    incoming.completed = true;
    if (session.files.values.every((file) => file.completed)) {
      _sessions.remove(sessionId);
    }
  }

  bool acceptIncoming(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null || session.decision.isCompleted) return false;
    session.decision.complete(true);
    return true;
  }

  bool declineIncoming(String sessionId) {
    final session = _sessions.remove(sessionId);
    if (session == null) return false;
    session.cancelled = true;
    if (!session.decision.isCompleted) {
      session.decision.complete(false);
    }
    return true;
  }

  bool cancelIncoming(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return false;
    session.cancelled = true;
    if (!session.decision.isCompleted) {
      session.decision.complete(false);
    }
    _sessions.remove(sessionId);
    return true;
  }

  Future<void> sendFile({
    required DiscoveredDevice target,
    required String path,
    void Function(int sent, int total)? onProgress,
    TransferHandle? handle,
  }) async {
    await sendFiles(
      target: target,
      paths: [path],
      onProgress: onProgress,
      handle: handle,
    );
  }

  Future<void> sendFiles({
    required DiscoveredDevice target,
    required List<String> paths,
    void Function(int sent, int total)? onProgress,
    TransferHandle? handle,
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

    final totalBytes = files.fold<int>(0, (sum, file) => sum + file.size);
    final resolved = await _prepareUploadWithFallback(
      target: target,
      files: files,
    );
    final prepareResponse = resolved.response;
    final uploadTarget = resolved.target;
    final remoteSessionId = prepareResponse.sessionId;
    handle?._bindRemote(uploadTarget, remoteSessionId);
    var uploadedAny = false;
    var sentBefore = 0;

    for (final file in files) {
      final token = prepareResponse.files[file.id];
      if (token == null) continue;
      uploadedAny = true;
      await _upload(
        target: uploadTarget,
        path: file.path,
        fileId: file.id,
        token: token,
        sessionId: remoteSessionId,
        handle: handle,
        onProgress: (fileSent) =>
            onProgress?.call(sentBefore + fileSent, totalBytes),
      );
      sentBefore += file.size;
    }
    if (!uploadedAny) {
      throw const HttpException('LocalSend receiver did not accept any files');
    }
  }

  Future<void> cancelRemote(TransferHandle handle) async {
    final target = handle.target;
    final sessionId = handle.sessionId;
    if (target == null || sessionId == null) return;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client.postUrl(
        Uri(
          scheme: target.https ? 'https' : 'http',
          host: target.ip,
          port: target.port,
          path: target.version == '1.0'
              ? '/api/localsend/v1/cancel'
              : '/api/localsend/v2/cancel',
          queryParameters: target.version == '1.0'
              ? null
              : {'sessionId': sessionId},
        ),
      );
      await request.close().timeout(const Duration(seconds: 4));
    } catch (_) {
      // Best-effort notification; the local connection is already closed.
    } finally {
      client.close(force: true);
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
          'info': _registerMessage(),
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

  Future<_ResolvedPrepareUpload> _prepareUploadWithFallback({
    required DiscoveredDevice target,
    required List<_OutgoingFile> files,
  }) async {
    Object? lastError;
    for (final port in _candidatePorts(target.port)) {
      final candidate = target.copyWith(port: port);
      try {
        final response = await _prepareUpload(target: candidate, files: files);
        return _ResolvedPrepareUpload(target: candidate, response: response);
      } catch (error) {
        lastError = error;
      }
    }
    final error = lastError;
    if (error is Exception) throw error;
    throw HttpException('prepare-upload failed: $error');
  }

  Iterable<int> _candidatePorts(int preferredPort) {
    return {preferredPort, ...LocalSendDiscoveryServer.fallbackPorts};
  }

  Future<void> _upload({
    required DiscoveredDevice target,
    required String path,
    required String fileId,
    required String token,
    required String? sessionId,
    void Function(int sent)? onProgress,
    TransferHandle? handle,
  }) async {
    final file = File(path);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    handle?._bind(client);
    try {
      if (handle?.isCancelled ?? false) {
        throw const TransferCancelledException();
      }
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

      var sent = 0;
      final source = file.openRead().transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (chunk, sink) {
            if (handle?.isCancelled ?? false) {
              sink.addError(const TransferCancelledException());
              return;
            }
            sent += chunk.length;
            onProgress?.call(sent);
            sink.add(chunk);
          },
        ),
      );
      await request.addStream(source);

      final response = await request.close().timeout(
        const Duration(minutes: 5),
      );
      await response.drain<void>();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('upload failed: ${response.statusCode}');
      }
    } catch (_) {
      // Forcing the client closed on cancel surfaces as a generic socket error;
      // normalize anything that happens after a cancel into TransferCancelled.
      if (handle?.isCancelled ?? false) {
        throw const TransferCancelledException();
      }
      rethrow;
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
      '.bmp' => 'image/bmp',
      '.heic' => 'image/heic',
      '.heif' => 'image/heif',
      '.pdf' => 'application/pdf',
      '.txt' || '.md' => 'text/plain',
      _ => 'application/octet-stream',
    };
  }

  Map<String, Object?> _registerMessage() {
    return {
      ...identity.infoJson(),
      'port': boundPort(),
      'protocol': identity.protocol,
    };
  }

  int _parseSize(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  NearSendPayloadType _payloadTypeFor(String fileName, String? fileType) {
    final normalized = fileType?.trim().toLowerCase();
    if (normalized != null && normalized.startsWith('image/')) {
      return NearSendPayloadType.image;
    }
    return NearSendPayloadTypeX.fromFileName(fileName);
  }

  String _token() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

class TransferDeclinedException implements Exception {
  const TransferDeclinedException();

  @override
  String toString() => 'TransferDeclinedException';
}

class IncomingTransferRequest {
  const IncomingTransferRequest({
    required this.sessionId,
    required this.senderAlias,
    required this.senderFingerprint,
    required this.files,
    this.senderDevice,
    this.autoAccepted = false,
  });

  final String sessionId;
  final String senderAlias;
  final String senderFingerprint;
  final DiscoveredDevice? senderDevice;
  final List<IncomingTransferFile> files;
  final bool autoAccepted;

  int get totalSize => files.fold(0, (sum, file) => sum + file.size);
}

class IncomingTransferFile {
  const IncomingTransferFile({
    required this.id,
    required this.name,
    required this.size,
  });

  final String id;
  final String name;
  final int size;
}

class _ReceiveSession {
  _ReceiveSession({
    required this.sessionId,
    required this.senderAlias,
    required this.senderFingerprint,
    required this.files,
    this.senderDevice,
  });

  final String sessionId;
  final String senderAlias;
  final String senderFingerprint;
  final Map<String, _IncomingFile> files;
  final DiscoveredDevice? senderDevice;
  final decision = Completer<bool>();
  bool cancelled = false;
}

class _IncomingFile {
  _IncomingFile({
    required this.id,
    required this.name,
    required this.size,
    required this.fileType,
    required this.token,
  });

  final String id;
  final String name;
  final int size;
  final String? fileType;
  final String token;
  int received = 0;
  bool completed = false;
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

class _ResolvedPrepareUpload {
  const _ResolvedPrepareUpload({required this.target, required this.response});

  final DiscoveredDevice target;
  final _PrepareUploadResponse response;
}
