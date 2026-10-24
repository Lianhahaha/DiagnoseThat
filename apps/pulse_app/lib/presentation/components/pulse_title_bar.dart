import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/theme/pulse_theme.dart';
import 'safe_hover.dart';

/// Native-feeling custom title bar that blends into Pulse chrome.
class PulseTitleBar extends StatefulWidget {
  const PulseTitleBar({
    super.key,
    this.onOpenSearch,
  });

  /// Opens the global command palette (title-bar search affordance).
  final VoidCallback? onOpenSearch;

  @override
  State<PulseTitleBar> createState() => _PulseTitleBarState();
}

class _PulseTitleBarState extends State<PulseTitleBar> with WindowListener {
  bool _maximized = false;
  bool _focused = true;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _refresh();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _refresh() async {
    final maximized = await windowManager.isMaximized();
    final focused = await windowManager.isFocused();
    if (!mounted) return;
    if (_maximized == maximized && _focused == focused) return;
    setState(() {
      _maximized = maximized;
      _focused = focused;
    });
  }

  @override
  void onWindowMaximize() => _refresh();

  @override
  void onWindowUnmaximize() => _refresh();

  @override
  void onWindowRestore() => _refresh();

  @override
  void onWindowFocus() => _refresh();

  @override
  void onWindowBlur() => _refresh();

  static const double _height = 44;
  static const double _searchMaxWidth = 460;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final fg = _focused ? PulseTokens.textPrimary : PulseTokens.textTertiary;

    return DragToMoveArea(
      child: Container(
        height: _height,
        color: PulseTokens.canvas,
        padding: const EdgeInsets.only(left: PulseTokens.shellGutter + 8),
        child: Row(
          children: [
            Text(
              'Pulse',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: _focused
                        ? PulseTokens.textSecondary
                        : PulseTokens.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Center(
                child: widget.onOpenSearch == null
                    ? const SizedBox.shrink()
                    : ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxWidth: _searchMaxWidth),
                        child: _TitleSearchButton(
                          onPressed: widget.onOpenSearch!,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            _CaptionButton(
              tooltip: 'Minimize',
              onPressed: windowManager.minimize,
              icon: Icons.remove,
              color: fg,
            ),
            _CaptionButton(
              tooltip: _maximized ? 'Restore' : 'Maximize',
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              icon: _maximized ? Icons.filter_none : Icons.crop_square,
              iconSize: _maximized ? 13 : 14,
              color: fg,
            ),
            _CaptionButton(
              tooltip: 'Close',
              isClose: true,
              onPressed: windowManager.close,
              icon: Icons.close,
              color: fg,
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleSearchButton extends StatefulWidget {
  const _TitleSearchButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_TitleSearchButton> createState() => _TitleSearchButtonState();
}

class _TitleSearchButtonState extends State<_TitleSearchButton>
    with SafeHoverState {
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Search commands (Ctrl+K)',
      waitDuration: const Duration(milliseconds: 500),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: MouseRegion(
          onEnter: (_) => setHovered(true),
          onExit: (_) => setHovered(false),
          child: AnimatedContainer(
            duration: PulseTokens.motionFast,
            height: 32,
            padding: const EdgeInsets.only(left: 14, right: 6),
            decoration: BoxDecoration(
              color: hover ? PulseTokens.surfaceHover : PulseTokens.surface,
              borderRadius: BorderRadius.circular(PulseTokens.radiusPill),
              border: Border.all(color: PulseTokens.stroke),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.search,
                  size: 14,
                  color: PulseTokens.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Search or jump to…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: PulseTokens.textTertiary,
                          fontWeight: FontWeight.w400,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(PulseTokens.radiusSm),
                    border: Border.all(color: PulseTokens.strokeStrong),
                  ),
                  child: Text(
                    'Ctrl K',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontFamily: PulseTheme.monoFont,
                          fontFamilyFallback: PulseTheme.monoFallback,
                          color: PulseTokens.textSecondary,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                          fontSize: 10.5,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    required this.color,
    this.iconSize = 16,
    this.isClose = false,
  });

  final IconData icon;
  final Future<void> Function() onPressed;
  final String tooltip;
  final Color color;
  final double iconSize;
  final bool isClose;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> with SafeHoverState {
  @override
  Widget build(BuildContext context) {
    final bg = !hover
        ? Colors.transparent
        : widget.isClose
            ? const Color(0xFFE81123)
            : PulseTokens.surfaceHover.withValues(alpha: 0.7);
    final iconColor =
        widget.isClose && hover ? Colors.white : widget.color;

    // Avoid Tooltip + MouseRegion nesting — Tooltip already tracks the pointer.
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onPressed(),
        child: MouseRegion(
          onEnter: (_) => setHovered(true),
          onExit: (_) => setHovered(false),
          child: AnimatedContainer(
            duration: PulseTokens.motionFast,
            width: 46,
            height: 44,
            color: bg,
            alignment: Alignment.center,
            child: Icon(widget.icon, size: widget.iconSize, color: iconColor),
          ),
        ),
      ),
    );
  }
}
