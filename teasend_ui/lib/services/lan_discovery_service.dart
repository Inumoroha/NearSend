import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/discovered_device.dart';
import '../models/nearsend_message.dart';
import 'localsend_file_transfer.dart';
import 'localsend_discovery_server.dart';
import 'localsend_identity.dart';

class LanDiscoveryService {
  LanDiscoveryService({
    LocalSendIdentity? identity,
    this.multicastGroup = defaultMulticastGroup,
    bool Function(String senderFingerprint)? shouldConfirmIncoming,
  }) : identity = identity ?? LocalSendIdentity() {
    _server = LocalSendDiscoveryServer(
      identity: this.identity,
      requireReceiveConfirmation: true,
      shouldConfirmIncoming: shouldConfirmIncoming,
    );
  }

  static const defaultMulticastGroup = '224.0.0.167';
  static const _probeConnectionTimeout = Duration(milliseconds: 1000);
  static const _probeResponseTimeout = Duration(seconds: 2);
  static const _maxProbeConcurrency = 48;
  static const _maxProbeSubnets = 16;

  final LocalSendIdentity identity;
  final String multicastGroup;
  late final LocalSendDiscoveryServer _server;

  final _deviceController = StreamController<DiscoveredDevice>.broadcast();
  final _sockets = <RawDatagramSocket>[];
  StreamSubscription<DiscoveredDevice>? _serverSubscription;
  Timer? _announceTimer;
  bool _started = false;
  Future<void>? _starting;
  bool _probing = false;

  Stream<DiscoveredDevice> get devices => _deviceController.stream;
  Stream<NearSendMessage> get messages => _server.messages;
  Stream<String> get diagnostics => _server.diagnostics;
  Stream<IncomingTransferRequest> get incomingRequests =>
      _server.incomingRequests;
  int get boundPort => _server.boundPort;
  bool get isRunning => _server.isRunning;

  bool acceptIncomingTransfer(String sessionId) =>
      _server.acceptIncomingTransfer(sessionId);

  bool declineIncomingTransfer(String sessionId) =>
      _server.declineIncomingTransfer(sessionId);

  Future<List<String>> localConnectEndpoints() async {
    final interfaces = await _networkInterfaces();
    final candidates = [
      for (final interface in interfaces)
        for (final address in interface.addresses.where(_isLanAddress))
          _LocalAddressCandidate(interface, address),
    ]..sort(_compareLocalAddressCandidates);

    return [
      for (final candidate in candidates)
        '${candidate.address.address}:$boundPort',
    ];
  }

  Future<void> start() async {
    if (_started) return;
    final starting = _starting;
    if (starting != null) {
      await starting;
      return;
    }

    final startFuture = _start();
    _starting = startFuture;
    try {
      await startFuture;
    } finally {
      _starting = null;
    }
  }

