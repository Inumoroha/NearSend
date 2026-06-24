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

import 'models/chat_message.dart';
import 'models/conversation.dart';
import 'models/device_type_label.dart';
import 'models/discovered_device.dart';
import 'models/file_kind.dart';
import 'models/message_attachment.dart';
import 'models/nearsend_message.dart';
import 'models/receive_history_entry.dart';
import 'models/string_initials.dart';
import 'models/transfer_file.dart';
import 'models/transfer_task.dart';
import 'services/android_platform.dart';
import 'services/conversation_store.dart';
import 'services/lan_discovery_service.dart';
import 'services/localsend_file_transfer.dart';
import 'services/localsend_identity.dart';
import 'services/manual_device_connector.dart';
import 'services/native_window_service.dart';
import 'services/nearsend_message_client.dart';
import 'services/receive_history_store.dart';
import 'services/temp_file_cleanup.dart' hide formatBytes;
import 'services/windows_clipboard_files.dart';
import 'services/windows_firewall_service.dart';
import 'ui/theme.dart';

// Re-export the symbols that were previously declared in this file so existing
// importers (tests, etc.) keep seeing them via `package:nearsend/main.dart`.
export 'models/chat_message.dart';
export 'models/conversation.dart';
export 'models/device_type_label.dart';
export 'models/file_kind.dart';
export 'models/message_attachment.dart';
export 'models/string_initials.dart';
export 'models/transfer_file.dart';
export 'models/transfer_task.dart';
export 'ui/theme.dart';

