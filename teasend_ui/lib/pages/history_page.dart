part of '../main.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.entries,
    required this.staleIds,
    required this.onOpenFile,
    required this.onOpenFolder,
    required this.onDelete,
    required this.onClear,
    required this.onCleanupStale,
    this.onMenu,
  });

  final List<ReceiveHistoryEntry> entries;

  /// IDs of entries whose backing file is missing from disk.
  final Set<String> staleIds;
  final ValueChanged<ReceiveHistoryEntry> onOpenFile;
  final ValueChanged<ReceiveHistoryEntry> onOpenFolder;
  final ValueChanged<ReceiveHistoryEntry> onDelete;
  final VoidCallback onClear;
  final VoidCallback onCleanupStale;
  final VoidCallback? onMenu;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Entries matching the current search query (file name or sender).
  List<ReceiveHistoryEntry> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.entries;
    return widget.entries.where((entry) {
      return entry.fileName.toLowerCase().contains(query) ||
          entry.senderAlias.toLowerCase().contains(query);
    }).toList();
  }

  /// Flattens [entries] into an alternating list of section headers (String)
  /// and entries, preserving the source's newest-first ordering.
  List<Object> _buildRows(List<ReceiveHistoryEntry> entries) {
    final rows = <Object>[];
    String? bucket;
    for (final entry in entries) {
      final label = _bucketLabel(entry.receivedAt);
      if (label != bucket) {
        bucket = label;
        rows.add(label);
      }
      rows.add(entry);
    }
    return rows;
  }

  String _bucketLabel(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    final diffDays = today.difference(day).inDays;
    if (diffDays <= 0) return '今天';
    if (diffDays == 1) return '昨天';
    if (diffDays < 7) return '本周';
    return '更早';
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 560;
    final hasEntries = widget.entries.isNotEmpty;
    final filtered = _filtered;
    final rows = _buildRows(filtered);
    final staleCount = widget.entries
        .where((entry) => widget.staleIds.contains(entry.id))
        .length;

    return Container(
      color: appColors.chatBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: isPhone ? 56 : 74,
            padding: EdgeInsets.symmetric(horizontal: isPhone ? 16 : 28),
            decoration: BoxDecoration(
              color: appColors.surface,
              border: Border(bottom: BorderSide(color: appColors.line)),
            ),
            child: Row(
              children: [
                if (widget.onMenu != null) ...[
                  _PageMenuButton(onPressed: widget.onMenu!),
                  const SizedBox(width: 8),
                ],
                Text(
                  '文件记录',
                  style: TextStyle(
                    color: appColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  hasEntries ? '${widget.entries.length} 条' : '',
                  style: TextStyle(color: appColors.muted, fontSize: 13),
                ),
                const Spacer(),
                if (isPhone && hasEntries)
                  PopupMenuButton<int>(
                    tooltip: '记录操作',
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (value) {
                      if (value == 0) widget.onCleanupStale();
                      if (value == 1) widget.onClear();
                    },
                    itemBuilder: (context) => [
                      if (staleCount > 0)
                        PopupMenuItem(
                          value: 0,
                          child: Text('清理失效记录 ($staleCount)'),
                        ),
                      const PopupMenuItem(value: 1, child: Text('清空全部记录')),
                    ],
                  ),
                if (!isPhone && staleCount > 0)
                  TextButton.icon(
                    onPressed: widget.onCleanupStale,
                    icon: const Icon(Icons.cleaning_services_rounded, size: 17),
                    label: Text('清理失效 ($staleCount)'),
                    style: TextButton.styleFrom(
                      foregroundColor: appColors.muted,
                    ),
                  ),
                if (!isPhone && hasEntries)
                  TextButton.icon(
                    onPressed: widget.onClear,
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: const Text('清空'),
                    style: TextButton.styleFrom(
                      foregroundColor: appColors.muted,
                    ),
                  ),
              ],
            ),
          ),
          if (hasEntries)
            Padding(
              padding: EdgeInsets.fromLTRB(
                isPhone ? 12 : 28,
                isPhone ? 10 : 14,
                isPhone ? 12 : 28,
                0,
              ),
              child: _HistorySearchField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                onClear: () => setState(() {
                  _searchController.clear();
                  _query = '';
                }),
              ),
            ),
          Expanded(
            child: !hasEntries
                ? _emptyState('暂无接收记录')
                : rows.isEmpty
                ? _emptyState('未找到匹配的记录')
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      isPhone ? 12 : 32,
                      isPhone ? 12 : 16,
                      isPhone ? 12 : 32,
                      isPhone ? 20 : 32,
                    ),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      if (row is String) {
                        return Padding(
                          padding: EdgeInsets.only(
                            top: index == 0 ? 6 : 18,
                            bottom: 8,
                          ),
                          child: Text(
                            row,
                            style: TextStyle(
                              color: appColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }
                      final entry = row as ReceiveHistoryEntry;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _HistoryTile(
                          entry: entry,
                          stale: widget.staleIds.contains(entry.id),
                          onOpenFile: () => widget.onOpenFile(entry),
                          onOpenFolder: () => widget.onOpenFolder(entry),
                          onDelete: () => widget.onDelete(entry),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String label) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 46,
            color: appColors.muted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: appColors.muted, fontSize: 14)),
        ],
      ),
    );
  }
}

class _HistorySearchField extends StatelessWidget {
  const _HistorySearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: appColors.surface,
        border: Border.all(color: appColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: appColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(color: appColors.text, fontSize: 14),
              cursorColor: appColors.accent,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: '搜索文件名或发送方',
                hintStyle: TextStyle(color: appColors.muted, fontSize: 14),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return InkWell(
                onTap: onClear,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: appColors.muted,
                  ),
                ),
              );
            },
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
    this.stale = false,
  });

  final ReceiveHistoryEntry entry;
  final VoidCallback onOpenFile;
  final VoidCallback onOpenFolder;
  final VoidCallback onDelete;

  /// Whether the backing file is missing from disk; dims the tile and swaps the
  /// status badge for a "失效" marker.
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 560;
    final kind = FileKind.fromExtension(p.extension(entry.fileName));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: appColors.surface,
        border: Border.all(color: appColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Opacity(
              opacity: stale ? 0.45 : 1,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: appColors.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(kind.icon, color: appColors.accent, size: 22),
              ),
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
                      color: stale ? appColors.muted : appColors.text,
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
                          style: TextStyle(
                            color: appColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _HistoryBadge(autoSaved: entry.autoSaved, stale: stale),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isPhone)
              PopupMenuButton<int>(
                tooltip: '文件操作',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) {
                  if (value == 0) onOpenFile();
                  if (value == 1) onOpenFolder();
                  if (value == 2) onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 0, child: Text('打开文件')),
                  PopupMenuItem(value: 1, child: Text('打开所在文件夹')),
                  PopupMenuItem(value: 2, child: Text('删除记录')),
                ],
              )
            else ...[
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
  const _HistoryBadge({required this.autoSaved, this.stale = false});

  final bool autoSaved;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final label = stale ? '已失效' : (autoSaved ? '已保存' : '临时');
    final color = stale
        ? const Color(0xFFC85D4D)
        : (autoSaved ? appColors.accent : appColors.muted);
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
        color: color ?? appColors.muted,
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
