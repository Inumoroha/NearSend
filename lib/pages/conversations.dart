part of '../main.dart';

class ConversationPanel extends StatelessWidget {
  const ConversationPanel({
    super.key,
    required this.conversations,
    required this.favoriteFingerprints,
    required this.onlineFingerprints,
    required this.isScanning,
    required this.scanStatus,
    required this.selected,
    required this.onRefresh,
    required this.onShowQrCode,
    required this.onManualConnect,
    required this.deviceAlias,
    required this.onShowDeviceInfo,
    required this.onContextMenu,
    required this.onSelect,
    this.onMenu,
    this.onEditRemark,
    this.onClearRecords,
    this.onDeleteConversation,
  });

  final List<Conversation> conversations;
  final Set<String> favoriteFingerprints;
  final Set<String> onlineFingerprints;
  final bool isScanning;
  final String scanStatus;
  final int selected;

  /// Rescans for devices. Returns a future so pull-to-refresh can await it.
  final Future<void> Function() onRefresh;
  final VoidCallback onShowQrCode;
  final VoidCallback onManualConnect;
  final String deviceAlias;
  final VoidCallback onShowDeviceInfo;
  final void Function(int index, Offset position) onContextMenu;
  final ValueChanged<int> onSelect;

  /// Opens the navigation drawer on phone layouts; null on tablet/desktop.
  final VoidCallback? onMenu;

