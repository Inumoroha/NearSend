import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/discovered_device.dart';
import '../models/nearsend_message.dart';
import 'localsend_file_transfer.dart';
import 'localsend_identity.dart';

class LocalSendDiscoveryServer {
  LocalSendDiscoveryServer({
    required this.identity,
    bool requireReceiveConfirmation = false,
    bool Function(String senderFingerprint)? shouldConfirmIncoming,
  }) {
    _fileTransfer = LocalSendFileTransferService(
      identity: identity,
      requireReceiveConfirmation: requireReceiveConfirmation,
      shouldConfirmIncoming: shouldConfirmIncoming,
    );
  }

  final LocalSendIdentity identity;
  late final LocalSendFileTransferService _fileTransfer;
  final _deviceController = StreamController<DiscoveredDevice>.broadcast();
  final _messageController = StreamController<NearSendMessage>.broadcast();
  final _diagnosticController = StreamController<String>.broadcast();
  StreamSubscription<NearSendMessage>? _fileSubscription;
  HttpServer? _server;

  static const fallbackPorts = [
    53317,
    53318,
    53319,
    53320,
    53321,
    53322,
    54317,
    54318,
    54319,
    54320,
    54321,
    54322,
    55317,
    55318,
    55319,
    55320,
    55321,
    55322,
    57317,
    57318,
    57319,
    57320,
    57321,
    57322,
  ];

  Stream<DiscoveredDevice> get devices => _deviceController.stream;
  Stream<NearSendMessage> get messages => _messageController.stream;
  Stream<String> get diagnostics => _diagnosticController.stream;
  Stream<IncomingTransferRequest> get incomingRequests =>
      _fileTransfer.incomingRequests;
  Stream<IncomingTransferProgress> get incomingProgress =>
      _fileTransfer.incomingProgress;

  int get boundPort => _server?.port ?? identity.port;
  bool get isRunning => _server != null;

  bool acceptIncomingTransfer(String sessionId) =>
      _fileTransfer.acceptIncoming(sessionId);
  bool declineIncomingTransfer(String sessionId) =>
      _fileTransfer.declineIncoming(sessionId);
  bool cancelIncomingTransfer(String sessionId) =>
      _fileTransfer.cancelIncoming(sessionId);

  Future<void> start() async {
    if (_server != null) return;
    _server = await _bindServer();
    _fileSubscription = _fileTransfer.incomingFiles.listen(
      _messageController.add,
    );
    _server!.listen(_handleRequest);
  }

  Future<void> dispose() async {
    await _server?.close(force: true);
    _server = null;
    await _fileSubscription?.cancel();
    await _fileTransfer.dispose();
    await _messageController.close();
    await _diagnosticController.close();
    await _deviceController.close();
  }

  Future<HttpServer> _bindServer() async {
    Object? lastError;
    final candidates = [
      identity.port,
      for (final port in fallbackPorts)
        if (port != identity.port) port,
    ];
    for (final port in candidates) {
      try {
        if (identity.https) {
          return await HttpServer.bindSecure(
            InternetAddress.anyIPv4,
            port,
            identity.securityContext.toServerSecurityContext(),
            shared: true,
          );
        }
        return await HttpServer.bind(
          InternetAddress.anyIPv4,
          port,
          shared: true,
        );
      } catch (error) {
        lastError = error;
      }
    }

    Error.throwWithStackTrace(
      lastError ?? StateError('Unable to bind LocalSend discovery server'),
      StackTrace.current,
    );
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final method = request.method.toUpperCase();
    final path = request.uri.path;

    if (method == 'GET' &&
        (path == '/api/localsend/v1/info' ||
            path == '/api/localsend/v2/info')) {
      await _handleInfo(request);
      return;
    }

    if (method == 'POST' &&
        (path == '/api/localsend/v1/register' ||
            path == '/api/localsend/v2/register')) {
      await _handleRegister(request);
      return;
    }

    if (method == 'POST' &&
        (path == '/api/localsend/v1/send-request' ||
            path == '/api/localsend/v2/prepare-upload')) {
      await _handlePrepareUpload(request);
      return;
    }

    if (method == 'POST' &&
        (path == '/api/localsend/v1/send' ||
            path == '/api/localsend/v2/upload')) {
      await _handleUpload(request);
      return;
    }

    if (method == 'POST' &&
        (path == '/api/localsend/v1/cancel' ||
            path == '/api/localsend/v2/cancel')) {
      await _handleCancel(request);
      return;
    }

    if (method == 'POST' && path == '/api/nearsend/v1/message') {
      await _handleNearSendMessage(request);
      return;
    }

    await _respondJson(request, HttpStatus.notFound, {'message': 'Not found'});
  }

  Future<void> _handleInfo(HttpRequest request) async {
    final fingerprint = request.uri.queryParameters['fingerprint'];
    if (fingerprint != 'nearsend-healthcheck') {
      _diagnosticController.add(_requestSource(request, 'info'));
    }
    final senderFingerprint = fingerprint;
    if (senderFingerprint == identity.fingerprint) {
      await _respondJson(request, HttpStatus.preconditionFailed, {
        'message': 'Self-discovered',
      });
      return;
    }

    await _respondJson(request, HttpStatus.ok, _selfInfoJson());
  }

