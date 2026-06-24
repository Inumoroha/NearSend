part of '../main.dart';

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

