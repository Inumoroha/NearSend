import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'models/discovered_device.dart';
import 'models/nearsend_message.dart';
import 'models/receive_history_entry.dart';
import 'services/android_platform.dart';
import 'services/conversation_store.dart';
import 'services/lan_discovery_service.dart';
import 'services/localsend_file_transfer.dart';
import 'services/localsend_identity.dart';
import 'services/manual_device_connector.dart';
import 'services/native_window_service.dart';
import 'services/nearsend_message_client.dart';
import 'services/receive_history_store.dart';
import 'services/temp_file_cleanup.dart';
import 'services/windows_clipboard_files.dart';
import 'services/windows_firewall_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Window management is desktop-only; skip it on mobile platforms.
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
  }
  runApp(const NearSendApp());
}

Color _sidebar = const Color(0xFFFFFFFF);
Color _sidebarMuted = const Color(0xFF64748B);
Color _panel = const Color(0xFFF4F6FA);
Color _surface = const Color(0xFFFFFFFF);
Color _line = const Color(0xFFE2E8F0);
Color _text = const Color(0xFF0F172A);
Color _muted = const Color(0xFF64748B);
Color _accent = const Color(0xFF2563EB);
Color _accentSoft = const Color(0xFFEFF6FF);
const _warning = Color(0xFFCB9A4B);
Color _bubbleMe = const Color(0xFFDBEAFE);
Color _chatBg = const Color(0xFFF8FAFC);
const _minimizeToTrayPreferenceKey = 'minimize_to_tray';
const _autoSaveEnabledPreferenceKey = 'auto_save_enabled';
const _autoSaveDirectoryPreferenceKey = 'auto_save_directory';
const _overwriteSameNameFilesPreferenceKey = 'overwrite_same_name_files';
const _themeModePreferenceKey = 'theme_mode';
const _themeColorPreferenceKey = 'theme_color';
const _clipboardAutoSendPreferenceKey = 'clipboard_auto_send_fingerprints';
const _favoriteDevicesPreferenceKey = 'favorite_device_fingerprints';
const _showImageCopyButtonPreferenceKey = 'show_image_copy_button';
const _deviceOfflineAfter = Duration(seconds: 120);
const _devicePresenceRefreshInterval = Duration(seconds: 5);

bool get _showFixedAndroidDownloadsDirectoryPlaceholder => false;

enum AppThemeMode { light, dark }

const _themeColorOptions = [
  Color(0xFF2563EB),
  Color(0xFF3D8F73),
  Color(0xFF0F172A),
  Color(0xFF8B6FD1),
  Color(0xFFD08B38),
  Color(0xFFE0527A),
];

class _ThemePalette {
  const _ThemePalette({
    required this.sidebar,
    required this.sidebarMuted,
    required this.panel,
    required this.surface,
    required this.line,
    required this.text,
    required this.muted,
    required this.accent,
    required this.accentSoft,
    required this.bubbleMe,
    required this.chatBg,
  });

  final Color sidebar;
  final Color sidebarMuted;
  final Color panel;
  final Color surface;
  final Color line;
  final Color text;
  final Color muted;
  final Color accent;
  final Color accentSoft;
  final Color bubbleMe;
  final Color chatBg;
}

_ThemePalette _buildPalette(AppThemeMode mode, Color accent) {
  if (mode == AppThemeMode.dark) {
    return _ThemePalette(
      sidebar: const Color(0xFF020617),
      sidebarMuted: const Color(0xFF94A3B8),
      panel: const Color(0xFF0F172A),
      surface: const Color(0xFF111827),
      line: const Color(0xFF1E293B),
      text: const Color(0xFFF8FAFC),
      muted: const Color(0xFFCBD5E1),
      accent: accent,
      accentSoft: Color.alphaBlend(
        accent.withValues(alpha: 0.18),
        const Color(0xFF111827),
      ),
      bubbleMe: Color.alphaBlend(
        accent.withValues(alpha: 0.20),
        const Color(0xFF111827),
      ),
      chatBg: const Color(0xFF020617),
    );
  }

  return _ThemePalette(
    sidebar: const Color(0xFFFFFFFF),
    sidebarMuted: const Color(0xFF64748B),
    panel: const Color(0xFFF4F6FA),
    surface: const Color(0xFFFFFFFF),
    line: const Color(0xFFE2E8F0),
    text: const Color(0xFF0F172A),
    muted: const Color(0xFF64748B),
    accent: accent,
    accentSoft: Color.alphaBlend(accent.withValues(alpha: 0.10), Colors.white),
    bubbleMe: Color.alphaBlend(accent.withValues(alpha: 0.18), Colors.white),
    chatBg: const Color(0xFFF8FAFC),
  );
}

void _applyPalette(_ThemePalette palette) {
  _sidebar = palette.sidebar;
  _sidebarMuted = palette.sidebarMuted;
  _panel = palette.panel;
  _surface = palette.surface;
  _line = palette.line;
  _text = palette.text;
  _muted = palette.muted;
  _accent = palette.accent;
  _accentSoft = palette.accentSoft;
  _bubbleMe = palette.bubbleMe;
  _chatBg = palette.chatBg;
}

String formatBytes(int size) {
  if (size <= 0) return '未知大小';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = size.toDouble();
  var index = 0;
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index++;
  }
  final digits = index == 0 || value >= 10 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[index]}';
}

class _SoftAppear extends StatelessWidget {
  const _SoftAppear({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 10),
    this.duration = const Duration(milliseconds: 260),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final delayed = delay == Duration.zero
            ? value
            : ((value * (duration + delay).inMilliseconds -
                          delay.inMilliseconds) /
                      duration.inMilliseconds)
                  .clamp(0.0, 1.0);
        return Opacity(
          opacity: delayed,
          child: Transform.translate(
            offset: Offset.lerp(offset, Offset.zero, delayed)!,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _PressableScale extends StatefulWidget {
  const _PressableScale({required this.child});

  final Widget child;

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class NearSendApp extends StatelessWidget {
  const NearSendApp({super.key, this.enableDiscovery = true});

  final bool enableDiscovery;

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      child: ShadApp.custom(
        theme: ShadThemeData(
          brightness: Brightness.light,
          colorScheme: const ShadZincColorScheme.light().copyWith(
            primary: _accent,
            ring: _accent,
            selection: _accent.withValues(alpha: 0.20),
          ),
          textTheme: ShadTextTheme(family: 'HarmonyOS Sans SC'),
          radius: const BorderRadius.all(Radius.circular(8)),
        ),
        darkTheme: ShadThemeData(
          brightness: Brightness.dark,
          colorScheme: const ShadZincColorScheme.dark().copyWith(
            primary: _accent,
            ring: _accent,
            selection: _accent.withValues(alpha: 0.28),
          ),
          textTheme: ShadTextTheme(family: 'HarmonyOS Sans SC'),
          radius: const BorderRadius.all(Radius.circular(8)),
        ),
        themeMode: ThemeMode.light,
        appBuilder: (context) {
          return MaterialApp(
            title: 'NearSend',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: _accent,
                brightness: Brightness.light,
              ),
              fontFamily: 'HarmonyOS Sans SC',
              scaffoldBackgroundColor: const Color(0xFFEDE9DE),
              dialogTheme: DialogThemeData(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              popupMenuTheme: PopupMenuThemeData(
                color: _surface,
                surfaceTintColor: Colors.transparent,
                elevation: 10,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: _line),
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: TextStyle(color: _text, fontSize: 13),
              ),
              useMaterial3: true,
            ),
            home: ChatPrototypePage(enableDiscovery: enableDiscovery),
          );
        },
      ),
    );
  }
}

class ChatPrototypePage extends StatefulWidget {
  const ChatPrototypePage({super.key, this.enableDiscovery = true});

  final bool enableDiscovery;

  @override
  State<ChatPrototypePage> createState() => _ChatPrototypePageState();
}

class _ChatPrototypePageState extends State<ChatPrototypePage>
    with WindowListener, TrayListener {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<MessageAttachment> _pendingAttachments = [];
  final _clipboardFiles = WindowsClipboardFiles();
  final _firewallService = const WindowsFirewallService();
  final _nativeWindow = const NativeWindowService();
  late final _discoveryService = LanDiscoveryService(
    shouldConfirmIncoming: _shouldConfirmIncomingTransfer,
  );
  late final _messageClient = NearSendMessageClient(
    identity: _discoveryService.identity,
    boundPort: () => _discoveryService.boundPort,
  );
  late final _localSendTransfer = LocalSendFileTransferService(
    identity: _discoveryService.identity,
    boundPort: () => _discoveryService.boundPort,
  );
  late final _manualConnector = ManualDeviceConnector(
    identity: _discoveryService.identity,
    boundPort: () => _discoveryService.boundPort,
  );
  final Map<String, DiscoveredDevice> _devices = {};
  final Map<String, Conversation> _deviceConversations = {};
  // Fingerprints of conversations the user explicitly deleted this session.
  // Discovery re-announces are ignored for these so a deleted chat does not
  // resurrect itself; a new inbound message clears the dismissal.
  final Set<String> _dismissedFingerprints = {};
  // Serializes _saveConversations so concurrent writes cannot land out of
  // order and persist a stale snapshot last.
  Future<void> _saveChain = Future<void>.value();
  final Map<String, TransferHandle> _transferHandles = {};
  final _historyStore = ReceiveHistoryStore();
  final _conversationStore = ConversationStore();
  TempFileCleanupService? _tempCleanup;
  List<ReceiveHistoryEntry> _receiveHistory = [];
  final Set<String> _clipboardAutoSendFingerprints = {};
  final Set<String> _favoriteDeviceFingerprints = {};
  Timer? _clipboardPollTimer;
  Timer? _presenceRefreshTimer;
  int _lastClipboardSequence = 0;
  StreamSubscription<DiscoveredDevice>? _discoverySubscription;
  StreamSubscription<NearSendMessage>? _messageSubscription;
  StreamSubscription<String>? _diagnosticSubscription;
  StreamSubscription<IncomingTransferRequest>? _incomingTransferSubscription;
  bool _isScanning = false;
  bool _messageSelectionMode = false;
  bool _showDeviceDetails = false;
  bool _autoSaveEnabled = false;
  bool _overwriteSameNameFiles = false;
  bool _minimizeToTrayEnabled = false;
  bool _showImageCopyButton = true;
  bool _trayReady = false;
  bool _quittingFromTray = false;
  bool _restoringSettings = true;
  bool _checkingFirewall = false;
  bool _repairingFirewall = false;
  WindowsFirewallStatus? _firewallStatus;
  WindowsFirewallRepairResult? _lastFirewallRepair;
  String? _lastInboundRequest;
  List<String> _localEndpointLines = const [];
  String? _localHttpStatus;
  AppThemeMode _themeMode = AppThemeMode.light;
  Color _themeColor = _themeColorOptions.first;
  MessageAttachment? _previewImage;
  String _scanStatus = '正在监听局域网设备';
  late String _autoSaveDirectory;
  String? _androidFallbackAutoSaveDirectory;
  _MainSection _activeSection = _MainSection.chats;
  int _selected = 0;
  // On narrow (phone) layouts, whether the full-screen chat page is open over
  // the conversation list. Ignored on wide layouts which show both side by side.
  bool _mobileChatOpen = false;
  final Set<String> _selectedMessageIds = {};
  final Map<String, IncomingTransferRequest> _incomingTransferRequests = {};
  final List<TransferTask> _transferTasks = [];

  final List<Conversation> _conversations = [];

  String get _defaultAutoSaveDirectory {
    if (Platform.isAndroid) return 'Download/NearSend';
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.trim().isNotEmpty) {
      return p.join(userProfile, 'Downloads', 'NearSend');
    }
    return p.join(Directory.current.path, 'NearSend Downloads');
  }

