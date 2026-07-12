part of '../main.dart';

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
    final isPhone = MediaQuery.sizeOf(context).width < 560;
    final keyboardInset = isPhone || Platform.isAndroid
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0.0;
    return Container(
      margin: isPhone
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(0, 12, 12, 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: appColors.chatBg,
        border: isPhone ? null : Border.all(color: appColors.line),
        borderRadius: isPhone ? BorderRadius.zero : BorderRadius.circular(8),
        boxShadow: isPhone
            ? const []
            : const [
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
                          isPhone ? 12 : 24,
                          isPhone ? 16 : 24,
                          isPhone ? 12 : 24,
                          isPhone ? 12 : 24 + keyboardInset,
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
                                color: appColors.muted,
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
    final isPhone = MediaQuery.sizeOf(context).width < 560;
    final hasSelection = selectedCount > 0;
    final allSelected = messageCount > 0 && selectedCount == messageCount;
    return Container(
      height: isPhone ? 56 : 74,
      padding: EdgeInsets.symmetric(horizontal: isPhone ? 6 : 24),
      decoration: BoxDecoration(
        color: appColors.surface,
        border: Border(bottom: BorderSide(color: appColors.line)),
      ),
      child: Row(
        children: [
          if (onMobileBack != null && !selectionMode && !showDetails) ...[
            _HeaderButton(
              icon: Icons.arrow_back_rounded,
              tooltip: '返回列表',
              onPressed: onMobileBack,
            ),
            SizedBox(width: isPhone ? 2 : 8),
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
                    color: appColors.text,
                    fontSize: isPhone ? 17 : 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (selectionMode || showDetails) ...[
                  const SizedBox(height: 4),
                  Text(
                    selectionMode ? '批量删除聊天记录' : conversation.title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: appColors.muted, fontSize: 13),
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
              color: hasSelection ? const Color(0xFFC85D4D) : appColors.muted,
            ),
            _HeaderButton(
              icon: Icons.close_rounded,
              tooltip: '取消多选',
              onPressed: onExitSelectionMode,
            ),
          ] else if (isPhone)
            PopupMenuButton<int>(
              tooltip: '聊天操作',
              icon: Icon(Icons.more_vert_rounded, color: appColors.muted),
              onSelected: (value) {
                if (value == 0) onShowDetails();
                if (value == 1) onEnterSelectionMode();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 0,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.info_outline_rounded),
                    title: Text('设备详情'),
                  ),
                ),
                PopupMenuItem(
                  value: 1,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.checklist_rounded),
                    title: Text('选择消息'),
                  ),
                ),
              ],
            )
          else ...[
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
        color: appColors.text,
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
          color: appColors.panel,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(color: appColors.muted, fontSize: 12),
        ),
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
