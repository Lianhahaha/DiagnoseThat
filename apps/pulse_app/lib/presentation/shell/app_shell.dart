import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../app/dev_flags.dart';
import '../../app/theme/pulse_theme.dart';
import '../../app/theme/pulse_window_chrome.dart';
import '../../application/diagnostics_controller.dart';
import '../../application/health_navigation.dart';
import '../../application/service_lifecycle_controller.dart';
import '../../application/settings_controller.dart';
import '../../application/shell_navigation.dart';
import '../../application/timeline_session_controller.dart';
import '../../application/update_check_controller.dart';
import '../../ipc/pulse_ipc_client.dart';
import '../../platform/pulse_service_scm.dart';
import '../assistant/assistant_host.dart';
import '../assistant/assistant_page.dart';
import '../components/pulse_content_frame.dart';
import '../components/connection_indicator.dart';
import '../components/pulse_nav_rail.dart';
import '../components/pulse_title_bar.dart';
import '../diagnostics/diagnostics_page.dart';
import '../health/health_view_models.dart';
import '../health/system_health_page.dart';
import '../inventory/inventory_page.dart';
import '../reports/reports_page.dart';
import '../settings/settings_category.dart';
import '../settings/settings_page.dart';
import '../timeline/timeline_page.dart';
import '../utils/pulse_snack.dart';
import '../utils/pulse_user_errors.dart';
import 'command_palette.dart';
import 'shortcuts_dialog.dart';

/// Sidebar / shell page indices.
abstract final class PulseShellPages {
  static const timeline = 0;
  static const health = 1;
  static const inventory = 2;
  static const reports = 3;
  static const diagnostics = 4;
  static const settings = 5;
  static const assistant = 6;
  static const count = 7;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = kStartPage >= 0 && kStartPage < PulseShellPages.count
      ? kStartPage
      : PulseShellPages.timeline;
  bool _paletteOpen = false;
  ShellNavigation? _shellNav;

  /// Stable page instances — IndexedStack keeps state alive so Timeline ↔
  /// Inventory never tears down Inventory (root cause of the open flash).
  late final List<Widget> _pages = [
    for (var i = 0; i < PulseShellPages.count; i++)
      KeyedSubtree(
        key: ValueKey('shell-page-$i'),
        child: _pageFor(i, _titles[i]),
      ),
  ];

  static const _primaryNav = [
    PulseNavItem(
      label: 'Timeline',
      icon: LucideIcons.listTree,
      pageIndex: PulseShellPages.timeline,
      tooltip: 'Timeline (Ctrl+1)',
    ),
    PulseNavItem(
      label: 'Health',
      icon: LucideIcons.heartPulse,
      pageIndex: PulseShellPages.health,
      tooltip: 'System Health (Ctrl+2)',
    ),
    PulseNavItem(
      label: 'Inventory',
      icon: LucideIcons.packageSearch,
      pageIndex: PulseShellPages.inventory,
      tooltip: 'Inventory (Ctrl+3)',
    ),
    PulseNavItem(
      label: 'Reports',
      icon: LucideIcons.fileText,
      pageIndex: PulseShellPages.reports,
      tooltip: 'Reports (Ctrl+4)',
    ),
    PulseNavItem(
      label: 'Diagnostics',
      icon: LucideIcons.stethoscope,
      pageIndex: PulseShellPages.diagnostics,
      tooltip: 'Diagnostics (Ctrl+5)',
    ),
  ];

  static const _secondaryNav = [
    PulseNavItem(
      label: 'Assistant',
      icon: LucideIcons.sparkles,
      pageIndex: PulseShellPages.assistant,
      tooltip: 'Assistant (Ctrl+7)',
    ),
    PulseNavItem(
      label: 'Settings',
      icon: LucideIcons.settings,
      pageIndex: PulseShellPages.settings,
      tooltip: 'Settings (Ctrl+6)',
    ),
  ];