  /// On Android the primary save path is MediaStore (public Downloads). This
  /// only sets a writable app-specific fallback used if MediaStore ever fails,
  /// since Directory.current is not writable on Android.
  Future<void> _initAndroidFallbackDirectory() async {
    if (!Platform.isAndroid) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      if (!mounted) return;
      setState(() {
        _androidFallbackAutoSaveDirectory = p.join(dir.path, 'NearSend');
      });
    } catch (_) {
      // Keep whatever default was set; MediaStore is the real target anyway.
    }
  }

  @override
  void initState() {
    super.initState();
    _autoSaveDirectory = _defaultAutoSaveDirectory;
    if (Platform.isWindows) {
      windowManager.addListener(this);
      trayManager.addListener(this);
    }
    _applyPalette(_buildPalette(_themeMode, _themeColor));
    unawaited(_initAndroidFallbackDirectory());
    unawaited(_restoreWindowSettings());
    unawaited(_refreshFirewallStatus());
    unawaited(_loadReceiveHistory());
    unawaited(_initialize());
  }

  /// Loads persisted conversations BEFORE wiring discovery/message listeners,
  /// so restored chat history can't be clobbered by a fresh device discovery
  /// or an inbound message racing the load.
  Future<void> _initialize() async {
    // Pin a stable device identity before announcing, so this device is not
    // seen as a brand-new peer (and duplicated in peers' lists) on every launch.
    await _discoveryService.identity.restorePersistentFingerprint();
    // Resolve the platform device name / persisted custom alias before
    // announcing, so peers see the right name.
    await _discoveryService.identity.restoreIdentity();
    await _loadConversations();

    // 初始化临时文件清理服务
    final preferences = await SharedPreferences.getInstance();
    _tempCleanup = TempFileCleanupService(preferences: preferences);
    unawaited(_tempCleanup!.performStartupCleanup());

    if (!mounted) return;
    if (widget.enableDiscovery) {
      // Android drops inbound multicast unless a MulticastLock is held.
      unawaited(AndroidPlatform.acquireMulticastLock());
      unawaited(AndroidPlatform.startBackgroundReceiveService());
      _discoverySubscription = _discoveryService.devices.listen(_upsertDevice);
      _messageSubscription = _discoveryService.messages.listen(
        (message) => unawaited(_handleIncomingMessage(message)),
      );
      _diagnosticSubscription = _discoveryService.diagnostics.listen(
        _handleInboundDiagnostic,
      );
      _incomingTransferSubscription = _discoveryService.incomingRequests.listen(
        _handleIncomingTransferRequest,
      );
      unawaited(_startDiscovery());
      unawaited(_refreshReceiveDiagnostics());
      _startPresenceRefreshTimer();
    } else {
      setState(() {
        _scanStatus = '测试模式未启动局域网发现';
      });
    }
  }

  /// Restores persisted device conversations into [_deviceConversations].
  Future<void> _loadConversations() async {
    final stored = await _conversationStore.load();
    if (stored.isEmpty || !mounted) return;
    setState(() {
      stored.forEach((fingerprint, json) {
        // putIfAbsent guards against a conversation already created in-memory
        // (e.g. an inbound message that arrived before this completed).
        _deviceConversations.putIfAbsent(
          fingerprint,
          () => Conversation.fromJson(json),
        );
      });
    });
    _jumpToBottom();
  }

  /// Persists the current device conversations. Called after every mutation
  /// that changes chat history, device presence, or conversation metadata.
  ///
  /// Writes are chained on [_saveChain] so two near-simultaneous mutations
  /// cannot race in SharedPreferences and persist an out-of-date snapshot last.
  /// Each run reads the latest in-memory state at execution time, so the final
  /// write always reflects the newest data.
  Future<void> _saveConversations() {
    final next = _saveChain.then((_) => _persistConversations());
    // Swallow errors on the chain so one failed write doesn't wedge the rest.
    _saveChain = next.catchError((_) {});
    return next;
  }

  Future<void> _persistConversations() async {
    final encoded = <String, Map<String, dynamic>>{};
    _deviceConversations.forEach((fingerprint, conversation) {
      // Skip discovery-only placeholders: a device merely seen on the LAN but
      // never messaged should not become a permanent on-disk conversation.
      if (conversation.ephemeral) return;
      encoded[fingerprint] = conversation.toJson();
    });
    await _conversationStore.persist(encoded);
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
      unawaited(trayManager.destroy());
      unawaited(windowManager.setPreventClose(false));
    }
    _clipboardPollTimer?.cancel();
    _presenceRefreshTimer?.cancel();
    unawaited(AndroidPlatform.releaseMulticastLock());
    unawaited(AndroidPlatform.stopBackgroundReceiveService());
    unawaited(_discoverySubscription?.cancel());
    unawaited(_messageSubscription?.cancel());
    unawaited(_diagnosticSubscription?.cancel());
    unawaited(_incomingTransferSubscription?.cancel());
    unawaited(_localSendTransfer.dispose());
    unawaited(_discoveryService.dispose());
    _tempCleanup?.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startDiscovery() async {
    setState(() {
      _isScanning = true;
      _scanStatus = '正在搜索 LocalSend 设备...';
    });

    try {
      await _discoveryService.start();
      if (!mounted) return;
      setState(() {
        _scanStatus = _devices.isEmpty
            ? '未发现设备，可点击刷新重试'
            : '已发现 ${_devices.length} 台设备';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _scanStatus = '发现服务启动失败，请检查防火墙或端口';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _restoreWindowSettings() async {
    final preferences = await SharedPreferences.getInstance();
    final enabled = preferences.getBool(_minimizeToTrayPreferenceKey) ?? false;
    final autoSaveEnabled =
        preferences.getBool(_autoSaveEnabledPreferenceKey) ?? false;
    final savedAutoSaveDirectory = preferences.getString(
      _autoSaveDirectoryPreferenceKey,
    );
    final overwriteSameNameFiles =
        preferences.getBool(_overwriteSameNameFilesPreferenceKey) ?? false;
    final savedThemeMode = preferences.getString(_themeModePreferenceKey);
    final themeMode = savedThemeMode == AppThemeMode.dark.name
        ? AppThemeMode.dark
        : AppThemeMode.light;
    final savedThemeColor = preferences.getInt(_themeColorPreferenceKey);
    final themeColor = savedThemeColor == null
        ? _themeColorOptions.first
        : Color(savedThemeColor);
    final autoSendFingerprints =
        preferences.getStringList(_clipboardAutoSendPreferenceKey) ??
        const <String>[];
    final favoriteFingerprints =
        preferences.getStringList(_favoriteDevicesPreferenceKey) ??
        const <String>[];
    final showImageCopyButton =
        preferences.getBool(_showImageCopyButtonPreferenceKey) ?? true;
    _applyPalette(_buildPalette(themeMode, themeColor));

    if (enabled && Platform.isWindows) {
      await _nativeWindow.setMinimizeToTrayEnabled(true);
      await windowManager.setPreventClose(true);
      unawaited(_ensureTrayReady());
    }

    if (!mounted) return;
    setState(() {
      _minimizeToTrayEnabled = enabled;
      _autoSaveEnabled = autoSaveEnabled;
      if (savedAutoSaveDirectory != null &&
          savedAutoSaveDirectory.trim().isNotEmpty) {
        _autoSaveDirectory = savedAutoSaveDirectory;
      }
      _overwriteSameNameFiles = overwriteSameNameFiles;
      _themeMode = themeMode;
      _themeColor = themeColor;
      _showImageCopyButton = showImageCopyButton;
      _clipboardAutoSendFingerprints
        ..clear()
        ..addAll(autoSendFingerprints);
      _favoriteDeviceFingerprints
        ..clear()
        ..addAll(favoriteFingerprints);
      _restoringSettings = false;
    });
    _syncClipboardPolling();
  }

  bool _shouldConfirmIncomingTransfer(String senderFingerprint) {
    return !_favoriteDeviceFingerprints.contains(senderFingerprint);
  }

  Future<void> _setFavoriteDevice(String fingerprint, bool favorite) async {
    setState(() {
      if (favorite) {
        _favoriteDeviceFingerprints.add(fingerprint);
      } else {
        _favoriteDeviceFingerprints.remove(fingerprint);
      }
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _favoriteDevicesPreferenceKey,
      _favoriteDeviceFingerprints.toList(),
    );
    if (!mounted) return;
    final conversation = _deviceConversations[fingerprint];
    final name = conversation?.title ?? _devices[fingerprint]?.alias ?? '设备';
    _showToast(favorite ? '已收藏 $name，将自动接收文件' : '已取消收藏 $name');
  }

  void _toggleFavoriteDevice(String fingerprint) {
    final favorite = !_favoriteDeviceFingerprints.contains(fingerprint);
    unawaited(_setFavoriteDevice(fingerprint, favorite));
  }

  Future<void> _setThemeMode(AppThemeMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeModePreferenceKey, mode.name);
    setState(() {
      _themeMode = mode;
      _applyPalette(_buildPalette(_themeMode, _themeColor));
    });
  }

  Future<void> _setThemeColor(Color color) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_themeColorPreferenceKey, color.toARGB32());
    setState(() {
      _themeColor = color;
      _applyPalette(_buildPalette(_themeMode, _themeColor));
    });
  }

  Future<void> _setAutoSaveEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_autoSaveEnabledPreferenceKey, enabled);
    if (!mounted) return;
    setState(() {
      _autoSaveEnabled = enabled;
    });
  }

  Future<void> _setOverwriteSameNameFiles(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_overwriteSameNameFilesPreferenceKey, enabled);
    if (!mounted) return;
    setState(() {
      _overwriteSameNameFiles = enabled;
    });
  }

  Future<void> _setShowImageCopyButton(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_showImageCopyButtonPreferenceKey, enabled);
    if (!mounted) return;
    setState(() {
      _showImageCopyButton = enabled;
    });
  }

  Future<void> _refreshFirewallStatus() async {
    if (!Platform.isWindows || _checkingFirewall) return;
    if (mounted) {
      setState(() {
        _checkingFirewall = true;
      });
    }
    final status = await _firewallService.checkStatus();
    if (!mounted) return;
    setState(() {
      _firewallStatus = status;
      _checkingFirewall = false;
    });
  }

  Future<void> _refreshReceiveDiagnostics() async {
    if (!widget.enableDiscovery) return;
    final running = await _ensureReceiveServiceStarted();
    if (!running) return;
    await Future.wait([
      _refreshLocalEndpoints(),
      _refreshLocalHttpStatus(),
      if (Platform.isWindows) _refreshFirewallStatus(),
    ]);
  }

  Future<bool> _ensureReceiveServiceStarted() async {
    if (_discoveryService.isRunning) return true;
    try {
      await _discoveryService.start();
      return _discoveryService.isRunning;
    } catch (error) {
      if (!mounted) return false;
      setState(() {
        _localHttpStatus = 'server start failed: ${error.runtimeType}';
      });
      return false;
    }
  }

  Future<void> _refreshLocalEndpoints() async {
    if (!widget.enableDiscovery) return;
    try {
      final endpoints = await _discoveryService.localConnectEndpoints();
      if (!mounted) return;
      setState(() {
        _localEndpointLines = endpoints;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _localEndpointLines = const [];
      });
    }
  }

  Future<void> _refreshLocalHttpStatus() async {
    if (!widget.enableDiscovery) return;
    final running = await _ensureReceiveServiceStarted();
    if (!running) return;
    final port = _discoveryService.boundPort;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
    try {
      final request = await client.getUrl(
        Uri(
          scheme: 'http',
          host: '127.0.0.1',
          port: port,
          path: '/api/localsend/v2/info',
          queryParameters: {'fingerprint': 'nearsend-healthcheck'},
        ),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 2),
      );
      await response.drain<void>();
      if (!mounted) return;
      setState(() {
        _localHttpStatus = '127.0.0.1:$port -> HTTP ${response.statusCode}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _localHttpStatus = '127.0.0.1:$port -> ${error.runtimeType}';
      });
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _repairFirewall() async {
    if (!Platform.isWindows || _repairingFirewall) return;
    setState(() {
      _repairingFirewall = true;
    });
    try {
      final result = await _firewallService.repair();
      if (mounted) {
        setState(() {
          _lastFirewallRepair = result;
        });
      }
      await _refreshFirewallStatus();
      if (!mounted) return;
      final status = _firewallStatus;
      _showToast(
        result.success || (status != null && !status.needsRepair)
            ? '防火墙规则已修复'
            : result.started
            ? '修复未生效：${_firewallRepairSummary(result)}'
            : '未启动修复：请在 UAC 弹窗中允许管理员权限',
      );
    } catch (_) {
      if (mounted) {
        _showToast('防火墙修复失败，请以管理员身份运行或手动放行端口');
      }
    } finally {
      if (mounted) {
        setState(() {
          _repairingFirewall = false;
        });
      }
    }
  }

  String _firewallRepairSummary(WindowsFirewallRepairResult result) {
    final log = result.log?.trim();
    if (log == null || log.isEmpty) return result.message;
    final lines = log
        .split(RegExp(r'\r?\n'))
        .where((line) {
          return line.trim().isNotEmpty;
        })
        .toList(growable: false);
    if (lines.isEmpty) return result.message;
    return lines.last.length > 80
        ? '${lines.last.substring(0, 80)}...'
        : lines.last;
  }

  Future<void> _setMinimizeToTrayEnabled(bool enabled) async {
    setState(() {
      _minimizeToTrayEnabled = enabled;
    });

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_minimizeToTrayPreferenceKey, enabled);

    if (!Platform.isWindows) return;

    if (enabled) {
      await _nativeWindow.setMinimizeToTrayEnabled(true);
      await windowManager.setPreventClose(true);
      try {
        await _ensureTrayReady();
      } catch (_) {
        if (mounted) {
          _showToast('托盘图标初始化失败，但已拦截关闭窗口');
        }
        return;
      }
      _showToast('已开启最小化到托盘');
    } else {
      await _nativeWindow.setMinimizeToTrayEnabled(false);
      await windowManager.setPreventClose(false);
      await trayManager.destroy();
      _trayReady = false;
      _showToast('已关闭最小化到托盘');
    }
  }

  Future<void> _ensureTrayReady() async {
    if (!Platform.isWindows || _trayReady) return;

    await trayManager.setIcon('windows/runner/resources/app_icon.ico');
    await trayManager.setToolTip('NearSend');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: '显示 NearSend'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: '退出'),
        ],
      ),
    );
    _trayReady = true;
  }

  Future<void> _hideToTray() async {
    if (!Platform.isWindows || !_minimizeToTrayEnabled) return;
    try {
      await _ensureTrayReady();
    } catch (_) {
      // Preventing close is more important than the tray icon; keep the app
      // alive even if the icon cannot be created for this run.
    }
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }

  Future<void> _restoreFromTray() async {
    if (!Platform.isWindows) return;
    await windowManager.setSkipTaskbar(false);
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _quitFromTray() async {
    if (!Platform.isWindows) return;
    _quittingFromTray = true;
    await trayManager.destroy();
    await _nativeWindow.setMinimizeToTrayEnabled(false);
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onWindowMinimize() {}

  @override
  void onWindowClose() {
    if (_minimizeToTrayEnabled && !_quittingFromTray) {
      unawaited(_hideToTray());
    }
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_restoreFromTray());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        unawaited(_restoreFromTray());
      case 'quit':
        unawaited(_quitFromTray());
    }
  }

  Future<void> _refreshDevices() async {
    setState(() {
      _isScanning = true;
      _scanStatus = '正在刷新局域网设备...';
    });

    try {
      await _discoveryService.announce();
      if (!mounted) return;
      setState(() {
        _scanStatus = _devices.isEmpty
            ? '未发现设备，可确认对方已打开 LocalSend'
            : '已发现 ${_devices.length} 台设备';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  bool _isDeviceOnline(DiscoveredDevice device) {
    return DateTime.now().difference(device.lastSeen) <= _deviceOfflineAfter;
  }

  bool _isDeviceFingerprintOnline(String fingerprint) {
    final device = _devices[fingerprint];
    return device != null && _isDeviceOnline(device);
  }

  void _startPresenceRefreshTimer() {
    _presenceRefreshTimer?.cancel();
    _presenceRefreshTimer = Timer.periodic(_devicePresenceRefreshInterval, (_) {
      if (!mounted || _devices.isEmpty) return;
      setState(() {});
    });
  }

  void _upsertDevice(DiscoveredDevice device, {bool force = false}) {
    if (!mounted) return;
    // The user deleted this conversation this session; ignore its discovery
    // re-announces so it does not silently come back. A fresh inbound message
    // clears the dismissal (see _handleIncomingMessage).
    if (!force && _dismissedFingerprints.contains(device.fingerprint)) return;
    if (force) {
      _dismissedFingerprints.remove(device.fingerprint);
    }
    // The conversation list is re-sorted by lastSeen on every announce, so a
    // bare positional _selected would silently jump to a different peer when
    // any other device re-announces. Pin the selection to its stable key and
    // recompute the index after the list order changes.
    final selectedKey = _selectionKeyAt(_selected);
    setState(() {
      _devices[device.fingerprint] = device;
      final existing = _deviceConversations[device.fingerprint];
      if (existing == null || existing.device == null) {
        // 如果会话不存在或没有设备信息，创建新的会话（包含设备信息）
        _deviceConversations.putIfAbsent(
          device.fingerprint,
          () => _deviceConversation(device),
        );
      } else {
        // 如果会话已存在且有设备信息，只更新设备信息（保留消息历史）
        _deviceConversations[device.fingerprint] = Conversation(
          title: device.alias,
          subtitle: '${device.displayModel} · ${device.endpoint}',
          status:
              '${device.deviceType.label} 在线 · LocalSend ${device.version} · ${device.ip}:${device.port}',
          time: existing.time,
          initials: device.initials,
          messages: existing.messages,
          files: existing.files,
          unread: existing.unread,
          device: device,
          ephemeral: existing.ephemeral,
        );
      }
      _scanStatus = '已发现 ${_devices.length} 台设备';
      _selected = _indexForSelectionKey(selectedKey);
      if (_selected < 0 || _selected >= _visibleConversations.length) {
        _selected = 0;
      }
    });
    unawaited(_saveConversations());
  }

  /// A stable identifier for the conversation currently shown at [index],
  /// independent of the list's sort order. Network conversations are keyed by
  /// device fingerprint; static ones by their offset into [_conversations].
  String? _selectionKeyAt(int index) {
    if (index < 0) return null;
    final networkCount = _networkConversationCount;
    if (index < networkCount) {
      final keys = _networkConversationKeys;
      return index < keys.length ? 'net:${keys[index]}' : null;
    }
    final staticIndex = index - networkCount;
    return staticIndex < _conversations.length ? 'static:$staticIndex' : null;
  }

  /// Resolves a key from [_selectionKeyAt] back to a list index against the
  /// current ordering. Returns 0 if the keyed conversation no longer exists.
  int _indexForSelectionKey(String? key) {
    if (key == null) return _selected;
    if (key.startsWith('net:')) {
      final fingerprint = key.substring(4);
      final position = _networkConversationKeys.indexOf(fingerprint);
      if (position >= 0) return position;
    } else if (key.startsWith('static:')) {
      final staticIndex = int.tryParse(key.substring(7));
      if (staticIndex != null && staticIndex < _conversations.length) {
        return _networkConversationCount + staticIndex;
      }
    }
    return 0;
  }

  List<Conversation> get _visibleConversations {
    final devices = _devices.values.toList()
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    final knownFingerprints = devices
        .map((device) => device.fingerprint)
        .toSet();
    final orphanConversations = _deviceConversations.entries
        .where((entry) => !knownFingerprints.contains(entry.key))
        .map((entry) => entry.value);
    return [
      ...devices.map(
        (device) => _deviceConversations.putIfAbsent(
          device.fingerprint,
          () => _deviceConversation(device),
        ),
      ),
      ...orphanConversations,
      ..._conversations,
    ];
  }

  int get _networkConversationCount {
    return _visibleConversations.length - _conversations.length;
  }

  List<String> get _networkConversationKeys {
    final devices = _devices.values.toList()
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    final knownFingerprints = devices
        .map((device) => device.fingerprint)
        .toSet();
    return [
      ...devices.map((device) => device.fingerprint),
      ..._deviceConversations.keys.where(
        (fingerprint) => !knownFingerprints.contains(fingerprint),
      ),
    ];
  }

  Conversation _deviceConversation(DiscoveredDevice device) {
    return Conversation(
      title: device.alias,
      subtitle: '${device.displayModel} · ${device.endpoint}',
      status:
          '${device.deviceType.label} 在线 · LocalSend ${device.version} · ${device.ip}:${device.port}',
      time: '在线',
      initials: device.initials,
      messages: [
        ChatMessage('刚刚发现 ${device.alias}', system: true),
        ChatMessage(
          '设备地址：${device.endpoint}\n指纹：${device.fingerprint}\n协议版本：${device.version}',
          sender: device.initials,
        ),
      ],
      files: [],
      device: device,
      ephemeral: true,
    );
  }

  Future<void> _handleIncomingMessage(NearSendMessage message) async {
    if (!mounted) return;
    final incomingDevice = message.senderDevice;
    final fingerprint =
        incomingDevice?.fingerprint ??
        (message.senderFingerprint.isEmpty
            ? 'incoming-${message.senderAlias}'
            : message.senderFingerprint);
    final device = incomingDevice ?? _devices[fingerprint];
    final attachment = await _incomingAttachment(message.attachment);
    if (!mounted) return;
    if (attachment != null) {
      unawaited(_recordReceiveHistory(message.senderAlias, attachment));
      _markIncomingFileReceived(message, attachment);
    }
    final chatMessage = ChatMessage(
      message.text,
      sender: message.senderAlias.initials,
      attachment: attachment,
    );

    setState(() {
      // A new inbound message un-deletes a previously dismissed conversation.
      _dismissedFingerprints.remove(fingerprint);
      if (incomingDevice != null) {
        _devices[incomingDevice.fingerprint] = incomingDevice;
        final existing = _deviceConversations[incomingDevice.fingerprint];
        if (existing != null && existing.device == null) {
          _deviceConversations[incomingDevice.fingerprint] = Conversation(
            title: incomingDevice.alias,
            subtitle: existing.subtitle,
            status:
                '${incomingDevice.deviceType.label} 在线 · ${incomingDevice.endpoint}',
            time: existing.time,
            initials: incomingDevice.initials,
            messages: existing.messages,
            files: existing.files,
            unread: existing.unread,
            device: incomingDevice,
            ephemeral: existing.ephemeral,
          );
        }
      }
      _deviceConversations[fingerprint] =
          (_deviceConversations[fingerprint] ??
                  Conversation(
                    title: message.senderAlias,
                    subtitle: 'NearSend 消息',
                    status: device == null
                        ? '通过 NearSend 收到消息'
                        : '${device.deviceType.label} 在线 · ${device.endpoint}',
                    time: '刚刚',
                    initials: message.senderAlias.initials,
                    messages: [],
                    files: [],
                    device: device,
                  ))
              .copyWith(device: device)
              .appendMessage(
                chatMessage,
                subtitle: _messageSubtitle(chatMessage),
                unread: _selectedConversationFingerprint == fingerprint ? 0 : 1,
              );
    });
    unawaited(_saveConversations());
    _scrollToBottom();
  }

  void _handleInboundDiagnostic(String source) {
    if (!mounted) return;
    setState(() {
      _lastInboundRequest =
          '${DateTime.now().toIso8601String().substring(11, 19)} $source';
    });
  }

  void _handleIncomingTransferRequest(IncomingTransferRequest request) {
    if (!mounted) return;
    setState(() {
      final device = request.senderDevice;
      if (device != null) {
        _devices[device.fingerprint] = device;
        _deviceConversations.putIfAbsent(
          device.fingerprint,
          () => _deviceConversation(device),
        );
      }
      if (request.autoAccepted) {
        _incomingTransferRequests.remove(request.sessionId);
      } else {
        _incomingTransferRequests[request.sessionId] = request;
      }
      _upsertTransferTask(
        TransferTask.incomingRequest(
          id: request.sessionId,
          peerAlias: request.senderAlias,
          fileName: request.files.length == 1
              ? request.files.first.name
              : '${request.files.length} 个文件',
          fileCount: request.files.length,
          totalBytes: request.totalSize,
        ).copyWith(
          status: request.autoAccepted
              ? TransferTaskStatus.transferring
              : TransferTaskStatus.waiting,
          subtitle: request.autoAccepted ? '收藏设备，正在自动接收' : '等待确认',
        ),
        notify: false,
      );
      if (!request.autoAccepted) {
        _activeSection = _MainSection.transfers;
      }
    });
    _showToast(
      request.autoAccepted
          ? '正在自动接收 ${request.senderAlias} 的 ${request.files.length} 个文件'
          : '${request.senderAlias} 请求发送 ${request.files.length} 个文件',
    );
  }

  void _acceptIncomingTransfer(String sessionId) {
    final request = _incomingTransferRequests.remove(sessionId);
    if (request == null) return;
    final accepted = _discoveryService.acceptIncomingTransfer(sessionId);
    setState(() {
      _upsertTransferTask(
        TransferTask.incomingRequest(
          id: sessionId,
          peerAlias: request.senderAlias,
          fileName: request.files.length == 1
              ? request.files.first.name
              : '${request.files.length} 个文件',
          fileCount: request.files.length,
          totalBytes: request.totalSize,
        ).copyWith(
          status: accepted
              ? TransferTaskStatus.transferring
              : TransferTaskStatus.failed,
          subtitle: accepted ? '等待对方上传' : '请求已失效',
        ),
        notify: false,
      );
    });
  }

  void _declineIncomingTransfer(String sessionId) {
    final request = _incomingTransferRequests.remove(sessionId);
    if (request == null) return;
    _discoveryService.declineIncomingTransfer(sessionId);
    setState(() {
      _upsertTransferTask(
        TransferTask.incomingRequest(
          id: sessionId,
          peerAlias: request.senderAlias,
          fileName: request.files.length == 1
              ? request.files.first.name
              : '${request.files.length} 个文件',
          fileCount: request.files.length,
          totalBytes: request.totalSize,
        ).copyWith(
          status: TransferTaskStatus.cancelled,
          progress: 1,
          subtitle: '已拒绝',
        ),
        notify: false,
      );
    });
  }

  void _markIncomingFileReceived(
    NearSendMessage message,
    MessageAttachment attachment,
  ) {
    final sessionId = message.sessionId;
    if (sessionId == null) return;
    final index = _transferTasks.indexWhere((item) => item.id == sessionId);
    if (index == -1) return;
    final task = _transferTasks[index];
    final fileCount = task.fileCount <= 0 ? 1 : task.fileCount;
    final nextReceived = (task.receivedFiles + 1).clamp(0, fileCount);
    final complete = nextReceived >= fileCount;
    final progress = complete
        ? 1.0
        : (nextReceived / fileCount).clamp(0.0, 1.0);
    _incomingTransferRequests.remove(sessionId);
    _upsertTransferTask(
      task.copyWith(
        receivedFiles: nextReceived,
        progress: progress,
        status: complete
            ? TransferTaskStatus.completed
            : TransferTaskStatus.transferring,
        subtitle: complete ? '已接收：${attachment.name}' : '正在接收',
      ),
    );
  }

  Future<MessageAttachment?> _incomingAttachment(
    NearSendAttachment? attachment,
  ) async {
    if (attachment == null) return null;
    if (!_autoSaveEnabled) {
      return MessageAttachment.fromNearSend(attachment);
    }

    try {
      final savedPath = await _autoSaveIncomingFile(attachment);
      return MessageAttachment.fromNearSend(attachment, savedPath: savedPath);
    } catch (_) {
      if (mounted) {
        _showToast('自动保存失败，文件暂时保留在临时目录');
      }
      return MessageAttachment.fromNearSend(attachment);
    }
  }

  Future<String> _autoSaveIncomingFile(NearSendAttachment attachment) async {
    final safeName = attachment.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    // On Android, prefer the user-selected SAF directory. Without a custom
    // directory, keep using public Downloads/NearSend via MediaStore.
    if (Platform.isAndroid) {
      final selectedDirectory = _autoSaveDirectory.trim();
      if (selectedDirectory.isNotEmpty &&
          selectedDirectory != _defaultAutoSaveDirectory) {
        final saved = await AndroidPlatform.saveToSelectedDirectory(
          sourcePath: attachment.path,
          fileName: safeName,
          mimeType: _mimeForName(safeName),
        );
        if (saved != null) return saved;
      }

      final saved = await AndroidPlatform.saveToDownloads(
        sourcePath: attachment.path,
        fileName: safeName,
        mimeType: _mimeForName(safeName),
      );
      if (saved != null) return saved;
      // Fall through to direct file IO if MediaStore failed.
    }

    final directoryPath = Platform.isAndroid
        ? (_androidFallbackAutoSaveDirectory ?? _defaultAutoSaveDirectory)
        : (_autoSaveDirectory.trim().isEmpty
              ? _defaultAutoSaveDirectory
              : _autoSaveDirectory.trim());
    final directory = Directory(directoryPath);
    await directory.create(recursive: true);

    final destination = _overwriteSameNameFiles
        ? File(p.join(directory.path, safeName))
        : await _availableDestination(directory, safeName);
    await File(attachment.path).copy(destination.path);
    return destination.path;
  }

  String _mimeForName(String fileName) {
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

  Future<File> _availableDestination(
    Directory directory,
    String fileName,
  ) async {
    final baseName = p.basenameWithoutExtension(fileName);
    final extension = p.extension(fileName);
    var candidate = File(p.join(directory.path, fileName));
    var index = 1;
    while (await candidate.exists()) {
      candidate = File(p.join(directory.path, '$baseName ($index)$extension'));
      index++;
    }
    return candidate;
  }

  Future<void> _loadReceiveHistory() async {
    final entries = await _historyStore.load();
    if (!mounted) return;
    setState(() {
      _receiveHistory = entries;
    });
  }

  Future<void> _recordReceiveHistory(
    String senderAlias,
    MessageAttachment attachment,
  ) async {
    var autoSaved = false;
    try {
      final savedPath = attachment.savedPath;
      autoSaved =
          _autoSaveEnabled && savedPath != null && savedPath.trim().isNotEmpty;
    } catch (_) {
      autoSaved = false;
    }

    final entry = ReceiveHistoryEntry(
      id: 'history-${DateTime.now().microsecondsSinceEpoch}',
      fileName: attachment.name,
      size: attachment.size,
      senderAlias: senderAlias.isEmpty ? '未知设备' : senderAlias,
      path: attachment.savedPath ?? attachment.path,
      autoSaved: autoSaved,
      receivedAt: DateTime.now(),
    );

    if (!mounted) return;
    setState(() {
      _receiveHistory = [entry, ..._receiveHistory];
    });
    unawaited(_historyStore.persist(_receiveHistory));
  }

  Future<void> _openHistoryFile(ReceiveHistoryEntry entry) async {
    if (!File(entry.path).existsSync()) {
      _showToast('文件不存在，可能已被移动或删除');
      return;
    }
    try {
      // explorer often exits non-zero even on success; ignore the exit code.
      await Process.run('explorer', [entry.path]);
    } catch (_) {
      if (mounted) _showToast('无法打开文件');
    }
  }

  Future<void> _openHistoryFolder(ReceiveHistoryEntry entry) async {
    if (!File(entry.path).existsSync()) {
      _showToast('文件不存在，可能已被移动或删除');
      return;
    }
    try {
      await Process.run('explorer', ['/select,${entry.path}']);
    } catch (_) {
      if (mounted) _showToast('无法打开所在文件夹');
    }
  }

  Future<void> _deleteHistoryEntry(ReceiveHistoryEntry entry) async {
    final result = await _confirmHistoryRemoval(
      title: '删除记录',
      message: '从文件记录中移除「${entry.fileName}」。',
    );
    if (result == null || !mounted) return;

    setState(() {
      _receiveHistory = _receiveHistory
          .where((item) => item.id != entry.id)
          .toList();
    });
    unawaited(_historyStore.persist(_receiveHistory));

    if (result.alsoDeleteFile) {
      await _deleteFileQuietly(entry.path);
    }
  }

  Future<void> _clearReceiveHistory() async {
    if (_receiveHistory.isEmpty) return;
    final result = await _confirmHistoryRemoval(
      title: '清空历史',
      message: '清空全部 ${_receiveHistory.length} 条接收记录。',
    );
    if (result == null || !mounted) return;

    final removed = _receiveHistory;
    setState(() {
      _receiveHistory = [];
    });
    unawaited(_historyStore.persist(_receiveHistory));

    if (result.alsoDeleteFile) {
      for (final entry in removed) {
        await _deleteFileQuietly(entry.path);
      }
    }
  }

  Future<void> _deleteFileQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      if (mounted) _showToast('部分文件删除失败');
    }
  }

  Future<_HistoryRemoval?> _confirmHistoryRemoval({
    required String title,
    required String message,
  }) {
    var alsoDeleteFile = false;
    return showDialog<_HistoryRemoval>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return TeaDialog(
              title: Text(title),
              icon: Icons.delete_outline_rounded,
              width: 380,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(color: _text, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () =>
                        setLocalState(() => alsoDeleteFile = !alsoDeleteFile),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Checkbox(
                            value: alsoDeleteFile,
                            onChanged: (value) => setLocalState(
                              () => alsoDeleteFile = value ?? false,
                            ),
                            visualDensity: VisualDensity.compact,
                            activeColor: _accent,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '同时删除磁盘上的文件',
                            style: TextStyle(color: _text, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TeaDialogButton(
                  onPressed: () => Navigator.of(context).pop(),
                  label: '取消',
                ),
                TeaDialogButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(_HistoryRemoval(alsoDeleteFile: alsoDeleteFile)),
                  label: '删除',
                  filled: true,
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// The status a freshly-composed outgoing message should start in.
  ///
  /// - A local conversation with no associated device (static helper chats, or
  ///   persisted conversations whose `device` is null) has nothing to transmit
  ///   over the network: the message is immediately [MessageSendStatus.sent].
  /// - A real peer conversation (has an associated device) that is currently
  ///   offline cannot receive the message, so it starts
  ///   [MessageSendStatus.failed] rather than falsely reporting "sent" (the
  ///   previous behavior silently dropped it).
  /// - An online peer starts [MessageSendStatus.sending] while the transfer
  ///   runs.
  MessageSendStatus _outgoingInitialStatus() {
    final fingerprint = _selectedConversationFingerprint;
    if (fingerprint == null) return MessageSendStatus.sent;
    if (_isDeviceFingerprintOnline(fingerprint)) {
      return MessageSendStatus.sending;
    }
    final conversation = _deviceConversations[fingerprint];
    return conversation?.device != null
        ? MessageSendStatus.failed
        : MessageSendStatus.sent;
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty && _pendingAttachments.isEmpty) return;

    if (text.isNotEmpty) {
      final message = ChatMessage(
        text,
        isMe: true,
        status: _outgoingInitialStatus(),
      );
      _appendOutgoingMessage(message, subtitle: text);
      unawaited(_sendNetworkMessage(message));
    }

    final attachments = List<MessageAttachment>.from(_pendingAttachments);
    final attachmentMessages = <ChatMessage>[];
    for (final attachment in attachments) {
      final message = ChatMessage(
        '',
        isMe: true,
        attachment: attachment,
        status: _outgoingInitialStatus(),
      );
      attachmentMessages.add(message);
      _appendOutgoingMessage(message, subtitle: _messageSubtitle(message));
    }
    if (attachments.isNotEmpty) {
      unawaited(_sendNetworkAttachments(attachmentMessages));
    }

    _controller.clear();
    setState(_pendingAttachments.clear);
  }

  Future<void> _sendImage() async {
    final files = await openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Images',
          extensions: [
            'jpg',
            'jpeg',
            'png',
            'gif',
            'webp',
            'bmp',
            'heic',
            'heif',
          ],
        ),
      ],
    );
    _addPendingAttachments(await _cachePickedFilesForSending(files));
  }

  Future<void> _sendFile() async {
    final files = await openFiles();
    _addPendingAttachments(await _cachePickedFilesForSending(files));
  }

  Future<List<String>> _cachePickedFilesForSending(List<XFile> files) async {
    if (!Platform.isAndroid) {
      return files.map((file) => file.path).toList(growable: false);
    }

    final directory = await Directory.systemTemp.createTemp(
      'nearsend_android_send_',
    );
    final paths = <String>[];
    for (final file in files) {
      final safeName = _safeFileName(
        file.name.trim().isEmpty ? p.basename(file.path) : file.name,
      );
      final destination = await _availableDestination(directory, safeName);
      final sink = destination.openWrite();
      try {
        await sink.addStream(file.openRead());
      } finally {
        await sink.close();
      }
      paths.add(destination.path);
    }
    return paths;
  }

  String _safeFileName(String fileName) {
    final sanitized = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return sanitized.trim().isEmpty
        ? 'attachment-${DateTime.now().millisecondsSinceEpoch}'
        : sanitized;
  }

  void _addPendingAttachments(Iterable<String> paths) {
    final attachments = paths
        .where((path) => path.trim().isNotEmpty)
        .map(MessageAttachment.fromPath)
        .toList();
    if (attachments.isEmpty) return;

    setState(() {
      _pendingAttachments.addAll(attachments);
    });
  }

  void _removePendingAttachment(MessageAttachment attachment) {
    setState(() {
      _pendingAttachments.remove(attachment);
    });
  }

  Future<bool> _pasteImagesFromClipboard() async {
    final paths = await _clipboardFiles.readImagePaths();
    if (paths.isEmpty) return false;
    _addPendingAttachments(paths);
    return true;
  }

  Future<void> _handlePaste() async {
    final pastedImages = await _pasteImagesFromClipboard();
    if (pastedImages) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    final value = _controller.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final nextText = value.text.replaceRange(start, end, text);
    final caret = start + text.length;
    _controller.value = value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: caret),
      composing: TextRange.empty,
    );
  }

  Future<void> _showManualConnectDialog() async {
    // Pre-fill the local /24 prefix so the user only types the last octet —
    // the peer is on the same LAN, so the first three octets match ours.
    final prefix = await _localSubnetPrefix();
    if (!mounted) return;

    // The dialog owns its text controllers (see _ManualConnectDialog) so they
    // are disposed when its subtree unmounts — after the close animation — not
    // the instant showDialog returns. Disposing them here in a `finally` raced
    // the exit transition and crashed with "TextEditingController used after
    // being disposed" when the dialog was dismissed.
    final result = await showDialog<_ManualConnectInput>(
      context: context,
      builder: (context) => _ManualConnectDialog(
        initialIp: prefix,
        initialPort: _discoveryService.boundPort.toString(),
        onInvalid: () => _showToast('请输入有效的 IP 地址和端口号'),
      ),
    );

    if (result == null || !mounted) return;
    await _connectManualDevice(result.host, result.port);
  }

  /// Returns the local IPv4 /24 prefix (e.g. "192.168.1.") for pre-filling the
  /// manual-connect field, or an empty string if it can't be determined.
  Future<String> _localSubnetPrefix() async {
    if (!widget.enableDiscovery) return '';
    try {
      final endpoints = await _discoveryService.localConnectEndpoints();
      if (endpoints.isEmpty) return '';
      final host = endpoints.first.split(':').first;
      final parts = host.split('.');
      if (parts.length == 4 &&
          parts.every((part) => int.tryParse(part) != null)) {
        return '${parts[0]}.${parts[1]}.${parts[2]}.';
      }
    } catch (_) {
      // Fall through to the empty prefix; the field just starts blank.
    }
    return '';
  }

  /// Shows this device's info and lets the user rename it. The chosen name is
  /// the alias broadcast to peers (what they see in their device list).
  Future<void> _showDeviceInfoDialog() async {
    final identity = _discoveryService.identity;
    final endpoints = await _loadLocalConnectEndpoints();
    if (!mounted) return;
    final endpoint = endpoints.isNotEmpty
        ? endpoints.first
        : '本机端口 ${_discoveryService.boundPort}';

    final newAlias = await showDialog<String>(
      context: context,
      builder: (context) => _DeviceInfoDialog(
        initialAlias: identity.alias,
        deviceTypeLabel: identity.deviceType == 'mobile' ? '移动设备' : '桌面设备',
        deviceModel: identity.deviceModel,
        endpoint: endpoint,
        fingerprint: identity.fingerprint,
      ),
    );

    if (newAlias == null || newAlias.isEmpty || !mounted) return;
    if (newAlias == identity.alias) return;
    await identity.updateAlias(newAlias);
    if (!mounted) return;
    // Refresh the avatar/name display, and re-announce so peers pick up the
    // new name.
    setState(() {});
    if (widget.enableDiscovery) {
      unawaited(_discoveryService.announce());
    }
    _showToast('已更新设备名称为 $newAlias');
  }

  Future<void> _showConnectionQrDialog() async {
    final endpoints = await _loadLocalConnectEndpoints();
    if (!mounted) return;

    final endpoint = endpoints.first;
    final payload = jsonEncode({
      'type': 'nearsend-connect',
      'version': 1,
      'alias': _discoveryService.identity.alias,
      'fingerprint': _discoveryService.identity.fingerprint,
      'protocol': _discoveryService.identity.protocol,
      'endpoint': endpoint,
      'port': _discoveryService.boundPort,
      'localsendVersion': LocalSendIdentity.protocolVersion,
    });

    await showDialog<void>(
      context: context,
      builder: (context) {
        return TeaDialog(
          title: const Text('连接二维码'),
          icon: Icons.qr_code_rounded,
          width: 380,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _line),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: PrettyQrView.data(data: payload),
                ),
              ),
              const SizedBox(height: 14),
              SelectableText(
                endpoint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '其他 NearSend 客户端扫描后可连接本机',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TeaDialogButton(
              onPressed: () => Navigator.of(context).pop(),
              label: '关闭',
              filled: true,
            ),
          ],
        );
      },
    );
  }

  Future<List<String>> _loadLocalConnectEndpoints() async {
    if (!widget.enableDiscovery) {
      return ['127.0.0.1:${LocalSendIdentity.defaultPort}'];
    }

    try {
      final endpoints = await _discoveryService.localConnectEndpoints();
      if (endpoints.isNotEmpty) return endpoints;
    } catch (_) {
      // The dialog can still show the known default port if adapters fail.
    }
    return ['本机端口 ${_discoveryService.boundPort}，未找到局域网 IP'];
  }

  Future<void> _connectManualDevice(String host, int port) async {
    setState(() {
      _isScanning = true;
      _scanStatus = '正在连接 $host:$port...';
    });

    try {
      final device = await _manualConnector.connect(host: host, port: port);
      if (!mounted) return;
      _upsertDevice(device, force: true);
      final selectedIndex = _networkConversationKeys.indexOf(
        device.fingerprint,
      );
      setState(() {
        if (selectedIndex >= 0) {
          _selected = selectedIndex;
        } else {
          _selected = _indexForSelectionKey('net:${device.fingerprint}');
        }
        _activeSection = _MainSection.chats;
        _mobileChatOpen = true;
        _scanStatus = '已手动连接 ${device.alias}';
      });
    } on ManualConnectException catch (error) {
      if (!mounted) return;
      setState(() {
        _scanStatus = '手动连接失败';
      });
      _showManualConnectError(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _scanStatus = '手动连接失败';
      });
      _showManualConnectError('连接失败，请确认对方已打开 LocalSend 且端口可访问');
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _showManualConnectError(String message) {
    _showToast(message);
  }

  Future<void> _sendNetworkMessage(ChatMessage message) async {
    final target = _selectedDevice;
    if (target == null) {
      _updateMessageStatus(message.id, MessageSendStatus.failed);
      _appendSystemMessage('无法发送：设备信息缺失，请尝试刷新设备列表或重新连接。');
      return;
    }

    final attachment = message.attachment;
    if (attachment == null) {
      try {
        await _messageClient.sendText(target: target, text: message.text);
        _updateMessageStatus(message.id, MessageSendStatus.sent);
      } catch (e) {
        _updateMessageStatus(message.id, MessageSendStatus.failed);
        _appendSystemMessage(
          '文字发送失败：对方需要支持 NearSend 消息接口，或网络不可达。\n设备地址：${target.endpoint}',
        );
      }
      return;
    }

    await _sendAttachment(target: target, message: message);
  }

  Future<void> _sendNetworkAttachments(List<ChatMessage> messages) async {
    final target = _selectedDevice;
    if (target == null || messages.isEmpty) return;

    for (final message in messages) {
      await _sendAttachment(target: target, message: message);
    }
  }

  /// Sends a single attachment with byte-level progress and a cancel handle, so
  /// each message bubble reflects and can abort its own transfer independently.
  Future<void> _sendAttachment({
    required DiscoveredDevice target,
    required ChatMessage message,
  }) async {
    final attachment = message.attachment;
    if (attachment == null) return;

    final handle = TransferHandle();
    _transferHandles[message.id] = handle;
    _updateMessageProgress(message.id, 0);
    _upsertTransferTask(
      TransferTask.outgoing(
        id: message.id,
        peerAlias: target.alias,
        fileName: attachment.name,
        fileCount: 1,
        totalBytes: attachment.size,
      ),
    );
    try {
      await _localSendTransfer.sendFile(
        target: target,
        path: attachment.path,
        handle: handle,
        onProgress: (sent, total) {
          final progress = total == 0 ? 0.0 : sent / total;
          _updateMessageProgress(message.id, progress);
          _updateTransferTask(
            message.id,
            progress: progress,
            status: TransferTaskStatus.transferring,
            subtitle: '${formatBytes(sent)} / ${formatBytes(total)}',
          );
        },
      );
      _updateMessageStatus(message.id, MessageSendStatus.sent);
      _updateTransferTask(
        message.id,
        progress: 1,
        status: TransferTaskStatus.completed,
        subtitle: '发送完成',
      );
    } on TransferCancelledException {
      _updateMessageStatus(message.id, MessageSendStatus.cancelled);
      _updateTransferTask(
        message.id,
        status: TransferTaskStatus.cancelled,
        subtitle: '已取消',
      );
    } catch (_) {
      _updateMessageStatus(message.id, MessageSendStatus.failed);
      _updateTransferTask(
        message.id,
        status: TransferTaskStatus.failed,
        subtitle: '发送失败',
      );
      _appendSystemMessage('文件发送失败：对方可能拒绝接收、需要 PIN，或网络不可达。');
    } finally {
      _transferHandles.remove(message.id);
    }
  }

  Future<void> _retrySendAttachment(String messageId) async {
    final target = _selectedDevice;
    final message = _findMessage(messageId);
    final attachment = message?.attachment;
    if (target == null || message == null || attachment == null) return;

    _updateMessageStatus(messageId, MessageSendStatus.sending);
    await _sendAttachment(target: target, message: message);
  }

  Future<void> _copyAttachmentPath(MessageAttachment attachment) async {
    final copiedFile = _clipboardFiles.writeFilePaths([attachment.path]);
    if (!copiedFile) {
      await Clipboard.setData(ClipboardData(text: attachment.path));
    }
    if (!mounted) return;
    _showToast('已复制：${attachment.name}');
  }

  void _showToast(String message) {
    toastification.dismissAll(delayForAnimation: false);
    toastification.show(
      context: context,
      title: Text(message),
      type: ToastificationType.info,
      style: ToastificationStyle.minimal,
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 2),
      animationDuration: const Duration(milliseconds: 220),
      showProgressBar: false,
      closeOnClick: true,
      pauseOnHover: true,
      dragToClose: true,
      primaryColor: _accent,
      backgroundColor: _surface,
      foregroundColor: _text,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.fromLTRB(0, 12, 18, 0),
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: _line),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1F31302D),
          blurRadius: 22,
          offset: Offset(0, 10),
        ),
      ],
      closeButton: const ToastCloseButton(
        showType: CloseButtonShowType.onHover,
      ),
    );
  }

  ChatMessage? _findMessage(String messageId) {
    for (final conversation in [
      ..._deviceConversations.values,
      ..._conversations,
    ]) {
      for (final message in conversation.messages) {
        if (message.id == messageId) return message;
      }
    }
    return null;
  }

  void _updateMessageStatus(String messageId, MessageSendStatus status) {
    if (!mounted) return;
    setState(() {
      for (final entry in _deviceConversations.entries.toList()) {
        _deviceConversations[entry.key] = entry.value.updateMessageStatus(
          messageId,
          status,
        );
      }

      for (var index = 0; index < _conversations.length; index++) {
        _conversations[index] = _conversations[index].updateMessageStatus(
          messageId,
          status,
        );
      }
    });
    unawaited(_saveConversations());
  }

  void _updateMessageProgress(String messageId, double progress) {
    if (!mounted) return;
    setState(() {
      for (final entry in _deviceConversations.entries.toList()) {
        _deviceConversations[entry.key] = entry.value.updateMessageProgress(
          messageId,
          progress,
        );
      }

      for (var index = 0; index < _conversations.length; index++) {
        _conversations[index] = _conversations[index].updateMessageProgress(
          messageId,
          progress,
        );
      }
    });
  }

  void _upsertTransferTask(TransferTask task, {bool notify = true}) {
    void apply() {
      final index = _transferTasks.indexWhere((item) => item.id == task.id);
      if (index == -1) {
        _transferTasks.insert(0, task);
      } else {
        _transferTasks[index] = task;
      }
    }

    if (!notify || !mounted) {
      apply();
      return;
    }
    setState(apply);
  }

  void _updateTransferTask(
    String id, {
    double? progress,
    TransferTaskStatus? status,
    String? subtitle,
    int? receivedFiles,
  }) {
    if (!mounted) return;
    setState(() {
      final index = _transferTasks.indexWhere((item) => item.id == id);
      if (index == -1) return;
      _transferTasks[index] = _transferTasks[index].copyWith(
        progress: progress?.clamp(0.0, 1.0),
        status: status,
        subtitle: subtitle,
        receivedFiles: receivedFiles,
      );
    });
  }

  void _cancelTransfer(String messageId) {
    final handle = _transferHandles[messageId];
    if (handle == null) return;
    handle.cancel();
    unawaited(_localSendTransfer.cancelRemote(handle));
    _updateTransferTask(
      messageId,
      status: TransferTaskStatus.cancelled,
      subtitle: '正在取消',
    );
  }

  void _enterMessageSelectionMode() {
    setState(() {
      _messageSelectionMode = true;
      _showDeviceDetails = false;
      _selectedMessageIds.clear();
    });
  }

  void _exitMessageSelectionMode() {
    setState(() {
      _messageSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  void _toggleMessageSelection(String messageId) {
    setState(() {
      if (!_selectedMessageIds.add(messageId)) {
        _selectedMessageIds.remove(messageId);
      }
    });
  }

  void _toggleSelectAllMessages(Set<String> messageIds) {
    if (messageIds.isEmpty) return;

    setState(() {
      if (_selectedMessageIds.length == messageIds.length &&
          _selectedMessageIds.containsAll(messageIds)) {
        _selectedMessageIds.clear();
      } else {
        _selectedMessageIds
          ..clear()
          ..addAll(messageIds);
      }
    });
  }

  void _deleteSelectedMessages() {
    if (_selectedMessageIds.isEmpty) return;
    final ids = Set<String>.from(_selectedMessageIds);
    setState(() {
      if (_selected < _networkConversationCount) {
        final fingerprint = _selectedConversationFingerprint;
        if (fingerprint != null) {
          _deviceConversations[fingerprint] = _deviceConversations[fingerprint]!
              .removeMessages(ids);
        }
      } else {
        final conversationIndex = _selected - _networkConversationCount;
        _conversations[conversationIndex] = _conversations[conversationIndex]
            .removeMessages(ids);
      }
      _messageSelectionMode = false;
      _selectedMessageIds.clear();
    });
    unawaited(_saveConversations());
  }

  Future<void> _showConversationMenu(int index, Offset position) async {
    final fingerprint = index < _networkConversationCount
        ? _networkConversationKeys[index]
        : null;
    final isFavorite =
        fingerprint != null &&
        _favoriteDeviceFingerprints.contains(fingerprint);

    // Build the menu items with current theme
    final isDark = _themeMode == AppThemeMode.dark;
    final menuColor = isDark
        ? const Color(0xFF1F2937)
        : const Color(0xFFFFFFFF);
    final lineColor = isDark
        ? const Color(0xFF374151)
        : const Color(0xFFE2E8F0);
    final textColor = isDark
        ? const Color(0xFFF9FAFB)
        : const Color(0xFF1F2937);

    final action = await showMenu<_ConversationMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: _ConversationMenuAction.rename,
          child: _MenuItemWithColor(
            icon: Icons.edit_rounded,
            label: '重命名',
            color: textColor,
          ),
        ),
        if (fingerprint != null)
          PopupMenuItem(
            value: _ConversationMenuAction.favorite,
            child: _MenuItemWithColor(
              icon: isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
              label: isFavorite ? '取消收藏' : '收藏设备',
              color: textColor,
            ),
          ),
        PopupMenuItem(
          value: _ConversationMenuAction.clear,
          child: _MenuItemWithColor(
            icon: Icons.cleaning_services_rounded,
            label: '清空会话',
            color: textColor,
          ),
        ),
        PopupMenuItem(
          value: _ConversationMenuAction.delete,
          child: _MenuItemWithColor(
            icon: Icons.delete_outline_rounded,
            label: '删除会话',
            color: const Color(0xFFC85D4D),
          ),
        ),
      ],
      color: menuColor,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: lineColor),
        borderRadius: BorderRadius.circular(8),
      ),
      elevation: 10,
    );
    if (action == null || !mounted) return;

    switch (action) {
      case _ConversationMenuAction.rename:
        await _renameConversation(index);
      case _ConversationMenuAction.favorite:
        if (fingerprint != null) {
          _toggleFavoriteDevice(fingerprint);
        }
      case _ConversationMenuAction.clear:
        _clearConversation(index);
      case _ConversationMenuAction.delete:
        _deleteConversation(index);
    }
  }

  Future<void> _renameConversation(
    int index, {
    String dialogTitle = '重命名',
    String hintText = '输入会话名称',
  }) async {
    final conversation = _visibleConversations[index];
    final title = await showDialog<String>(
      context: context,
      builder: (context) => _TextPromptDialog(
        title: dialogTitle,
        hintText: hintText,
        initialValue: conversation.title,
        confirmLabel: '确定',
        icon: Icons.edit_rounded,
        width: 360,
      ),
    );
    if (title == null || title.isEmpty || !mounted) return;
    _updateConversationAt(index, (conversation) {
      return conversation.copyWith(title: title, initials: title.initials);
    });
  }

  void _clearConversation(int index) {
    _updateConversationAt(index, (conversation) {
      return conversation.copyWith(
        subtitle: '暂无聊天记录',
        unread: 0,
        messages: [],
        files: [],
      );
    });
  }

  void _deleteConversation(int index) {
    setState(() {
      if (index < _networkConversationCount) {
        final fingerprint = _networkConversationKeys[index];
        _devices.remove(fingerprint);
        _deviceConversations.remove(fingerprint);
        _dismissedFingerprints.add(fingerprint);
      } else {
        final conversationIndex = index - _networkConversationCount;
        _conversations.removeAt(conversationIndex);
      }
      // Guard the empty case: clamp throws when upperLimit < lowerLimit, which
      // happens when the last conversation is removed (length - 1 == -1).
      final maxIndex = _visibleConversations.length - 1;
      _selected = maxIndex < 0 ? 0 : _selected.clamp(0, maxIndex).toInt();
      _mobileChatOpen = false;
      _messageSelectionMode = false;
      _showDeviceDetails = false;
      _selectedMessageIds.clear();
    });
    unawaited(_saveConversations());
  }

  void _updateConversationAt(
    int index,
    Conversation Function(Conversation conversation) update,
  ) {
    setState(() {
      if (index < _networkConversationCount) {
        final fingerprint = _networkConversationKeys[index];
        final conversation = _deviceConversations[fingerprint];
        if (conversation != null) {
          _deviceConversations[fingerprint] = update(conversation);
        }
      } else {
        final conversationIndex = index - _networkConversationCount;
        _conversations[conversationIndex] = update(
          _conversations[conversationIndex],
        );
      }
    });
    unawaited(_saveConversations());
  }

  void _showChatsSection() {
    setState(() {
      _activeSection = _MainSection.chats;
    });
  }

  void _showTransfersSection() {
    setState(() {
      _activeSection = _MainSection.transfers;
      _messageSelectionMode = false;
      _showDeviceDetails = false;
      _selectedMessageIds.clear();
      _mobileChatOpen = false;
    });
  }

  void _showSettingsSection() {
    unawaited(_refreshLocalEndpoints());
    unawaited(_refreshLocalHttpStatus());
    setState(() {
      _activeSection = _MainSection.settings;
      _messageSelectionMode = false;
      _showDeviceDetails = false;
      _selectedMessageIds.clear();
    });
  }

  void _showThemeSection() {
    setState(() {
      _activeSection = _MainSection.theme;
      _messageSelectionMode = false;
      _showDeviceDetails = false;
      _selectedMessageIds.clear();
    });
  }

  void _showHistorySection() {
    setState(() {
      _activeSection = _MainSection.history;
      _messageSelectionMode = false;
      _showDeviceDetails = false;
      _selectedMessageIds.clear();
    });
  }

  void _openNavDrawer() => _scaffoldKey.currentState?.openDrawer();

  Future<void> _chooseAutoSaveDirectory() async {
    if (Platform.isAndroid) {
      final directory = await AndroidPlatform.chooseSaveDirectory();
      if (directory == null || !mounted) return;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_autoSaveDirectoryPreferenceKey, directory);
      if (!mounted) return;
      setState(() {
        _autoSaveDirectory = directory;
      });
      return;
    }

    final directory = await getDirectoryPath(
      initialDirectory: Directory(_autoSaveDirectory).existsSync()
          ? _autoSaveDirectory
          : null,
    );
    if (directory == null || !mounted) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_autoSaveDirectoryPreferenceKey, directory);
    if (!mounted) return;
    setState(() {
      _autoSaveDirectory = directory;
    });
  }

  void _showConversationDetails() {
    setState(() {
      _showDeviceDetails = true;
      _messageSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  void _hideConversationDetails() {
    setState(() {
      _showDeviceDetails = false;
    });
  }

  void _openImagePreview(MessageAttachment attachment) {
    setState(() {
      _previewImage = attachment;
    });
  }

  void _closeImagePreview() {
    setState(() {
      _previewImage = null;
    });
  }

  void _appendOutgoingMessage(ChatMessage message, {required String subtitle}) {
    setState(() {
      if (_selected < _networkConversationCount) {
        final fingerprint = _selectedConversationFingerprint;
        if (fingerprint == null) return;
        _deviceConversations[fingerprint] = _deviceConversations[fingerprint]!
            .appendMessage(message, subtitle: subtitle, unread: 0);
        return;
      }

      final conversationIndex = _selected - _networkConversationCount;
      _conversations[conversationIndex].messages.add(message);
      _conversations[conversationIndex] = _conversations[conversationIndex]
          .copyWith(subtitle: subtitle, time: '刚刚', unread: 0);
    });
    unawaited(_saveConversations());
    _scrollToBottom();
  }

  /// Appends an outgoing message to a specific device conversation (by
  /// fingerprint), creating the conversation if needed. Used by auto-send,
  /// which targets devices that may not be the currently open chat.
  void _appendOutgoingMessageTo(
    String fingerprint,
    ChatMessage message, {
    required String subtitle,
  }) {
    setState(() {
      final existing = _deviceConversations[fingerprint];
      final device = _devices[fingerprint];
      final base =
          existing ?? (device != null ? _deviceConversation(device) : null);
      if (base == null) return;
      _deviceConversations[fingerprint] = base.appendMessage(
        message,
        subtitle: subtitle,
        unread: _selectedConversationFingerprint == fingerprint ? 0 : 1,
      );
    });
    unawaited(_saveConversations());
    _scrollToBottom();
  }

  void _setClipboardAutoSendEnabled(String fingerprint, bool enabled) {
    setState(() {
      if (enabled) {
        _clipboardAutoSendFingerprints.add(fingerprint);
      } else {
        _clipboardAutoSendFingerprints.remove(fingerprint);
      }
    });
    unawaited(_persistClipboardAutoSend());
    _syncClipboardPolling();
  }

  Future<void> _persistClipboardAutoSend() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _clipboardAutoSendPreferenceKey,
      _clipboardAutoSendFingerprints.toList(),
    );
  }

  /// Starts polling when at least one device opted in, stops otherwise.
  void _syncClipboardPolling() {
    if (!Platform.isWindows) return;
    final shouldPoll = _clipboardAutoSendFingerprints.isNotEmpty;
    if (shouldPoll && _clipboardPollTimer == null) {
      // Ignore whatever is already on the clipboard when polling begins.
      _lastClipboardSequence = _clipboardFiles.clipboardSequence();
      _clipboardPollTimer = Timer.periodic(
        const Duration(milliseconds: 800),
        (_) => unawaited(_pollClipboard()),
      );
    } else if (!shouldPoll) {
      _clipboardPollTimer?.cancel();
      _clipboardPollTimer = null;
    }
  }

  Future<void> _pollClipboard() async {
    if (!Platform.isWindows || !mounted) return;
    final sequence = _clipboardFiles.clipboardSequence();
    if (sequence == 0 || sequence == _lastClipboardSequence) return;
    _lastClipboardSequence = sequence;
    if (!_clipboardFiles.hasClipboardBitmap()) return;

    final targets = _clipboardAutoSendFingerprints
        .where(_devices.containsKey)
        .toList();
    if (targets.isEmpty) return;

    final path = await _clipboardFiles.readBitmapImagePath();
    if (path == null || !mounted) return;

    final names = <String>[];
    for (final fingerprint in targets) {
      final device = _devices[fingerprint];
      if (device == null) continue;
      names.add(device.alias);
      unawaited(_autoSendClipboardImage(fingerprint, device, path));
    }
    if (names.isNotEmpty) {
      _showToast('已自动发送截图到 ${names.join('、')}');
    }
  }

  Future<void> _autoSendClipboardImage(
    String fingerprint,
    DiscoveredDevice device,
    String path,
  ) async {
    final attachment = MessageAttachment.fromPath(path);
    final message = ChatMessage(
      '',
      isMe: true,
      attachment: attachment,
      status: MessageSendStatus.sending,
    );
    _appendOutgoingMessageTo(
      fingerprint,
      message,
      subtitle: _messageSubtitle(message),
    );

    final handle = TransferHandle();
    _transferHandles[message.id] = handle;
    _updateMessageProgress(message.id, 0);
    _upsertTransferTask(
      TransferTask.outgoing(
        id: message.id,
        peerAlias: device.alias,
        fileName: attachment.name,
        fileCount: 1,
        totalBytes: attachment.size,
      ),
    );
    try {
      await _localSendTransfer.sendFile(
        target: device,
        path: path,
        handle: handle,
        onProgress: (sent, total) {
          final progress = total == 0 ? 0.0 : sent / total;
          _updateMessageProgress(message.id, progress);
          _updateTransferTask(
            message.id,
            progress: progress,
            status: TransferTaskStatus.transferring,
            subtitle: '${formatBytes(sent)} / ${formatBytes(total)}',
          );
        },
      );
      _updateMessageStatus(message.id, MessageSendStatus.sent);
      _updateTransferTask(
        message.id,
        progress: 1,
        status: TransferTaskStatus.completed,
        subtitle: '发送完成',
      );
    } on TransferCancelledException {
      _updateMessageStatus(message.id, MessageSendStatus.cancelled);
      _updateTransferTask(
        message.id,
        status: TransferTaskStatus.cancelled,
        subtitle: '已取消',
      );
    } catch (_) {
      _updateMessageStatus(message.id, MessageSendStatus.failed);
      _updateTransferTask(
        message.id,
        status: TransferTaskStatus.failed,
        subtitle: '发送失败',
      );
    } finally {
      _transferHandles.remove(message.id);
    }
  }

  void _appendSystemMessage(String text) {
    setState(() {
      if (_selected < _networkConversationCount) {
        final fingerprint = _selectedConversationFingerprint;
        if (fingerprint == null) return;
        _deviceConversations[fingerprint] = _deviceConversations[fingerprint]!
            .appendMessage(
              ChatMessage(text, system: true),
              subtitle: text,
              unread: 0,
            );
        return;
      }

      final conversationIndex = _selected - _networkConversationCount;
      _conversations[conversationIndex].messages.add(
        ChatMessage(text, system: true),
      );
      _conversations[conversationIndex] = _conversations[conversationIndex]
          .copyWith(subtitle: text, time: '刚刚', unread: 0);
    });
    unawaited(_saveConversations());
    _scrollToBottom();
  }

  DiscoveredDevice? get _selectedDevice {
    final fingerprint = _selectedConversationFingerprint;
    if (fingerprint == null) return null;
    // 尝试从设备列表获取
    final device = _devices[fingerprint];
    if (device != null) return device;
    // 如果设备列表中没有，尝试从会话中获取缓存的设备信息
    final conversation = _deviceConversations[fingerprint];
    return conversation?.device;
  }

  String? get _selectedConversationFingerprint {
    final keys = _networkConversationKeys;
    if (_selected < 0 || _selected >= keys.length) return null;
    return keys[_selected];
  }

  String _messageSubtitle(ChatMessage message) {
    final attachment = message.attachment;
    if (attachment == null) return message.text;
    return attachment.isImage
        ? '[图片] ${attachment.name}'
        : '[文件] ${attachment.name}';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Wide (tablet/desktop): list + chat side by side. Narrow (phone): one at a
    // time, navigating list -> chat -> back.
    final wide = width >= 880;
    // The left rail shows on tablets+desktop; true phones use a Drawer instead.
    final hasRail = width >= 560;
    final showDrawer = !hasRail;
    final conversationWidth = wide
        ? 320.0
        : hasRail
        ? width - 112
        : width;
    final conversations = _visibleConversations;
    final hasConversations = conversations.isNotEmpty;
    final safeSelected = hasConversations
        ? _selected.clamp(0, conversations.length - 1).toInt()
        : 0;
    final selected = hasConversations ? conversations[safeSelected] : null;
    final showChatPage = wide || _mobileChatOpen;

    return Scaffold(
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
      backgroundColor: _panel,
      drawer: showDrawer
          ? _NavDrawer(
              activeSection: _activeSection,
              deviceAlias: _discoveryService.identity.alias,
              onShowDeviceInfo: _showDeviceInfoDialog,
              onChats: _showChatsSection,
              onTransfers: _showTransfersSection,
              onTheme: _showThemeSection,
              onSettings: _showSettingsSection,
              onHistory: _showHistorySection,
            )
          : null,
      body: SafeArea(
        child: ColoredBox(
          color: _panel,
          child: Row(
            children: [
              if (hasRail)
                _Sidebar(
                  activeSection: _activeSection,
                  deviceAlias: _discoveryService.identity.alias,
                  onShowDeviceInfo: _showDeviceInfoDialog,
                  onChats: _showChatsSection,
                  onTransfers: _showTransfersSection,
                  onTheme: _showThemeSection,
                  onSettings: _showSettingsSection,
                  onHistory: _showHistorySection,
                ),
              if (_activeSection == _MainSection.theme)
                Expanded(
                  child: ThemePage(
                    themeMode: _themeMode,
                    themeColor: _themeColor,
                    onThemeModeChanged: _setThemeMode,
                    onThemeColorChanged: _setThemeColor,
                    onMenu: showDrawer ? _openNavDrawer : null,
                  ),
                )
              else if (_activeSection == _MainSection.history)
                Expanded(
                  child: HistoryPage(
                    entries: _receiveHistory,
                    onOpenFile: _openHistoryFile,
                    onOpenFolder: _openHistoryFolder,
                    onDelete: _deleteHistoryEntry,
                    onClear: _clearReceiveHistory,
                    onMenu: showDrawer ? _openNavDrawer : null,
                  ),
                )
              else if (_activeSection == _MainSection.transfers)
                Expanded(
                  child: TransfersPage(
                    tasks: _transferTasks,
                    incomingRequests: _incomingTransferRequests,
                    onAccept: _acceptIncomingTransfer,
                    onDecline: _declineIncomingTransfer,
                    onCancel: _cancelTransfer,
                    onMenu: showDrawer ? _openNavDrawer : null,
                  ),
                )
              else if (_activeSection == _MainSection.settings)
                Expanded(
                  child: SettingsPage(
                    autoSaveEnabled: _autoSaveEnabled,
                    autoSaveDirectory: _autoSaveDirectory,
                    overwriteSameNameFiles: _overwriteSameNameFiles,
                    showImageCopyButton: _showImageCopyButton,
                    minimizeToTrayEnabled: _minimizeToTrayEnabled,
                    restoringWindowSettings: _restoringSettings,
                    firewallStatus: _firewallStatus,
                    lastFirewallRepair: _lastFirewallRepair,
                    lastInboundRequest: _lastInboundRequest,
                    localEndpoints: _localEndpointLines,
                    localHttpStatus: _localHttpStatus,
                    checkingFirewall: _checkingFirewall,
                    repairingFirewall: _repairingFirewall,
                    tempCleanupService: _tempCleanup,
                    onAutoSaveChanged: _setAutoSaveEnabled,
                    onOverwriteSameNameFilesChanged: _setOverwriteSameNameFiles,
                    onShowImageCopyButtonChanged: _setShowImageCopyButton,
                    onMinimizeToTrayChanged: _setMinimizeToTrayEnabled,
                    onChooseDirectory: _chooseAutoSaveDirectory,
                    onRefreshFirewall: _refreshReceiveDiagnostics,
                    onRepairFirewall: _repairFirewall,
                    onMenu: showDrawer ? _openNavDrawer : null,
                  ),
                )
              else ...[
                // Phone with chat open: hide the list and show the chat full-width.
                if (!(_mobileChatOpen && !wide))
                  SizedBox(
                    width: conversationWidth,
                    child: ConversationPanel(
                      conversations: conversations,
                      favoriteFingerprints: _favoriteDeviceFingerprints,
                      onlineFingerprints: _devices.entries
                          .where((entry) => _isDeviceOnline(entry.value))
                          .map((entry) => entry.key)
                          .toSet(),
                      isScanning: _isScanning,
                      scanStatus: _scanStatus,
                      selected: _selected,
                      onRefresh: _refreshDevices,
                      onShowQrCode: _showConnectionQrDialog,
                      onManualConnect: _showManualConnectDialog,
                      onContextMenu: _showConversationMenu,
                      onMenu: showDrawer ? _openNavDrawer : null,
                      onEditRemark: (index) => _renameConversation(
                        index,
                        dialogTitle: '编辑备注',
                        hintText: '输入备注名称',
                      ),
                      onClearRecords: _clearConversation,
                      onDeleteConversation: _deleteConversation,
                      onSelect: (index) {
                        setState(() {
                          _selected = index;
                          _pendingAttachments.clear();
                          _messageSelectionMode = false;
                          _showDeviceDetails = false;
                          _previewImage = null;
                          _selectedMessageIds.clear();
                          if (!wide) _mobileChatOpen = true;
                          if (index < _networkConversationCount) {
                            final fingerprint = _networkConversationKeys[index];
                            final conversation =
                                _deviceConversations[fingerprint];
                            if (conversation != null &&
                                conversation.unread != 0) {
                              _deviceConversations[fingerprint] = conversation
                                  .copyWith(unread: 0);
                            }
                          } else {
                            final conversationIndex =
                                index - _networkConversationCount;
                            _conversations[conversationIndex] =
                                _conversations[conversationIndex].copyWith(
                                  unread: 0,
                                );
                          }
                        });
                        _jumpToBottom();
                        unawaited(_saveConversations());
                      },
                    ),
                  ),
                if (showChatPage)
                  Expanded(
                    child: selected == null
                        ? Center(
                            child: Text(
                              '暂无会话，等待局域网设备…',
                              style: TextStyle(color: _muted, fontSize: 14),
                            ),
                          )
                        : PopScope(
                            canPop: wide || !_mobileChatOpen,
                            onPopInvokedWithResult: (didPop, _) {
                              if (!didPop && !wide && _mobileChatOpen) {
                                setState(() => _mobileChatOpen = false);
                              }
                            },
                            child: ChatPanel(
                              conversation: selected,
                              controller: _controller,
                              scrollController: _scrollController,
                              pendingAttachments: _pendingAttachments,
                              onSend: _sendMessage,
                              onSendImage: _sendImage,
                              onSendFile: _sendFile,
                              onPasteImages: _handlePaste,
                              onRemovePendingAttachment:
                                  _removePendingAttachment,
                              selectionMode: _messageSelectionMode,
                              showDetails: _showDeviceDetails,
                              selectedMessageIds: _selectedMessageIds,
                              onEnterSelectionMode: _enterMessageSelectionMode,
                              onExitSelectionMode: _exitMessageSelectionMode,
                              onShowDetails: _showConversationDetails,
                              onHideDetails: _hideConversationDetails,
                              onToggleMessageSelection: _toggleMessageSelection,
                              onDeleteSelectedMessages: _deleteSelectedMessages,
                              onToggleSelectAllMessages:
                                  _toggleSelectAllMessages,
                              onRetrySendAttachment: _retrySendAttachment,
                              onCancelTransfer: _cancelTransfer,
                              onCopyAttachment: _copyAttachmentPath,
                              showImageCopyButton: _showImageCopyButton,
                              previewImage: _previewImage,
                              onPreviewImage: _openImagePreview,
                              onClosePreview: _closeImagePreview,
                              favoriteDevice:
                                  _selectedConversationFingerprint != null &&
                                  _favoriteDeviceFingerprints.contains(
                                    _selectedConversationFingerprint,
                                  ),
                              onFavoriteDeviceChanged: (value) {
                                final fingerprint =
                                    _selectedConversationFingerprint;
                                if (fingerprint != null) {
                                  unawaited(
                                    _setFavoriteDevice(fingerprint, value),
                                  );
                                }
                              },
                              clipboardAutoSendEnabled:
                                  _clipboardAutoSendFingerprints.contains(
                                    _selectedConversationFingerprint,
                                  ),
                              onClipboardAutoSendChanged: (value) {
                                final fingerprint =
                                    _selectedConversationFingerprint;
                                if (fingerprint != null) {
                                  _setClipboardAutoSendEnabled(
                                    fingerprint,
                                    value,
                                  );
                                }
                              },
                              onMobileBack: (!wide && _mobileChatOpen)
                                  ? () =>
                                        setState(() => _mobileChatOpen = false)
                                  : null,
                            ),
                          ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.activeSection,
    required this.deviceAlias,
    required this.onShowDeviceInfo,
    required this.onChats,
    required this.onTransfers,
    required this.onTheme,
    required this.onSettings,
    required this.onHistory,
  });

  final _MainSection activeSection;
  final String deviceAlias;
  final VoidCallback onShowDeviceInfo;
  final VoidCallback onChats;
  final VoidCallback onTransfers;
  final VoidCallback onTheme;
  final VoidCallback onSettings;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: _sidebar,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Tooltip(
            message: '本设备信息',
            child: InkWell(
              onTap: onShowDeviceInfo,
              customBorder: const CircleBorder(),
              child: CircleAvatar(
                radius: 23,
                backgroundColor: _accent,
                child: Text(
                  deviceAlias.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),
          _NavIcon(
            icon: Icons.chat_bubble_rounded,
            active: activeSection == _MainSection.chats,
            tooltip: '消息',
            onPressed: onChats,
          ),
          _NavIcon(
            icon: Icons.sync_alt_rounded,
            active: activeSection == _MainSection.transfers,
            tooltip: '传输',
            onPressed: onTransfers,
          ),
          _NavIcon(
            icon: Icons.history_rounded,
            active: activeSection == _MainSection.history,
            tooltip: '文件记录',
            onPressed: onHistory,
          ),
          const Spacer(),
          _NavIcon(
            icon: Icons.palette_rounded,
            active: activeSection == _MainSection.theme,
            tooltip: '主题',
            onPressed: onTheme,
          ),
          _NavIcon(
            icon: Icons.settings_rounded,
            active: activeSection == _MainSection.settings,
            tooltip: '设置',
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}

/// Phone navigation: the left rail is replaced by this slide-in drawer on
/// narrow screens. Selecting an item switches section and closes the drawer.
class _NavDrawer extends StatelessWidget {
  const _NavDrawer({
    required this.activeSection,
    required this.deviceAlias,
    required this.onShowDeviceInfo,
    required this.onChats,
    required this.onTransfers,
    required this.onTheme,
    required this.onSettings,
    required this.onHistory,
  });

  final _MainSection activeSection;
  final String deviceAlias;
  final VoidCallback onShowDeviceInfo;
  final VoidCallback onChats;
  final VoidCallback onTransfers;
  final VoidCallback onTheme;
  final VoidCallback onSettings;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: _surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () {
                Navigator.of(context).pop();
                onShowDeviceInfo();
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _accent,
                      child: Text(
                        deviceAlias.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        deviceAlias,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: _muted),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: _line),
            _NavDrawerItem(
              icon: Icons.chat_bubble_rounded,
              label: '消息',
              active: activeSection == _MainSection.chats,
              onTap: () => _select(context, onChats),
            ),
            _NavDrawerItem(
              icon: Icons.sync_alt_rounded,
              label: '传输',
              active: activeSection == _MainSection.transfers,
              onTap: () => _select(context, onTransfers),
            ),
            _NavDrawerItem(
              icon: Icons.history_rounded,
              label: '文件记录',
              active: activeSection == _MainSection.history,
              onTap: () => _select(context, onHistory),
            ),
            _NavDrawerItem(
              icon: Icons.palette_rounded,
              label: '主题',
              active: activeSection == _MainSection.theme,
              onTap: () => _select(context, onTheme),
            ),
            _NavDrawerItem(
              icon: Icons.settings_rounded,
              label: '设置',
              active: activeSection == _MainSection.settings,
              onTap: () => _select(context, onSettings),
            ),
          ],
        ),
      ),
    );
  }

  void _select(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }
}

class _NavDrawerItem extends StatelessWidget {
  const _NavDrawerItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: active ? _accent : _muted),
      title: Text(
        label,
        style: TextStyle(
          color: active ? _accent : _text,
          fontSize: 15,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: active,
      selectedTileColor: _accentSoft,
    );
  }
}

enum _MainSection { chats, transfers, theme, settings, history }

enum _ConversationMenuAction { rename, favorite, clear, delete }

/// A label/value row used in the device-info dialog.
class _DeviceInfoRow extends StatelessWidget {
  const _DeviceInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: TextStyle(color: _muted, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                color: _text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Result of the delete/clear confirmation dialog.
class _HistoryRemoval {
  const _HistoryRemoval({required this.alsoDeleteFile});

  final bool alsoDeleteFile;
}

InputDecoration teaInputDecoration({String? labelText, String? hintText}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    filled: true,
    fillColor: _panel,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: _line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: _line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: _accent, width: 1.4),
    ),
    labelStyle: TextStyle(color: _muted, fontSize: 13),
    hintStyle: TextStyle(color: _sidebarMuted, fontSize: 13),
  );
}

/// 输入框文本样式，确保暗黑模式下文本可见
TextStyle teaInputTextStyle() {
  return TextStyle(color: _text, fontSize: 14);
}

class TeaDialog extends StatelessWidget {
  const TeaDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.icon,
    this.width = 400,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final IconData? icon;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ShadDialog(
        constraints: BoxConstraints(maxWidth: width),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        radius: BorderRadius.circular(8),
        backgroundColor: _surface,
        border: Border.all(color: _line),
        shadows: const [
          BoxShadow(
            color: Color(0x2431302D),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
        title: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: _accent, size: 19),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(child: title),
          ],
        ),
        titleStyle: TextStyle(
          color: _text,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
        actions: actions,
        actionsGap: 8,
        actionsMainAxisAlignment: MainAxisAlignment.end,
        expandActionsWhenTiny: false,
        child: content,
      ),
    );
  }
}

class TeaDialogButton extends StatelessWidget {
  const TeaDialogButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.filled = false,
  });

  final VoidCallback onPressed;
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return filled
        ? ShadButton(
            onPressed: onPressed,
            width: 76,
            height: 38,
            backgroundColor: _accent,
            hoverBackgroundColor: Color.alphaBlend(
              Colors.black.withValues(alpha: 0.08),
              _accent,
            ),
            foregroundColor: Colors.white,
            hoverForegroundColor: Colors.white,
            child: Text(label),
          )
        : ShadButton.ghost(
            onPressed: onPressed,
            width: 76,
            height: 38,
            foregroundColor: _muted,
            hoverForegroundColor: _text,
            hoverBackgroundColor: _accentSoft,
            child: Text(label),
          );
  }
}

