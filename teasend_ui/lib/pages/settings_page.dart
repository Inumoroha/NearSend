part of '../main.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.autoSaveEnabled,
    required this.autoSaveDirectory,
    required this.overwriteSameNameFiles,
    required this.showImageCopyButton,
    required this.minimizeToTrayEnabled,
    required this.restoringWindowSettings,
    this.firewallStatus,
    this.lastFirewallRepair,
    this.lastInboundRequest,
    this.localEndpoints = const [],
    this.localHttpStatus,
    this.checkingFirewall = false,
    this.repairingFirewall = false,
    required this.onAutoSaveChanged,
    required this.onOverwriteSameNameFilesChanged,
    required this.onShowImageCopyButtonChanged,
    required this.onMinimizeToTrayChanged,
    required this.onChooseDirectory,
    this.onRefreshFirewall,
    this.onRepairFirewall,
    this.tempCleanupService,
    this.onShowTempCleanup,
    this.onMenu,
  });

  final bool autoSaveEnabled;
  final String autoSaveDirectory;
  final bool overwriteSameNameFiles;
  final bool showImageCopyButton;
  final bool minimizeToTrayEnabled;
  final bool restoringWindowSettings;
  final WindowsFirewallStatus? firewallStatus;
  final WindowsFirewallRepairResult? lastFirewallRepair;
  final String? lastInboundRequest;
  final List<String> localEndpoints;
  final String? localHttpStatus;
  final bool checkingFirewall;
  final bool repairingFirewall;
  final ValueChanged<bool> onAutoSaveChanged;
  final ValueChanged<bool> onOverwriteSameNameFilesChanged;
  final ValueChanged<bool> onShowImageCopyButtonChanged;
  final ValueChanged<bool> onMinimizeToTrayChanged;
  final VoidCallback onChooseDirectory;
  final VoidCallback? onRefreshFirewall;
  final VoidCallback? onRepairFirewall;
  final TempFileCleanupService? tempCleanupService;
  final VoidCallback? onShowTempCleanup;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final imageCopyButtonSetting = _SettingsSwitchCard(
      icon: Icons.image_rounded,
      title: '图片复制按钮',
      description: '控制发送和接收的图片消息是否显示复制按钮',
      value: showImageCopyButton,
      onChanged: onShowImageCopyButtonChanged,
    );

    return Container(
      color: appColors.chatBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 74,
            padding: const EdgeInsets.symmetric(horizontal: 28),
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
                  '设置',
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
              children: [
                imageCopyButtonSetting,
                const SizedBox(height: 14),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: appColors.surface,
                    border: Border.all(color: appColors.line),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
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
                                Icons.save_alt_rounded,
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
                                    '自动保存',
                                    style: TextStyle(
                                      color: appColors.text,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    Platform.isAndroid
                                        ? '开启后，对方发来的文件会自动保存到“下载/NearSend”'
                                        : '开启后，对方发来的文件会自动保存到指定路径',
                                    style: TextStyle(
                                      color: appColors.muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ShadSwitch(
                              value: autoSaveEnabled,
                              checkedTrackColor: appColors.accent,
                              onChanged: onAutoSaveChanged,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        // Android uses SAF behind this picker; desktop uses
                        // file_selector. Both persist the chosen display path.
                        if (_showFixedAndroidDownloadsDirectoryPlaceholder)
                          Container(
                            height: 42,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: appColors.panel,
                              border: Border.all(color: appColors.line),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '下载/NearSend',
                              style: TextStyle(
                                color: appColors.text,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 42,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: appColors.panel,
                                    border: Border.all(color: appColors.line),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SelectableText(
                                    autoSaveDirectory,
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: appColors.text,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                onPressed: onChooseDirectory,
                                icon: const Icon(
                                  Icons.folder_open_rounded,
                                  size: 20,
                                ),
                                color: appColors.text,
                                style: IconButton.styleFrom(
                                  fixedSize: const Size(42, 42),
                                  side: BorderSide(color: appColors.line),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _SettingsSwitchCard(
                  icon: Icons.file_copy_rounded,
                  title: '覆盖同名文件',
                  description: '开启后，自动保存时同名文件会直接覆盖',
                  value: overwriteSameNameFiles,
                  onChanged: onOverwriteSameNameFilesChanged,
                ),
                const SizedBox(height: 14),
                if (tempCleanupService != null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: appColors.surface,
                      border: Border.all(color: appColors.line),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
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
                                  Icons.cleaning_services_rounded,
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
                                      '临时文件清理',
                                      style: TextStyle(
                                        color: appColors.text,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '清理接收文件产生的临时数据',
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
                          const SizedBox(height: 14),
                          _TempFileCleanupWidget(service: tempCleanupService!),
                        ],
                      ),
                    ),
                  ),
                // Tray/minimize is a desktop-only feature.
                if (Platform.isWindows) ...[
                  const SizedBox(height: 14),
                  FirewallRepairCard(
                    status: firewallStatus,
                    lastRepair: lastFirewallRepair,
                    lastInboundRequest: lastInboundRequest,
                    localEndpoints: localEndpoints,
                    localHttpStatus: localHttpStatus,
                    checking: checkingFirewall,
                    repairing: repairingFirewall,
                    onRefresh: onRefreshFirewall ?? () {},
                    onRepair: onRepairFirewall ?? () {},
                  ),
                  const SizedBox(height: 14),
                  _SettingsSwitchCard(
                    icon: Icons.system_update_alt_rounded,
                    title: '最小化到托盘',
                    description: restoringWindowSettings
                        ? '正在读取窗口设置'
                        : '开启后，最小化或关闭窗口时隐藏到系统托盘',
                    value: minimizeToTrayEnabled,
                    onChanged: restoringWindowSettings
                        ? null
                        : onMinimizeToTrayChanged,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSwitchCard extends StatelessWidget {
  const _SettingsSwitchCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;

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
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(color: appColors.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            ShadSwitch(
              value: value,
              checkedTrackColor: appColors.accent,
              enabled: onChanged != null,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

