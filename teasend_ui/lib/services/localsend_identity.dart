class LocalSendIdentity {
  LocalSendIdentity({
    this.alias = 'NearSend Windows',
    this.port = defaultPort,
    this.protocol = 'http',
    this.deviceModel = 'Windows',
    this.deviceType = 'desktop',
  }) : fingerprint = 'nearsend-${DateTime.now().millisecondsSinceEpoch}';

  static const defaultPort = 53317;
  static const protocolVersion = '2.1';

  final String alias;
  final int port;
  final String protocol;
  final String deviceModel;
  final String deviceType;
  final String fingerprint;

  bool get https => protocol == 'https';

  Map<String, Object?> infoJson() {
    return {
      'alias': alias,
      'version': protocolVersion,
      'deviceModel': deviceModel,
      'deviceType': deviceType,
      'fingerprint': fingerprint,
      'download': false,
    };
  }

  Map<String, Object?> registerJson() {
    return {...infoJson(), 'port': port, 'protocol': protocol};
  }

  Map<String, Object?> multicastJson({required bool announce}) {
    return {...registerJson(), 'announcement': announce, 'announce': announce};
  }
}
