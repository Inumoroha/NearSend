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

