part of '../main.dart';

class TeaDialog extends StatelessWidget {
  const TeaDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.icon,
    this.width = 400,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final IconData? icon;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ShadDialog(
        constraints: BoxConstraints(maxWidth: width),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        radius: BorderRadius.circular(8),
        backgroundColor: appColors.surface,
        border: Border.all(color: appColors.line),
        shadows: const [
          BoxShadow(
            color: Color(0x2431302D),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
        title: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: appColors.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: appColors.accent, size: 19),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(child: title),
          ],
        ),
        titleStyle: TextStyle(
          color: appColors.text,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
        actions: actions,
        actionsGap: 8,
        actionsMainAxisAlignment: MainAxisAlignment.end,
        expandActionsWhenTiny: false,
        child: content,
      ),
    );
  }
}

class TeaDialogButton extends StatelessWidget {
  const TeaDialogButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.filled = false,
  });

  final VoidCallback onPressed;
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return filled
        ? ShadButton(
            onPressed: onPressed,
            width: 76,
            height: 38,
            backgroundColor: appColors.accent,
            hoverBackgroundColor: Color.alphaBlend(
              Colors.black.withValues(alpha: 0.08),
              appColors.accent,
            ),
            foregroundColor: Colors.white,
            hoverForegroundColor: Colors.white,
            child: Text(label),
          )
        : ShadButton.ghost(
            onPressed: onPressed,
            width: 76,
            height: 38,
            foregroundColor: appColors.muted,
            hoverForegroundColor: appColors.text,
            hoverBackgroundColor: appColors.accentSoft,
            child: Text(label),
          );
  }
}

class _DeviceInfoRow extends StatelessWidget {
  const _DeviceInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: TextStyle(color: appColors.muted, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                color: appColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Result of the delete/clear confirmation dialog.
class _HistoryRemoval {
  const _HistoryRemoval({required this.alsoDeleteFile});

  final bool alsoDeleteFile;
}

InputDecoration teaInputDecoration({String? labelText, String? hintText}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    filled: true,
    fillColor: appColors.panel,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: appColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: appColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: appColors.accent, width: 1.4),
    ),
    labelStyle: TextStyle(color: appColors.muted, fontSize: 13),
    hintStyle: TextStyle(color: appColors.sidebarMuted, fontSize: 13),
  );
}

/// 输入框文本样式，确保暗黑模式下文本可见
TextStyle teaInputTextStyle() {
  return TextStyle(color: appColors.text, fontSize: 14);
}

class _PopupMenuActionLabel extends StatelessWidget {
  const _PopupMenuActionLabel({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final color = danger ? const Color(0xFFC85D4D) : textColor;
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color, fontSize: 13)),
      ],
    );
  }
}

class _MenuItemWithColor extends StatelessWidget {
  const _MenuItemWithColor({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color, fontSize: 13)),
      ],
    );
  }
}

class _ManualConnectInput {
  const _ManualConnectInput({required this.host, required this.port});

  final String host;
  final int port;
}

/// Single text-field prompt dialog (rename / remark). Owns its controller so it
/// is disposed when the dialog subtree unmounts — see [_ManualConnectDialog].
class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.initialValue,
    required this.confirmLabel,
    this.hintText,
    this.icon = Icons.edit_rounded,
    this.width = 360,
  });

  final String title;
  final String initialValue;
  final String confirmLabel;
  final String? hintText;
  final IconData icon;
  final double width;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return TeaDialog(
      title: Text(widget.title),
      icon: widget.icon,
      width: widget.width,
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: teaInputTextStyle(),
        decoration: teaInputDecoration(hintText: widget.hintText),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TeaDialogButton(
          onPressed: () => Navigator.of(context).pop(),
          label: '取消',
        ),
        TeaDialogButton(
          onPressed: _submit,
          label: widget.confirmLabel,
          filled: true,
        ),
      ],
    );
  }
}

