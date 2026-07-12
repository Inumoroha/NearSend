part of '../main.dart';

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
    final isPhone = MediaQuery.sizeOf(context).width < 560;
    final rows = _groupedRows(tasks);
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
                    color: appColors.text,
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
                      style: TextStyle(color: appColors.muted, fontSize: 14),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      isPhone ? 12 : 32,
                      isPhone ? 16 : 28,
                      isPhone ? 12 : 32,
                      isPhone ? 20 : 32,
                    ),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      if (row is String) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
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
                      final task = row as TransferTask;
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

  List<Object> _groupedRows(List<TransferTask> tasks) {
    final rows = <Object>[];
    void addGroup(String label, bool Function(TransferTask) matches) {
      final group = tasks.where(matches).toList(growable: false);
      if (group.isEmpty) return;
      rows
        ..add(label)
        ..addAll(group);
    }

    addGroup('等待确认', (task) => task.status == TransferTaskStatus.waiting);
    addGroup('进行中', (task) => task.status == TransferTaskStatus.transferring);
    addGroup(
      '已完成',
      (task) =>
          task.status == TransferTaskStatus.completed ||
          task.status == TransferTaskStatus.failed ||
          task.status == TransferTaskStatus.cancelled,
    );
    return rows;
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
    // Both directions can be cancelled mid-flight: outgoing aborts the upload,
    // incoming discards the partial download (with a confirm dialog).
    final canCancel = task.status == TransferTaskStatus.transferring;
    final progress = task.progress;

    return ShadCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: appColors.surface,
      radius: BorderRadius.circular(8),
      border: ShadBorder.all(color: appColors.line, width: 1),
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
                  color: appColors.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _iconForTask(task),
                  color: appColors.accent,
                  size: 22,
                ),
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
                        color: appColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_directionLabel(task)} · ${task.peerAlias} · ${formatBytes(task.totalBytes)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: appColors.muted, fontSize: 12),
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
            color: appColors.accent,
            backgroundColor: appColors.accentSoft,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  task.subtitle ?? _statusLabel(task.status),
                  style: TextStyle(color: appColors.muted, fontSize: 12),
                ),
              ),
              if (isWaiting) ...[
                ShadButton.ghost(
                  onPressed: onDecline,
                  height: 34,
                  foregroundColor: appColors.muted,
                  hoverForegroundColor: appColors.text,
                  child: const Text('拒绝'),
                ),
                const SizedBox(width: 8),
                ShadButton(
                  onPressed: onAccept,
                  height: 34,
                  backgroundColor: appColors.accent,
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
      TransferTaskStatus.waiting => warning,
      TransferTaskStatus.transferring => appColors.accent,
      TransferTaskStatus.completed => const Color(0xFF27A95D),
      TransferTaskStatus.failed => const Color(0xFFC85D4D),
      TransferTaskStatus.cancelled => appColors.muted,
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
        color: appColors.accentSoft,
        border: Border.all(color: appColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        size <= 0 ? name : '$name · ${formatBytes(size)}',
        style: TextStyle(color: appColors.text, fontSize: 12),
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