class _PopupMenuActionLabel extends StatelessWidget {
  const _PopupMenuActionLabel({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final color = danger ? const Color(0xFFC85D4D) : textColor;
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color, fontSize: 13)),
      ],
    );
  }
}

class _MenuItemWithColor extends StatelessWidget {
  const _MenuItemWithColor({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color, fontSize: 13)),
      ],
    );
  }
}

class _ManualConnectInput {
  const _ManualConnectInput({required this.host, required this.port});

  final String host;
  final int port;
}

/// Single text-field prompt dialog (rename / remark). Owns its controller so it
/// is disposed when the dialog subtree unmounts — see [_ManualConnectDialog].
class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.initialValue,
    required this.confirmLabel,
    this.hintText,
    this.icon = Icons.edit_rounded,
    this.width = 360,
  });

  final String title;
  final String initialValue;
  final String confirmLabel;
  final String? hintText;
  final IconData icon;
  final double width;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return TeaDialog(
      title: Text(widget.title),
      icon: widget.icon,
      width: widget.width,
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: teaInputTextStyle(),
        decoration: teaInputDecoration(hintText: widget.hintText),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TeaDialogButton(
          onPressed: () => Navigator.of(context).pop(),
          label: '取消',
        ),
        TeaDialogButton(
          onPressed: _submit,
          label: widget.confirmLabel,
          filled: true,
        ),
      ],
    );
  }
}