/// Local device info + alias rename dialog. Owns its alias controller so it is
/// disposed with the dialog subtree — see [_ManualConnectDialog].
class _DeviceInfoDialog extends StatefulWidget {
  const _DeviceInfoDialog({
    required this.initialAlias,
    required this.deviceTypeLabel,
    required this.deviceModel,
    required this.endpoint,
    required this.fingerprint,
  });

  final String initialAlias;
  final String deviceTypeLabel;
  final String deviceModel;
  final String endpoint;
  final String fingerprint;

  @override
  State<_DeviceInfoDialog> createState() => _DeviceInfoDialogState();
}

class _DeviceInfoDialogState extends State<_DeviceInfoDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialAlias);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return TeaDialog(
      title: const Text('本设备信息'),
      icon: Icons.devices_rounded,
      width: 400,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            style: teaInputTextStyle(),
            decoration: teaInputDecoration(
              labelText: '设备名称',
              hintText: '其他设备搜索时显示的名称',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          _DeviceInfoRow(label: '设备类型', value: widget.deviceTypeLabel),
          _DeviceInfoRow(label: '型号', value: widget.deviceModel),
          _DeviceInfoRow(label: '本机地址', value: widget.endpoint),
          _DeviceInfoRow(label: '设备指纹', value: widget.fingerprint),
        ],
      ),
      actions: [
        TeaDialogButton(
          onPressed: () => Navigator.of(context).pop(),
          label: '取消',
        ),
        TeaDialogButton(onPressed: _submit, label: '保存', filled: true),
      ],
    );
  }
}

/// Manual-connect dialog. Owns its [TextEditingController]s so they live exactly
/// as long as the dialog's element subtree — disposing them in the caller's
/// `finally` raced the close animation and crashed with "TextEditingController
/// used after being disposed" on cancel.
class _ManualConnectDialog extends StatefulWidget {
  const _ManualConnectDialog({
    required this.initialIp,
    required this.initialPort,
    required this.onInvalid,
  });

  final String initialIp;
  final String initialPort;
  final VoidCallback onInvalid;

  @override
  State<_ManualConnectDialog> createState() => _ManualConnectDialogState();
}

class _ManualConnectDialogState extends State<_ManualConnectDialog> {
  late final TextEditingController _ipController;
  late final TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: widget.initialIp)
      ..selection = TextSelection.collapsed(offset: widget.initialIp.length);
    _portController = TextEditingController(text: widget.initialPort);
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _submit() {
    var host = _ipController.text.trim();
    var port = int.tryParse(_portController.text.trim());
    final endpointMatch = RegExp(
      r'^(?:https?://)?([^:/\s]+):(\d{1,5})/?$',
    ).firstMatch(host);
    if (endpointMatch != null) {
      host = endpointMatch.group(1) ?? host;
      port = int.tryParse(endpointMatch.group(2) ?? '');
    }
    if (host.isEmpty || port == null || port < 1 || port > 65535) {
      widget.onInvalid();
      return;
    }
    Navigator.of(context).pop(_ManualConnectInput(host: host, port: port));
  }

  @override
  Widget build(BuildContext context) {
    return TeaDialog(
      title: const Text('手动连接'),
      icon: Icons.add_link_rounded,
      width: 420,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ipController,
            autofocus: true,
            style: teaInputTextStyle(),
            decoration: teaInputDecoration(
              labelText: '对方 IP 地址',
              hintText: '例如 192.168.1.20',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _portController,
            style: teaInputTextStyle(),
            decoration: teaInputDecoration(
              labelText: '端口号',
              hintText: '默认 53317',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TeaDialogButton(
          onPressed: () => Navigator.of(context).pop(),
          label: '取消',
        ),
        TeaDialogButton(onPressed: _submit, label: '连接', filled: true),
      ],
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.tooltip,
    this.active = false,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: onPressed ?? () {},
          icon: Icon(icon, size: 21),
          color: active ? appColors.accent : appColors.sidebarMuted,
          style: IconButton.styleFrom(
            fixedSize: const Size(42, 42),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            backgroundColor: active ? appColors.accentSoft : Colors.transparent,
            hoverColor: appColors.accentSoft,
          ),
        ),
      ),
    );
  }
}

