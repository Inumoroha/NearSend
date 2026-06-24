part of '../main.dart';

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.activeSection,
    required this.deviceAlias,
    required this.onShowDeviceInfo,
    required this.onChats,
    required this.onTransfers,
    required this.onTheme,
    required this.onSettings,
    required this.onHistory,
  });

  final _MainSection activeSection;
  final String deviceAlias;
  final VoidCallback onShowDeviceInfo;
  final VoidCallback onChats;
  final VoidCallback onTransfers;
  final VoidCallback onTheme;
  final VoidCallback onSettings;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: appColors.sidebar,
        border: Border.all(color: appColors.line),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Tooltip(
            message: '本设备信息',
            child: InkWell(
              onTap: onShowDeviceInfo,
              customBorder: const CircleBorder(),
              child: CircleAvatar(
                radius: 23,
                backgroundColor: appColors.accent,
                child: Text(
                  deviceAlias.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 36),
          _NavIcon(
            icon: Icons.chat_bubble_rounded,
            active: activeSection == _MainSection.chats,
            tooltip: '消息',
            onPressed: onChats,
          ),
          _NavIcon(
            icon: Icons.sync_alt_rounded,
            active: activeSection == _MainSection.transfers,
            tooltip: '传输',
            onPressed: onTransfers,
          ),
          _NavIcon(
            icon: Icons.history_rounded,
            active: activeSection == _MainSection.history,
            tooltip: '文件记录',
            onPressed: onHistory,
          ),
          const Spacer(),
          _NavIcon(
            icon: Icons.palette_rounded,
            active: activeSection == _MainSection.theme,
            tooltip: '主题',
            onPressed: onTheme,
          ),
          _NavIcon(
            icon: Icons.settings_rounded,
            active: activeSection == _MainSection.settings,
            tooltip: '设置',
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}

/// Phone navigation: the left rail is replaced by this slide-in drawer on
/// narrow screens. Selecting an item switches section and closes the drawer.
class _NavDrawer extends StatelessWidget {
  const _NavDrawer({
    required this.activeSection,
    required this.deviceAlias,
    required this.onShowDeviceInfo,
    required this.onChats,
    required this.onTransfers,
    required this.onTheme,
    required this.onSettings,
    required this.onHistory,
  });

  final _MainSection activeSection;
  final String deviceAlias;
  final VoidCallback onShowDeviceInfo;
  final VoidCallback onChats;
  final VoidCallback onTransfers;
  final VoidCallback onTheme;
  final VoidCallback onSettings;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: appColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () {
                Navigator.of(context).pop();
                onShowDeviceInfo();
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: appColors.accent,
                      child: Text(
                        deviceAlias.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        deviceAlias,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: appColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: appColors.muted),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: appColors.line),
            _NavDrawerItem(
              icon: Icons.chat_bubble_rounded,
              label: '消息',
              active: activeSection == _MainSection.chats,
              onTap: () => _select(context, onChats),
            ),
            _NavDrawerItem(
              icon: Icons.sync_alt_rounded,
              label: '传输',
              active: activeSection == _MainSection.transfers,
              onTap: () => _select(context, onTransfers),
            ),
            _NavDrawerItem(
              icon: Icons.history_rounded,
              label: '文件记录',
              active: activeSection == _MainSection.history,
              onTap: () => _select(context, onHistory),
            ),
            _NavDrawerItem(
              icon: Icons.palette_rounded,
              label: '主题',
              active: activeSection == _MainSection.theme,
              onTap: () => _select(context, onTheme),
            ),
            _NavDrawerItem(
              icon: Icons.settings_rounded,
              label: '设置',
              active: activeSection == _MainSection.settings,
              onTap: () => _select(context, onSettings),
            ),
          ],
        ),
      ),
    );
  }

  void _select(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }
}

class _NavDrawerItem extends StatelessWidget {
  const _NavDrawerItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: active ? appColors.accent : appColors.muted),
      title: Text(
        label,
        style: TextStyle(
          color: active ? appColors.accent : appColors.text,
          fontSize: 15,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: active,
      selectedTileColor: appColors.accentSoft,
    );
  }
}

