part of '../main.dart';

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