  Future<void> _handlePrepareUpload(HttpRequest request) async {
    _diagnosticController.add(_requestSource(request, 'prepare-upload'));
    try {
      final response = await _fileTransfer.handlePrepareUpload(request);
      await _respondJson(request, HttpStatus.ok, response);
    } on TransferDeclinedException {
      await _respondJson(request, HttpStatus.forbidden, {
        'message': 'File request declined by recipient',
      });
    } catch (_) {
      await _respondJson(request, HttpStatus.badRequest, {
        'message': 'Request body malformed',
      });
    }
  }

  Future<void> _handleUpload(HttpRequest request) async {
    try {
      await _fileTransfer.handleUpload(request);
      await _respondJson(request, HttpStatus.ok, {'ok': true});
    } on TransferCancelledException {
      await _respondJson(request, HttpStatus.forbidden, {
        'message': 'Transfer cancelled',
      });
    } catch (_) {
      await _respondJson(request, HttpStatus.forbidden, {
        'message': 'Invalid upload',
      });
    }
  }

  Future<void> _handleCancel(HttpRequest request) async {
    final sessionId = request.uri.queryParameters['sessionId'];
    if (sessionId == null || sessionId.isEmpty) {
      await _respondJson(request, HttpStatus.badRequest, {
        'message': 'Missing sessionId',
      });
      return;
    }
    _fileTransfer.cancelIncoming(sessionId);
    await _respondJson(request, HttpStatus.ok, {'ok': true});
  }

  Future<void> _handleRegister(HttpRequest request) async {
    _diagnosticController.add(_requestSource(request, 'register'));
    final body = await utf8.decodeStream(request);
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      await _respondJson(request, HttpStatus.badRequest, {
        'message': 'Request body malformed',
      });
      return;
    }

    if (decoded['fingerprint'] == identity.fingerprint) {
      await _respondJson(request, HttpStatus.preconditionFailed, {
        'message': 'Self-discovered',
      });
      return;
    }

    final device = DiscoveredDevice.fromLocalSendJson(
      decoded,
      request.connectionInfo?.remoteAddress.address ?? '',
      fallbackPort: identity.port,
      fallbackHttps: identity.https,
    );
    if (device != null) {
      _deviceController.add(device);
    }

    await _respondJson(request, HttpStatus.ok, _selfInfoJson());
  }

  Future<void> _handleNearSendMessage(HttpRequest request) async {
    try {
      await _handleJsonMessage(request);
    } catch (_) {
      if (request.response.headers.contentType == null) {
        await _respondJson(request, HttpStatus.badRequest, {
          'message': 'Message body malformed',
        });
      }
    }
  }

  Future<void> _handleJsonMessage(HttpRequest request) async {
    final body = await utf8.decodeStream(request);
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      await _respondJson(request, HttpStatus.badRequest, {
        'message': 'Message body malformed',
      });
      return;
    }

    _messageController.add(
      NearSendMessage(
        senderFingerprint: _stringField(decoded, 'senderFingerprint'),
        senderAlias: _stringField(decoded, 'senderAlias', fallback: 'Peer'),
        text: _stringField(decoded, 'text'),
        receivedAt: DateTime.now(),
        attachment: await _attachmentFromJson(decoded),
        senderDevice: _senderDeviceFromJson(
          decoded['senderDevice'],
          request.connectionInfo?.remoteAddress.address ?? '',
        ),
      ),
    );
    _diagnosticController.add(_requestSource(request, 'message'));
    await _respondJson(request, HttpStatus.ok, {'ok': true});
  }

  DiscoveredDevice? _senderDeviceFromJson(Object? value, String remoteIp) {
    if (value is! Map<String, dynamic> || remoteIp.isEmpty) return null;
    return DiscoveredDevice.fromLocalSendJson(
      value,
      remoteIp,
      fallbackPort: identity.port,
      fallbackHttps: identity.https,
    );
  }

  Future<NearSendAttachment?> _attachmentFromJson(
    Map<String, dynamic> json,
  ) async {
    final name = json['attachmentName'];
    final encoded = json['attachmentBase64'];
    if (name is! String || encoded is! String) return null;

    final bytes = base64Decode(encoded);
    final directory = await Directory.systemTemp.createTemp(
      'nearsend_incoming_',
    );
    final safeName = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${directory.path}${Platform.pathSeparator}$safeName');
    await file.writeAsBytes(bytes, flush: true);
    return NearSendAttachment(
      path: file.path,
      name: name,
      size: bytes.length,
      type: _payloadTypeFromJson(json['type'], name),
    );
  }

  NearSendPayloadType _payloadTypeFromJson(Object? value, String fileName) {
    if (value is String && value.toLowerCase() == 'image') {
      return NearSendPayloadType.image;
    }
    return NearSendPayloadTypeX.fromFileName(fileName);
  }

  String _stringField(
    Map<String, dynamic> json,
    String key, {
    String fallback = '',
  }) {
    final value = json[key];
    return value is String ? value : fallback;
  }

  Future<void> _respondJson(
    HttpRequest request,
    int statusCode,
    Map<String, Object?> body,
  ) async {
    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  }

  Map<String, Object?> _selfInfoJson() {
    return {
      ...identity.infoJson(),
      'port': boundPort,
      'protocol': identity.protocol,
    };
  }

  String _requestSource(HttpRequest request, String kind) {
    final remote = request.connectionInfo?.remoteAddress.address ?? 'unknown';
    return '$kind from $remote ${request.method} ${request.uri.path}';
  }
}