/// Local device info + alias rename dialog. Owns its alias controller so it is
/// disposed with the dialog subtree — see [_ManualConnectDialog].
class _DeviceInfoDialog extends StatefulWidget {
  const _DeviceInfoDialog({
    required this.initialAlias,
    required this.deviceTypeLabel,
    required this.deviceModel,
    required this.endpoint,
    required this.fingerprint,
  });

  final String initialAlias;
  final String deviceTypeLabel;
  final String deviceModel;
  final String endpoint;
  final String fingerprint;

  @override
  State<_DeviceInfoDialog> createState() => _DeviceInfoDialogState();
}

class _DeviceInfoDialogState extends State<_DeviceInfoDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialAlias);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return TeaDialog(
      title: const Text('本设备信息'),
      icon: Icons.devices_rounded,
      width: 400,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            style: teaInputTextStyle(),
            decoration: teaInputDecoration(
              labelText: '设备名称',
              hintText: '其他设备搜索时显示的名称',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          _DeviceInfoRow(label: '设备类型', value: widget.deviceTypeLabel),
          _DeviceInfoRow(label: '型号', value: widget.deviceModel),
          _DeviceInfoRow(label: '本机地址', value: widget.endpoint),
          _DeviceInfoRow(label: '设备指纹', value: widget.fingerprint),
        ],
      ),
      actions: [
        TeaDialogButton(
          onPressed: () => Navigator.of(context).pop(),
          label: '取消',
        ),
        TeaDialogButton(onPressed: _submit, label: '保存', filled: true),
      ],
    );
  }
}

