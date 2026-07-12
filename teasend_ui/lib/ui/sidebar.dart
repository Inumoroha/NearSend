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

class _MobileNavigationBar extends StatelessWidget {
  const _MobileNavigationBar({
    required this.activeSection,
    required this.onChats,
    required this.onTransfers,
    required this.onHistory,
    required this.onSettings,
  });

  final _MainSection activeSection;
  final VoidCallback onChats;
  final VoidCallback onTransfers;
  final VoidCallback onHistory;
  final VoidCallback onSettings;

  int get _selectedIndex => switch (activeSection) {
    _MainSection.chats => 0,
    _MainSection.transfers => 1,
    _MainSection.history => 2,
    _MainSection.settings || _MainSection.theme => 3,
  };

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: appColors.surface,
        border: Border(top: BorderSide(color: appColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          key: const ValueKey('mobile-bottom-navigation'),
          height: 64,
          selectedIndex: _selectedIndex,
          backgroundColor: appColors.surface,
          indicatorColor: appColors.accentSoft,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) {
            switch (index) {
              case 0:
                onChats();
              case 1:
                onTransfers();
              case 2:
                onHistory();
              case 3:
                onSettings();
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_bubble_rounded),
              label: '消息',
            ),
            NavigationDestination(
              icon: Icon(Icons.swap_horiz_rounded),
              selectedIcon: Icon(Icons.sync_alt_rounded),
              label: '传输',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history_rounded),
              label: '记录',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: '设置',
            ),
          ],
        ),
      ),
    );
  }
}
