part of '../main.dart';

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
      color: appColors.chatBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 74,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(
              color: appColors.surface,
              border: Border(bottom: BorderSide(color: appColors.line)),
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
                    color: appColors.text,
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
                    color: appColors.surface,
                    border: Border.all(color: appColors.line),
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
                                color: appColors.accentSoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.save_alt_rounded,
                                color: appColors.accent,
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
                                      color: appColors.text,
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
                                      color: appColors.muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ShadSwitch(
                              value: autoSaveEnabled,
                              checkedTrackColor: appColors.accent,
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
                              color: appColors.panel,
                              border: Border.all(color: appColors.line),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '下载/NearSend',
                              style: TextStyle(
                                color: appColors.text,
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
                                    color: appColors.panel,
                                    border: Border.all(color: appColors.line),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SelectableText(
                                    autoSaveDirectory,
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: appColors.text,
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
                                color: appColors.text,
                                style: IconButton.styleFrom(
                                  fixedSize: const Size(42, 42),
                                  side: BorderSide(color: appColors.line),
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
                      color: appColors.surface,
                      border: Border.all(color: appColors.line),
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
                                  color: appColors.accentSoft,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.cleaning_services_rounded,
                                  color: appColors.accent,
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
                                        color: appColors.text,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '清理接收文件产生的临时数据',
                                      style: TextStyle(
                                        color: appColors.muted,
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
        color: appColors.surface,
        border: Border.all(color: appColors.line),
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
                color: appColors.accentSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: appColors.accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: appColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(color: appColors.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            ShadSwitch(
              value: value,
              checkedTrackColor: appColors.accent,
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
    final iconColor = ok ? const Color(0xFF27A95D) : warning;
    final diagnosticText = _diagnosticText(
      current,
      lastRepair,
      hasInbound: hasInbound,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: appColors.surface,
        border: Border.all(color: appColors.line),
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
                    color: appColors.accentSoft,
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
                          color: appColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(color: appColors.muted, fontSize: 13),
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
                color: appColors.muted,
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
                color: appColors.muted,
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
                color: appColors.muted,
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
                  backgroundColor: appColors.accent,
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
                  color: appColors.muted,
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
        ? appColors.muted
        : ok
        ? const Color(0xFF27A95D)
        : warning;
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
                      backgroundColor: appColors.accent,
                      foregroundColor: Colors.white,
                      hoverForegroundColor: Colors.white,
                      hoverBackgroundColor: appColors.accent.withValues(alpha: 0.9),
                      child: Text(_isLoading ? '清理中...' : '清理过期文件'),
                    )
                  : ShadButton.outline(
                      onPressed: null,
                      width: double.infinity,
                      height: 38,
                      backgroundColor: appColors.surface,
                      foregroundColor: appColors.muted,
                      child: const Text('清理过期文件'),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ShadButton.outline(
                onPressed: hasFiles && !_isLoading ? _performFullCleanup : null,
                width: double.infinity,
                height: 38,
                foregroundColor: hasFiles ? appColors.text : appColors.muted,
                hoverBackgroundColor: appColors.accentSoft,
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
        Text(label, style: TextStyle(color: appColors.muted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? appColors.text,
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
                  color: appColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.description,
                style: TextStyle(color: appColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        ShadSwitch(
          value: _value,
          checkedTrackColor: appColors.accent,
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
                  color: appColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text('自动清理保留天数', style: TextStyle(color: appColors.muted, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: appColors.panel,
            border: Border.all(color: appColors.line),
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
                  color: _days > 1 ? appColors.muted : appColors.line,
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
                    color: appColors.text,
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
                  color: _days < 365 ? appColors.muted : appColors.line,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text('天', style: TextStyle(color: appColors.muted, fontSize: 14)),
      ],
    );
  }
}