  static const _titles = [
    'Timeline',
    'System Health',
    'Inventory',
    'Reports',
    'Diagnostics',
    'Settings',
    'Assistant',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncPageVisibility(_index);
      _shellNav = context.read<ShellNavigation>();
      _shellNav!.addListener(_onShellNavigation);
      _onShellNavigation();
    });
  }

  @override
  void dispose() {
    _shellNav?.removeListener(_onShellNavigation);
    super.dispose();
  }

  void _onShellNavigation() {
    final nav = _shellNav;
    if (nav == null || !mounted) return;
    final page = nav.pendingShellPage;
    final panel = nav.pendingHealthPanel;
    final clearPanel = nav.clearHealthPanel;
    if (page == null && panel == null && !clearPanel) return;

    if (page != null) {
      _selectPage(page);
    }
    final healthNav = context.read<HealthNavigation>();
    if (clearPanel) {
      healthNav.clearPanel();
    } else if (panel != null) {
      healthNav.openPanel(panel);
    }
    nav.consume();
  }

  void _selectPage(int index) {
    if (index < 0 || index >= PulseShellPages.count) return;
    if (_index == index) return;
    setState(() => _index = index);
    _syncPageVisibility(index);
  }

  /// IndexedStack keeps pages mounted — visibility side-effects must be driven
  /// by the shell, not by State.deactivate (which no longer fires on nav).
  void _syncPageVisibility(int index) {
    final timeline = context.read<TimelineSessionController>();
    final diag = context.read<DiagnosticsController>();
    unawaited(timeline.setPageVisible(index == PulseShellPages.timeline));
    if (index == PulseShellPages.diagnostics) {
      diag.frameMetrics.noteRebuild();
      diag.startPolling();
    } else {
      diag.stopPolling();
    }
    if (index == PulseShellPages.inventory) {
      // Inventory may have mounted before IPC was ready — nudge a load.
      InventoryPage.visibilityTick.value++;
    }
  }

  Future<void> _openCommandPalette({String initialQuery = ''}) async {
    if (_paletteOpen || !mounted) return;
    _paletteOpen = true;
    try {
      await showCommandPalette(
        context,
        initialQuery: initialQuery,
        commands: _buildCommands(),
      );
    } finally {
      _paletteOpen = false;
    }
  }

  List<PulseCommand> _buildCommands() {
    final settings = context.read<SettingsController>();
    final healthNav = context.read<HealthNavigation>();
    final service = context.read<ServiceLifecycleController>();
    final diag = context.read<DiagnosticsController>();

    void go(int page) => _selectPage(page);

    void openHealthPanel(HealthPanelKind kind) {
      _selectPage(PulseShellPages.health);
      healthNav.openPanel(kind);
    }

    Future<void> exportSettings() async {
      try {
        final saved = await settings.exportSettingsJson();
        if (!mounted) return;
        PulseSnack.success(context, saved.summary);
      } catch (e) {
        if (!mounted) return;
        PulseSnack.error(context, 'Failed: $e');
      }
    }

    Future<void> runService(Future<void> Function() action) async {
      try {
        await action();
        if (!mounted) return;
        PulseSnack.success(
          context,
          service.lastSuccess ?? 'PulseService updated',
        );
      } catch (e) {
        if (!mounted) return;
        PulseSnack.error(context, PulseUserErrors.fromObject(e));
      }
    }

    Future<void> checkForUpdates() async {
      final updates = context.read<UpdateCheckController>();
      try {
        await updates.check();
        if (!mounted) return;
        if (updates.status == UpdateCheckStatus.available) {
          final latest = updates.latest;
          PulseSnack.success(
            context,
            latest == null
                ? 'A newer version is available'
                : 'Update ${latest.version} is available',
          );
        } else if (updates.status == UpdateCheckStatus.upToDate) {
          PulseSnack.success(context, 'DiagnoseThat is up to date');
        } else if (updates.status == UpdateCheckStatus.failed) {
          PulseSnack.error(context, updates.error ?? 'Update check failed');
        }
      } catch (e) {
        if (!mounted) return;
        PulseSnack.error(context, 'Failed: $e');
      }
    }

    Future<void> exportDiagnostics() async {
      try {
        final saved = await diag.exportReport();
        if (!mounted) return;
        PulseSnack.success(context, saved.summary);
      } catch (e) {
        if (!mounted) return;
        PulseSnack.error(context, 'Failed: $e');
      }
    }

    Future<void> exportLogs() async {
      try {
        final saved = await diag.exportLogsOnly();
        if (!mounted) return;
        PulseSnack.success(context, saved.summary);
      } catch (e) {
        if (!mounted) return;
        PulseSnack.error(context, 'Failed: $e');
      }
    }

    final serviceStateLabel = switch (service.state) {
      PulseServiceScmState.running => 'Running',
      PulseServiceScmState.stopped => 'Stopped',
      PulseServiceScmState.startPending => 'Starting…',
      PulseServiceScmState.stopPending => 'Stopping…',
      PulseServiceScmState.notInstalled => 'Not installed',
      PulseServiceScmState.unknown => 'Status unknown',
    };

    return [
      PulseCommand(
        id: 'nav.timeline',
        title: 'Go to Timeline',
        subtitle: 'Ctrl+1',
        icon: LucideIcons.listTree,
        keywords: const ['navigate', 'page'],
        onInvoke: () => go(PulseShellPages.timeline),
      ),
      PulseCommand(
        id: 'nav.health',
        title: 'Go to System Health',
        subtitle: 'Ctrl+2',
        icon: LucideIcons.heartPulse,
        keywords: const ['navigate', 'page', 'health'],
        onInvoke: () => go(PulseShellPages.health),
      ),
      PulseCommand(
        id: 'nav.inventory',
        title: 'Go to Inventory',
        subtitle: 'Ctrl+3',
        icon: LucideIcons.packageSearch,
        keywords: const ['navigate', 'page', 'services', 'drivers', 'software'],
        onInvoke: () => go(PulseShellPages.inventory),
      ),
      PulseCommand(
        id: 'nav.reports',
        title: 'Go to Reports',
        subtitle: 'Ctrl+4',
        icon: LucideIcons.fileText,
        keywords: const ['navigate', 'page', 'export'],
        onInvoke: () => go(PulseShellPages.reports),
      ),
      PulseCommand(
        id: 'nav.diagnostics',
        title: 'Go to Diagnostics',
        subtitle: 'Ctrl+5',
        icon: LucideIcons.activity,
        keywords: const ['navigate', 'page'],
        onInvoke: () => go(PulseShellPages.diagnostics),
      ),
      PulseCommand(
        id: 'nav.settings',
        title: 'Go to Settings',
        subtitle: 'Ctrl+6',
        icon: LucideIcons.settings,
        keywords: const ['navigate', 'page', 'preferences'],
        onInvoke: () => go(PulseShellPages.settings),
      ),
      for (final category in SettingsCategoryId.values)
        PulseCommand(
          id: 'settings.${category.name}',
          title: 'Settings · ${category.label}',
          subtitle: 'Open the ${category.label} section',
          icon: category.icon,
          keywords: [
            'settings',
            'preferences',
            category.label.toLowerCase(),
            category.name,
          ],
          onInvoke: () {
            context.read<ShellNavigation>().openSettingsCategory(category);
          },
        ),
      PulseCommand(
        id: 'nav.assistant',
        title: 'Go to Assistant',
        subtitle: 'Local AI diagnostics chat · Ctrl+7',
        icon: LucideIcons.bot,
        keywords: const ['assistant', 'ai', 'chat', 'ollama', 'lm studio'],
        onInvoke: () => go(PulseShellPages.assistant),
      ),
      PulseCommand(
        id: 'theme.cycle',
        title: 'Toggle theme',
        subtitle: 'Cycle light / dark / system',
        icon: LucideIcons.sun,
        keywords: const ['appearance', 'dark', 'light', 'system'],
        onInvoke: () {
          settings.cycleThemeMode();
        },
      ),
      PulseCommand(
        id: 'health.cpu',
        title: 'Open CPU panel',
        icon: LucideIcons.cpu,
        keywords: const ['health', 'panel'],
        onInvoke: () => openHealthPanel(HealthPanelKind.cpu),
      ),
      PulseCommand(
        id: 'health.memory',
        title: 'Open Memory panel',
        icon: LucideIcons.memoryStick,
        keywords: const ['health', 'panel', 'ram'],
        onInvoke: () => openHealthPanel(HealthPanelKind.memory),
      ),
      PulseCommand(
        id: 'health.gpu',
        title: 'Open GPU panel',
        icon: LucideIcons.circuitBoard,
        keywords: const ['health', 'panel'],
        onInvoke: () => openHealthPanel(HealthPanelKind.gpu),
      ),
      PulseCommand(
        id: 'health.network',
        title: 'Open Network panel',
        icon: LucideIcons.wifi,
        keywords: const ['health', 'panel'],
        onInvoke: () => openHealthPanel(HealthPanelKind.network),
      ),
      PulseCommand(
        id: 'health.disk',
        title: 'Open Disk panel',
        icon: LucideIcons.hardDrive,
        keywords: const ['health', 'panel', 'storage'],
        onInvoke: () => openHealthPanel(HealthPanelKind.disk),
      ),
      PulseCommand(
        id: 'health.hardware',
        title: 'Open Hardware panel',
        icon: LucideIcons.thermometer,
        keywords: const ['health', 'panel', 'sensors'],
        onInvoke: () => openHealthPanel(HealthPanelKind.hardware),
      ),
      PulseCommand(
        id: 'settings.export',
        title: 'Export settings',
        icon: LucideIcons.download,
        keywords: const ['backup', 'json'],
        onInvoke: () {
          exportSettings();
        },
      ),
      PulseCommand(
        id: 'updates.check',
        title: 'Check for updates',
        subtitle: 'Look for a newer release on GitHub',
        icon: LucideIcons.circleArrowUp,
        keywords: const ['update', 'version', 'upgrade', 'release'],
        onInvoke: () {
          unawaited(checkForUpdates());
        },
      ),
      PulseCommand(
        id: 'diagnostics.export',
        title: 'Export diagnostic report',
        subtitle: 'Save a snapshot for troubleshooting',
        icon: LucideIcons.save,
        keywords: const ['diagnostics', 'export', 'report', 'snapshot'],
        onInvoke: () {
          unawaited(exportDiagnostics());
        },
      ),
      PulseCommand(
        id: 'logs.export',
        title: 'Export logs',
        subtitle: 'Save the recent app log file',
        icon: LucideIcons.arrowDownToLine,
        keywords: const ['logs', 'log', 'export', 'troubleshooting'],
        onInvoke: () {
          unawaited(exportLogs());
        },
      ),
      PulseCommand(
        id: 'service.start',
        title: 'Start PulseService',
        subtitle: 'Service status: $serviceStateLabel',
        icon: LucideIcons.play,
        keywords: const ['service', 'pulse service', 'start', 'run'],
        onInvoke: () {
          unawaited(runService(service.startService));
        },
      ),
      PulseCommand(
        id: 'service.stop',
        title: 'Stop PulseService',
        subtitle: 'Service status: $serviceStateLabel',
        icon: LucideIcons.square,
        keywords: const ['service', 'pulse service', 'stop', 'halt'],
        onInvoke: () {
          unawaited(runService(service.stopService));
        },
      ),
      PulseCommand(
        id: 'service.restart',
        title: 'Restart PulseService',
        subtitle: 'Service status: $serviceStateLabel',
        icon: LucideIcons.refreshCw,
        keywords: const ['service', 'pulse service', 'restart', 'reload'],
        onInvoke: () {
          unawaited(runService(service.restartService));
        },
      ),
      PulseCommand(
        id: 'service.repair',
        title: 'Repair or install PulseService',
        subtitle: 'Service status: $serviceStateLabel',
        icon: LucideIcons.wrench,
        keywords: const ['service', 'repair', 'install', 'fix', 'missing'],
        onInvoke: () {
          unawaited(runService(service.repairInstall));
        },
      ),
      PulseCommand(
        id: 'shortcuts.show',
        title: 'Keyboard shortcuts',
        subtitle: 'Show every shell shortcut',
        icon: LucideIcons.keyboard,
        keywords: const ['help', 'keys', 'hotkeys', 'shortcuts'],
        onInvoke: () {
          unawaited(showShortcutsDialog(context));
        },
      ),
      PulseCommand(
        id: 'search.focus',
        title: 'Focus search',
        subtitle: 'Open command palette',
        icon: LucideIcons.search,
        keywords: const ['find', 'command'],
        onInvoke: () {
          // Palette already closed; reopen empty for focus.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openCommandPalette();
          });
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Bind the whole shell + active page to Material theme animation frames so
    // PulseTokens.* never lag behind Dark/Light switches.
    final materialTheme = Theme.of(context);
    final pulse = materialTheme.extension<PulseThemeData>();
    if (pulse != null) {
      PulseThemeScope.sync(pulse);
    }
    PulseWindowChrome.syncLater(materialTheme.brightness);

    // Do not watch IPC here — that rebuilt the entire page tree (and every
    // MouseRegion) on each connection tick. Sidebar status is isolated below.
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            () => _openCommandPalette(),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            () => _openCommandPalette(),
        const SingleActivator(LogicalKeyboardKey.digit1, control: true):
            () => _selectPage(PulseShellPages.timeline),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true):
            () => _selectPage(PulseShellPages.health),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true):
            () => _selectPage(PulseShellPages.inventory),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true):
            () => _selectPage(PulseShellPages.reports),
        const SingleActivator(LogicalKeyboardKey.digit5, control: true):
            () => _selectPage(PulseShellPages.diagnostics),
        const SingleActivator(LogicalKeyboardKey.digit6, control: true):
            () => _selectPage(PulseShellPages.settings),
        const SingleActivator(LogicalKeyboardKey.digit7, control: true):
            () => _selectPage(PulseShellPages.assistant),
        const SingleActivator(LogicalKeyboardKey.digit1, meta: true):
            () => _selectPage(PulseShellPages.timeline),
        const SingleActivator(LogicalKeyboardKey.digit2, meta: true):
            () => _selectPage(PulseShellPages.health),
        const SingleActivator(LogicalKeyboardKey.digit3, meta: true):
            () => _selectPage(PulseShellPages.inventory),
        const SingleActivator(LogicalKeyboardKey.digit4, meta: true):
            () => _selectPage(PulseShellPages.reports),
        const SingleActivator(LogicalKeyboardKey.digit5, meta: true):
            () => _selectPage(PulseShellPages.diagnostics),
        const SingleActivator(LogicalKeyboardKey.digit6, meta: true):
            () => _selectPage(PulseShellPages.settings),
        const SingleActivator(LogicalKeyboardKey.digit7, meta: true):
            () => _selectPage(PulseShellPages.assistant),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: PulseTokens.canvas,
          body: AssistantHost(
            child: Column(
              children: [
                PulseTitleBar(
                  onOpenSearch: () => _openCommandPalette(),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          PulseTokens.shellGutter,
                          0,
                          0,
                          PulseTokens.shellGutter,
                        ),
                        child: PulseNavRail(
                          selectedIndex: _index,
                          onSelected: _selectPage,
                          primaryItems: _primaryNav,
                          secondaryItems: _secondaryNav,
                          footer: const _RailServiceStatus(),
                        ),
                      ),
                      Expanded(
                        child: ColoredBox(
                          color: PulseTokens.canvas,
                          child: PulseContentFrame(
                            // Keep every page Element alive. AnimatedSwitcher was
                            // fading through a transparent frame (canvas flash)
                            // and disposing Inventory on every leave.
                            child: IndexedStack(
                              index: _index,
                              sizing: StackFit.expand,
                              children: _pages,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageFor(int index, String title) {
    switch (index) {
      case PulseShellPages.timeline:
        return TimelinePage(title: title);
      case PulseShellPages.health:
        return SystemHealthPage(title: title);
      case PulseShellPages.inventory:
        return InventoryPage(title: title);
      case PulseShellPages.reports:
        return ReportsPage(title: title);
      case PulseShellPages.diagnostics:
        return DiagnosticsPage(title: title);
      case PulseShellPages.settings:
        return SettingsPage(title: title);
      case PulseShellPages.assistant:
        return AssistantPage(title: title);
      default:
        return SettingsPage(title: title);
    }
  }
}

/// Rail footer: a calm status dot for PulseService. Rebuilds only when the
/// connection state or service version changes.
class _RailServiceStatus extends StatelessWidget {
  const _RailServiceStatus();

  static const double _dotSize = 9;
  static const double _hitSize = 44;

  @override
  Widget build(BuildContext context) {
    final state = context.select<PulseIpcClient, IpcConnectionState>(
      (c) => c.status.state,
    );
    final version = context.select<PulseIpcClient, String>(
      (c) => c.status.serviceVersion,
    );
    final status = switch (state) {
      IpcConnectionState.connected => 'PulseService connected',
      IpcConnectionState.connecting => 'Connecting to PulseService',
      IpcConnectionState.error => 'PulseService unavailable',
      IpcConnectionState.disconnected => 'PulseService offline',
    };
    final message = version.isEmpty ? status : '$status · v$version';
    return Tooltip(
      message: message,
      preferBelow: false,
      child: Semantics(
        label: message,
        child: SizedBox(
          width: _hitSize,
          height: _hitSize,
          child: Center(child: ConnectionDot(state: state, size: _dotSize)),
        ),
      ),
    );
  }
}
