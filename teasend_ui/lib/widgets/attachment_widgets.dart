part of '../main.dart';

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
