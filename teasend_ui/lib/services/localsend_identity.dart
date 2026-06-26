import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'android_platform.dart';
import 'localsend_security.dart';

class LocalSendIdentity {
  LocalSendIdentity({
    this.alias = 'NearSend',
    this.port = defaultPort,
    this.protocol = 'https',
    this.deviceModel = 'Unknown',
    this.deviceType = 'desktop',
    LocalSendSecurityContext? securityContext,
  }) {
    _securityContext = securityContext;
    fingerprint =
        securityContext?.certificateHash ??
        'nearsend-${DateTime.now().millisecondsSinceEpoch}';
  }

  static const defaultPort = 53317;
  static const protocolVersion = '2.1';
  static const _securityContextPreferenceKey = 'device_security_context';
  static const _fingerprintPreferenceKey = 'device_fingerprint';
  static const _aliasPreferenceKey = 'device_alias';

  /// Display name advertised to peers. Defaults to the OS device name
  /// (computer name / phone model) and can be overridden by the user.
  String alias;
  final int port;
  final String protocol;

  /// Model line peers show in device details. Platform-derived on startup.
  String deviceModel;

  /// 'desktop' or 'mobile'. Drives the icon peers render.
  String deviceType;

  /// Stable per-install identifier advertised to peers. Generated fresh on
  /// first launch, then overwritten with the persisted certificate hash on
  /// startup (see [LocalSendIdentity.restorePersistentFingerprint]) so the
  /// same physical device keeps one identity across restarts.
  late String fingerprint;

  LocalSendSecurityContext? _securityContext;

  LocalSendSecurityContext get securityContext {
    final context = _securityContext;
    if (context != null) return context;
    final generated = generateLocalSendSecurityContext();
    _applySecurityContext(generated);
    return generated;
  }

  bool get https => protocol == 'https';

  /// Loads the persisted certificate identity, or creates one on first launch.
  /// The method name is kept for existing callers/tests; for HTTPS the device
  /// fingerprint is the SHA-256 hash of the self-signed certificate.
  Future<void> restorePersistentFingerprint() async {
    final preferences = await SharedPreferences.getInstance();
    final restored = _restoreSecurityContext(preferences);
    if (restored != null) {
      _applySecurityContext(restored);
      return;
    }

    final generated = generateLocalSendSecurityContext();
    _applySecurityContext(generated);
    await preferences.setString(
      _securityContextPreferenceKey,
      jsonEncode(generated.toJson()),
    );
    await preferences.setString(_fingerprintPreferenceKey, fingerprint);
  }

  LocalSendSecurityContext? _restoreSecurityContext(
    SharedPreferences preferences,
  ) {
    final raw = preferences.getString(_securityContextPreferenceKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return LocalSendSecurityContext.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  void _applySecurityContext(LocalSendSecurityContext context) {
    _securityContext = context;
    fingerprint = context.certificateHash;
  }

  /// Resolves the platform-appropriate device type/model and the advertised
  /// [alias] (persisted user override, otherwise the OS device name). Must be
  /// awaited before discovery starts so peers see the right name.
  Future<void> restoreIdentity() async {
    final deviceName = await _resolveDeviceName();
    if (Platform.isAndroid) {
      deviceType = 'mobile';
      deviceModel = deviceName;
    } else {
      deviceType = 'desktop';
      deviceModel = 'Windows';
    }

    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_aliasPreferenceKey);
    alias = (saved != null && saved.trim().isNotEmpty)
        ? saved.trim()
        : deviceName;
  }

  /// Persists a user-chosen [alias] and applies it immediately. Callers should
  /// re-announce afterwards so peers pick up the new name.
  Future<void> updateAlias(String newAlias) async {
    final trimmed = newAlias.trim();
    if (trimmed.isEmpty) return;
    alias = trimmed;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_aliasPreferenceKey, trimmed);
  }

  /// The OS device name: phone model on Android, COMPUTERNAME / hostname on
  /// desktop, with a safe fallback.
  Future<String> _resolveDeviceName() async {
    if (Platform.isAndroid) {
      final model = await AndroidPlatform.deviceName();
      if (model != null && model.trim().isNotEmpty) return model.trim();
      return 'Android 设备';
    }
    final computerName = Platform.environment['COMPUTERNAME'];
    if (computerName != null && computerName.trim().isNotEmpty) {
      return computerName.trim();
    }
    try {
      final host = Platform.localHostname;
      if (host.trim().isNotEmpty) return host.trim();
    } catch (_) {
      // Fall through to the generic default.
    }
    return 'NearSend 设备';
  }

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