  Future<void> _start() async {
    _serverSubscription = _server.devices.listen(_deviceController.add);
    try {
      await _server.start();
      _started = true;
    } catch (_) {
      await _serverSubscription?.cancel();
      _serverSubscription = null;
      _started = false;
      rethrow;
    }

    _runInBackground(_bindMulticastListener());
    _runInBackground(announce());

    // 每10秒重新公告一次，确保新设备能快速发现我们
    _announceTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _runInBackground(announce());
    });
  }

  Future<void> announce() async {
    if (!_server.isRunning) {
      await start();
      return;
    }
    await _sendAnnouncementBurst();
    _runInBackground(_probeLocalSubnets());
  }

  void _runInBackground(Future<void> future) {
    unawaited(future.catchError((_) {}));
  }

  Future<void> _bindMulticastListener() async {
    RawDatagramSocket? socket;
    try {
      // LocalSend 协议使用固定端口 53317 接收多播消息
      // 尝试与 HTTP 服务器共享端口（所有平台都启用 reusePort）
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        53317,
        reuseAddress: true,
        reusePort: true,
      );
      socket.multicastHops = 1;
      socket.multicastLoopback = true;
    } catch (_) {
      // Windows 上端口共享可能失败，多播监听无法工作
      // 主动探测仍可发现设备，所以静默失败
      return;
    }

    final group = InternetAddress(multicastGroup);
    var joinedAnyInterface = false;
    final interfaces = await _networkInterfaces();
    for (final interface in interfaces) {
      try {
        socket.joinMulticast(group, interface);
        joinedAnyInterface = true;
      } catch (_) {
        // Some adapters, VPNs, or virtual NICs cannot join multicast.
      }
    }

    if (!joinedAnyInterface) {
      try {
        socket.joinMulticast(group);
        joinedAnyInterface = true;
      } catch (_) {
        // Keep the socket alive anyway; active probing can still discover peers.
      }
    }

    socket.listen((event) {
      if (event == RawSocketEvent.read) {
        _handleDatagram(socket?.receive());
      }
    });
    _sockets.add(socket);
  }

  Future<void> _sendAnnouncementBurst() async {
    for (final delay in const [50, 200, 500, 1000, 2000]) {
      await Future<void>.delayed(Duration(milliseconds: delay));
      await _sendUdpDiscovery(_multicastMessage(announce: true));
    }
  }

  /// Sends a multicast datagram out of every LAN interface.
  ///
  /// Binding the sender to each interface address (instead of a single
  /// `anyIPv4` socket) pins the egress interface, so the packet is not confined
  /// to the OS default route — which on multi-homed hosts is often a virtual /
  /// VPN / wrong adapter, leaving Wi-Fi peers unable to hear the announcement.
  Future<void> _sendUdpDiscovery(Map<String, Object?> message) async {
    final payload = utf8.encode(jsonEncode(message));
    final interfaces = await _networkInterfaces();
    final addresses = <InternetAddress>[
      for (final interface in interfaces)
        for (final address in interface.addresses.where(_isLanAddress)) address,
    ];
    if (addresses.isEmpty) {
      addresses.add(InternetAddress.anyIPv4);
    }

    for (final address in addresses) {
      RawDatagramSocket? socket;
      try {
        socket = await RawDatagramSocket.bind(address, 0, reuseAddress: true);
        socket.multicastHops = 1;
        socket.multicastLoopback = true;
        socket.broadcastEnabled = true;
        // LocalSend 协议使用固定端口 53317 接收多播消息
        socket.send(payload, InternetAddress(multicastGroup), 53317);
        for (final target in _broadcastTargetsFor(address)) {
          socket.send(payload, target, 53317);
        }
      } catch (_) {
        // Some adapters cannot send multicast; keep trying the rest.
      } finally {
        socket?.close();
      }
    }
  }

  Future<void> dispose() async {
    _announceTimer?.cancel();
    _announceTimer = null;
    for (final socket in _sockets) {
      socket.close();
    }
    _sockets.clear();
    await _serverSubscription?.cancel();
    _serverSubscription = null;
    await _server.dispose();
    _started = false;
    await _deviceController.close();
  }

  List<InternetAddress> _broadcastTargetsFor(InternetAddress address) {
    final parts = address.address.split('.');
    if (parts.length != 4) return [InternetAddress('255.255.255.255')];

    return [
      InternetAddress('${parts[0]}.${parts[1]}.${parts[2]}.255'),
      InternetAddress('255.255.255.255'),
    ];
  }

  Future<List<NetworkInterface>> _networkInterfaces() async {
    final interfaces = await NetworkInterface.list(
      includeLinkLocal: false,
      type: InternetAddressType.IPv4,
    );

    return interfaces
        .where((interface) => interface.addresses.any(_isLanAddress))
        .toList(growable: false);
  }

  Future<void> _probeLocalSubnets() async {
    if (_probing) return;
    _probing = true;
    try {
      final hosts = await _probeHosts();
      await _runWithConcurrency(hosts, _maxProbeConcurrency, _probeHost);
    } finally {
      _probing = false;
    }
  }

  Future<List<String>> _probeHosts() async {
    final interfaces = await _networkInterfaces();
    final candidates = [
      for (final interface in interfaces)
        for (final address in interface.addresses.where(_isProbeableLanAddress))
          _LocalAddressCandidate(interface, address),
    ]..sort(_compareLocalAddressCandidates);

    final localAddresses = candidates
        .map((candidate) => candidate.address.address)
        .toSet();
    final hosts = <String>{};
    final seenSubnets = <String>{};
    for (final candidate in candidates) {
      final parts = candidate.address.address.split('.');
      if (parts.length != 4) continue;
      final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
      if (!seenSubnets.add(subnet)) continue;
      if (seenSubnets.length > _maxProbeSubnets) break;

      for (var host = 1; host <= 254; host++) {
        final address = '$subnet.$host';
        if (!localAddresses.contains(address)) {
          hosts.add(address);
        }
      }
    }
    return hosts.toList(growable: false);
  }

  bool _isProbeableLanAddress(InternetAddress address) {
    if (!_isLanAddress(address)) return false;
    final parts = address.address.split('.');
    if (parts.length != 4) return false;
    return !(parts[0] == '169' && parts[1] == '254');
  }

  Future<void> _runWithConcurrency<T>(
    List<T> items,
    int limit,
    Future<void> Function(T item) task,
  ) async {
    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final index = nextIndex++;
        if (index >= items.length) return;
        await task(items[index]);
      }
    }

    final workerCount = items.length < limit ? items.length : limit;
    await Future.wait([for (var i = 0; i < workerCount; i++) worker()]);
  }

  Future<void> _probeHost(String host) async {
    for (final port in _probePorts()) {
      for (final attempt in const [
        _ProbeAttempt('http', '/api/localsend/v2/info'),
        _ProbeAttempt('http', '/api/localsend/v1/info'),
      ]) {
        final device = await _tryProbeInfo(host, port, attempt);
        if (device == null) continue;
        if (device.fingerprint == identity.fingerprint) return;

        _deviceController.add(device);
        unawaited(_postRegister(device));
        return;
      }
    }
  }

  Future<DiscoveredDevice?> _tryProbeInfo(
    String host,
    int port,
    _ProbeAttempt attempt,
  ) async {
    final client = HttpClient()..connectionTimeout = _probeConnectionTimeout;
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
      final response = await request.close().timeout(_probeResponseTimeout);
      final body = await utf8
          .decodeStream(response)
          .timeout(_probeResponseTimeout);
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

  bool _isLanAddress(InternetAddress address) {
    if (address.isLoopback) return false;
    final parts = address.address.split('.');
    if (parts.length != 4) return false;
    final first = int.tryParse(parts[0]);
    final second = int.tryParse(parts[1]);
    if (first == null || second == null) return false;

    return first == 10 ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168) ||
        (first == 169 && second == 254);
  }

  int _compareLocalAddressCandidates(
    _LocalAddressCandidate a,
    _LocalAddressCandidate b,
  ) {
    final scoreDiff = _localAddressScore(b) - _localAddressScore(a);
    if (scoreDiff != 0) return scoreDiff;
    return a.address.address.compareTo(b.address.address);
  }

  int _localAddressScore(_LocalAddressCandidate candidate) {
    final name = candidate.interface.name.toLowerCase();
    final address = candidate.address.address;
    var score = 0;

    if (name.contains('wi-fi') ||
        name.contains('wifi') ||
        name.contains('wlan') ||
        name.contains('wireless')) {
      score += 40;
    }
    if (name.contains('ethernet') ||
        name.contains('以太网') ||
        name.contains('local area')) {
      score += 35;
    }
    if (_looksVirtualInterface(name)) {
      score -= 80;
    }

    if (address.startsWith('192.168.')) {
      score += 20;
    } else if (address.startsWith('10.')) {
      score += 15;
    } else if (address.startsWith('172.')) {
      score += 5;
    } else if (address.startsWith('169.254.')) {
      score -= 20;
    }

    return score;
  }

  bool _looksVirtualInterface(String name) {
    return name.contains('virtual') ||
        name.contains('vmware') ||
        name.contains('virtualbox') ||
        name.contains('hyper-v') ||
        name.contains('hyperv') ||
        name.contains('wsl') ||
        name.contains('docker') ||
        name.contains('vethernet') ||
        name.contains('vpn') ||
        name.contains('tap') ||
        name.contains('tun') ||
        name.contains('loopback');
  }

  void _handleDatagram(Datagram? datagram) {
    if (datagram == null) return;

    try {
      final decoded = jsonDecode(utf8.decode(datagram.data));
      if (decoded is! Map<String, dynamic>) return;
      final device = DiscoveredDevice.fromLocalSendJson(
        decoded,
        datagram.address.address,
        fallbackPort: identity.port,
        fallbackHttps: identity.https,
      );
      if (device == null || device.fingerprint == identity.fingerprint) return;
      _deviceController.add(device);
      if (decoded['announcement'] == true || decoded['announce'] == true) {
        unawaited(_answerAnnouncement(device));
      }
    } catch (_) {
      // Ignore non-LocalSend multicast traffic.
    }
  }

  Future<void> _answerAnnouncement(DiscoveredDevice peer) async {
    final tcpAnswered = await _postRegister(peer);
    if (tcpAnswered) return;

    // Fall back to a multicast reply (announce:false) out of every interface.
    await _sendUdpDiscovery(_multicastMessage(announce: false));
  }

  Future<bool> _postRegister(DiscoveredDevice peer) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
    client.badCertificateCallback = (_, _, _) => true;
    try {
      final request = await client.postUrl(
        Uri(
          scheme: peer.https ? 'https' : 'http',
          host: peer.ip,
          port: peer.port,
          path: peer.version == '1.0'
              ? '/api/localsend/v1/register'
              : '/api/localsend/v2/register',
        ),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(_registerMessage()));
      final response = await request.close().timeout(
        const Duration(seconds: 2),
      );
      await response.drain<void>();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Map<String, Object?> _multicastMessage({required bool announce}) {
    return {
      ..._registerMessage(),
      'announcement': announce,
      'announce': announce,
    };
  }

  Map<String, Object?> _registerMessage() {
    return {
      ...identity.infoJson(),
      'port': boundPort,
      'protocol': identity.protocol,
    };
  }

  List<int> _probePorts() {
    return {
      identity.port,
      boundPort,
      ...LocalSendDiscoveryServer.fallbackPorts,
    }.toList(growable: false);
  }
}

class _LocalAddressCandidate {
  const _LocalAddressCandidate(this.interface, this.address);

  final NetworkInterface interface;
  final InternetAddress address;
}

class _ProbeAttempt {
  const _ProbeAttempt(this.scheme, this.path);

  final String scheme;
  final String path;
}
