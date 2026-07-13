part of '../main.dart';

class ThemePage extends StatelessWidget {
  const ThemePage({
    super.key,
    required this.themeMode,
    required this.themeColor,
    required this.onThemeModeChanged,
    required this.onThemeColorChanged,
    this.onMenu,
  });

  final AppThemeMode themeMode;
  final Color themeColor;
  final ValueChanged<AppThemeMode> onThemeModeChanged;
  final ValueChanged<Color> onThemeColorChanged;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < 560;
    return Container(
      color: appColors.chatBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: isPhone ? 56 : 74,
            padding: EdgeInsets.symmetric(horizontal: isPhone ? 16 : 28),
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
                  '主题',
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
              padding: EdgeInsets.fromLTRB(
                isPhone ? 12 : 32,
                isPhone ? 16 : 28,
                isPhone ? 12 : 32,
                isPhone ? 20 : 32,
              ),
              children: [
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
                        _ThemeSectionHeader(
                          icon: Icons.dark_mode_rounded,
                          title: '显示模式',
                          description: '切换日间或夜间界面',
                        ),
                        const SizedBox(height: 16),
                        _ThemeModePicker(
                          value: themeMode,
                          onChanged: onThemeModeChanged,
                        ),
                      ],
                    ),
                  ),
                ),
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
                        _ThemeSectionHeader(
                          icon: Icons.palette_rounded,
                          title: '主题色',
                          description: '选择按钮、状态和强调元素的颜色',
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final color in themeColorOptions)
                              _ThemeColorSwatch(
                                color: color,
                                selected:
                                    color.toARGB32() == themeColor.toARGB32(),
                                onTap: () => onThemeColorChanged(color),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModePicker extends StatelessWidget {
  const _ThemeModePicker({required this.value, required this.onChanged});

  final AppThemeMode value;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ThemeModeOption(
          icon: Icons.light_mode_rounded,
          label: '日间',
          selected: value == AppThemeMode.light,
          onPressed: () => onChanged(AppThemeMode.light),
        ),
        const SizedBox(width: 8),
        _ThemeModeOption(
          icon: Icons.dark_mode_rounded,
          label: '夜间',
          selected: value == AppThemeMode.dark,
          onPressed: () => onChanged(AppThemeMode.dark),
        ),
      ],
    );
  }
}

class _ThemeModeOption extends StatelessWidget {
  const _ThemeModeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ShadButton.outline(
      onPressed: onPressed,
      height: 38,
      backgroundColor: selected ? appColors.accent : appColors.surface,
      hoverBackgroundColor: selected ? appColors.accent : appColors.accentSoft,
      foregroundColor: selected ? Colors.white : appColors.text,
      hoverForegroundColor: selected ? Colors.white : appColors.text,
      leading: Icon(icon, size: 18),
      child: Text(label),
    );
  }
}

class _ThemeSectionHeader extends StatelessWidget {
  const _ThemeSectionHeader({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
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
      ],
    );
  }
}

class _ThemeColorSwatch extends StatelessWidget {
  const _ThemeColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: selected ? '当前主题色' : '切换主题色',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? appColors.text : appColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: selected
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
              : null,
        ),
      ),
    );
  }
}
