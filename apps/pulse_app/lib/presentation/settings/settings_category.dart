import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Public Settings categories for deep-links.
enum SettingsCategoryId {
  general,
  appearance,
  background,
  systemHealth,
  timeline,
  diagnostics,
  performance,
  privacy,
  updates,
  developer,
}

extension on SettingsCategoryId {
  String get label => switch (this) {
        SettingsCategoryId.general => 'General',
        SettingsCategoryId.appearance => 'Appearance',
        SettingsCategoryId.background => 'Background',
        SettingsCategoryId.systemHealth => 'System Health',
        SettingsCategoryId.timeline => 'Timeline',
        SettingsCategoryId.diagnostics => 'Diagnostics',
        SettingsCategoryId.performance => 'Performance',
        SettingsCategoryId.privacy => 'Privacy',
        SettingsCategoryId.updates => 'Updates',
        SettingsCategoryId.developer => 'Developer',
      };

  IconData get icon => switch (this) {
        SettingsCategoryId.general => LucideIcons.settings,
        SettingsCategoryId.appearance => LucideIcons.palette,
        SettingsCategoryId.background => LucideIcons.panelBottom,
        SettingsCategoryId.systemHealth => LucideIcons.heartPulse,
        SettingsCategoryId.timeline => LucideIcons.listOrdered,
        SettingsCategoryId.diagnostics => LucideIcons.bug,
        SettingsCategoryId.performance => LucideIcons.gauge,
        SettingsCategoryId.privacy => LucideIcons.shieldCheck,
        SettingsCategoryId.updates => LucideIcons.download,
        SettingsCategoryId.developer => LucideIcons.codeXml,
      };
}