part 'ui/dialogs.dart';
part 'ui/sidebar.dart';
part 'pages/theme_page.dart';
part 'pages/settings_page.dart';
part 'pages/transfers_page.dart';
part 'pages/history_page.dart';
part 'pages/conversations.dart';
part 'pages/device_details_page.dart';
part 'widgets/message_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Window management is desktop-only; skip it on mobile platforms.
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
  }
  runApp(const NearSendApp());
}

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
            primary: appColors.accent,
            ring: appColors.accent,
            selection: appColors.accent.withValues(alpha: 0.20),
          ),
          textTheme: ShadTextTheme(family: 'HarmonyOS Sans SC'),
          radius: const BorderRadius.all(Radius.circular(8)),
        ),
        darkTheme: ShadThemeData(
          brightness: Brightness.dark,
          colorScheme: const ShadZincColorScheme.dark().copyWith(
            primary: appColors.accent,
            ring: appColors.accent,
            selection: appColors.accent.withValues(alpha: 0.28),
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
                seedColor: appColors.accent,
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
                color: appColors.surface,
                surfaceTintColor: Colors.transparent,
                elevation: 10,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: appColors.line),
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: TextStyle(color: appColors.text, fontSize: 13),
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
  // IDs of history entries whose file no longer exists on disk. Recomputed
  // asynchronously after the history changes; not persisted.
  Set<String> _staleHistoryIds = {};
  final Set<String> _clipboardAutoSendFingerprints = {};
  final Set<String> _favoriteDeviceFingerprints = {};
  Timer? _clipboardPollTimer;
  Timer? _presenceRefreshTimer;
  int _lastClipboardSequence = 0;
  StreamSubscription<DiscoveredDevice>? _discoverySubscription;
  StreamSubscription<NearSendMessage>? _messageSubscription;
  StreamSubscription<String>? _diagnosticSubscription;
  StreamSubscription<IncomingTransferRequest>? _incomingTransferSubscription;
  StreamSubscription<IncomingTransferProgress>? _incomingProgressSubscription;
  // Per-transfer-task smoothed byte-rate samplers, keyed by task id. Removed
  // when the task reaches a terminal state.
  final Map<String, _TransferRateTracker> _rateTrackers = {};
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
  Color _themeColor = themeColorOptions.first;
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
    applyPalette(_themeMode, _themeColor);
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
      _incomingProgressSubscription = _discoveryService.incomingProgress.listen(
        _handleIncomingProgress,
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
    unawaited(_incomingProgressSubscription?.cancel());
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
        ? themeColorOptions.first
        : Color(savedThemeColor);
    final autoSendFingerprints =
        preferences.getStringList(_clipboardAutoSendPreferenceKey) ??
        const <String>[];
    final favoriteFingerprints =
        preferences.getStringList(_favoriteDevicesPreferenceKey) ??
        const <String>[];
    final showImageCopyButton =
        preferences.getBool(_showImageCopyButtonPreferenceKey) ?? true;
    applyPalette(themeMode, themeColor);

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
      applyPalette(_themeMode, _themeColor);
    });
  }

  Future<void> _setThemeColor(Color color) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_themeColorPreferenceKey, color.toARGB32());
    setState(() {
      _themeColor = color;
      applyPalette(_themeMode, _themeColor);
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
    if (complete) _rateTrackers.remove(sessionId);
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
    unawaited(_refreshHistoryFileStatus());
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
    unawaited(_refreshHistoryFileStatus());
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
      _staleHistoryIds = _staleHistoryIds
          .where((id) => id != entry.id)
          .toSet();
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
      _staleHistoryIds = {};
    });
    unawaited(_historyStore.persist(_receiveHistory));

    if (result.alsoDeleteFile) {
      for (final entry in removed) {
        await _deleteFileQuietly(entry.path);
      }
    }
  }

  /// Re-checks which history entries point at files that no longer exist and
  /// updates [_staleHistoryIds]. Runs file I/O off the build path; the result is
  /// pruned to ids still present in the (possibly changed) current list.
  Future<void> _refreshHistoryFileStatus() async {
    final snapshot = List<ReceiveHistoryEntry>.from(_receiveHistory);
    final stale = <String>{};
    for (final entry in snapshot) {
      if (entry.path.trim().isEmpty || !await File(entry.path).exists()) {
        stale.add(entry.id);
      }
    }
    if (!mounted) return;
    final liveIds = _receiveHistory.map((entry) => entry.id).toSet();
    setState(() {
      _staleHistoryIds = stale.where(liveIds.contains).toSet();
    });
  }

  /// Removes history records whose files are gone. Does not touch the disk
  /// (the files are already missing), so no "also delete file" option is shown.
  Future<void> _cleanupStaleHistory() async {
    final staleIds = _staleHistoryIds;
    final count = _receiveHistory
        .where((entry) => staleIds.contains(entry.id))
        .length;
    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return TeaDialog(
          title: const Text('清理失效记录'),
          icon: Icons.cleaning_services_rounded,
          width: 380,
          content: Text(
            '移除 $count 条文件已不存在的记录（不影响磁盘上的文件）。',
            style: TextStyle(color: appColors.text, fontSize: 14, height: 1.5),
          ),
          actions: [
            TeaDialogButton(
              onPressed: () => Navigator.of(context).pop(false),
              label: '取消',
            ),
            TeaDialogButton(
              onPressed: () => Navigator.of(context).pop(true),
              label: '清理',
              filled: true,
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _receiveHistory = _receiveHistory
          .where((entry) => !staleIds.contains(entry.id))
          .toList();
      _staleHistoryIds = {};
    });
    unawaited(_historyStore.persist(_receiveHistory));
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
                    style: TextStyle(color: appColors.text, fontSize: 14, height: 1.5),
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
                            activeColor: appColors.accent,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '同时删除磁盘上的文件',
                            style: TextStyle(color: appColors.text, fontSize: 13),
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
                  border: Border.all(color: appColors.line),
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
                  color: appColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '其他 NearSend 客户端扫描后可连接本机',
                textAlign: TextAlign.center,
                style: TextStyle(color: appColors.muted, fontSize: 12),
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
          final rate = _rateTrackers
              .putIfAbsent(message.id, _TransferRateTracker.new)
              .update(sent);
          _updateMessageProgress(message.id, progress);
          _updateTransferTask(
            message.id,
            progress: progress,
            status: TransferTaskStatus.transferring,
            subtitle: _progressSubtitle(sent, total, rate),
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
      primaryColor: appColors.accent,
      backgroundColor: appColors.surface,
      foregroundColor: appColors.text,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.fromLTRB(0, 12, 18, 0),
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: appColors.line),
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
    if (status != null && status != TransferTaskStatus.transferring) {
      // Transfer reached a terminal state — drop its rate sampler.
      _rateTrackers.remove(id);
    }
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

  /// Updates an incoming task's bar with live byte progress as the file is
  /// written to disk. For multi-file sessions the bar blends completed files
  /// (tracked by [_markIncomingFileReceived]) with the current file's fraction.
  void _handleIncomingProgress(IncomingTransferProgress progress) {
    if (!mounted) return;
    final index = _transferTasks.indexWhere(
      (item) => item.id == progress.sessionId,
    );
    if (index == -1) return;
    final task = _transferTasks[index];
    if (task.status != TransferTaskStatus.transferring &&
        task.status != TransferTaskStatus.waiting) {
      return;
    }

    final tracker = _rateTrackers.putIfAbsent(
      progress.sessionId,
      _TransferRateTracker.new,
    );
    final rate = tracker.update(progress.received);

    final fileCount = task.fileCount <= 0 ? 1 : task.fileCount;
    final completedFraction = task.receivedFiles / fileCount;
    final currentFraction = progress.total <= 0
        ? 0.0
        : (progress.received / progress.total) / fileCount;
    final ratio = (completedFraction + currentFraction).clamp(0.0, 1.0);

    _updateTransferTask(
      progress.sessionId,
      progress: ratio,
      status: TransferTaskStatus.transferring,
      subtitle: _progressSubtitle(progress.received, progress.total, rate),
    );
  }

  /// Builds a transfer subtitle like "5.0 / 20.0 MB · 3.2 MB/s · 剩余 5 秒".
  /// Speed and ETA are omitted until a meaningful rate is sampled.
  String _progressSubtitle(int sent, int total, double bytesPerSecond) {
    final base = '${formatBytes(sent)} / ${formatBytes(total)}';
    if (bytesPerSecond < 1) return base;
    final speed = '${formatBytes(bytesPerSecond.round())}/s';
    final remaining = total - sent;
    if (remaining <= 0) return '$base · $speed';
    final etaSeconds = (remaining / bytesPerSecond).ceil();
    return '$base · $speed · 剩余 ${_formatEta(etaSeconds)}';
  }

  String _formatEta(int seconds) {
    if (seconds < 60) return '$seconds 秒';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes < 60) return secs == 0 ? '$minutes 分' : '$minutes 分 $secs 秒';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins == 0 ? '$hours 时' : '$hours 时 $mins 分';
  }

  Future<void> _cancelTransfer(String messageId) async {
    final handle = _transferHandles[messageId];
    if (handle != null) {
      // Outgoing transfer: abort the upload and notify the receiver.
      handle.cancel();
      unawaited(_localSendTransfer.cancelRemote(handle));
      _updateTransferTask(
        messageId,
        status: TransferTaskStatus.cancelled,
        subtitle: '正在取消',
      );
      return;
    }

    // Incoming transfer: confirm before discarding the partial download.
    final index = _transferTasks.indexWhere((item) => item.id == messageId);
    if (index == -1) return;
    final task = _transferTasks[index];
    if (task.direction != TransferTaskDirection.incoming ||
        task.status != TransferTaskStatus.transferring) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return TeaDialog(
          title: const Text('中断接收'),
          icon: Icons.cancel_outlined,
          width: 380,
          content: Text(
            '中断接收「${task.fileName}」？已下载的部分将被丢弃。',
            style: TextStyle(color: appColors.text, fontSize: 14, height: 1.5),
          ),
          actions: [
            TeaDialogButton(
              onPressed: () => Navigator.of(context).pop(false),
              label: '继续接收',
            ),
            TeaDialogButton(
              onPressed: () => Navigator.of(context).pop(true),
              label: '中断',
              filled: true,
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    _discoveryService.cancelIncomingTransfer(messageId);
    _incomingTransferRequests.remove(messageId);
    _updateTransferTask(
      messageId,
      status: TransferTaskStatus.cancelled,
      subtitle: '已取消',
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
          final rate = _rateTrackers
              .putIfAbsent(message.id, _TransferRateTracker.new)
              .update(sent);
          _updateMessageProgress(message.id, progress);
          _updateTransferTask(
            message.id,
            progress: progress,
            status: TransferTaskStatus.transferring,
            subtitle: _progressSubtitle(sent, total, rate),
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
      backgroundColor: appColors.panel,
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
          color: appColors.panel,
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
                    staleIds: _staleHistoryIds,
                    onOpenFile: _openHistoryFile,
                    onOpenFolder: _openHistoryFolder,
                    onDelete: _deleteHistoryEntry,
                    onClear: _clearReceiveHistory,
                    onCleanupStale: _cleanupStaleHistory,
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
                              style: TextStyle(color: appColors.muted, fontSize: 14),
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

enum _MainSection { chats, transfers, theme, settings, history }

enum _ConversationMenuAction { rename, favorite, clear, delete }

/// A label/value row used in the device-info dialog.

/// Smooths a transfer's instantaneous byte rate into a stable bytes/sec value.
///
/// Fed cumulative byte counts via [update]; uses an exponential moving average
/// so the displayed speed does not jitter with per-chunk timing noise.
class _TransferRateTracker {
  int? _lastBytes;
  DateTime? _lastTime;
  double _rate = 0;

  double update(int bytes) {
    final now = DateTime.now();
    final lastBytes = _lastBytes;
    final lastTime = _lastTime;
    _lastBytes = bytes;
    _lastTime = now;
    if (lastBytes == null || lastTime == null) return _rate;

    final deltaBytes = bytes - lastBytes;
    final deltaSeconds = now.difference(lastTime).inMicroseconds / 1000000.0;
    if (deltaSeconds <= 0 || deltaBytes < 0) return _rate;

    final instant = deltaBytes / deltaSeconds;
    _rate = _rate == 0 ? instant : _rate * 0.7 + instant * 0.3;
    return _rate;
  }
}

