import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/pulse_theme.dart';

/// One keyboard shortcut shown in the shortcuts dialog.
class ShortcutRow {
  const ShortcutRow(this.keys, this.action);

  /// Human-readable key combo, for example `Ctrl + 1`.
  final String keys;

  /// What the combo does.
  final String action;
}

/// Shell-level shortcuts advertised in the palette and the shortcuts dialog.
/// Kept next to the bindings in `AppShell` so the list cannot drift far.
const List<ShortcutRow> kShellShortcutRows = [
  ShortcutRow('Ctrl + K', 'Open the command palette'),
  ShortcutRow('Ctrl + 1', 'Timeline'),
  ShortcutRow('Ctrl + 2', 'System Health'),
  ShortcutRow('Ctrl + 3', 'Inventory'),
  ShortcutRow('Ctrl + 4', 'Reports'),
  ShortcutRow('Ctrl + 5', 'Diagnostics'),
  ShortcutRow('Ctrl + 6', 'Settings'),
  ShortcutRow('Ctrl + 7', 'Assistant'),
  ShortcutRow('↑ ↓ + Enter', 'Pick a command in the palette'),
  ShortcutRow('Esc', 'Close the palette or a dialog'),
];

/// Shows the keyboard shortcuts reference. Returns when dismissed.
Future<void> showShortcutsDialog(BuildContext context) {
  final theme = context.pulseTheme;
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss keyboard shortcuts',
    builder: (dialogContext) {
      final text = Theme.of(dialogContext).textTheme;
      return AlertDialog(
        backgroundColor: theme.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(theme.radiusXl),
          side: BorderSide(color: theme.stroke.withValues(alpha: 0.7)),
        ),
        title: Row(
          children: [
            Icon(LucideIcons.keyboard, size: 20, color: theme.accent),
            const SizedBox(width: 10),
            Text(
              'Keyboard shortcuts',
              style: text.titleLarge?.copyWith(color: theme.textPrimary),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final row in kShellShortcutRows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 132,
                        child: Text(
                          row.keys,
                          style: text.labelMedium?.copyWith(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.action,
                          style: text.bodyMedium?.copyWith(
                            color: theme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Close',
              style: TextStyle(
                color: theme.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    },
  );
}