/// Manual-connect dialog. Owns its [TextEditingController]s so they live exactly
/// as long as the dialog's element subtree — disposing them in the caller's
/// `finally` raced the close animation and crashed with "TextEditingController
/// used after being disposed" on cancel.
class _ManualConnectDialog extends StatefulWidget {
  const _ManualConnectDialog({
    required this.initialIp,
    required this.initialPort,
    required this.onInvalid,
  });

  final String initialIp;
  final String initialPort;
  final VoidCallback onInvalid;

  @override
  State<_ManualConnectDialog> createState() => _ManualConnectDialogState();
}

class _ManualConnectDialogState extends State<_ManualConnectDialog> {
  late final TextEditingController _ipController;
  late final TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: widget.initialIp)
      ..selection = TextSelection.collapsed(offset: widget.initialIp.length);
    _portController = TextEditingController(text: widget.initialPort);
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _submit() {
    var host = _ipController.text.trim();
    var port = int.tryParse(_portController.text.trim());
    final endpointMatch = RegExp(
      r'^(?:https?://)?([^:/\s]+):(\d{1,5})/?$',
    ).firstMatch(host);
    if (endpointMatch != null) {
      host = endpointMatch.group(1) ?? host;
      port = int.tryParse(endpointMatch.group(2) ?? '');
    }
    if (host.isEmpty || port == null || port < 1 || port > 65535) {
      widget.onInvalid();
      return;
    }
    Navigator.of(context).pop(_ManualConnectInput(host: host, port: port));
  }

  @override
  Widget build(BuildContext context) {
    return TeaDialog(
      title: const Text('手动连接'),
      icon: Icons.add_link_rounded,
      width: 420,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ipController,
            autofocus: true,
            style: teaInputTextStyle(),
            decoration: teaInputDecoration(
              labelText: '对方 IP 地址',
              hintText: '例如 192.168.1.20',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _portController,
            style: teaInputTextStyle(),
            decoration: teaInputDecoration(
              labelText: '端口号',
              hintText: '默认 53317',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TeaDialogButton(
          onPressed: () => Navigator.of(context).pop(),
          label: '取消',
        ),
        TeaDialogButton(onPressed: _submit, label: '连接', filled: true),
      ],
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.tooltip,
    this.active = false,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: onPressed ?? () {},
          icon: Icon(icon, size: 21),
          color: active ? _accent : _sidebarMuted,
          style: IconButton.styleFrom(
            fixedSize: const Size(42, 42),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            backgroundColor: active ? _accentSoft : Colors.transparent,
            hoverColor: _accentSoft,
          ),
        ),
      ),
    );
  }
}

class ThemePage extends StatelessWidget {
  const ThemePage({
    super.key,
    required this.themeMode,
    required this.themeColor,
    required this.onThemeModeChanged,
    required this.onThemeColorChanged,
    this.onMenu,
  });

