part of '../main.dart';

class DeviceDetailsPage extends StatelessWidget {
  const DeviceDetailsPage({
    super.key,
    required this.conversation,
    required this.favoriteDevice,
    required this.onFavoriteDeviceChanged,
    required this.clipboardAutoSendEnabled,
    required this.onClipboardAutoSendChanged,
  });

  final Conversation conversation;
  final bool favoriteDevice;
  final ValueChanged<bool> onFavoriteDeviceChanged;
  final bool clipboardAutoSendEnabled;
  final ValueChanged<bool> onClipboardAutoSendChanged;

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 560;
    final device = conversation.device;
    return Container(
      width: double.infinity,
      color: appColors.chatBg,
      child: device == null
          ? const _DeviceDetailsEmpty()
          : ListView(
              padding: EdgeInsets.fromLTRB(
                isPhone ? 16 : 32,
                isPhone ? 20 : 28,
                isPhone ? 16 : 32,
                isPhone ? 24 : 32,
              ),
              children: [
                Row(
                  children: [
                    InitialAvatar(text: device.initials, size: 58),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device.alias,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: appColors.text,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${device.deviceType.label} · ${device.displayModel}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: appColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _DeviceSwitchCard(
                  icon: Icons.star_rounded,
                  title: '收藏设备',
                  description: '收藏后，此设备发来的文件会自动接收，不再弹出确认或拒绝。',
                  enabled: favoriteDevice,
                  onChanged: onFavoriteDeviceChanged,
                ),
                const SizedBox(height: 14),
                _DeviceAutoSendCard(
                  enabled: clipboardAutoSendEnabled,
                  onChanged: onClipboardAutoSendChanged,
                ),
                const SizedBox(height: 14),
                _DeviceDetailSection(
                  title: '设备标识',
                  rows: [
                    _DeviceDetailRow('唯一 ID', device.fingerprint),
                    _DeviceDetailRow('别名', device.alias),
                    _DeviceDetailRow('协议版本', 'LocalSend ${device.version}'),
                  ],
                ),
                const SizedBox(height: 14),
                _DeviceDetailSection(
                  title: '网络',
                  rows: [
                    _DeviceDetailRow('IP', device.ip),
                    _DeviceDetailRow('端口', device.port.toString()),
                    _DeviceDetailRow('协议', device.https ? 'HTTPS' : 'HTTP'),
                    _DeviceDetailRow('地址', device.endpoint),
                  ],
                ),
                const SizedBox(height: 14),
                _DeviceDetailSection(
                  title: '设备',
                  rows: [
                    _DeviceDetailRow('设备类型', device.deviceType.label),
                    _DeviceDetailRow('设备型号', device.displayModel),
                    _DeviceDetailRow('允许下载', device.download ? '是' : '否'),
                    _DeviceDetailRow('最后发现', _formatDateTime(device.lastSeen)),
                  ],
                ),
              ],
            ),
    );
  }

  static String _formatDateTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }
}

class _DeviceAutoSendCard extends StatelessWidget {
  const _DeviceAutoSendCard({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: appColors.surface,
        border: Border.all(color: appColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: appColors.accentSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.content_paste_go_rounded,
                color: appColors.accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '自动发送截图',
                    style: TextStyle(
                      color: appColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '截屏并复制到剪贴板后，自动把图片发送到此设备',
                    style: TextStyle(
                      color: appColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: enabled,
              activeThumbColor: appColors.accent,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceSwitchCard extends StatelessWidget {
  const _DeviceSwitchCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: appColors.surface,
        border: Border.all(color: appColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: appColors.accentSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: appColors.accent, size: 22),
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
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: appColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: enabled,
              activeThumbColor: appColors.accent,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceDetailsEmpty extends StatelessWidget {
  const _DeviceDetailsEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded, color: appColors.muted, size: 34),
          const SizedBox(height: 12),
          Text(
            '当前会话没有设备信息',
            style: TextStyle(
              color: appColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '通过局域网发现或手动连接的设备会显示完整详情',
            style: TextStyle(color: appColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _DeviceDetailSection extends StatelessWidget {
  const _DeviceDetailSection({required this.title, required this.rows});

  final String title;
  final List<_DeviceDetailRow> rows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: appColors.surface,
        border: Border.all(color: appColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: appColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            for (final row in rows) _DeviceDetailLine(row: row),
          ],
        ),
      ),
    );
  }
}

class _DeviceDetailLine extends StatelessWidget {
  const _DeviceDetailLine({required this.row});

  final _DeviceDetailRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              row.label,
              style: TextStyle(color: appColors.muted, fontSize: 13),
            ),
          ),
          Expanded(
            child: SelectableText(
              row.value,
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

class _DeviceDetailRow {
  const _DeviceDetailRow(this.label, this.value);

  final String label;
  final String value;
}
