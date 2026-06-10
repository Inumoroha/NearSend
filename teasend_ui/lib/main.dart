import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'models/discovered_device.dart';
import 'models/nearsend_message.dart';
import 'models/receive_history_entry.dart';
import 'services/android_platform.dart';
import 'services/lan_discovery_service.dart';
import 'services/localsend_file_transfer.dart';
import 'services/localsend_identity.dart';
import 'services/manual_device_connector.dart';
import 'services/native_window_service.dart';
import 'services/nearsend_message_client.dart';
import 'services/receive_history_store.dart';
import 'services/windows_clipboard_files.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Window management is desktop-only; skip it on mobile platforms.
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
  }
  runApp(const NearSendApp());
}

Color _sidebar = const Color(0xFF1F1E1D);
Color _sidebarMuted = const Color(0xFF8D8A80);
Color _panel = const Color(0xFFF5F4EE);
Color _surface = const Color(0xFFFFFFFF);
Color _line = const Color(0xFFE5E3DA);
Color _text = const Color(0xFF1F1E1D);
Color _muted = const Color(0xFF6F6E69);
Color _accent = const Color(0xFFD97757);
Color _accentSoft = const Color(0xFFF7EDE8);
const _warning = Color(0xFFCB9A4B);
Color _bubbleMe = const Color(0xFFF5E9E2);
Color _chatBg = const Color(0xFFFAF9F5);
const _minimizeToTrayPreferenceKey = 'minimize_to_tray';
const _overwriteSameNameFilesPreferenceKey = 'overwrite_same_name_files';
const _themeModePreferenceKey = 'theme_mode';
const _themeColorPreferenceKey = 'theme_color';
const _clipboardAutoSendPreferenceKey = 'clipboard_auto_send_fingerprints';

enum AppThemeMode { light, dark }

