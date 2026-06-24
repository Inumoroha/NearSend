part of '../main.dart';

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
              activeColor: appColors.accent,
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
            color: appColors.panel,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            message.text,
            style: TextStyle(color: appColors.muted, fontSize: 12),
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
          backgroundColor: appColors.surface,
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
          backgroundColor: appColors.surface,
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
                color: appColors.accent,
                backgroundColor: appColors.panel,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$percent%', style: TextStyle(color: appColors.muted, fontSize: 12)),
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
        color: appColors.muted,
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
          color: message.isMe ? appColors.bubbleMe : appColors.surface,
          border: Border.all(
            color: message.isMe ? const Color(0xFFECD9CD) : appColors.line,
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
      MessageSendStatus.sent => (Icons.done_all_rounded, appColors.accent, '已发送'),
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
      MessageSendStatus.sent => (Icons.done_all_rounded, appColors.accent, '已发送'),
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
        style: TextStyle(color: appColors.text, fontSize: 14, height: 1.55),
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
            style: TextStyle(color: appColors.text, fontSize: 14, height: 1.55),
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
        color: appColors.surface,
        border: Border.all(color: appColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: appColors.accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(attachment.icon, color: appColors.accent, size: 22),
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
                    color: appColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  attachment.sizeLabel,
                  style: TextStyle(color: appColors.muted, fontSize: 12),
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
      backgroundColor: appColors.surface,
      radius: BorderRadius.circular(8),
      border: ShadBorder.all(color: appColors.line, width: 1),
      shadows: const [],
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: appColors.accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(file.icon, color: appColors.accent, size: 22),
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
                    color: appColors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                Text(file.size, style: TextStyle(color: appColors.muted, fontSize: 12)),
                const SizedBox(height: 8),
                StableProgressBar(
                  value: file.progress / 100,
                  height: 5,
                  color: appColors.accent,
                  backgroundColor: const Color(0xFFEFECE3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${file.progress}%',
            style: TextStyle(color: appColors.muted, fontSize: 12),
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
          color: appColors.surface,
          border: Border(top: BorderSide(color: appColors.line)),
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
                        color: appColors.text,
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
                      backgroundColor: appColors.accent,
                      hoverBackgroundColor: Color.alphaBlend(
                        Colors.black.withValues(alpha: 0.08),
                        appColors.accent,
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
          color: appColors.muted,
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
                border: Border.all(color: appColors.line),
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
          Icon(attachment.icon, color: appColors.accent, size: 26),
          const SizedBox(height: 8),
          Text(
            attachment.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: appColors.text,
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