  /// Android swipe-action callbacks. Null on desktop, where the right-click
  /// context menu provides the same operations instead.
  final ValueChanged<int>? onEditRemark;
  final ValueChanged<int>? onClearRecords;
  final ValueChanged<int>? onDeleteConversation;

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 560;
    return Container(
      margin: isPhone
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(0, 12, 12, 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: appColors.surface,
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
      child: Column(
        children: [
          if (isPhone)
            _CompactMobileConversationHeader(
              deviceAlias: deviceAlias,
              isScanning: isScanning,
              scanStatus: scanStatus,
              onRefresh: onRefresh,
              onShowQrCode: onShowQrCode,
              onManualConnect: onManualConnect,
              onShowDeviceInfo: onShowDeviceInfo,
            )
          else
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: appColors.line),
                  bottom: BorderSide(color: appColors.line),
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
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: isScanning
                            ? CircularProgressIndicator(
                                strokeWidth: 2,
                                color: appColors.accent,
                              )
                            : Icon(
                                Icons.lan_rounded,
                                size: 15,
                                color: appColors.muted,
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          scanStatus,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: appColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Expanded(
            child: Builder(
              builder: (context) {
                final list = ListView.builder(
                  padding: isPhone ? EdgeInsets.zero : const EdgeInsets.all(8),
                  // Always scrollable so pull-to-refresh works even when the
                  // list is short or empty.
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: conversations.isEmpty ? 1 : conversations.length,
                  itemBuilder: (context, index) {
                    if (conversations.isEmpty) {
                      return _ConversationEmptyState(
                        onRefresh: onRefresh,
                        onManualConnect: onManualConnect,
                      );
                    }
                    final conversation = conversations[index];
                    final swipeEnabled =
                        Platform.isAndroid && onDeleteConversation != null;
                    // Stable per-conversation identity. The list re-sorts as
                    // devices re-announce, so without a key the swipe State
                    // would attach to whichever conversation lands at this
                    // slot, leaving an unrelated row showing its actions open.
                    final itemKey = ValueKey(
                      conversation.device?.fingerprint ?? conversation.title,
                    );
                    final tile = ConversationTile(
                      conversation: conversation,
                      favorite:
                          conversation.device != null &&
                          favoriteFingerprints.contains(
                            conversation.device!.fingerprint,
                          ),
                      online:
                          conversation.device != null &&
                          onlineFingerprints.contains(
                            conversation.device!.fingerprint,
                          ),
                      selected: selected == index,
                      mobile: isPhone,
                      padded: !swipeEnabled,
                      onTap: () => onSelect(index),
                      onContextMenu: (position) {
                        onSelect(index);
                        onContextMenu(index, position);
                      },
                    );
                    if (!swipeEnabled) {
                      return KeyedSubtree(key: itemKey, child: tile);
                    }
                    return _SwipeActionTile(
                      key: itemKey,
                      actions: [
                        _SwipeAction(
                          icon: Icons.edit_rounded,
                          label: '备注',
                          color: appColors.accent,
                          onTap: () => onEditRemark?.call(index),
                        ),
                        _SwipeAction(
                          icon: Icons.cleaning_services_rounded,
                          label: '清空',
                          color: warning,
                          onTap: () => onClearRecords?.call(index),
                        ),
                        _SwipeAction(
                          icon: Icons.delete_outline_rounded,
                          label: '删除',
                          color: const Color(0xFFC85D4D),
                          onTap: () => onDeleteConversation?.call(index),
                        ),
                      ],
                      child: tile,
                    );
                  },
                );
                // Pull-to-refresh to rescan devices (phone only).
                if (!Platform.isAndroid) return list;
                return RefreshIndicator(
                  onRefresh: onRefresh,
                  color: appColors.accent,
                  child: list,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Kept temporarily to make the desktop/mobile header migration easy to review.
// ignore: unused_element
class _MobileConversationHeader extends StatelessWidget {
  const _MobileConversationHeader({
    required this.deviceAlias,
    required this.isScanning,
    required this.scanStatus,
    required this.onRefresh,
    required this.onShowQrCode,
    required this.onManualConnect,
    required this.onShowDeviceInfo,
  });

  final String deviceAlias;
  final bool isScanning;
  final String scanStatus;
  final Future<void> Function() onRefresh;
  final VoidCallback onShowQrCode;
  final VoidCallback onManualConnect;
  final VoidCallback onShowDeviceInfo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 10),
      decoration: BoxDecoration(
        color: appColors.surface,
        border: Border(bottom: BorderSide(color: appColors.line)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '消息',
                    style: TextStyle(
                      color: appColors.text,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '刷新设备',
                  onPressed: isScanning ? null : onRefresh,
                  icon: isScanning
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: appColors.accent,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
                PopupMenuButton<int>(
                  tooltip: '连接方式',
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (value) {
                    if (value == 0) onShowQrCode();
                    if (value == 1) onManualConnect();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 0,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.qr_code_rounded),
                        title: Text('连接二维码'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 1,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.add_link_rounded),
                        title: Text('手动连接'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 2),
                Tooltip(
                  message: '本设备信息',
                  child: InkWell(
                    onTap: onShowDeviceInfo,
                    customBorder: const CircleBorder(),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: appColors.accent,
                      child: Text(
                        deviceAlias.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(Icons.lan_rounded, size: 15, color: appColors.muted),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  scanStatus,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: appColors.muted, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactMobileConversationHeader extends StatelessWidget {
  const _CompactMobileConversationHeader({
    required this.deviceAlias,
    required this.isScanning,
    required this.scanStatus,
    required this.onRefresh,
    required this.onShowQrCode,
    required this.onManualConnect,
    required this.onShowDeviceInfo,
  });

  final String deviceAlias;
  final bool isScanning;
  final String scanStatus;
  final Future<void> Function() onRefresh;
  final VoidCallback onShowQrCode;
  final VoidCallback onManualConnect;
  final VoidCallback onShowDeviceInfo;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('mobile-page-header'),
      height: 56,
      padding: const EdgeInsets.only(left: 16, right: 6),
      decoration: BoxDecoration(
        color: appColors.surface,
        border: Border(bottom: BorderSide(color: appColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '消息',
                  style: TextStyle(
                    color: appColors.text,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  scanStatus,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: appColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '刷新设备',
            onPressed: isScanning ? null : onRefresh,
            icon: isScanning
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: appColors.accent,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<int>(
            tooltip: '连接方式',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 0) onShowQrCode();
              if (value == 1) onManualConnect();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 0,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.qr_code_rounded),
                  title: Text('连接二维码'),
                ),
              ),
              PopupMenuItem(
                value: 1,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.add_link_rounded),
                  title: Text('手动连接'),
                ),
              ),
            ],
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: Tooltip(
              message: '本设备信息',
              child: InkWell(
                onTap: onShowDeviceInfo,
                customBorder: const CircleBorder(),
                child: Center(
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: appColors.accent,
                    child: Text(
                      deviceAlias.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _ConversationEmptyState extends StatelessWidget {
  const _ConversationEmptyState({
    required this.onRefresh,
    required this.onManualConnect,
  });

  final Future<void> Function() onRefresh;
  final VoidCallback onManualConnect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 96, 24, 24),
      child: Column(
        children: [
          Icon(
            Icons.devices_rounded,
            size: 48,
            color: appColors.muted.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 16),
          Text(
            '附近还没有设备',
            style: TextStyle(
              color: appColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '确保两台设备连接到同一局域网',
            textAlign: TextAlign.center,
            style: TextStyle(color: appColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重新扫描'),
              ),
              FilledButton.icon(
                onPressed: onManualConnect,
                icon: const Icon(Icons.add_link_rounded, size: 18),
                label: const Text('手动连接'),
              ),
            ],
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
      child: _PressableScale(
        child: Tooltip(
          message: tooltip,
          child: ShadButton.outline(
            onPressed: enabled ? onPressed ?? () {} : null,
            width: 42,
            height: 42,
            padding: EdgeInsets.zero,
            backgroundColor: appColors.surface,
            foregroundColor: appColors.muted,
            hoverForegroundColor: appColors.text,
            hoverBackgroundColor: appColors.accentSoft,
            child: Icon(icon, size: 19),
          ),
        ),
      ),
    );
  }
}

class _IconShadButton extends StatelessWidget {
  const _IconShadButton({
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
    return _PressableScale(
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          color: color ?? appColors.muted,
          style: IconButton.styleFrom(
            fixedSize: const Size(42, 42),
            backgroundColor: Colors.transparent,
            foregroundColor: color ?? appColors.muted,
            hoverColor: appColors.accentSoft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _SendShadButton extends StatelessWidget {
  const _SendShadButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ShadButton(
      onPressed: onPressed,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      backgroundColor: appColors.accent,
      hoverBackgroundColor: Color.alphaBlend(
        Colors.black.withValues(alpha: 0.08),
        appColors.accent,
      ),
      foregroundColor: Colors.white,
      hoverForegroundColor: Colors.white,
      child: const Text('发送', style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

// ignore: unused_element
class _ComposerShadTextarea extends StatelessWidget {
  const _ComposerShadTextarea({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return ShadTextarea(
      controller: controller,
      minHeight: 78,
      maxHeight: 130,
      resizable: false,
      placeholder: const Text('输入消息...'),
      inputPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: ShadDecoration(
        color: Colors.transparent,
        border: ShadBorder.all(color: Colors.transparent, width: 0),
        secondaryBorder: ShadBorder.all(color: Colors.transparent, width: 0),
        focusedBorder: ShadBorder.all(color: Colors.transparent, width: 0),
        secondaryFocusedBorder: ShadBorder.all(
          color: Colors.transparent,
          width: 0,
        ),
      ),
      style: TextStyle(color: appColors.text, fontSize: 14, height: 1.55),
      onSubmitted: (_) => onSend(),
    );
  }
}

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.favorite,
    required this.online,
    required this.selected,
    required this.onTap,
    required this.onContextMenu,
    this.padded = true,
    this.mobile = false,
  });

  final Conversation conversation;
  final bool favorite;
  final bool online;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<Offset> onContextMenu;

  /// When false, omits the outer bottom spacing so a wrapper (e.g. the swipe
  /// action container) can own the list gap instead.
  final bool padded;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final tile = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(mobile ? 0 : 8),
      child: GestureDetector(
        onSecondaryTapDown: (details) {
          onContextMenu(details.globalPosition);
        },
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(mobile ? 0 : 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            constraints: BoxConstraints(minHeight: mobile ? 76 : 72),
            margin: EdgeInsets.only(left: !mobile && selected ? 2 : 0),
            padding: EdgeInsets.symmetric(
              horizontal: mobile ? 16 : 10,
              vertical: mobile ? 12 : 10,
            ),
            decoration: BoxDecoration(
              color: !mobile && selected
                  ? appColors.accentSoft
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(mobile ? 0 : 8),
              border: mobile
                  ? Border(bottom: BorderSide(color: appColors.line))
                  : Border.all(
                      color: selected
                          ? appColors.accent.withValues(alpha: 0.24)
                          : Colors.transparent,
                    ),
              boxShadow: !mobile && selected
                  ? const [
                      BoxShadow(
                        color: Color(0x0F0F172A),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ]
                  : const [],
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
                                color: appColors.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (favorite) ...[
                            Icon(Icons.star_rounded, color: warning, size: 16),
                            const SizedBox(width: 5),
                          ],
                          if (conversation.device != null)
                            Icon(
                              online
                                  ? Icons.wifi_rounded
                                  : Icons
                                        .signal_wifi_connected_no_internet_4_rounded,
                              color: online
                                  ? const Color(0xFF27A95D)
                                  : appColors.muted,
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
                        style: TextStyle(color: appColors.muted, fontSize: 13),
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
                      color: warning,
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
    );
    if (!padded) return tile;
    return Padding(padding: const EdgeInsets.only(bottom: 4), child: tile);
  }
}

/// A single revealed action behind a [_SwipeActionTile].
class _SwipeAction {
  const _SwipeAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

/// Fixed width of each revealed swipe action button.
const double _kSwipeActionExtent = 72;

/// Swipe-left-to-reveal action buttons (Android only). Drag the tile left to
/// expose the actions on the right; release past the halfway point (or with a
/// leftward fling) to latch open, tap an action to run it, or tap the tile /
/// drag back to close.
class _SwipeActionTile extends StatefulWidget {
  const _SwipeActionTile({
    super.key,
    required this.child,
    required this.actions,
  });

  final Widget child;
  final List<_SwipeAction> actions;

  @override
  State<_SwipeActionTile> createState() => _SwipeActionTileState();
}

class _SwipeActionTileState extends State<_SwipeActionTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  double get _maxDrag => widget.actions.length * _kSwipeActionExtent;

  void _onDragUpdate(DragUpdateDetails details) {
    if (_maxDrag <= 0) return;
    _controller.value -= details.primaryDelta! / _maxDrag;
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -250) {
      _controller.animateTo(1, curve: Curves.easeOut);
    } else if (velocity > 250) {
      _controller.animateTo(0, curve: Curves.easeOut);
    } else {
      _controller.animateTo(
        _controller.value > 0.5 ? 1 : 0,
        curve: Curves.easeOut,
      );
    }
  }

  void _close() => _controller.animateTo(0, curve: Curves.easeOut);

  Future<void> _runAction(_SwipeAction action) async {
    await _controller.animateTo(0, curve: Curves.easeOut);
    if (!mounted) return;
    action.onTap();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Positioned.fill(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (final action in widget.actions)
                    _SwipeActionButton(
                      action: action,
                      width: _kSwipeActionExtent,
                      onPressed: () => _runAction(action),
                    ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final isOpen = _controller.value > 0.001;
                return Transform.translate(
                  offset: Offset(-_controller.value * _maxDrag, 0),
                  // Opaque background: the foreground must fully occlude the
                  // action buttons behind it when closed. ConversationTile is
                  // transparent unless selected, so without this the actions
                  // would bleed through any unselected row.
                  child: ColoredBox(
                    color: appColors.panel,
                    child: Stack(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragUpdate: _onDragUpdate,
                          onHorizontalDragEnd: _onDragEnd,
                          child: widget.child,
                        ),
                        // While open, a transparent barrier swallows taps so
                        // the first tap closes the tile instead of selecting it.
                        if (isOpen)
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _close,
                              onHorizontalDragUpdate: _onDragUpdate,
                              onHorizontalDragEnd: _onDragEnd,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeActionButton extends StatelessWidget {
  const _SwipeActionButton({
    required this.action,
    required this.width,
    required this.onPressed,
  });

  final _SwipeAction action;
  final double width;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        width: width,
        color: action.color,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(action.icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(
              action.label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
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