const _themeColorOptions = [
  Color(0xFFD97757),
  Color(0xFF3D8F73),
  Color(0xFF3B82C4),
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
      sidebar: const Color(0xFF171615),
      sidebarMuted: const Color(0xFF8F8A82),
      panel: const Color(0xFF23211F),
      surface: const Color(0xFF2C2926),
      line: const Color(0xFF3F3A35),
      text: const Color(0xFFF2EEE8),
      muted: const Color(0xFFB4ACA3),
      accent: accent,
      accentSoft: Color.alphaBlend(
        accent.withValues(alpha: 0.18),
        const Color(0xFF2C2926),
      ),
      bubbleMe: Color.alphaBlend(
        accent.withValues(alpha: 0.20),
        const Color(0xFF2C2926),
      ),
      chatBg: const Color(0xFF1F1D1B),
    );
  }

  return _ThemePalette(
    sidebar: const Color(0xFF1F1E1D),
    sidebarMuted: const Color(0xFF8D8A80),
    panel: const Color(0xFFF5F4EE),
    surface: const Color(0xFFFFFFFF),
    line: const Color(0xFFE5E3DA),
    text: const Color(0xFF1F1E1D),
    muted: const Color(0xFF6F6E69),
    accent: accent,
    accentSoft: Color.alphaBlend(accent.withValues(alpha: 0.12), Colors.white),
    bubbleMe: Color.alphaBlend(accent.withValues(alpha: 0.14), Colors.white),
    chatBg: const Color(0xFFFAF9F5),
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

class NearSendApp extends StatelessWidget {
  const NearSendApp({super.key, this.enableDiscovery = true});

  final bool enableDiscovery;

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      child: MaterialApp(
        title: 'NearSend',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: _accent,
            brightness: Brightness.light,
          ),
          fontFamily: 'Microsoft YaHei',
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
  final _nativeWindow = const NativeWindowService();
  final _discoveryService = LanDiscoveryService();
  late final _messageClient = NearSendMessageClient(
    identity: _discoveryService.identity,
  );
  late final _localSendTransfer = LocalSendFileTransferService(
    identity: _discoveryService.identity,
  );
  late final _manualConnector = ManualDeviceConnector(
    identity: _discoveryService.identity,
  );
  final Map<String, DiscoveredDevice> _devices = {};
  final Map<String, Conversation> _deviceConversations = {};
  final Map<String, TransferHandle> _transferHandles = {};
  final _historyStore = ReceiveHistoryStore();
  List<ReceiveHistoryEntry> _receiveHistory = [];
  final Set<String> _clipboardAutoSendFingerprints = {};
  Timer? _clipboardPollTimer;
  int _lastClipboardSequence = 0;
  StreamSubscription<DiscoveredDevice>? _discoverySubscription;
  StreamSubscription<NearSendMessage>? _messageSubscription;
  bool _isScanning = false;
  bool _messageSelectionMode = false;
  bool _showDeviceDetails = false;
  bool _autoSaveEnabled = false;
  bool _overwriteSameNameFiles = false;
  bool _minimizeToTrayEnabled = false;
  bool _trayReady = false;
  bool _quittingFromTray = false;
  bool _restoringSettings = true;
  AppThemeMode _themeMode = AppThemeMode.light;
  Color _themeColor = _themeColorOptions.first;
  MessageAttachment? _previewImage;
  String _scanStatus = '正在监听局域网设备';
  late String _autoSaveDirectory;
  _MainSection _activeSection = _MainSection.chats;
  int _selected = 0;
  // On narrow (phone) layouts, whether the full-screen chat page is open over
  // the conversation list. Ignored on wide layouts which show both side by side.
  bool _mobileChatOpen = false;
  final Set<String> _selectedMessageIds = {};

  final List<Conversation> _conversations = [
    Conversation(
      title: '文件传输助手',
      subtitle: '已保存 3 个文件到本地',
      status: '常用工具',
      time: '周五',
      initials: '文',
      messages: [
        ChatMessage('周五 14:22', system: true),
        ChatMessage('文件会暂时保留在本地下载目录', sender: '文'),
      ],
      files: [
        TransferFile('invoice.pdf', '680 KB', 100, FileKind.pdf),
        TransferFile('photo-set.zip', '42.6 MB', 100, FileKind.archive),
      ],
    ),
  ];

  String get _defaultAutoSaveDirectory {
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
        _autoSaveDirectory = p.join(dir.path, 'NearSend');
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
    unawaited(_loadReceiveHistory());
    if (widget.enableDiscovery) {
      // Android drops inbound multicast unless a MulticastLock is held.
      unawaited(AndroidPlatform.acquireMulticastLock());
      _discoverySubscription = _discoveryService.devices.listen(_upsertDevice);
      _messageSubscription = _discoveryService.messages.listen(
        (message) => unawaited(_handleIncomingMessage(message)),
      );
      unawaited(_startDiscovery());
    } else {
      _scanStatus = '测试模式未启动局域网发现';
    }
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
    unawaited(AndroidPlatform.releaseMulticastLock());
    unawaited(_discoverySubscription?.cancel());
    unawaited(_messageSubscription?.cancel());
    unawaited(_localSendTransfer.dispose());
    unawaited(_discoveryService.dispose());
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
    _applyPalette(_buildPalette(themeMode, themeColor));

    if (enabled && Platform.isWindows) {
      await _nativeWindow.setMinimizeToTrayEnabled(true);
      await windowManager.setPreventClose(true);
      unawaited(_ensureTrayReady());
    }

    if (!mounted) return;
    setState(() {
      _minimizeToTrayEnabled = enabled;
      _overwriteSameNameFiles = overwriteSameNameFiles;
      _themeMode = themeMode;
      _themeColor = themeColor;
      _clipboardAutoSendFingerprints
        ..clear()
        ..addAll(autoSendFingerprints);
      _restoringSettings = false;
    });
    _syncClipboardPolling();
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

  Future<void> _setOverwriteSameNameFiles(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_overwriteSameNameFilesPreferenceKey, enabled);
    if (!mounted) return;
    setState(() {
      _overwriteSameNameFiles = enabled;
    });
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
  void onWindowMinimize() {
    if (_minimizeToTrayEnabled) {
      unawaited(_hideToTray());
    }
  }

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

  void _upsertDevice(DiscoveredDevice device) {
    if (!mounted) return;
    setState(() {
      _devices[device.fingerprint] = device;
      _deviceConversations.putIfAbsent(
        device.fingerprint,
        () => _deviceConversation(device),
      );
      _scanStatus = '已发现 ${_devices.length} 台设备';
      if (_selected >= _visibleConversations.length) {
        _selected = 0;
      }
    });
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
    );
  }

  Future<void> _handleIncomingMessage(NearSendMessage message) async {
    if (!mounted) return;
    final fingerprint = message.senderFingerprint.isEmpty
        ? 'incoming-${message.senderAlias}'
        : message.senderFingerprint;
    final device = _devices[fingerprint];
    final attachment = await _incomingAttachment(message.attachment);
    if (!mounted) return;
    if (attachment != null) {
      unawaited(_recordReceiveHistory(message.senderAlias, attachment));
    }
    final chatMessage = ChatMessage(
      message.text,
      sender: message.senderAlias.initials,
      attachment: attachment,
    );

    setState(() {
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
              .appendMessage(
                chatMessage,
                subtitle: _messageSubtitle(chatMessage),
                unread: _selectedConversationFingerprint == fingerprint ? 0 : 1,
              );
    });
    _scrollToBottom();
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
      return MessageAttachment.fromPath(savedPath);
    } catch (_) {
      if (mounted) {
        _showToast('自动保存失败，文件暂时保留在临时目录');
      }
      return MessageAttachment.fromNearSend(attachment);
    }
  }

  Future<String> _autoSaveIncomingFile(NearSendAttachment attachment) async {
    final safeName = attachment.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    // On Android, write into the public Downloads folder through MediaStore so
    // the file is visible to file managers and survives without runtime perms.
    if (Platform.isAndroid) {
      final saved = await AndroidPlatform.saveToDownloads(
        sourcePath: attachment.path,
        fileName: safeName,
        mimeType: _mimeForName(safeName),
      );
      if (saved != null) return saved;
      // Fall through to direct file IO if MediaStore failed.
    }

    final directoryPath = _autoSaveDirectory.trim().isEmpty
        ? _defaultAutoSaveDirectory
        : _autoSaveDirectory.trim();
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

  String get _activeAutoSaveDirectory => _autoSaveDirectory.trim().isEmpty
      ? _defaultAutoSaveDirectory
      : _autoSaveDirectory.trim();

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
      autoSaved =
          _autoSaveEnabled &&
          p.isWithin(_activeAutoSaveDirectory, attachment.path);
    } catch (_) {
      autoSaved = false;
    }

    final entry = ReceiveHistoryEntry(
      id: 'history-${DateTime.now().microsecondsSinceEpoch}',
      fileName: attachment.name,
      size: attachment.size,
      senderAlias: senderAlias.isEmpty ? '未知设备' : senderAlias,
      path: attachment.path,
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
      message: '从接收历史中移除「${entry.fileName}」。',
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


  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty && _pendingAttachments.isEmpty) return;

    if (text.isNotEmpty) {
      final message = ChatMessage(
        text,
        isMe: true,
        status: _selectedDevice == null
            ? MessageSendStatus.sent
            : MessageSendStatus.sending,
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
        status: _selectedDevice == null
            ? MessageSendStatus.sent
            : MessageSendStatus.sending,
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
          extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
        ),
      ],
    );
    _addPendingAttachments(files.map((file) => file.path));
  }

  Future<void> _sendFile() async {
    final files = await openFiles();
    _addPendingAttachments(files.map((file) => file.path));
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
    final ipController = TextEditingController();
    final portController = TextEditingController(
      text: LocalSendIdentity.defaultPort.toString(),
    );
    final localEndpoints = _loadLocalConnectEndpoints();

    try {
      final result = await showDialog<_ManualConnectInput>(
        context: context,
        builder: (context) {
          return TeaDialog(
            title: const Text('手动连接'),
            icon: Icons.add_link_rounded,
            width: 420,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: ipController,
                  autofocus: true,
                  decoration: teaInputDecoration(
                    labelText: '对方 IP 地址',
                    hintText: '例如 192.168.1.20',
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: portController,
                  decoration: teaInputDecoration(
                    labelText: '端口号',
                    hintText: '默认 53317',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: (_) => _submitManualConnectDialog(
                    context,
                    ipController,
                    portController,
                  ),
                ),
                const SizedBox(height: 18),
                _LocalConnectInfo(
                  endpoints: localEndpoints,
                  onCopy: _copyLocalConnectEndpoint,
                ),
              ],
            ),
            actions: [
              TeaDialogButton(
                onPressed: () => Navigator.of(context).pop(),
                label: '取消',
              ),
              TeaDialogButton(
                onPressed: () => _submitManualConnectDialog(
                  context,
                  ipController,
                  portController,
                ),
                label: '连接',
                filled: true,
              ),
            ],
          );
        },
      );

      if (result == null || !mounted) return;
      await _connectManualDevice(result.host, result.port);
    } finally {
      ipController.dispose();
      portController.dispose();
    }
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

  Future<void> _copyLocalConnectEndpoint(String endpoint) async {
    final value = endpoint.contains('未找到') ? endpoint : endpoint.trim();
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    _showToast('已复制：$value');
  }

  void _submitManualConnectDialog(
    BuildContext context,
    TextEditingController ipController,
    TextEditingController portController,
  ) {
    final host = ipController.text.trim();
    final port = int.tryParse(portController.text.trim());
    if (host.isEmpty || port == null || port < 1 || port > 65535) {
      _showToast('请输入有效的 IP 地址和端口号');
      return;
    }

    Navigator.of(context).pop(_ManualConnectInput(host: host, port: port));
  }

  Future<void> _connectManualDevice(String host, int port) async {
    setState(() {
      _isScanning = true;
      _scanStatus = '正在连接 $host:$port...';
    });

    try {
      final device = await _manualConnector.connect(host: host, port: port);
      if (!mounted) return;
      _upsertDevice(device);
      final selectedIndex = _networkConversationKeys.indexOf(
        device.fingerprint,
      );
      setState(() {
        if (selectedIndex >= 0) {
          _selected = selectedIndex;
        }
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
    if (target == null) return;

    final attachment = message.attachment;
    if (attachment == null) {
      try {
        await _messageClient.sendText(target: target, text: message.text);
        _updateMessageStatus(message.id, MessageSendStatus.sent);
      } catch (_) {
        _updateMessageStatus(message.id, MessageSendStatus.failed);
        _appendSystemMessage('文字发送失败：对方需要支持 NearSend 消息接口。');
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
    try {
      await _localSendTransfer.sendFile(
        target: target,
        path: attachment.path,
        handle: handle,
        onProgress: (sent, total) => _updateMessageProgress(
          message.id,
          total == 0 ? 0 : sent / total,
        ),
      );
      _updateMessageStatus(message.id, MessageSendStatus.sent);
    } on TransferCancelledException {
      _updateMessageStatus(message.id, MessageSendStatus.cancelled);
    } catch (_) {
      _updateMessageStatus(message.id, MessageSendStatus.failed);
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
    toastification.show(
      context: context,
      title: Text(message),
      type: ToastificationType.info,
      style: ToastificationStyle.minimal,
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 3),
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

  void _cancelTransfer(String messageId) {
    _transferHandles[messageId]?.cancel();
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
  }

  Future<void> _showConversationMenu(int index, Offset position) async {
    final action = await showMenu<_ConversationMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: const [
        PopupMenuItem(
          value: _ConversationMenuAction.rename,
          child: _PopupMenuActionLabel(icon: Icons.edit_rounded, label: '重命名'),
        ),
        PopupMenuItem(
          value: _ConversationMenuAction.clear,
          child: _PopupMenuActionLabel(
            icon: Icons.cleaning_services_rounded,
            label: '清空会话',
          ),
        ),
        PopupMenuItem(
          value: _ConversationMenuAction.delete,
          child: _PopupMenuActionLabel(
            icon: Icons.delete_outline_rounded,
            label: '删除会话',
            danger: true,
          ),
        ),
      ],
    );
    if (action == null || !mounted) return;

    switch (action) {
      case _ConversationMenuAction.rename:
        await _renameConversation(index);
      case _ConversationMenuAction.clear:
        _clearConversation(index);
      case _ConversationMenuAction.delete:
        _deleteConversation(index);
    }
  }

  Future<void> _renameConversation(int index) async {
    final conversation = _visibleConversations[index];
    final controller = TextEditingController(text: conversation.title);
    try {
      final title = await showDialog<String>(
        context: context,
        builder: (context) {
          return TeaDialog(
            title: const Text('重命名'),
            icon: Icons.edit_rounded,
            width: 360,
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: teaInputDecoration(hintText: '输入会话名称'),
              onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
            ),
            actions: [
              TeaDialogButton(
                onPressed: () => Navigator.of(context).pop(),
                label: '取消',
              ),
              TeaDialogButton(
                onPressed: () =>
                    Navigator.of(context).pop(controller.text.trim()),
                label: '确定',
                filled: true,
              ),
            ],
          );
        },
      );
      if (title == null || title.isEmpty || !mounted) return;
      _updateConversationAt(index, (conversation) {
        return conversation.copyWith(title: title, initials: title.initials);
      });
    } finally {
      controller.dispose();
    }
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
      } else {
        final conversationIndex = index - _networkConversationCount;
        _conversations.removeAt(conversationIndex);
      }
      _selected = _selected.clamp(0, _visibleConversations.length - 1).toInt();
      _messageSelectionMode = false;
      _showDeviceDetails = false;
      _selectedMessageIds.clear();
    });
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
  }

  void _showChatsSection() {
    setState(() {
      _activeSection = _MainSection.chats;
    });
  }

  void _showSettingsSection() {
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
    final directory = await getDirectoryPath(
      initialDirectory: Directory(_autoSaveDirectory).existsSync()
          ? _autoSaveDirectory
          : null,
    );
    if (directory == null || !mounted) return;
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
          existing ??
          (device != null ? _deviceConversation(device) : null);
      if (base == null) return;
      _deviceConversations[fingerprint] = base.appendMessage(
        message,
        subtitle: subtitle,
        unread: _selectedConversationFingerprint == fingerprint ? 0 : 1,
      );
    });
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
    try {
      await _localSendTransfer.sendFile(
        target: device,
        path: path,
        handle: handle,
        onProgress: (sent, total) => _updateMessageProgress(
          message.id,
          total == 0 ? 0 : sent / total,
        ),
      );
      _updateMessageStatus(message.id, MessageSendStatus.sent);
    } on TransferCancelledException {
      _updateMessageStatus(message.id, MessageSendStatus.cancelled);
    } catch (_) {
      _updateMessageStatus(message.id, MessageSendStatus.failed);
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
    _scrollToBottom();
  }

  DiscoveredDevice? get _selectedDevice {
    final fingerprint = _selectedConversationFingerprint;
    if (fingerprint == null) return null;
    return _devices[fingerprint];
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
        ? width - 76
        : width;
    final conversations = _visibleConversations;
    final safeSelected = _selected.clamp(0, conversations.length - 1).toInt();
    final selected = conversations[safeSelected];
    final showChatPage = wide || _mobileChatOpen;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _panel,
      drawer: showDrawer
          ? _NavDrawer(
              activeSection: _activeSection,
              onChats: _showChatsSection,
              onTheme: _showThemeSection,
              onSettings: _showSettingsSection,
              onHistory: _showHistorySection,
            )
          : null,
      body: SafeArea(
        child: ColoredBox(
          color: _surface,
          child: Row(
            children: [
              if (hasRail)
                _Sidebar(
                  activeSection: _activeSection,
                  onChats: _showChatsSection,
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
            else if (_activeSection == _MainSection.settings)
              Expanded(
                child: SettingsPage(
                  autoSaveEnabled: _autoSaveEnabled,
                  autoSaveDirectory: _autoSaveDirectory,
                  overwriteSameNameFiles: _overwriteSameNameFiles,
                  minimizeToTrayEnabled: _minimizeToTrayEnabled,
                  restoringWindowSettings: _restoringSettings,
                  onAutoSaveChanged: (value) => setState(() {
                    _autoSaveEnabled = value;
                  }),
                  onOverwriteSameNameFilesChanged: _setOverwriteSameNameFiles,
                  onMinimizeToTrayChanged: _setMinimizeToTrayEnabled,
                  onChooseDirectory: _chooseAutoSaveDirectory,
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
                    isScanning: _isScanning,
                    scanStatus: _scanStatus,
                    selected: _selected,
                    onRefresh: _refreshDevices,
                    onShowQrCode: _showConnectionQrDialog,
                    onManualConnect: _showManualConnectDialog,
                    onContextMenu: _showConversationMenu,
                    onMenu: showDrawer ? _openNavDrawer : null,
                    onSelect: (index) => setState(() {
                      _selected = index;
                      _pendingAttachments.clear();
                      _messageSelectionMode = false;
                      _showDeviceDetails = false;
                      _previewImage = null;
                      _selectedMessageIds.clear();
                      if (!wide) _mobileChatOpen = true;
                      if (index >= _networkConversationCount) {
                        final conversationIndex =
                            index - _networkConversationCount;
                        _conversations[conversationIndex] =
                            _conversations[conversationIndex].copyWith(
                              unread: 0,
                            );
                      }
                    }),
                  ),
                ),
              if (showChatPage)
                Expanded(
                  child: PopScope(
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
                      onRemovePendingAttachment: _removePendingAttachment,
                      selectionMode: _messageSelectionMode,
                      showDetails: _showDeviceDetails,
                      selectedMessageIds: _selectedMessageIds,
                      onEnterSelectionMode: _enterMessageSelectionMode,
                      onExitSelectionMode: _exitMessageSelectionMode,
                      onShowDetails: _showConversationDetails,
                      onHideDetails: _hideConversationDetails,
                      onToggleMessageSelection: _toggleMessageSelection,
                      onDeleteSelectedMessages: _deleteSelectedMessages,
                      onToggleSelectAllMessages: _toggleSelectAllMessages,
                      onRetrySendAttachment: _retrySendAttachment,
                      onCancelTransfer: _cancelTransfer,
                      onCopyAttachment: _copyAttachmentPath,
                      previewImage: _previewImage,
                      onPreviewImage: _openImagePreview,
                      onClosePreview: _closeImagePreview,
                      clipboardAutoSendEnabled: _clipboardAutoSendFingerprints
                          .contains(_selectedConversationFingerprint),
                      onClipboardAutoSendChanged: (value) {
                        final fingerprint = _selectedConversationFingerprint;
                        if (fingerprint != null) {
                          _setClipboardAutoSendEnabled(fingerprint, value);
                        }
                      },
                      onMobileBack: (!wide && _mobileChatOpen)
                          ? () => setState(() => _mobileChatOpen = false)
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
    required this.onChats,
    required this.onTheme,
    required this.onSettings,
    required this.onHistory,
  });

  final _MainSection activeSection;
  final VoidCallback onChats;
  final VoidCallback onTheme;
  final VoidCallback onSettings;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      color: _sidebar,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      child: Column(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: _accent,
            child: const Text(
              'T',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
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
          const _NavIcon(icon: Icons.devices_rounded, tooltip: '设备'),
          const _NavIcon(icon: Icons.star_rounded, tooltip: '收藏'),
          _NavIcon(
            icon: Icons.history_rounded,
            active: activeSection == _MainSection.history,
            tooltip: '接收历史',
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
    required this.onChats,
    required this.onTheme,
    required this.onSettings,
    required this.onHistory,
  });

  final _MainSection activeSection;
  final VoidCallback onChats;
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _accent,
                    child: const Text(
                      'T',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'NearSend',
                    style: TextStyle(
                      color: _text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
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
              icon: Icons.history_rounded,
              label: '接收历史',
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

enum _MainSection { chats, theme, settings, history }

enum _ConversationMenuAction { rename, clear, delete }

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
    fillColor: const Color(0xFFF8F6F0),
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
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _surface,
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2431302D),
                blurRadius: 28,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
                  child: Row(
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
                      Expanded(
                        child: DefaultTextStyle(
                          style: TextStyle(
                            color: _text,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                          child: title,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: _line),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: content,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (final action in actions) ...[
                        action,
                        if (action != actions.last) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
    final style = filled
        ? FilledButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            minimumSize: const Size(76, 38),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          )
        : TextButton.styleFrom(
            foregroundColor: _muted,
            minimumSize: const Size(76, 38),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          );

    return filled
        ? FilledButton(onPressed: onPressed, style: style, child: Text(label))
        : TextButton(onPressed: onPressed, style: style, child: Text(label));
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
    final color = danger ? const Color(0xFFC85D4D) : _text;
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

class _LocalConnectInfo extends StatelessWidget {
  const _LocalConnectInfo({required this.endpoints, required this.onCopy});

  final Future<List<String>> endpoints;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6F0),
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings_ethernet_rounded, size: 17, color: _muted),
                const SizedBox(width: 8),
                Text(
                  '允许别人连接本机',
                  style: TextStyle(
                    color: _text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<String>>(
              future: endpoints,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return SizedBox(
                    height: 32,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _accent,
                        ),
                      ),
                    ),
                  );
                }

                final values = snapshot.data ?? const <String>[];
                if (values.isEmpty) {
                  return Text(
                    '未找到可用局域网 IP',
                    style: TextStyle(color: _muted, fontSize: 12),
                  );
                }

                return Column(
                  children: [
                    for (final endpoint in values)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                endpoint,
                                style: TextStyle(
                                  color: _text,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Tooltip(
                              message: '复制',
                              child: IconButton(
                                onPressed: () => onCopy(endpoint),
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                color: _muted,
                                style: IconButton.styleFrom(
                                  fixedSize: const Size(30, 30),
                                  minimumSize: const Size(30, 30),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
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
          color: active ? Colors.white : _sidebarMuted,
          style: IconButton.styleFrom(
            fixedSize: const Size(42, 42),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            backgroundColor: active
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
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
                        SegmentedButton<AppThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: AppThemeMode.light,
                              icon: Icon(Icons.light_mode_rounded, size: 18),
                              label: Text('日间'),
                            ),
                            ButtonSegment(
                              value: AppThemeMode.dark,
                              icon: Icon(Icons.dark_mode_rounded, size: 18),
                              label: Text('夜间'),
                            ),
                          ],
                          selected: {themeMode},
                          onSelectionChanged: (values) {
                            onThemeModeChanged(values.first);
                          },
                          style: ButtonStyle(
                            foregroundColor: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.selected)
                                  ? Colors.white
                                  : _text,
                            ),
                            backgroundColor: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.selected)
                                  ? _accent
                                  : _surface,
                            ),
                            side: WidgetStateProperty.all(
                              BorderSide(color: _line),
                            ),
                            shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
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
    required this.minimizeToTrayEnabled,
    required this.restoringWindowSettings,
    required this.onAutoSaveChanged,
    required this.onOverwriteSameNameFilesChanged,
    required this.onMinimizeToTrayChanged,
    required this.onChooseDirectory,
    this.onMenu,
  });

  final bool autoSaveEnabled;
  final String autoSaveDirectory;
  final bool overwriteSameNameFiles;
  final bool minimizeToTrayEnabled;
  final bool restoringWindowSettings;
  final ValueChanged<bool> onAutoSaveChanged;
  final ValueChanged<bool> onOverwriteSameNameFilesChanged;
  final ValueChanged<bool> onMinimizeToTrayChanged;
  final VoidCallback onChooseDirectory;
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
                            Switch(
                              value: autoSaveEnabled,
                              activeThumbColor: _accent,
                              onChanged: onAutoSaveChanged,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        // Android saves into the public Downloads folder via
                        // MediaStore; choosing an arbitrary folder needs SAF and
                        // is out of scope, so only desktop shows a path picker.
                        if (Platform.isAndroid)
                          Container(
                            height: 42,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F6F0),
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
                                    color: const Color(0xFFF8F6F0),
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
                // Tray/minimize is a desktop-only feature.
                if (Platform.isWindows) ...[
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
            Switch(
              value: value,
              activeThumbColor: _accent,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
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
                  '接收历史',
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
    required this.isScanning,
    required this.scanStatus,
    required this.selected,
    required this.onRefresh,
    required this.onShowQrCode,
    required this.onManualConnect,
    required this.onContextMenu,
    required this.onSelect,
    this.onMenu,
  });

  final List<Conversation> conversations;
  final bool isScanning;
  final String scanStatus;
  final int selected;
  final VoidCallback onRefresh;
  final VoidCallback onShowQrCode;
  final VoidCallback onManualConnect;
  final void Function(int index, Offset position) onContextMenu;
  final ValueChanged<int> onSelect;

  /// Opens the navigation drawer on phone layouts; null on tablet/desktop.
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _panel,
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
                    _ToolButton(
                      icon: Icons.drive_folder_upload_rounded,
                      tooltip: '发送文件夹',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFECE3),
                    border: Border.all(color: _line),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 18, color: _muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '搜索设备、联系人或文件',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _muted, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
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
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                return ConversationTile(
                  conversation: conversations[index],
                  selected: selected == index,
                  onTap: () => onSelect(index),
                  onContextMenu: (position) {
                    onSelect(index);
                    onContextMenu(index, position);
                  },
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
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: enabled ? onPressed ?? () {} : null,
          icon: Icon(icon, size: 19),
          color: _muted,
          style: IconButton.styleFrom(
            fixedSize: const Size(42, 42),
            backgroundColor: _surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.selected,
    required this.onTap,
    required this.onContextMenu,
  });

  final Conversation conversation;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<Offset> onContextMenu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? _surface : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: GestureDetector(
          onSecondaryTapDown: (details) {
            onContextMenu(details.globalPosition);
          },
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(minHeight: 70),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: selected
                    ? Border(left: BorderSide(color: _accent, width: 3))
                    : null,
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
                            if (conversation.device != null)
                              const Icon(
                                Icons.wifi_rounded,
                                color: Color(0xFF27A95D),
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
    required this.clipboardAutoSendEnabled,
    required this.onClipboardAutoSendChanged,
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
  final bool clipboardAutoSendEnabled;
  final ValueChanged<bool> onClipboardAutoSendChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _chatBg,
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
                  child: DeviceDetailsPage(
                    conversation: conversation,
                    clipboardAutoSendEnabled: clipboardAutoSendEnabled,
                    onClipboardAutoSendChanged: onClipboardAutoSendChanged,
                  ),
                )
              else ...[
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    children: [
                      ...conversation.messages.map(
                        (message) => MessageBubble(
                          message: message,
                          selectionMode: selectionMode,
                          selected: selectedMessageIds.contains(message.id),
                          onToggleSelected: () =>
                              onToggleMessageSelection(message.id),
                          onRetrySend: () => onRetrySendAttachment(message.id),
                          onCancelTransfer: () =>
                              onCancelTransfer(message.id),
                          onCopyAttachment: onCopyAttachment,
                          onPreviewImage: onPreviewImage,
                        ),
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
                          children: conversation.files
                              .map((file) => FileCard(file: file))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                Composer(
                  controller: controller,
                  pendingAttachments: pendingAttachments,
                  onSend: onSend,
                  onSendImage: onSendImage,
                  onSendFile: onSendFile,
                  onPasteImages: onPasteImages,
                  onRemovePendingAttachment: onRemovePendingAttachment,
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
                const SizedBox(height: 4),
                Text(
                  selectionMode
                      ? '批量删除聊天记录'
                      : showDetails
                      ? conversation.title
                      : conversation.status,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
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
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        color: color ?? _muted,
        style: IconButton.styleFrom(
          fixedSize: const Size(42, 42),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
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

class DeviceDetailsPage extends StatelessWidget {
  const DeviceDetailsPage({
    super.key,
    required this.conversation,
    required this.clipboardAutoSendEnabled,
    required this.onClipboardAutoSendChanged,
  });

  final Conversation conversation;
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
  });

  final ChatMessage message;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onToggleSelected;
  final VoidCallback onRetrySend;
  final VoidCallback onCancelTransfer;
  final ValueChanged<MessageAttachment> onCopyAttachment;
  final ValueChanged<MessageAttachment> onPreviewImage;

  @override
  Widget build(BuildContext context) {
    final bubble = _buildBubble();
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
            color: const Color(0xFFEFECE3),
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
      InitialAvatar(text: message.sender, size: 36),
      const SizedBox(width: 10),
      _BubbleSurface(
        message: message,
        onRetrySend: onRetrySend,
        onCancelTransfer: onCancelTransfer,
        onCopyAttachment: onCopyAttachment,
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
        onPreviewImage: onPreviewImage,
      ),
      const SizedBox(width: 10),
      const InitialAvatar(text: '文', size: 36),
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
          backgroundColor: const Color(0xEEFFFFFF),
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
          backgroundColor: const Color(0xEEFFFFFF),
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
                backgroundColor: const Color(0xFFEFECE3),
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
    required this.onPreviewImage,
  });

  final ChatMessage message;
  final VoidCallback onRetrySend;
  final VoidCallback onCancelTransfer;
  final ValueChanged<MessageAttachment> onCopyAttachment;
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
    required this.onPreviewImage,
  });

  final ChatMessage message;
  final VoidCallback onRetrySend;
  final VoidCallback onCancelTransfer;
  final ValueChanged<MessageAttachment> onCopyAttachment;
  final ValueChanged<MessageAttachment> onPreviewImage;

  @override
  Widget build(BuildContext context) {
    final attachment = message.attachment;
    if (attachment == null) {
      return Text(
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
          child: Image.file(
            File(attachment.path),
            width: 260,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return AttachmentTile(attachment: attachment);
            },
          ),
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
          Text(
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
          child: content,
        ),
      ],
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
    required this.child,
  });

  final ChatMessage message;
  final MessageAttachment attachment;
  final VoidCallback onRetrySend;
  final VoidCallback onCancelTransfer;
  final VoidCallback onCopyAttachment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final copyButton = CopyAttachmentButton(onPressed: onCopyAttachment);
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
        const SizedBox(width: 6),
        Padding(padding: const EdgeInsets.only(bottom: 3), child: copyButton),
      ],
    );
  }
}

class _AttachmentActionRail extends StatelessWidget {
  const _AttachmentActionRail({
    required this.top,
    required this.bottom,
    required this.attachment,
  });

  final Widget top;
  final Widget bottom;
  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: attachment.isImage ? 180 : 66,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [top, bottom],
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
    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(8),
      ),
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
                SizedBox(
                  height: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: file.progress / 100,
                      color: _accent,
                      backgroundColor: const Color(0xFFEFECE3),
                    ),
                  ),
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
                    icon: Icons.emoji_emotions_outlined,
                    tooltip: '表情',
                  ),
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
                  _ComposerButton(
                    icon: Icons.screenshot_monitor_rounded,
                    tooltip: '截图',
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
                    child: TextField(
                      controller: controller,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: '输入消息...',
                        border: InputBorder.none,
                        isDense: true,
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
                    child: FilledButton(
                      onPressed: onSend,
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
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
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed ?? () {},
        icon: Icon(icon, size: 20),
        color: _muted,
        style: IconButton.styleFrom(
          fixedSize: const Size(36, 36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          return PendingAttachmentTile(
            attachment: attachment,
            onRemove: () => onRemove(attachment),
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
                    ? Image.file(
                        File(attachment.path),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _PendingFilePreview(attachment: attachment);
                        },
                      )
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

  Conversation copyWith({
    String? title,
    String? subtitle,
    String? status,
    String? time,
    String? initials,
    int? unread,
    List<ChatMessage>? messages,
    List<TransferFile>? files,
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
      device: device,
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
  }) : id =
           id ??
           'msg-${DateTime.now().microsecondsSinceEpoch}-${_nextSequence++}';

  static int _nextSequence = 0;

  final String id;
  final String text;
  final String sender;
  final bool isMe;
  final bool system;
  final MessageAttachment? attachment;
  final MessageSendStatus status;

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
    );
  }
}

enum MessageSendStatus { none, sending, sent, failed, cancelled }

class MessageAttachment {
  MessageAttachment({
    required this.path,
    required this.name,
    required this.size,
    required this.kind,
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

  factory MessageAttachment.fromNearSend(NearSendAttachment attachment) {
    return MessageAttachment(
      path: attachment.path,
      name: attachment.name,
      size: attachment.size,
      kind: attachment.isImage ? FileKind.image : FileKind.file,
    );
  }

  final String path;
  final String name;
  final int size;
  final FileKind kind;

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
      '.bmp' => FileKind.image,
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