  final AppThemeMode themeMode;
  final Color themeColor;
  final ValueChanged<AppThemeMode> onThemeModeChanged;
  final ValueChanged<Color> onThemeColorChanged;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _chatBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 74,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(
              color: _surface,
              border: Border(bottom: BorderSide(color: _line)),
            ),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                if (onMenu != null) ...[
                  _PageMenuButton(onPressed: onMenu!),
                  const SizedBox(width: 8),
                ],
                Text(
                  '主题',
                  style: TextStyle(
                    color: _text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _surface,
                    border: Border.all(color: _line),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ThemeSectionHeader(
                          icon: Icons.dark_mode_rounded,
                          title: '显示模式',
                          description: '切换日间或夜间界面',
                        ),
                        const SizedBox(height: 16),
                        _ThemeModePicker(
                          value: themeMode,
                          onChanged: onThemeModeChanged,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _surface,
                    border: Border.all(color: _line),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ThemeSectionHeader(
                          icon: Icons.palette_rounded,
                          title: '主题色',
                          description: '选择按钮、状态和强调元素的颜色',
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final color in _themeColorOptions)
                              _ThemeColorSwatch(
                                color: color,
                                selected:
                                    color.toARGB32() == themeColor.toARGB32(),
                                onTap: () => onThemeColorChanged(color),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModePicker extends StatelessWidget {
  const _ThemeModePicker({required this.value, required this.onChanged});

  final AppThemeMode value;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ThemeModeOption(
          icon: Icons.light_mode_rounded,
          label: '日间',
          selected: value == AppThemeMode.light,
          onPressed: () => onChanged(AppThemeMode.light),
        ),
        const SizedBox(width: 8),
        _ThemeModeOption(
          icon: Icons.dark_mode_rounded,
          label: '夜间',
          selected: value == AppThemeMode.dark,
          onPressed: () => onChanged(AppThemeMode.dark),
        ),
      ],
    );
  }
}

class _ThemeModeOption extends StatelessWidget {
  const _ThemeModeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ShadButton.outline(
      onPressed: onPressed,
      height: 38,
      backgroundColor: selected ? _accent : _surface,
      hoverBackgroundColor: selected ? _accent : _accentSoft,
      foregroundColor: selected ? Colors.white : _text,
      hoverForegroundColor: selected ? Colors.white : _text,
      leading: Icon(icon, size: 18),
      child: Text(label),
    );
  }
}

class _ThemeSectionHeader extends StatelessWidget {
  const _ThemeSectionHeader({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _accentSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _accent, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(description, style: TextStyle(color: _muted, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemeColorSwatch extends StatelessWidget {
  const _ThemeColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: selected ? '当前主题色' : '切换主题色',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? _text : _line,
              width: selected ? 2 : 1,
            ),
          ),
          child: selected
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
              : null,
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.autoSaveEnabled,
    required this.autoSaveDirectory,
    required this.overwriteSameNameFiles,
    required this.showImageCopyButton,
    required this.minimizeToTrayEnabled,
    required this.restoringWindowSettings,
    this.firewallStatus,
    this.lastFirewallRepair,
    this.lastInboundRequest,
    this.localEndpoints = const [],
    this.localHttpStatus,
    this.checkingFirewall = false,
    this.repairingFirewall = false,
    required this.onAutoSaveChanged,
    required this.onOverwriteSameNameFilesChanged,
    required this.onShowImageCopyButtonChanged,
    required this.onMinimizeToTrayChanged,
    required this.onChooseDirectory,
    this.onRefreshFirewall,
    this.onRepairFirewall,
    this.tempCleanupService,
    this.onShowTempCleanup,
    this.onMenu,
  });

  final bool autoSaveEnabled;
  final String autoSaveDirectory;
  final bool overwriteSameNameFiles;
  final bool showImageCopyButton;
  final bool minimizeToTrayEnabled;
  final bool restoringWindowSettings;
  final WindowsFirewallStatus? firewallStatus;
  final WindowsFirewallRepairResult? lastFirewallRepair;
  final String? lastInboundRequest;
  final List<String> localEndpoints;
  final String? localHttpStatus;
  final bool checkingFirewall;
  final bool repairingFirewall;
  final ValueChanged<bool> onAutoSaveChanged;
  final ValueChanged<bool> onOverwriteSameNameFilesChanged;
  final ValueChanged<bool> onShowImageCopyButtonChanged;
  final ValueChanged<bool> onMinimizeToTrayChanged;
  final VoidCallback onChooseDirectory;
  final VoidCallback? onRefreshFirewall;
  final VoidCallback? onRepairFirewall;
  final TempFileCleanupService? tempCleanupService;
  final VoidCallback? onShowTempCleanup;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final imageCopyButtonSetting = _SettingsSwitchCard(
      icon: Icons.image_rounded,
      title: '图片复制按钮',
      description: '控制发送和接收的图片消息是否显示复制按钮',
      value: showImageCopyButton,
      onChanged: onShowImageCopyButtonChanged,
    );

    return Container(
      color: _chatBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 74,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(
              color: _surface,
              border: Border(bottom: BorderSide(color: _line)),
            ),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                if (onMenu != null) ...[
                  _PageMenuButton(onPressed: onMenu!),
                  const SizedBox(width: 8),
                ],
                Text(
                  '设置',
                  style: TextStyle(
                    color: _text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
              children: [
                imageCopyButtonSetting,
                const SizedBox(height: 14),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _surface,
                    border: Border.all(color: _line),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _accentSoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.save_alt_rounded,
                                color: _accent,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '自动保存',
                                    style: TextStyle(
                                      color: _text,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    Platform.isAndroid
                                        ? '开启后，对方发来的文件会自动保存到“下载/NearSend”'
                                        : '开启后，对方发来的文件会自动保存到指定路径',
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ShadSwitch(
                              value: autoSaveEnabled,
                              checkedTrackColor: _accent,
                              onChanged: onAutoSaveChanged,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        // Android uses SAF behind this picker; desktop uses
                        // file_selector. Both persist the chosen display path.
                        if (_showFixedAndroidDownloadsDirectoryPlaceholder)
                          Container(
                            height: 42,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: _panel,
                              border: Border.all(color: _line),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '下载/NearSend',
                              style: TextStyle(
                                color: _text,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 42,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _panel,
                                    border: Border.all(color: _line),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SelectableText(
                                    autoSaveDirectory,
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: _text,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                onPressed: onChooseDirectory,
                                icon: const Icon(
                                  Icons.folder_open_rounded,
                                  size: 20,
                                ),
                                color: _text,
                                style: IconButton.styleFrom(
                                  fixedSize: const Size(42, 42),
                                  side: BorderSide(color: _line),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _SettingsSwitchCard(
                  icon: Icons.file_copy_rounded,
                  title: '覆盖同名文件',
                  description: '开启后，自动保存时同名文件会直接覆盖',
                  value: overwriteSameNameFiles,
                  onChanged: onOverwriteSameNameFilesChanged,
                ),
                const SizedBox(height: 14),
                if (tempCleanupService != null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: _surface,
                      border: Border.all(color: _line),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: _accentSoft,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.cleaning_services_rounded,
                                  color: _accent,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '临时文件清理',
                                      style: TextStyle(
                                        color: _text,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '清理接收文件产生的临时数据',
                                      style: TextStyle(
                                        color: _muted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _TempFileCleanupWidget(service: tempCleanupService!),
                        ],
                      ),
                    ),
                  ),
                // Tray/minimize is a desktop-only feature.
                if (Platform.isWindows) ...[
                  const SizedBox(height: 14),
                  FirewallRepairCard(
                    status: firewallStatus,
                    lastRepair: lastFirewallRepair,
                    lastInboundRequest: lastInboundRequest,
                    localEndpoints: localEndpoints,
                    localHttpStatus: localHttpStatus,
                    checking: checkingFirewall,
                    repairing: repairingFirewall,
                    onRefresh: onRefreshFirewall ?? () {},
                    onRepair: onRepairFirewall ?? () {},
                  ),
                  const SizedBox(height: 14),
                  _SettingsSwitchCard(
                    icon: Icons.system_update_alt_rounded,
                    title: '最小化到托盘',
                    description: restoringWindowSettings
                        ? '正在读取窗口设置'
                        : '开启后，最小化或关闭窗口时隐藏到系统托盘',
                    value: minimizeToTrayEnabled,
                    onChanged: restoringWindowSettings
                        ? null
                        : onMinimizeToTrayChanged,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSwitchCard extends StatelessWidget {
  const _SettingsSwitchCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _accentSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: _accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: _text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            ShadSwitch(
              value: value,
              checkedTrackColor: _accent,
              enabled: onChanged != null,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class FirewallRepairCard extends StatelessWidget {
  const FirewallRepairCard({
    super.key,
    required this.status,
    required this.lastRepair,
    required this.lastInboundRequest,
    required this.localEndpoints,
    required this.localHttpStatus,
    required this.checking,
    required this.repairing,
    required this.onRefresh,
    required this.onRepair,
  });

  final WindowsFirewallStatus? status;
  final WindowsFirewallRepairResult? lastRepair;
  final String? lastInboundRequest;
  final List<String> localEndpoints;
  final String? localHttpStatus;
  final bool checking;
  final bool repairing;
  final VoidCallback onRefresh;
  final VoidCallback onRepair;

  @override
  Widget build(BuildContext context) {
    final current = status;
    final hasInbound = lastInboundRequest != null;
    final ok =
        hasInbound ||
        (current != null && !current.needsRepair && current.error == null);
    final title = checking
        ? '正在检测防火墙'
        : ok
        ? '防火墙已放行'
        : '防火墙可能阻止接收';
    final description = current?.error != null
        ? '检测失败：${current!.error}'
        : ok
        ? '已允许 NearSend TCP ${WindowsFirewallService.ports}、UDP ${WindowsFirewallService.discoveryPorts} 入站。'
        : '平板发不到电脑时，需要允许 TCP ${WindowsFirewallService.ports}、UDP ${WindowsFirewallService.discoveryPorts} 入站。';
    final icon = ok
        ? Icons.verified_user_rounded
        : Icons.security_update_warning_rounded;
    final iconColor = ok ? const Color(0xFF27A95D) : _warning;
    final diagnosticText = _diagnosticText(
      current,
      lastRepair,
      hasInbound: hasInbound,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _accentSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: _text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(color: _muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FirewallStatusChip(
                  label: 'TCP',
                  ok: hasInbound || current?.tcpAllowed == true,
                  loading: checking,
                ),
                _FirewallStatusChip(
                  label: 'UDP',
                  ok: hasInbound || current?.udpAllowed == true,
                  loading: checking,
                ),
                _FirewallStatusChip(
                  label: '程序',
                  ok: hasInbound || current?.programAllowed == true,
                  loading: checking,
                ),
                _FirewallStatusChip(
                  label: '防火墙',
                  ok: current?.firewallEnabled != true || ok,
                  loading: checking,
                ),
                _FirewallStatusChip(
                  label: '本地规则',
                  ok: current?.localRulesAllowed != false,
                  loading: checking,
                ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(
              lastInboundRequest == null
                  ? 'last inbound: none'
                  : 'last inbound: $lastInboundRequest',
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 10),
            SelectableText(
              localHttpStatus == null
                  ? 'local http: unchecked'
                  : 'local http: $localHttpStatus',
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 10),
            SelectableText(
              localEndpoints.isEmpty
                  ? 'local endpoints: none'
                  : 'local endpoints:\n${localEndpoints.join('\n')}',
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                ShadButton.outline(
                  onPressed: checking || repairing ? null : onRefresh,
                  height: 34,
                  child: Text(checking ? '检测中' : '重新检测'),
                ),
                const SizedBox(width: 8),
                ShadButton.outline(
                  onPressed: localEndpoints.isEmpty
                      ? null
                      : () {
                          Clipboard.setData(
                            ClipboardData(text: localEndpoints.join('\n')),
                          );
                        },
                  height: 34,
                  child: const Text('复制地址'),
                ),
                const SizedBox(width: 8),
                ShadButton(
                  onPressed: checking || repairing ? null : onRepair,
                  height: 34,
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  hoverForegroundColor: Colors.white,
                  child: Text(repairing ? '等待授权' : '一键修复'),
                ),
              ],
            ),
            if (diagnosticText != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                diagnosticText,
                maxLines: 8,
                style: TextStyle(
                  color: _muted,
                  fontSize: 12,
                  height: 1.35,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _diagnosticText(
    WindowsFirewallStatus? status,
    WindowsFirewallRepairResult? repair, {
    required bool hasInbound,
  }) {
    final parts = <String>[];
    if (!hasInbound && repair != null && !repair.success) {
      parts.add('repair: ${repair.message}');
      final log = repair.log?.trim();
      if (log != null && log.isNotEmpty) {
        parts.add(log);
      }
    }
    final details = status?.details?.trim();
    if (status != null &&
        !hasInbound &&
        status.needsRepair &&
        details != null &&
        details.isNotEmpty) {
      final formatted = _formatFirewallDetails(details);
      if (formatted != null) {
        parts.add(formatted);
      }
    }
    if (parts.isEmpty) return null;
    return parts.join('\n');
  }

  /// 把后台返回的防火墙检测 JSON（含大段 netsh 原始输出）整理成简洁可读的摘要。
  /// 解析失败时返回 null，避免把原始 JSON 直接展示给用户。
  String? _formatFirewallDetails(String details) {
    Map<String, dynamic> decoded;
    try {
      final value = jsonDecode(details);
      if (value is! Map<String, dynamic>) return null;
      decoded = value;
    } catch (_) {
      return null;
    }

    final lines = <String>['检测详情'];
    lines.add('  TCP 规则：${_formatRuleList(decoded['tcpRules'])}');
    lines.add('  UDP 规则：${_formatRuleList(decoded['udpRules'])}');
    lines.add('  程序规则：${_formatRuleList(decoded['programRules'])}');
    return lines.join('\n');
  }

  String _formatRuleList(Object? rules) {
    if (rules is! List || rules.isEmpty) {
      return '未找到';
    }
    final summaries = rules
        .whereType<Map<String, dynamic>>()
        .map(_formatRule)
        .where((s) => s.isNotEmpty)
        .toList();
    if (summaries.isEmpty) {
      return '${rules.length} 条';
    }
    return '${rules.length} 条 · ${summaries.join('；')}';
  }

  String _formatRule(Map<String, dynamic> rule) {
    final fields = <String>[];
    final enabled = rule['enabled']?.toString();
    if (enabled != null && enabled.isNotEmpty) {
      fields.add(enabled.toLowerCase() == 'true' ? '已启用' : '已禁用');
    }
    final action = rule['action']?.toString();
    if (action != null && action.isNotEmpty) {
      fields.add(action.toLowerCase() == 'allow' ? '允许' : '阻止');
    }
    final protocol = _normalizeProtocol(rule['protocol']?.toString());
    if (protocol != null) {
      fields.add(protocol);
    }
    final localPort = rule['localPort']?.toString();
    if (localPort != null && localPort.isNotEmpty && localPort != 'Any') {
      fields.add(localPort);
    }
    final program = rule['program']?.toString();
    if (program != null && program.isNotEmpty && program != 'Any') {
      fields.add(program.split(RegExp(r'[\\/]')).last);
    }
    return fields.join(' / ');
  }

  String? _normalizeProtocol(String? protocol) {
    if (protocol == null || protocol.isEmpty) return null;
    switch (protocol) {
      case '6':
        return 'TCP';
      case '17':
        return 'UDP';
      default:
        return protocol;
    }
  }
}

class _FirewallStatusChip extends StatelessWidget {
  const _FirewallStatusChip({
    required this.label,
    required this.ok,
    required this.loading,
  });

  final String label;
  final bool ok;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final color = loading
        ? _muted
        : ok
        ? const Color(0xFF27A95D)
        : _warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        loading ? '$label 检测中' : '$label ${ok ? "已放行" : "未放行"}',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TempFileCleanupWidget extends StatefulWidget {
  const _TempFileCleanupWidget({required this.service});

  final TempFileCleanupService service;

  @override
  State<_TempFileCleanupWidget> createState() => _TempFileCleanupWidgetState();
}

class _TempFileCleanupWidgetState extends State<_TempFileCleanupWidget> {
  TempFileUsage? _usage;
  bool _isLoading = false;
  CleanupResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _loadUsage();
  }

  Future<void> _loadUsage() async {
    setState(() {
      _isLoading = true;
    });
    final usage = await widget.service.getTempFileUsage();
    if (mounted) {
      setState(() {
        _usage = usage;
        _isLoading = false;
      });
    }
  }

  Future<void> _performCleanup() async {
    setState(() {
      _isLoading = true;
    });
    final result = await widget.service.performCleanup();
    if (mounted) {
      setState(() {
        _lastResult = result;
        _isLoading = false;
      });
    }
    // 在 setState 之后再加载使用情况
    if (mounted) {
      await _loadUsage();
    }
  }

  Future<void> _performFullCleanup() async {
    setState(() {
      _isLoading = true;
    });
    final result = await widget.service.performFullCleanup();
    if (mounted) {
      setState(() {
        _lastResult = result;
        _isLoading = false;
      });
    }
    if (mounted) {
      await _loadUsage();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _usage == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final hasFiles = _usage != null && _usage!.totalFiles > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 文件统计
        if (_usage != null) ...[
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: '临时文件',
                  value: '${_usage!.totalFiles} 个',
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: '占用空间',
                  value: formatBytes(_usage!.totalBytes),
                ),
              ),
              if (_usage!.oldFiles > 0)
                Expanded(
                  child: _StatItem(
                    label: '可清理',
                    value: '${_usage!.oldFiles} 个',
                    valueColor: const Color(0xFFCB9A4B),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        // 设置选项
        _CleanupOptionRow(
          label: '自动清理',
          description: '定期清理过期临时文件',
          value: widget.service.autoCleanupEnabled,
          onChanged: (value) async {
            await widget.service.setAutoCleanupEnabled(value);
            setState(() {});
          },
        ),
        const SizedBox(height: 10),
        _CleanupOptionRow(
          label: '启动时清理',
          description: '应用启动时自动清理',
          value: widget.service.cleanupOnStartup,
          onChanged: (value) async {
            await widget.service.setCleanupOnStartup(value);
            setState(() {});
          },
        ),
        const SizedBox(height: 10),
        _CleanupDaysRow(
          days: widget.service.cleanupOlderThanDays,
          onChanged: (days) async {
            await widget.service.setCleanupOlderThanDays(days);
            setState(() {});
          },
        ),
        const SizedBox(height: 14),
        // 清理按钮
        Row(
          children: [
            Expanded(
              child: hasFiles
                  ? ShadButton(
                      onPressed: !_isLoading ? _performCleanup : null,
                      width: double.infinity,
                      height: 38,
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      hoverForegroundColor: Colors.white,
                      hoverBackgroundColor: _accent.withValues(alpha: 0.9),
                      child: Text(_isLoading ? '清理中...' : '清理过期文件'),
                    )
                  : ShadButton.outline(
                      onPressed: null,
                      width: double.infinity,
                      height: 38,
                      backgroundColor: _surface,
                      foregroundColor: _muted,
                      child: const Text('清理过期文件'),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ShadButton.outline(
                onPressed: hasFiles && !_isLoading ? _performFullCleanup : null,
                width: double.infinity,
                height: 38,
                foregroundColor: hasFiles ? _text : _muted,
                hoverBackgroundColor: _accentSoft,
                child: const Text('全部清理'),
              ),
            ),
          ],
        ),
        // 清理结果
        if (_lastResult != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _lastResult!.success
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFFEE2E2),
              border: Border.all(
                color: _lastResult!.success
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
                width: 0.5,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  _lastResult!.success
                      ? Icons.check_circle_rounded
                      : Icons.error_rounded,
                  size: 18,
                  color: _lastResult!.success
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _lastResult!.success
                        ? '已清理 ${_lastResult!.filesCleaned} 个文件，释放 ${formatBytes(_lastResult!.bytesFreed)}'
                        : '清理失败：${_lastResult!.error ?? "未知错误"}',
                    style: TextStyle(
                      color: _lastResult!.success
                          ? const Color(0xFF065F46)
                          : const Color(0xFF991B1B),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? _text,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CleanupOptionRow extends StatefulWidget {
  const _CleanupOptionRow({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<_CleanupOptionRow> createState() => _CleanupOptionRowState();
}

class _CleanupOptionRowState extends State<_CleanupOptionRow> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  void didUpdateWidget(_CleanupOptionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _value = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: _text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.description,
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        ShadSwitch(
          value: _value,
          checkedTrackColor: _accent,
          onChanged: (value) {
            setState(() {
              _value = value;
            });
            widget.onChanged(value);
          },
        ),
      ],
    );
  }
}

class _CleanupDaysRow extends StatefulWidget {
  const _CleanupDaysRow({required this.days, required this.onChanged});

  final int days;
  final ValueChanged<int> onChanged;

  @override
  State<_CleanupDaysRow> createState() => _CleanupDaysRowState();
}

class _CleanupDaysRowState extends State<_CleanupDaysRow> {
  late int _days;

  @override
  void initState() {
    super.initState();
    _days = widget.days;
  }

  @override
  void didUpdateWidget(_CleanupDaysRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.days != widget.days) {
      _days = widget.days;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '清理超过',
                style: TextStyle(
                  color: _text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text('自动清理保留天数', style: TextStyle(color: _muted, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: _panel,
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _days > 1
                    ? () {
                        setState(() {
                          _days--;
                        });
                        widget.onChanged(_days);
                      }
                    : null,
                icon: Icon(
                  Icons.remove_rounded,
                  size: 18,
                  color: _days > 1 ? _muted : _line,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              Container(
                width: 40,
                alignment: Alignment.center,
                child: Text(
                  '$_days',
                  style: TextStyle(
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: _days < 365
                    ? () {
                        setState(() {
                          _days++;
                        });
                        widget.onChanged(_days);
                      }
                    : null,
                icon: Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: _days < 365 ? _muted : _line,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text('天', style: TextStyle(color: _muted, fontSize: 14)),
      ],
    );
  }
}

class TransfersPage extends StatelessWidget {
  const TransfersPage({
    super.key,
    required this.tasks,
    required this.incomingRequests,
    required this.onAccept,
    required this.onDecline,
    required this.onCancel,
    this.onMenu,
  });

  final List<TransferTask> tasks;
  final Map<String, IncomingTransferRequest> incomingRequests;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onDecline;
  final ValueChanged<String> onCancel;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _chatBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 74,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(
              color: _surface,
              border: Border(bottom: BorderSide(color: _line)),
            ),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                if (onMenu != null) ...[
                  _PageMenuButton(onPressed: onMenu!),
                  const SizedBox(width: 8),
                ],
                Text(
                  '传输任务',
                  style: TextStyle(
                    color: _text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Text(
                      '暂无传输任务',
                      style: TextStyle(color: _muted, fontSize: 14),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
                    itemCount: tasks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return TransferTaskCard(
                        task: task,
                        request: incomingRequests[task.id],
                        onAccept: () => onAccept(task.id),
                        onDecline: () => onDecline(task.id),
                        onCancel: () => onCancel(task.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class TransferTaskCard extends StatelessWidget {
  const TransferTaskCard({
    super.key,
    required this.task,
    this.request,
    required this.onAccept,
    required this.onDecline,
    required this.onCancel,
  });

  final TransferTask task;
  final IncomingTransferRequest? request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isWaiting = task.status == TransferTaskStatus.waiting;
    final canCancel =
        task.direction == TransferTaskDirection.outgoing &&
        task.status == TransferTaskStatus.transferring;
    final progress = task.progress;

    return ShadCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: _surface,
      radius: BorderRadius.circular(8),
      border: ShadBorder.all(color: _line, width: 1),
      shadows: const [],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_iconForTask(task), color: _accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_directionLabel(task)} · ${task.peerAlias} · ${formatBytes(task.totalBytes)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _TransferStatusBadge(status: task.status),
            ],
          ),
          if (request != null && isWaiting) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final file in request!.files.take(4))
                  _TransferFileChip(name: file.name, size: file.size),
                if (request!.files.length > 4)
                  _TransferFileChip(
                    name: '+${request!.files.length - 4} 个文件',
                    size: 0,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          StableProgressBar(
            value: progress,
            height: 6,
            color: _accent,
            backgroundColor: _accentSoft,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  task.subtitle ?? _statusLabel(task.status),
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ),
              if (isWaiting) ...[
                ShadButton.ghost(
                  onPressed: onDecline,
                  height: 34,
                  foregroundColor: _muted,
                  hoverForegroundColor: _text,
                  child: const Text('拒绝'),
                ),
                const SizedBox(width: 8),
                ShadButton(
                  onPressed: onAccept,
                  height: 34,
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  hoverForegroundColor: Colors.white,
                  child: const Text('接收'),
                ),
              ] else if (canCancel)
                ShadButton.outline(
                  onPressed: onCancel,
                  height: 34,
                  foregroundColor: const Color(0xFFC85D4D),
                  child: const Text('取消'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconForTask(TransferTask task) {
    return switch (task.direction) {
      TransferTaskDirection.incoming => Icons.call_received_rounded,
      TransferTaskDirection.outgoing => Icons.call_made_rounded,
    };
  }

  String _directionLabel(TransferTask task) {
    return switch (task.direction) {
      TransferTaskDirection.incoming => '接收',
      TransferTaskDirection.outgoing => '发送',
    };
  }
}

class _TransferStatusBadge extends StatelessWidget {
  const _TransferStatusBadge({required this.status});

  final TransferTaskStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      TransferTaskStatus.waiting => _warning,
      TransferTaskStatus.transferring => _accent,
      TransferTaskStatus.completed => const Color(0xFF27A95D),
      TransferTaskStatus.failed => const Color(0xFFC85D4D),
      TransferTaskStatus.cancelled => _muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TransferFileChip extends StatelessWidget {
  const _TransferFileChip({required this.name, required this.size});

  final String name;
  final int size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _accentSoft,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        size <= 0 ? name : '$name · ${formatBytes(size)}',
        style: TextStyle(color: _text, fontSize: 12),
      ),
    );
  }
}

String _statusLabel(TransferTaskStatus status) {
  return switch (status) {
    TransferTaskStatus.waiting => '待确认',
    TransferTaskStatus.transferring => '传输中',
    TransferTaskStatus.completed => '已完成',
    TransferTaskStatus.failed => '失败',
    TransferTaskStatus.cancelled => '已取消',
  };
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({
    super.key,
    required this.entries,
    required this.onOpenFile,
    required this.onOpenFolder,
    required this.onDelete,
    required this.onClear,
    this.onMenu,
  });

  final List<ReceiveHistoryEntry> entries;
  final ValueChanged<ReceiveHistoryEntry> onOpenFile;
  final ValueChanged<ReceiveHistoryEntry> onOpenFolder;
  final ValueChanged<ReceiveHistoryEntry> onDelete;
  final VoidCallback onClear;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _chatBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 74,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(
              color: _surface,
              border: Border(bottom: BorderSide(color: _line)),
            ),
            child: Row(
              children: [
                if (onMenu != null) ...[
                  _PageMenuButton(onPressed: onMenu!),
                  const SizedBox(width: 8),
                ],
                Text(
                  '文件记录',
                  style: TextStyle(
                    color: _text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  entries.isEmpty ? '' : '${entries.length} 条',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
                const Spacer(),
                if (entries.isNotEmpty)
                  TextButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: const Text('清空'),
                    style: TextButton.styleFrom(foregroundColor: _muted),
                  ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 46,
                          color: _muted.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '暂无接收记录',
                          style: TextStyle(color: _muted, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _HistoryTile(
                        entry: entry,
                        onOpenFile: () => onOpenFile(entry),
                        onOpenFolder: () => onOpenFolder(entry),
                        onDelete: () => onDelete(entry),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
    required this.onOpenFile,
    required this.onOpenFolder,
    required this.onDelete,
  });

  final ReceiveHistoryEntry entry;
  final VoidCallback onOpenFile;
  final VoidCallback onOpenFolder;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final kind = FileKind.fromExtension(p.extension(entry.fileName));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _accentSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(kind.icon, color: _accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${_formatBytes(entry.size)} · ${entry.senderAlias} · ${_formatTime(entry.receivedAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _HistoryBadge(autoSaved: entry.autoSaved),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _HistoryAction(
              icon: Icons.open_in_new_rounded,
              tooltip: '打开文件',
              onPressed: onOpenFile,
            ),
            _HistoryAction(
              icon: Icons.folder_open_rounded,
              tooltip: '打开所在文件夹',
              onPressed: onOpenFolder,
            ),
            _HistoryAction(
              icon: Icons.delete_outline_rounded,
              tooltip: '删除记录',
              color: const Color(0xFFC85D4D),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int size) {
    if (size <= 0) return '未知大小';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = size.toDouble();
    var index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }
    final digits = index == 0 || value >= 10 ? 0 : 1;
    return '${value.toStringAsFixed(digits)} ${units[index]}';
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24 && now.day == time.day) {
      final hh = time.hour.toString().padLeft(2, '0');
      final mm = time.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    return '${time.month}月${time.day}日';
  }
}

class _HistoryBadge extends StatelessWidget {
  const _HistoryBadge({required this.autoSaved});

  final bool autoSaved;

  @override
  Widget build(BuildContext context) {
    final label = autoSaved ? '已保存' : '临时';
    final color = autoSaved ? _accent : _muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HistoryAction extends StatelessWidget {
  const _HistoryAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        color: color ?? _muted,
        style: IconButton.styleFrom(
          fixedSize: const Size(34, 34),
          minimumSize: const Size(34, 34),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

class ConversationPanel extends StatelessWidget {
  const ConversationPanel({
    super.key,
    required this.conversations,
    required this.favoriteFingerprints,
    required this.onlineFingerprints,
    required this.isScanning,
    required this.scanStatus,
    required this.selected,
    required this.onRefresh,
    required this.onShowQrCode,
    required this.onManualConnect,
    required this.onContextMenu,
    required this.onSelect,
    this.onMenu,
    this.onEditRemark,
    this.onClearRecords,
    this.onDeleteConversation,
  });

  final List<Conversation> conversations;
  final Set<String> favoriteFingerprints;
  final Set<String> onlineFingerprints;
  final bool isScanning;
  final String scanStatus;
  final int selected;

  /// Rescans for devices. Returns a future so pull-to-refresh can await it.
  final Future<void> Function() onRefresh;
  final VoidCallback onShowQrCode;
  final VoidCallback onManualConnect;
  final void Function(int index, Offset position) onContextMenu;
  final ValueChanged<int> onSelect;

  /// Opens the navigation drawer on phone layouts; null on tablet/desktop.
  final VoidCallback? onMenu;

  /// Android swipe-action callbacks. Null on desktop, where the right-click
  /// context menu provides the same operations instead.
  final ValueChanged<int>? onEditRemark;
  final ValueChanged<int>? onClearRecords;
  final ValueChanged<int>? onDeleteConversation;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: _line),
                bottom: BorderSide(color: _line),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    if (onMenu != null)
                      _ToolButton(
                        icon: Icons.menu_rounded,
                        tooltip: '菜单',
                        onPressed: onMenu,
                      ),
                    _ToolButton(
                      icon: Icons.refresh_rounded,
                      tooltip: '刷新',
                      enabled: !isScanning,
                      onPressed: onRefresh,
                    ),
                    _ToolButton(
                      icon: Icons.qr_code_rounded,
                      tooltip: '二维码',
                      onPressed: onShowQrCode,
                    ),
                    _ToolButton(
                      icon: Icons.add_link_rounded,
                      tooltip: '手动连接',
                      enabled: !isScanning,
                      onPressed: onManualConnect,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: isScanning
                          ? CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _accent,
                            )
                          : Icon(Icons.lan_rounded, size: 15, color: _muted),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        scanStatus,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                final list = ListView.builder(
                  padding: const EdgeInsets.all(8),
                  // Always scrollable so pull-to-refresh works even when the
                  // list is short or empty.
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    final swipeEnabled =
                        Platform.isAndroid && onDeleteConversation != null;
                    // Stable per-conversation identity. The list re-sorts as
                    // devices re-announce, so without a key the swipe State
                    // would attach to whichever conversation lands at this
                    // slot, leaving an unrelated row showing its actions open.
                    final itemKey = ValueKey(
                      conversation.device?.fingerprint ?? conversation.title,
                    );
                    final tile = ConversationTile(
                      conversation: conversation,
                      favorite:
                          conversation.device != null &&
                          favoriteFingerprints.contains(
                            conversation.device!.fingerprint,
                          ),
                      online:
                          conversation.device != null &&
                          onlineFingerprints.contains(
                            conversation.device!.fingerprint,
                          ),
                      selected: selected == index,
                      padded: !swipeEnabled,
                      onTap: () => onSelect(index),
                      onContextMenu: (position) {
                        onSelect(index);
                        onContextMenu(index, position);
                      },
                    );
                    if (!swipeEnabled) {
                      return KeyedSubtree(key: itemKey, child: tile);
                    }
                    return _SwipeActionTile(
                      key: itemKey,
                      actions: [
                        _SwipeAction(
                          icon: Icons.edit_rounded,
                          label: '备注',
                          color: _accent,
                          onTap: () => onEditRemark?.call(index),
                        ),
                        _SwipeAction(
                          icon: Icons.cleaning_services_rounded,
                          label: '清空',
                          color: _warning,
                          onTap: () => onClearRecords?.call(index),
                        ),
                        _SwipeAction(
                          icon: Icons.delete_outline_rounded,
                          label: '删除',
                          color: const Color(0xFFC85D4D),
                          onTap: () => onDeleteConversation?.call(index),
                        ),
                      ],
                      child: tile,
                    );
                  },
                );
                // Pull-to-refresh to rescan devices (phone only).
                if (!Platform.isAndroid) return list;
                return RefreshIndicator(
                  onRefresh: onRefresh,
                  color: _accent,
                  child: list,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.tooltip,
    this.enabled = true,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: _PressableScale(
        child: Tooltip(
          message: tooltip,
          child: ShadButton.outline(
            onPressed: enabled ? onPressed ?? () {} : null,
            width: 42,
            height: 42,
            padding: EdgeInsets.zero,
            backgroundColor: _surface,
            foregroundColor: _muted,
            hoverForegroundColor: _text,
            hoverBackgroundColor: _accentSoft,
            child: Icon(icon, size: 19),
          ),
        ),
      ),
    );
  }
}

class _IconShadButton extends StatelessWidget {
  const _IconShadButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          color: color ?? _muted,
          style: IconButton.styleFrom(
            fixedSize: const Size(42, 42),
            backgroundColor: Colors.transparent,
            foregroundColor: color ?? _muted,
            hoverColor: _accentSoft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _SendShadButton extends StatelessWidget {
  const _SendShadButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ShadButton(
      onPressed: onPressed,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      backgroundColor: _accent,
      hoverBackgroundColor: Color.alphaBlend(
        Colors.black.withValues(alpha: 0.08),
        _accent,
      ),
      foregroundColor: Colors.white,
      hoverForegroundColor: Colors.white,
      child: const Text('发送', style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

// ignore: unused_element
class _ComposerShadTextarea extends StatelessWidget {
  const _ComposerShadTextarea({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return ShadTextarea(
      controller: controller,
      minHeight: 78,
      maxHeight: 130,
      resizable: false,
      placeholder: const Text('输入消息...'),
      inputPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: ShadDecoration(
        color: Colors.transparent,
        border: ShadBorder.all(color: Colors.transparent, width: 0),
        secondaryBorder: ShadBorder.all(color: Colors.transparent, width: 0),
        focusedBorder: ShadBorder.all(color: Colors.transparent, width: 0),
        secondaryFocusedBorder: ShadBorder.all(
          color: Colors.transparent,
          width: 0,
        ),
      ),
      style: TextStyle(color: _text, fontSize: 14, height: 1.55),
      onSubmitted: (_) => onSend(),
    );
  }
}

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.favorite,
    required this.online,
    required this.selected,
    required this.onTap,
    required this.onContextMenu,
    this.padded = true,
  });

  final Conversation conversation;
  final bool favorite;
  final bool online;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<Offset> onContextMenu;

  /// When false, omits the outer bottom spacing so a wrapper (e.g. the swipe
  /// action container) can own the list gap instead.
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final tile = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: GestureDetector(
        onSecondaryTapDown: (details) {
          onContextMenu(details.globalPosition);
        },
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 72),
            margin: EdgeInsets.only(left: selected ? 2 : 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected ? _accentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? _accent.withValues(alpha: 0.24)
                    : Colors.transparent,
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x0F0F172A),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              children: [
                ConversationAvatar(conversation: conversation, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _text,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (favorite) ...[
                            Icon(Icons.star_rounded, color: _warning, size: 16),
                            const SizedBox(width: 5),
                          ],
                          if (conversation.device != null)
                            Icon(
                              online
                                  ? Icons.wifi_rounded
                                  : Icons
                                        .signal_wifi_connected_no_internet_4_rounded,
                              color: online ? const Color(0xFF27A95D) : _muted,
                              size: 16,
                            )
                          else
                            Text(
                              conversation.time,
                              style: const TextStyle(
                                color: Color(0xFF9C998F),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        conversation.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (conversation.unread > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    height: 20,
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: _warning,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${conversation.unread}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (!padded) return tile;
    return Padding(padding: const EdgeInsets.only(bottom: 4), child: tile);
  }
}

/// A single revealed action behind a [_SwipeActionTile].
class _SwipeAction {
  const _SwipeAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

/// Fixed width of each revealed swipe action button.
const double _kSwipeActionExtent = 72;

/// Swipe-left-to-reveal action buttons (Android only). Drag the tile left to
/// expose the actions on the right; release past the halfway point (or with a
/// leftward fling) to latch open, tap an action to run it, or tap the tile /
/// drag back to close.
class _SwipeActionTile extends StatefulWidget {
  const _SwipeActionTile({
    super.key,
    required this.child,
    required this.actions,
  });

  final Widget child;
  final List<_SwipeAction> actions;

  @override
  State<_SwipeActionTile> createState() => _SwipeActionTileState();
}

class _SwipeActionTileState extends State<_SwipeActionTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  double get _maxDrag => widget.actions.length * _kSwipeActionExtent;

  void _onDragUpdate(DragUpdateDetails details) {
    if (_maxDrag <= 0) return;
    _controller.value -= details.primaryDelta! / _maxDrag;
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -250) {
      _controller.animateTo(1, curve: Curves.easeOut);
    } else if (velocity > 250) {
      _controller.animateTo(0, curve: Curves.easeOut);
    } else {
      _controller.animateTo(
        _controller.value > 0.5 ? 1 : 0,
        curve: Curves.easeOut,
      );
    }
  }

  void _close() => _controller.animateTo(0, curve: Curves.easeOut);

  Future<void> _runAction(_SwipeAction action) async {
    await _controller.animateTo(0, curve: Curves.easeOut);
    if (!mounted) return;
    action.onTap();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Positioned.fill(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (final action in widget.actions)
                    _SwipeActionButton(
                      action: action,
                      width: _kSwipeActionExtent,
                      onPressed: () => _runAction(action),
                    ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final isOpen = _controller.value > 0.001;
                return Transform.translate(
                  offset: Offset(-_controller.value * _maxDrag, 0),
                  // Opaque background: the foreground must fully occlude the
                  // action buttons behind it when closed. ConversationTile is
                  // transparent unless selected, so without this the actions
                  // would bleed through any unselected row.
                  child: ColoredBox(
                    color: _panel,
                    child: Stack(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragUpdate: _onDragUpdate,
                          onHorizontalDragEnd: _onDragEnd,
                          child: widget.child,
                        ),
                        // While open, a transparent barrier swallows taps so
                        // the first tap closes the tile instead of selecting it.
                        if (isOpen)
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _close,
                              onHorizontalDragUpdate: _onDragUpdate,
                              onHorizontalDragEnd: _onDragEnd,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeActionButton extends StatelessWidget {
  const _SwipeActionButton({
    required this.action,
    required this.width,
    required this.onPressed,
  });

  final _SwipeAction action;
  final double width;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        width: width,
        color: action.color,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(action.icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(
              action.label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class ConversationAvatar extends StatelessWidget {
  const ConversationAvatar({
    super.key,
    required this.conversation,
    required this.size,
  });

  final Conversation conversation;
  final double size;

  @override
  Widget build(BuildContext context) {
    final device = conversation.device;
    if (device == null) {
      return InitialAvatar(text: conversation.initials, size: size);
    }

    final (icon, color) = switch (device.deviceType) {
      DiscoveredDeviceType.mobile => (
        Icons.android_rounded,
        const Color(0xFF3DDC84),
      ),
      DiscoveredDeviceType.desktop => (
        Icons.desktop_windows_rounded,
        const Color(0xFF2E7CCB),
      ),
      DiscoveredDeviceType.web => (
        Icons.language_rounded,
        const Color(0xFF6B7A90),
      ),
      DiscoveredDeviceType.headless => (
        Icons.dns_rounded,
        const Color(0xFF7B6FD6),
      ),
      DiscoveredDeviceType.server => (
        Icons.storage_rounded,
        const Color(0xFF67706A),
      ),
    };

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class ChatPanel extends StatelessWidget {
  const ChatPanel({
    super.key,
    required this.conversation,
    required this.controller,
    required this.scrollController,
    required this.pendingAttachments,
    required this.onSend,
    required this.onSendImage,
    required this.onSendFile,
    required this.onPasteImages,
    required this.onRemovePendingAttachment,
    required this.selectionMode,
    required this.showDetails,
    required this.selectedMessageIds,
    required this.onEnterSelectionMode,
    required this.onExitSelectionMode,
    required this.onShowDetails,
    required this.onHideDetails,
    required this.onToggleMessageSelection,
    required this.onDeleteSelectedMessages,
    required this.onToggleSelectAllMessages,
    required this.onRetrySendAttachment,
    required this.onCancelTransfer,
    required this.onCopyAttachment,
    required this.previewImage,
    required this.onPreviewImage,
    required this.onClosePreview,
    required this.favoriteDevice,
    required this.onFavoriteDeviceChanged,
    required this.clipboardAutoSendEnabled,
    required this.onClipboardAutoSendChanged,
    required this.showImageCopyButton,
    this.onMobileBack,
  });

  final Conversation conversation;
  final TextEditingController controller;
  final ScrollController scrollController;
  final List<MessageAttachment> pendingAttachments;
  final VoidCallback? onMobileBack;
  final VoidCallback onSend;
  final VoidCallback onSendImage;
  final VoidCallback onSendFile;
  final Future<void> Function() onPasteImages;
  final ValueChanged<MessageAttachment> onRemovePendingAttachment;
  final bool selectionMode;
  final bool showDetails;
  final Set<String> selectedMessageIds;
  final VoidCallback onEnterSelectionMode;
  final VoidCallback onExitSelectionMode;
  final VoidCallback onShowDetails;
  final VoidCallback onHideDetails;
  final ValueChanged<String> onToggleMessageSelection;
  final VoidCallback onDeleteSelectedMessages;
  final ValueChanged<Set<String>> onToggleSelectAllMessages;
  final ValueChanged<String> onRetrySendAttachment;
  final ValueChanged<String> onCancelTransfer;
  final ValueChanged<MessageAttachment> onCopyAttachment;
  final MessageAttachment? previewImage;
  final ValueChanged<MessageAttachment> onPreviewImage;
  final VoidCallback onClosePreview;
  final bool favoriteDevice;
  final ValueChanged<bool> onFavoriteDeviceChanged;
  final bool clipboardAutoSendEnabled;
  final ValueChanged<bool> onClipboardAutoSendChanged;
  final bool showImageCopyButton;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = Platform.isAndroid
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0.0;
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _chatBg,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            children: [
              ChatHeader(
                conversation: conversation,
                selectionMode: selectionMode,
                showDetails: showDetails,
                selectedCount: selectedMessageIds.length,
                messageCount: conversation.messages.length,
                onEnterSelectionMode: onEnterSelectionMode,
                onExitSelectionMode: onExitSelectionMode,
                onShowDetails: onShowDetails,
                onHideDetails: onHideDetails,
                onDeleteSelectedMessages: onDeleteSelectedMessages,
                onToggleSelectAllMessages: () => onToggleSelectAllMessages(
                  conversation.messages.map((message) => message.id).toSet(),
                ),
                onMobileBack: onMobileBack,
              ),
              if (showDetails)
                Expanded(
                  child: _SoftAppear(
                    offset: const Offset(10, 0),
                    duration: const Duration(milliseconds: 260),
                    child: DeviceDetailsPage(
                      conversation: conversation,
                      favoriteDevice: favoriteDevice,
                      onFavoriteDeviceChanged: onFavoriteDeviceChanged,
                      clipboardAutoSendEnabled: clipboardAutoSendEnabled,
                      onClipboardAutoSendChanged: onClipboardAutoSendChanged,
                    ),
                  ),
                )
              else ...[
                Expanded(
                  child: _SoftAppear(
                    offset: const Offset(10, 0),
                    duration: const Duration(milliseconds: 260),
                    child: _BottomAnchoredScroll(
                      controller: scrollController,
                      anchorKey:
                          conversation.device?.fingerprint ??
                          conversation.title,
                      itemCount: conversation.messages.length,
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.fromLTRB(
                          24,
                          24,
                          24,
                          24 + keyboardInset,
                        ),
                        children: [
                          ..._buildMessageTimeline(
                            conversation.messages,
                            selectedMessageIds,
                          ),
                          if (conversation.files.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              '传输队列',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (
                                  var index = 0;
                                  index < conversation.files.length;
                                  index++
                                )
                                  _SoftAppear(
                                    delay: Duration(milliseconds: index * 35),
                                    offset: const Offset(0, 8),
                                    child: FileCard(
                                      file: conversation.files[index],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.only(bottom: keyboardInset),
                  child: _SoftAppear(
                    offset: const Offset(0, 16),
                    duration: const Duration(milliseconds: 320),
                    child: Composer(
                      controller: controller,
                      pendingAttachments: pendingAttachments,
                      onSend: onSend,
                      onSendImage: onSendImage,
                      onSendFile: onSendFile,
                      onPasteImages: onPasteImages,
                      onRemovePendingAttachment: onRemovePendingAttachment,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (previewImage != null)
            Positioned.fill(
              child: ImagePreviewOverlay(
                attachment: previewImage!,
                onClose: onClosePreview,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildMessageTimeline(
    List<ChatMessage> messages,
    Set<String> selectedMessageIds,
  ) {
    final widgets = <Widget>[];
    ChatMessage? previousMessage;
    for (final message in messages) {
      final label = _messageTimeLabel(previousMessage, message);
      if (label != null) {
        widgets.add(
          MessageTimeDivider(key: ValueKey('time-${message.id}'), label: label),
        );
      }
      widgets.add(
        MessageBubble(
          key: ValueKey('message-${message.id}'),
          message: message,
          selectionMode: selectionMode,
          selected: selectedMessageIds.contains(message.id),
          onToggleSelected: () => onToggleMessageSelection(message.id),
          onRetrySend: () => onRetrySendAttachment(message.id),
          onCancelTransfer: () => onCancelTransfer(message.id),
          onCopyAttachment: onCopyAttachment,
          showImageCopyButton: showImageCopyButton,
          onPreviewImage: onPreviewImage,
        ),
      );
      if (!message.system) previousMessage = message;
    }
    return widgets;
  }

  String? _messageTimeLabel(ChatMessage? previous, ChatMessage current) {
    if (current.system) return null;
    if (previous == null ||
        !_isSameDay(previous.createdAt, current.createdAt)) {
      return '${_formatMessageDate(current.createdAt)} ${_formatMessageClock(current.createdAt)}';
    }
    if (current.createdAt.difference(previous.createdAt).inMinutes >= 10) {
      return _formatMessageClock(current.createdAt);
    }
    return null;
  }
}

class ImagePreviewOverlay extends StatelessWidget {
  const ImagePreviewOverlay({
    super.key,
    required this.attachment,
    required this.onClose,
  });

  final MessageAttachment attachment;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xE61F1E1D),
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.6,
              maxScale: 5,
              child: Center(
                child: Image.file(
                  File(attachment.path),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Text(
                      '图片无法预览',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned(
            top: 18,
            right: 18,
            child: Tooltip(
              message: '关闭',
              child: IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 22),
                color: Colors.white,
                style: IconButton.styleFrom(
                  fixedSize: const Size(42, 42),
                  backgroundColor: const Color(0x66000000),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.conversation,
    required this.selectionMode,
    required this.showDetails,
    required this.selectedCount,
    required this.messageCount,
    required this.onEnterSelectionMode,
    required this.onExitSelectionMode,
    required this.onShowDetails,
    required this.onHideDetails,
    required this.onDeleteSelectedMessages,
    required this.onToggleSelectAllMessages,
    this.onMobileBack,
  });

  final Conversation conversation;
  final bool selectionMode;
  final bool showDetails;
  final int selectedCount;
  final int messageCount;
  final VoidCallback onEnterSelectionMode;
  final VoidCallback onExitSelectionMode;
  final VoidCallback onShowDetails;
  final VoidCallback onHideDetails;
  final VoidCallback onDeleteSelectedMessages;
  final VoidCallback onToggleSelectAllMessages;

  /// On phone layouts, returns from the full-screen chat to the list. Null on
  /// wide layouts where the list is always visible beside the chat.
  final VoidCallback? onMobileBack;

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedCount > 0;
    final allSelected = messageCount > 0 && selectedCount == messageCount;
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          if (onMobileBack != null && !selectionMode && !showDetails) ...[
            _HeaderButton(
              icon: Icons.arrow_back_rounded,
              tooltip: '返回列表',
              onPressed: onMobileBack,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectionMode
                      ? '已选择 $selectedCount 条'
                      : showDetails
                      ? '详细信息'
                      : conversation.title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (selectionMode || showDetails) ...[
                  const SizedBox(height: 4),
                  Text(
                    selectionMode ? '批量删除聊天记录' : conversation.title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          if (showDetails)
            _HeaderButton(
              icon: Icons.arrow_back_rounded,
              tooltip: '返回聊天',
              onPressed: onHideDetails,
            )
          else if (selectionMode) ...[
            _HeaderButton(
              icon: allSelected
                  ? Icons.deselect_rounded
                  : Icons.select_all_rounded,
              tooltip: allSelected ? '取消全选' : '全选',
              onPressed: messageCount > 0 ? onToggleSelectAllMessages : null,
            ),
            _HeaderButton(
              icon: Icons.delete_outline_rounded,
              tooltip: hasSelection ? '删除选中消息' : '先选择消息',
              onPressed: hasSelection ? onDeleteSelectedMessages : null,
              color: hasSelection ? const Color(0xFFC85D4D) : _muted,
            ),
            _HeaderButton(
              icon: Icons.close_rounded,
              tooltip: '取消多选',
              onPressed: onExitSelectionMode,
            ),
          ] else ...[
            _HeaderButton(
              icon: Icons.info_outline_rounded,
              tooltip: '详细信息',
              onPressed: onShowDetails,
            ),
            _HeaderButton(
              icon: Icons.checklist_rounded,
              tooltip: '多选',
              onPressed: onEnterSelectionMode,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return _IconShadButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      color: color,
    );
  }
}

/// A 42x42 menu (hamburger) button shown in page title bars on phone layouts
/// to open the navigation drawer.
class _PageMenuButton extends StatelessWidget {
  const _PageMenuButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '菜单',
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.menu_rounded, size: 22),
        color: _text,
        style: IconButton.styleFrom(
          fixedSize: const Size(42, 42),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _BottomAnchoredScroll extends StatefulWidget {
  const _BottomAnchoredScroll({
    required this.controller,
    required this.itemCount,
    required this.child,
    this.anchorKey,
  });

  final ScrollController controller;
  final Object? anchorKey;
  final int itemCount;
  final Widget child;

  @override
  State<_BottomAnchoredScroll> createState() => _BottomAnchoredScrollState();
}

class _BottomAnchoredScrollState extends State<_BottomAnchoredScroll> {
  Object? _anchorKey;
  late int _itemCount;

  @override
  void initState() {
    super.initState();
    _anchorKey = widget.anchorKey;
    _itemCount = widget.itemCount;
    _jumpAfterLayout();
  }

  @override
  void didUpdateWidget(covariant _BottomAnchoredScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.anchorKey != _anchorKey || widget.itemCount != _itemCount) {
      _anchorKey = widget.anchorKey;
      _itemCount = widget.itemCount;
      _jumpAfterLayout();
    }
  }

  void _jumpAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.controller.hasClients) return;
      widget.controller.jumpTo(widget.controller.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MessageTimeDivider extends StatelessWidget {
  const MessageTimeDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, style: TextStyle(color: _muted, fontSize: 12)),
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _formatMessageDate(DateTime value) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(value.year, value.month, value.day);
  if (day == today) return '今天';
  if (day == today.subtract(const Duration(days: 1))) return '昨天';
  return '${value.year}-${_twoDigits(value.month)}-${_twoDigits(value.day)}';
}

String _formatMessageClock(DateTime value) {
  return '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

class DeviceDetailsPage extends StatelessWidget {
  const DeviceDetailsPage({
    super.key,
    required this.conversation,
    required this.favoriteDevice,
    required this.onFavoriteDeviceChanged,
    required this.clipboardAutoSendEnabled,
    required this.onClipboardAutoSendChanged,
  });

  final Conversation conversation;
  final bool favoriteDevice;
  final ValueChanged<bool> onFavoriteDeviceChanged;
  final bool clipboardAutoSendEnabled;
  final ValueChanged<bool> onClipboardAutoSendChanged;

  @override
  Widget build(BuildContext context) {
    final device = conversation.device;
    return Container(
      width: double.infinity,
      color: _chatBg,
      child: device == null
          ? const _DeviceDetailsEmpty()
          : ListView(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
              children: [
                Row(
                  children: [
                    InitialAvatar(text: device.initials, size: 58),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device.alias,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _text,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${device.deviceType.label} · ${device.displayModel}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _DeviceSwitchCard(
                  icon: Icons.star_rounded,
                  title: '收藏设备',
                  description: '收藏后，此设备发来的文件会自动接收，不再弹出确认或拒绝。',
                  enabled: favoriteDevice,
                  onChanged: onFavoriteDeviceChanged,
                ),
                const SizedBox(height: 14),
                _DeviceAutoSendCard(
                  enabled: clipboardAutoSendEnabled,
                  onChanged: onClipboardAutoSendChanged,
                ),
                const SizedBox(height: 14),
                _DeviceDetailSection(
                  title: '设备标识',
                  rows: [
                    _DeviceDetailRow('唯一 ID', device.fingerprint),
                    _DeviceDetailRow('别名', device.alias),
                    _DeviceDetailRow('协议版本', 'LocalSend ${device.version}'),
                  ],
                ),
                const SizedBox(height: 14),
                _DeviceDetailSection(
                  title: '网络',
                  rows: [
                    _DeviceDetailRow('IP', device.ip),
                    _DeviceDetailRow('端口', device.port.toString()),
                    _DeviceDetailRow('协议', device.https ? 'HTTPS' : 'HTTP'),
                    _DeviceDetailRow('地址', device.endpoint),
                  ],
                ),
                const SizedBox(height: 14),
                _DeviceDetailSection(
                  title: '设备',
                  rows: [
                    _DeviceDetailRow('设备类型', device.deviceType.label),
                    _DeviceDetailRow('设备型号', device.displayModel),
                    _DeviceDetailRow('允许下载', device.download ? '是' : '否'),
                    _DeviceDetailRow('最后发现', _formatDateTime(device.lastSeen)),
                  ],
                ),
              ],
            ),
    );
  }

  static String _formatDateTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }
}

class _DeviceAutoSendCard extends StatelessWidget {
  const _DeviceAutoSendCard({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _accentSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.content_paste_go_rounded,
                color: _accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '自动发送截图',
                    style: TextStyle(
                      color: _text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '截屏并复制到剪贴板后，自动把图片发送到此设备',
                    style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: enabled,
              activeThumbColor: _accent,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceSwitchCard extends StatelessWidget {
  const _DeviceSwitchCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _accentSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: _accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: _text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: enabled,
              activeThumbColor: _accent,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceDetailsEmpty extends StatelessWidget {
  const _DeviceDetailsEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded, color: _muted, size: 34),
          const SizedBox(height: 12),
          Text(
            '当前会话没有设备信息',
            style: TextStyle(
              color: _text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '通过局域网发现或手动连接的设备会显示完整详情',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _DeviceDetailSection extends StatelessWidget {
  const _DeviceDetailSection({required this.title, required this.rows});

  final String title;
  final List<_DeviceDetailRow> rows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: _text,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            for (final row in rows) _DeviceDetailLine(row: row),
          ],
        ),
      ),
    );
  }
}

class _DeviceDetailLine extends StatelessWidget {
  const _DeviceDetailLine({required this.row});

  final _DeviceDetailRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              row.label,
              style: TextStyle(color: _muted, fontSize: 13),
            ),
          ),
          Expanded(
            child: SelectableText(
              row.value,
              style: TextStyle(
                color: _text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceDetailRow {
  const _DeviceDetailRow(this.label, this.value);

  final String label;
  final String value;
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelected,
    required this.onRetrySend,
    required this.onCancelTransfer,
    required this.onCopyAttachment,
    required this.onPreviewImage,
    this.showImageCopyButton = true,
  });

  final ChatMessage message;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onToggleSelected;
  final VoidCallback onRetrySend;
  final VoidCallback onCancelTransfer;
  final ValueChanged<MessageAttachment> onCopyAttachment;
  final ValueChanged<MessageAttachment> onPreviewImage;
  final bool showImageCopyButton;

  @override
  Widget build(BuildContext context) {
    final bubble = _SoftAppear(
      offset: message.system
          ? const Offset(0, 8)
          : Offset(message.isMe ? 12 : -12, 8),
      duration: const Duration(milliseconds: 240),
      child: _buildBubble(),
    );
    if (!selectionMode) return bubble;

    return InkWell(
      onTap: onToggleSelected,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: message.system ? 0 : 7, right: 10),
            child: Checkbox(
              value: selected,
              onChanged: (_) => onToggleSelected(),
              visualDensity: VisualDensity.compact,
              activeColor: _accent,
            ),
          ),
          Expanded(child: bubble),
        ],
      ),
    );
  }

  Widget _buildBubble() {
    if (message.system) {
      return Align(
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            message.text,
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ),
      );
    }

    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: message.isMe ? _meChildren() : _peerChildren(),
          ),
        ),
      ),
    );
  }

  List<Widget> _peerChildren() {
    return [
      _BubbleSurface(
        message: message,
        onRetrySend: onRetrySend,
        onCancelTransfer: onCancelTransfer,
        onCopyAttachment: onCopyAttachment,
        showImageCopyButton: showImageCopyButton,
        onPreviewImage: onPreviewImage,
      ),
    ];
  }

  List<Widget> _meChildren() {
    return [
      if (message.attachment == null &&
          message.status != MessageSendStatus.none) ...[
        MessageStatusIcon(status: message.status),
        const SizedBox(width: 6),
      ],
      _BubbleSurface(
        message: message,
        onRetrySend: onRetrySend,
        onCancelTransfer: onCancelTransfer,
        onCopyAttachment: onCopyAttachment,
        showImageCopyButton: showImageCopyButton,
        onPreviewImage: onPreviewImage,
      ),
    ];
  }
}

class RetrySendButton extends StatelessWidget {
  const RetrySendButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '重试发送',
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.refresh_rounded, size: 17),
        color: const Color(0xFFC85D4D),
        style: IconButton.styleFrom(
          fixedSize: const Size(30, 30),
          minimumSize: const Size(30, 30),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class CancelTransferButton extends StatelessWidget {
  const CancelTransferButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '取消发送',
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.close_rounded, size: 17),
        color: const Color(0xFFC85D4D),
        style: IconButton.styleFrom(
          fixedSize: const Size(30, 30),
          minimumSize: const Size(30, 30),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class TransferProgressBar extends StatelessWidget {
  const TransferProgressBar({super.key, required this.progress});

  /// 0.0–1.0
  final double progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.clamp(0.0, 1.0) * 100).round();
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                color: _accent,
                backgroundColor: _panel,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$percent%', style: TextStyle(color: _muted, fontSize: 12)),
      ],
    );
  }
}

class CopyAttachmentButton extends StatelessWidget {
  const CopyAttachmentButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '复制',
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.copy_rounded, size: 16),
        color: _muted,
        style: IconButton.styleFrom(
          fixedSize: const Size(30, 30),
          minimumSize: const Size(30, 30),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: const Color(0xEEFFFFFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _BubbleSurface extends StatelessWidget {
  const _BubbleSurface({
    required this.message,
    required this.onRetrySend,
    required this.onCancelTransfer,
    required this.onCopyAttachment,
    required this.showImageCopyButton,
    required this.onPreviewImage,
  });

  final ChatMessage message;
  final VoidCallback onRetrySend;
  final VoidCallback onCancelTransfer;
  final ValueChanged<MessageAttachment> onCopyAttachment;
  final bool showImageCopyButton;
  final ValueChanged<MessageAttachment> onPreviewImage;

  @override
  Widget build(BuildContext context) {
    if (message.attachment != null) {
      return Flexible(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: message.text.trim().isEmpty ? 0 : 4,
            vertical: message.text.trim().isEmpty ? 0 : 2,
          ),
          child: MessageContent(
            message: message,
            onRetrySend: onRetrySend,
            onCancelTransfer: onCancelTransfer,
            onCopyAttachment: onCopyAttachment,
            showImageCopyButton: showImageCopyButton,
            onPreviewImage: onPreviewImage,
          ),
        ),
      );
    }

    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: message.isMe ? _bubbleMe : _surface,
          border: Border.all(
            color: message.isMe ? const Color(0xFFECD9CD) : _line,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A1F1E1D),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: MessageContent(
          message: message,
          onRetrySend: onRetrySend,
          onCancelTransfer: onCancelTransfer,
          onCopyAttachment: onCopyAttachment,
          showImageCopyButton: showImageCopyButton,
          onPreviewImage: onPreviewImage,
        ),
      ),
    );
  }
}

class MessageStatusIcon extends StatelessWidget {
  const MessageStatusIcon({super.key, required this.status});

  final MessageSendStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, color, tooltip) = switch (status) {
      MessageSendStatus.sending => (
        Icons.access_time_rounded,
        const Color(0xFFB7B1A5),
        '发送中',
      ),
      MessageSendStatus.sent => (Icons.done_all_rounded, _accent, '已发送'),
      MessageSendStatus.failed => (
        Icons.error_outline_rounded,
        const Color(0xFFC85D4D),
        '发送失败',
      ),
      MessageSendStatus.cancelled => (
        Icons.block_rounded,
        const Color(0xFFB7B1A5),
        '已取消',
      ),
      MessageSendStatus.none => (Icons.done_rounded, Colors.transparent, ''),
    };

    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class StableProgressBar extends StatelessWidget {
  const StableProgressBar({
    super.key,
    required this.value,
    required this.height,
    required this.color,
    required this.backgroundColor,
  });

  final double? value;
  final double height;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final normalized = (value ?? 0).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: ColoredBox(
        color: backgroundColor,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: normalized,
              heightFactor: 1,
              child: ColoredBox(color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class MessageStatusPill extends StatelessWidget {
  const MessageStatusPill({super.key, required this.status});

  final MessageSendStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, color, tooltip) = switch (status) {
      MessageSendStatus.sending => (
        Icons.access_time_rounded,
        const Color(0xFFB7B1A5),
        '发送中',
      ),
      MessageSendStatus.sent => (Icons.done_all_rounded, _accent, '已发送'),
      MessageSendStatus.failed => (
        Icons.error_outline_rounded,
        const Color(0xFFC85D4D),
        '发送失败',
      ),
      MessageSendStatus.cancelled => (
        Icons.block_rounded,
        const Color(0xFFB7B1A5),
        '已取消',
      ),
      MessageSendStatus.none => (Icons.done_rounded, Colors.transparent, ''),
    };

    return Tooltip(
      message: tooltip,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xEEFFFFFF),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

class MessageContent extends StatelessWidget {
  const MessageContent({
    super.key,
    required this.message,
    required this.onRetrySend,
    required this.onCancelTransfer,
    required this.onCopyAttachment,
    required this.showImageCopyButton,
    required this.onPreviewImage,
  });

  final ChatMessage message;
  final VoidCallback onRetrySend;
  final VoidCallback onCancelTransfer;
  final ValueChanged<MessageAttachment> onCopyAttachment;
  final bool showImageCopyButton;
  final ValueChanged<MessageAttachment> onPreviewImage;

  @override
  Widget build(BuildContext context) {
    final attachment = message.attachment;
    if (attachment == null) {
      return SelectableText(
        message.text,
        style: TextStyle(color: _text, fontSize: 14, height: 1.55),
      );
    }

    Widget content;
    if (attachment.isImage) {
      content = InkWell(
        key: const ValueKey('image-preview-button'),
        onTap: () => onPreviewImage(attachment),
        borderRadius: BorderRadius.circular(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AttachmentImagePreview(attachment: attachment),
        ),
      );
    } else {
      content = AttachmentTile(attachment: attachment);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.text.trim().isNotEmpty) ...[
          SelectableText(
            message.text,
            style: TextStyle(color: _text, fontSize: 14, height: 1.55),
          ),
          const SizedBox(height: 10),
        ],
        AttachmentMessageFrame(
          message: message,
          attachment: attachment,
          onRetrySend: onRetrySend,
          onCancelTransfer: onCancelTransfer,
          onCopyAttachment: () => onCopyAttachment(attachment),
          showCopyButton: !attachment.isImage || showImageCopyButton,
          child: content,
        ),
      ],
    );
  }
}

class AttachmentImagePreview extends StatelessWidget {
  const AttachmentImagePreview({super.key, required this.attachment});

  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final fallback = AttachmentTile(attachment: attachment);
    return SizedBox(
      width: 260,
      height: 180,
      child: Image.file(
        File(attachment.path),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => fallback,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return fallback;
        },
      ),
    );
  }
}

class AttachmentMessageFrame extends StatelessWidget {
  const AttachmentMessageFrame({
    super.key,
    required this.message,
    required this.attachment,
    required this.onRetrySend,
    required this.onCancelTransfer,
    required this.onCopyAttachment,
    required this.showCopyButton,
    required this.child,
  });

  final ChatMessage message;
  final MessageAttachment attachment;
  final VoidCallback onRetrySend;
  final VoidCallback onCancelTransfer;
  final VoidCallback onCopyAttachment;
  final bool showCopyButton;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final copyButton = showCopyButton
        ? CopyAttachmentButton(onPressed: onCopyAttachment)
        : null;
    final isSending = message.status == MessageSendStatus.sending;
    final statusButton = switch (message.status) {
      MessageSendStatus.failed => RetrySendButton(onPressed: onRetrySend),
      MessageSendStatus.sending => CancelTransferButton(
        onPressed: onCancelTransfer,
      ),
      _ => MessageStatusPill(status: message.status),
    };

    // While sending, show a thin progress bar + percentage under the tile.
    final body = (message.isMe && isSending)
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              child,
              const SizedBox(height: 6),
              TransferProgressBar(progress: message.progress ?? 0),
            ],
          )
        : child;

    if (message.isMe) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AttachmentActionRail(
            top: message.status != MessageSendStatus.none
                ? statusButton
                : const SizedBox(width: 30, height: 30),
            bottom: copyButton,
            attachment: attachment,
          ),
          const SizedBox(width: 6),
          Flexible(child: body),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        child,
        if (copyButton != null) ...[
          const SizedBox(width: 6),
          Padding(padding: const EdgeInsets.only(bottom: 3), child: copyButton),
        ],
      ],
    );
  }
}

class _AttachmentActionRail extends StatelessWidget {
  const _AttachmentActionRail({
    required this.top,
    required this.attachment,
    this.bottom,
  });

  final Widget top;
  final Widget? bottom;
  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: attachment.isImage ? 180 : 66,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [top, ?bottom],
      ),
    );
  }
}

class AttachmentTile extends StatelessWidget {
  const AttachmentTile({super.key, required this.attachment});

  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(attachment.icon, color: _accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  attachment.sizeLabel,
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FileCard extends StatelessWidget {
  const FileCard({super.key, required this.file});

  final TransferFile file;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      width: 240,
      padding: const EdgeInsets.all(12),
      backgroundColor: _surface,
      radius: BorderRadius.circular(8),
      border: ShadBorder.all(color: _line, width: 1),
      shadows: const [],
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(file.icon, color: _accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                Text(file.size, style: TextStyle(color: _muted, fontSize: 12)),
                const SizedBox(height: 8),
                StableProgressBar(
                  value: file.progress / 100,
                  height: 5,
                  color: _accent,
                  backgroundColor: const Color(0xFFEFECE3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${file.progress}%',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class Composer extends StatelessWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.pendingAttachments,
    required this.onSend,
    required this.onSendImage,
    required this.onSendFile,
    required this.onPasteImages,
    required this.onRemovePendingAttachment,
  });

  final TextEditingController controller;
  final List<MessageAttachment> pendingAttachments;
  final VoidCallback onSend;
  final VoidCallback onSendImage;
  final VoidCallback onSendFile;
  final Future<void> Function() onPasteImages;
  final ValueChanged<MessageAttachment> onRemovePendingAttachment;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyV, control: true):
            onPasteImages,
      },
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          border: Border(top: BorderSide(color: _line)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Row(
                children: [
                  _ComposerButton(
                    icon: Icons.image_outlined,
                    tooltip: '图片',
                    onPressed: onSendImage,
                  ),
                  _ComposerButton(
                    icon: Icons.attach_file_rounded,
                    tooltip: '文件',
                    onPressed: onSendFile,
                  ),
                  _ComposerButton(
                    icon: Icons.content_paste_rounded,
                    tooltip: '粘贴图片',
                    onPressed: () => onPasteImages(),
                  ),
                ],
              ),
            ),
            if (pendingAttachments.isNotEmpty)
              PendingAttachmentStrip(
                attachments: pendingAttachments,
                onRemove: onRemovePendingAttachment,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: ShadTextarea(
                      controller: controller,
                      key: const ValueKey('composer-input'),
                      minHeight: 78,
                      maxHeight: 130,
                      resizable: false,
                      placeholder: const Text('输入消息...'),
                      decoration: ShadDecoration(
                        color: Colors.transparent,
                        border: ShadBorder.all(
                          color: Colors.transparent,
                          width: 0,
                        ),
                        focusedBorder: ShadBorder.all(
                          color: Colors.transparent,
                          width: 0,
                        ),
                        secondaryBorder: ShadBorder.all(
                          color: Colors.transparent,
                          width: 0,
                        ),
                        secondaryFocusedBorder: ShadBorder.all(
                          color: Colors.transparent,
                          width: 0,
                        ),
                      ),
                      style: TextStyle(
                        color: _text,
                        fontSize: 14,
                        height: 1.55,
                      ),
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    height: 38,
                    child: ShadButton(
                      onPressed: onSend,
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      backgroundColor: _accent,
                      hoverBackgroundColor: Color.alphaBlend(
                        Colors.black.withValues(alpha: 0.08),
                        _accent,
                      ),
                      foregroundColor: Colors.white,
                      hoverForegroundColor: Colors.white,
                      child: const Text(
                        '发送',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerButton extends StatelessWidget {
  const _ComposerButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return _PressableScale(
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: onPressed ?? () {},
          icon: Icon(icon, size: 20),
          color: _muted,
          style: IconButton.styleFrom(
            fixedSize: const Size(36, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

class PendingAttachmentStrip extends StatelessWidget {
  const PendingAttachmentStrip({
    super.key,
    required this.attachments,
    required this.onRemove,
  });

  final List<MessageAttachment> attachments;
  final ValueChanged<MessageAttachment> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      margin: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final attachment = attachments[index];
          return _SoftAppear(
            key: ValueKey(attachment.path),
            delay: Duration(milliseconds: index * 30),
            offset: const Offset(0, 8),
            child: PendingAttachmentTile(
              attachment: attachment,
              onRemove: () => onRemove(attachment),
            ),
          );
        },
      ),
    );
  }
}

class PendingAttachmentTile extends StatelessWidget {
  const PendingAttachmentTile({
    super.key,
    required this.attachment,
    required this.onRemove,
  });

  final MessageAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: attachment.isImage ? 92 : 170,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F6F0),
                border: Border.all(color: _line),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: attachment.isImage
                    ? PendingAttachmentImagePreview(attachment: attachment)
                    : _PendingFilePreview(attachment: attachment),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Tooltip(
              message: '移除',
              child: IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 15),
                color: Colors.white,
                style: IconButton.styleFrom(
                  fixedSize: const Size(24, 24),
                  minimumSize: const Size(24, 24),
                  padding: EdgeInsets.zero,
                  backgroundColor: const Color(0x99000000),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PendingAttachmentImagePreview extends StatelessWidget {
  const PendingAttachmentImagePreview({super.key, required this.attachment});

  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final fallback = _PendingFilePreview(attachment: attachment);
    return Image.file(
      File(attachment.path),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => fallback,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return fallback;
      },
    );
  }
}

class _PendingFilePreview extends StatelessWidget {
  const _PendingFilePreview({required this.attachment});

  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(attachment.icon, color: _accent, size: 26),
          const SizedBox(height: 8),
          Text(
            attachment.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class InitialAvatar extends StatelessWidget {
  const InitialAvatar({super.key, required this.text, required this.size});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFE8E4D8),
        shape: BoxShape.circle,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: const Color(0xFF57544C),
          fontWeight: FontWeight.w700,
          fontSize: size <= 36 ? 13 : 15,
        ),
      ),
    );
  }
}

class Conversation {
  Conversation({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.time,
    required this.initials,
    required this.messages,
    required this.files,
    this.unread = 0,
    this.device,
    this.ephemeral = false,
  });

  final String title;
  final String subtitle;
  final String status;
  final String time;
  final String initials;
  final int unread;
  final List<ChatMessage> messages;
  final List<TransferFile> files;
  final DiscoveredDevice? device;

  /// True for a placeholder created purely from LAN discovery (no real message
  /// exchanged yet). Ephemeral conversations are not persisted to disk, so a
  /// device merely seen on the network does not accumulate as a ghost chat.
  final bool ephemeral;

  Conversation copyWith({
    String? title,
    String? subtitle,
    String? status,
    String? time,
    String? initials,
    int? unread,
    List<ChatMessage>? messages,
    List<TransferFile>? files,
    DiscoveredDevice? device,
  }) {
    return Conversation(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      status: status ?? this.status,
      time: time ?? this.time,
      initials: initials ?? this.initials,
      unread: unread ?? this.unread,
      messages: messages ?? this.messages,
      files: files ?? this.files,
      device: device ?? this.device,
      ephemeral: ephemeral,
    );
  }

  Conversation removeMessages(Set<String> messageIds) {
    final nextMessages = messages
        .where((message) => !messageIds.contains(message.id))
        .toList();
    if (nextMessages.length == messages.length) return this;

    final lastMessage = nextMessages.isEmpty ? null : nextMessages.last;
    return Conversation(
      title: title,
      subtitle: lastMessage == null ? '暂无聊天记录' : _subtitleFor(lastMessage),
      status: status,
      time: lastMessage == null ? time : '刚刚',
      initials: initials,
      unread: unread,
      messages: nextMessages,
      files: files,
      device: device,
      ephemeral: ephemeral,
    );
  }

  Conversation appendMessage(
    ChatMessage message, {
    required String subtitle,
    required int unread,
  }) {
    return Conversation(
      title: title,
      subtitle: subtitle,
      status: status,
      time: '刚刚',
      initials: initials,
      unread: unread,
      messages: [...messages, message],
      files: files,
      device: device,
      // A real message exchange promotes the conversation out of the
      // discovery-only placeholder state, so it is now worth persisting.
      ephemeral: false,
    );
  }

  Conversation updateMessageStatus(String messageId, MessageSendStatus status) {
    var changed = false;
    final nextMessages = messages.map((message) {
      if (message.id != messageId) return message;
      changed = true;
      return message.copyWith(status: status);
    }).toList();
    if (!changed) return this;

    return Conversation(
      title: title,
      subtitle: subtitle,
      status: this.status,
      time: time,
      initials: initials,
      unread: unread,
      messages: nextMessages,
      files: files,
      device: device,
      ephemeral: ephemeral,
    );
  }

  Conversation updateMessageProgress(String messageId, double progress) {
    var changed = false;
    final nextMessages = messages.map((message) {
      if (message.id != messageId) return message;
      changed = true;
      return message.copyWith(progress: progress);
    }).toList();
    if (!changed) return this;

    return Conversation(
      title: title,
      subtitle: subtitle,
      status: status,
      time: time,
      initials: initials,
      unread: unread,
      messages: nextMessages,
      files: files,
      device: device,
      ephemeral: ephemeral,
    );
  }

  String _subtitleFor(ChatMessage message) {
    final attachment = message.attachment;
    if (attachment != null) {
      return attachment.isImage
          ? '[图片] ${attachment.name}'
          : '[文件] ${attachment.name}';
    }
    return message.text;
  }

  /// Serializes the conversation (including chat history and the associated
  /// device) for local persistence across restarts.
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subtitle': subtitle,
      'status': status,
      'time': time,
      'initials': initials,
      'unread': unread,
      'ephemeral': ephemeral,
      'messages': messages.map((message) => message.toJson()).toList(),
      'files': files.map((file) => file.toJson()).toList(),
      'device': device?.toJson(),
    };
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final device = json['device'];
    return Conversation(
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      status: json['status'] as String? ?? '',
      time: json['time'] as String? ?? '',
      initials: json['initials'] as String? ?? '?',
      unread: json['unread'] is int ? json['unread'] as int : 0,
      ephemeral: json['ephemeral'] is bool ? json['ephemeral'] as bool : false,
      messages:
          (json['messages'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(ChatMessage.fromJson)
              .toList() ??
          [],
      files:
          (json['files'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(TransferFile.fromJson)
              .toList() ??
          [],
      device: device is Map<String, dynamic>
          ? DiscoveredDevice.fromJson(device)
          : null,
    );
  }
}

extension on DiscoveredDeviceType {
  String get label {
    return switch (this) {
      DiscoveredDeviceType.mobile => '移动设备',
      DiscoveredDeviceType.desktop => '桌面设备',
      DiscoveredDeviceType.web => '网页设备',
      DiscoveredDeviceType.headless => '无界面设备',
      DiscoveredDeviceType.server => '服务器',
    };
  }
}

class ChatMessage {
  ChatMessage(
    this.text, {
    String? id,
    this.sender = 'T',
    this.isMe = false,
    this.system = false,
    this.attachment,
    this.status = MessageSendStatus.none,
    this.progress,
    DateTime? createdAt,
  }) : id =
           id ??
           'msg-${(createdAt ?? DateTime.now()).microsecondsSinceEpoch}-${_nextSequence++}',
       createdAt = createdAt ?? DateTime.now();

  static int _nextSequence = 0;

  final String id;
  final String text;
  final String sender;
  final bool isMe;
  final bool system;
  final MessageAttachment? attachment;
  final MessageSendStatus status;
  final DateTime createdAt;

  /// Upload progress in 0.0–1.0 while [status] is sending; null when unknown.
  final double? progress;

  ChatMessage copyWith({MessageSendStatus? status, double? progress}) {
    return ChatMessage(
      text,
      id: id,
      sender: sender,
      isMe: isMe,
      system: system,
      attachment: attachment,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'sender': sender,
      'isMe': isMe,
      'system': system,
      'attachment': attachment?.toJson(),
      'status': status.name,
      'progress': progress,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    var status = MessageSendStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => MessageSendStatus.none,
    );
    // No live transfer survives a restart, so a persisted "sending" message is
    // stuck — surface it as failed so the user can retry.
    if (status == MessageSendStatus.sending) {
      status = MessageSendStatus.failed;
    }
    final attachment = json['attachment'];
    return ChatMessage(
      json['text'] as String? ?? '',
      id: json['id'] as String?,
      sender: json['sender'] as String? ?? 'T',
      isMe: json['isMe'] as bool? ?? false,
      system: json['system'] as bool? ?? false,
      attachment: attachment is Map<String, dynamic>
          ? MessageAttachment.fromJson(attachment)
          : null,
      status: status,
      progress: status == MessageSendStatus.failed
          ? null
          : (json['progress'] as num?)?.toDouble(),
      createdAt: _parseMessageCreatedAt(json),
    );
  }

  static DateTime _parseMessageCreatedAt(Map<String, dynamic> json) {
    final stored = DateTime.tryParse(json['createdAt'] as String? ?? '');
    if (stored != null) return stored;
    final id = json['id'] as String? ?? '';
    final match = RegExp(r'^msg-(\d+)').firstMatch(id);
    final micros = match == null ? null : int.tryParse(match.group(1)!);
    if (micros != null) {
      return DateTime.fromMicrosecondsSinceEpoch(micros);
    }
    return DateTime.now();
  }
}

enum MessageSendStatus { none, sending, sent, failed, cancelled }

enum TransferTaskDirection { incoming, outgoing }

enum TransferTaskStatus { waiting, transferring, completed, failed, cancelled }

class TransferTask {
  const TransferTask({
    required this.id,
    required this.direction,
    required this.status,
    required this.peerAlias,
    required this.fileName,
    required this.fileCount,
    required this.totalBytes,
    this.progress,
    this.subtitle,
    this.receivedFiles = 0,
  });

  factory TransferTask.outgoing({
    required String id,
    required String peerAlias,
    required String fileName,
    required int fileCount,
    required int totalBytes,
  }) {
    return TransferTask(
      id: id,
      direction: TransferTaskDirection.outgoing,
      status: TransferTaskStatus.transferring,
      peerAlias: peerAlias,
      fileName: fileName,
      fileCount: fileCount,
      totalBytes: totalBytes,
      progress: 0,
      subtitle: '准备发送',
    );
  }

  factory TransferTask.incomingRequest({
    required String id,
    required String peerAlias,
    required String fileName,
    required int fileCount,
    required int totalBytes,
  }) {
    return TransferTask(
      id: id,
      direction: TransferTaskDirection.incoming,
      status: TransferTaskStatus.waiting,
      peerAlias: peerAlias,
      fileName: fileName,
      fileCount: fileCount,
      totalBytes: totalBytes,
      subtitle: '等待确认',
    );
  }

  final String id;
  final TransferTaskDirection direction;
  final TransferTaskStatus status;
  final String peerAlias;
  final String fileName;
  final int fileCount;
  final int totalBytes;
  final double? progress;
  final String? subtitle;
  final int receivedFiles;

  TransferTask copyWith({
    TransferTaskStatus? status,
    double? progress,
    String? subtitle,
    int? receivedFiles,
  }) {
    return TransferTask(
      id: id,
      direction: direction,
      status: status ?? this.status,
      peerAlias: peerAlias,
      fileName: fileName,
      fileCount: fileCount,
      totalBytes: totalBytes,
      progress: progress ?? this.progress,
      subtitle: subtitle ?? this.subtitle,
      receivedFiles: receivedFiles ?? this.receivedFiles,
    );
  }
}

class MessageAttachment {
  MessageAttachment({
    required this.path,
    required this.name,
    required this.size,
    required this.kind,
    this.savedPath,
  });

  factory MessageAttachment.fromPath(String path) {
    final file = File(path);
    final name = p.basename(path);
    final extension = p.extension(path).toLowerCase();
    final size = file.existsSync() ? file.lengthSync() : 0;

    return MessageAttachment(
      path: path,
      name: name,
      size: size,
      kind: FileKind.fromExtension(extension),
    );
  }

  factory MessageAttachment.fromNearSend(
    NearSendAttachment attachment, {
    String? savedPath,
  }) {
    return MessageAttachment(
      path: attachment.path,
      name: attachment.name,
      size: attachment.size,
      kind: attachment.isImage ? FileKind.image : FileKind.file,
      savedPath: savedPath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
      'size': size,
      'kind': kind.name,
      'savedPath': savedPath,
    };
  }

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      path: json['path'] as String? ?? '',
      name: json['name'] as String? ?? '',
      size: json['size'] is int ? json['size'] as int : 0,
      kind: FileKind.fromName(json['kind']),
      savedPath: json['savedPath'] as String?,
    );
  }

  final String path;
  final String name;
  final int size;
  final FileKind kind;
  final String? savedPath;

  bool get isImage => kind == FileKind.image;

  String get sizeLabel {
    if (size <= 0) return '未知大小';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = size.toDouble();
    var index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }

    final digits = index == 0 || value >= 10 ? 0 : 1;
    return '${value.toStringAsFixed(digits)} ${units[index]}';
  }

  IconData get icon {
    switch (kind) {
      case FileKind.image:
        return Icons.image_rounded;
      case FileKind.pdf:
        return Icons.picture_as_pdf_rounded;
      case FileKind.archive:
        return Icons.folder_zip_rounded;
      case FileKind.doc:
        return Icons.description_rounded;
      case FileKind.file:
        return Icons.insert_drive_file_rounded;
    }
  }

  NearSendAttachment toNearSend() {
    return NearSendAttachment(
      path: path,
      name: name,
      size: size,
      type: isImage ? NearSendPayloadType.image : NearSendPayloadType.file,
    );
  }
}

class TransferFile {
  TransferFile(this.name, this.size, this.progress, this.kind);

  final String name;
  final String size;
  final int progress;
  final FileKind kind;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'size': size,
      'progress': progress,
      'kind': kind.name,
    };
  }

  factory TransferFile.fromJson(Map<String, dynamic> json) {
    return TransferFile(
      json['name'] as String? ?? '',
      json['size'] as String? ?? '',
      json['progress'] is int ? json['progress'] as int : 0,
      FileKind.fromName(json['kind']),
    );
  }

  IconData get icon {
    switch (kind) {
      case FileKind.image:
        return Icons.image_rounded;
      case FileKind.pdf:
        return Icons.picture_as_pdf_rounded;
      case FileKind.archive:
        return Icons.folder_zip_rounded;
      case FileKind.doc:
        return Icons.description_rounded;
      case FileKind.file:
        return Icons.insert_drive_file_rounded;
    }
  }
}

enum FileKind {
  image,
  pdf,
  archive,
  doc,
  file;

  static FileKind fromExtension(String extension) {
    return switch (extension) {
      '.jpg' ||
      '.jpeg' ||
      '.png' ||
      '.gif' ||
      '.webp' ||
      '.bmp' ||
      '.heic' ||
      '.heif' => FileKind.image,
      '.pdf' => FileKind.pdf,
      '.zip' || '.rar' || '.7z' || '.tar' || '.gz' => FileKind.archive,
      '.doc' ||
      '.docx' ||
      '.txt' ||
      '.md' ||
      '.xls' ||
      '.xlsx' ||
      '.ppt' ||
      '.pptx' => FileKind.doc,
      _ => FileKind.file,
    };
  }

  /// Parses a persisted enum name (see [FileKind.name]).
  static FileKind fromName(Object? value) {
    return FileKind.values.firstWhere(
      (kind) => kind.name == value,
      orElse: () => FileKind.file,
    );
  }

  IconData get icon {
    switch (this) {
      case FileKind.image:
        return Icons.image_rounded;
      case FileKind.pdf:
        return Icons.picture_as_pdf_rounded;
      case FileKind.archive:
        return Icons.folder_zip_rounded;
      case FileKind.doc:
        return Icons.description_rounded;
      case FileKind.file:
        return Icons.insert_drive_file_rounded;
    }
  }
}

extension StringInitials on String {
  String get initials {
    final trimmed = trim();
    if (trimmed.isEmpty) return '?';
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }
}
