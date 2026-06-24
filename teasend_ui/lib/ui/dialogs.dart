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
