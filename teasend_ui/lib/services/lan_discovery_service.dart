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
  }) : identity = identity ?? LocalSendIdentity() {
    _server = LocalSendDiscoveryServer(
      identity: this.identity,
      requireReceiveConfirmation: true,
    );
  }

  static const defaultMulticastGroup = '224.0.0.167';

  final LocalSendIdentity identity;
  final String multicastGroup;
  late final LocalSendDiscoveryServer _server;

  final _deviceController = StreamController<DiscoveredDevice>.broadcast();
  final _sockets = <RawDatagramSocket>[];
  StreamSubscription<DiscoveredDevice>? _serverSubscription;
  bool _started = false;

  Stream<DiscoveredDevice> get devices => _deviceController.stream;
  Stream<NearSendMessage> get messages => _server.messages;
  Stream<IncomingTransferRequest> get incomingRequests =>
      _server.incomingRequests;
  int get boundPort => _server.boundPort;

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

    if (candidates.isEmpty) return [];
    final best = candidates.first;
    return ['${best.address.address}:$boundPort'];
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;

    _serverSubscription = _server.devices.listen(_deviceController.add);
    await _server.start();

    final interfaces = await _networkInterfaces();
    for (final interface in interfaces) {
      try {
        final socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          identity.port,
          reuseAddress: true,
          reusePort: Platform.isLinux || Platform.isMacOS,
        );
        socket.joinMulticast(InternetAddress(multicastGroup), interface);
        socket.listen((event) {
          if (event == RawSocketEvent.read) {
            _handleDatagram(socket.receive());
          }
        });
        _sockets.add(socket);
      } catch (_) {
        // Some adapters, VPNs, or virtual NICs cannot join multicast.
      }
    }

    await announce();
  }

  Future<void> announce() async {
    for (final delay in const [100, 500, 2000]) {
      await Future<void>.delayed(Duration(milliseconds: delay));
      await _sendMulticast(_multicastMessage(announce: true));
    }
  }

  /// Sends a multicast datagram out of every LAN interface.
  ///
  /// Binding the sender to each interface address (instead of a single
  /// `anyIPv4` socket) pins the egress interface, so the packet is not confined
  /// to the OS default route — which on multi-homed hosts is often a virtual /
  /// VPN / wrong adapter, leaving Wi-Fi peers unable to hear the announcement.
  Future<void> _sendMulticast(Map<String, Object?> message) async {
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
        socket.send(payload, InternetAddress(multicastGroup), boundPort);
      } catch (_) {
        // Some adapters cannot send multicast; keep trying the rest.
      } finally {
        socket?.close();
      }
    }
  }

  Future<void> dispose() async {
    for (final socket in _sockets) {
      socket.close();
    }
    _sockets.clear();
    await _serverSubscription?.cancel();
    await _server.dispose();
    await _deviceController.close();
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
    await _sendMulticast(_multicastMessage(announce: false));
  }

  Future<bool> _postRegister(DiscoveredDevice peer) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
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
      request.write(jsonEncode(identity.registerJson()));
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
    final message = identity.multicastJson(announce: announce);
    message['port'] = boundPort;
    return message;
  }
}

class _LocalAddressCandidate {
  const _LocalAddressCandidate(this.interface, this.address);

  final NetworkInterface interface;
  final InternetAddress address;
}
