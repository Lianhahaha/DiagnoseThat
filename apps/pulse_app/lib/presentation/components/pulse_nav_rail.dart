import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme/pulse_theme.dart';
import 'safe_hover.dart';

/// One destination in the Midnight icon rail.
class PulseNavItem {
  const PulseNavItem({
    required this.label,
    required this.icon,
    required this.pageIndex,
    this.tooltip,
  });

  /// Short label shown under the icon (keep to one word).
  final String label;
  final IconData icon;

  /// Shell page index this item opens.
  final int pageIndex;

  /// Longer description for the hover tooltip (defaults to [label]).
  final String? tooltip;
}

/// Midnight icon rail (ADR-012 D6): a 76 px floating panel with the Pulse
/// mark on top, primary destinations, then secondary destinations and an
/// optional status footer pinned to the bottom.
class PulseNavRail extends StatelessWidget {
  const PulseNavRail({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.primaryItems,
    this.secondaryItems = const [],
    this.footer,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<PulseNavItem> primaryItems;
  final List<PulseNavItem> secondaryItems;
  final Widget? footer;

  static const double _markTileSize = 44;
  static const double _markSize = 26;

  Widget _tile(PulseNavItem item) => _RailTile(
    item: item,
    selected: item.pageIndex == selectedIndex,
    onTap: () => onSelected(item.pageIndex),
  );

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Container(
      width: PulseTokens.railWidth,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: PulseTokens.sidebarSolid,
        borderRadius: BorderRadius.circular(PulseTokens.radiusCard),
        border: Border.all(color: PulseTokens.stroke),
      ),
      child: Column(
        children: [
          Semantics(
            label: 'Pulse',
            image: true,
            child: Container(
              width: _markTileSize,
              height: _markTileSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PulseTokens.accent,
                borderRadius: BorderRadius.circular(PulseTokens.radiusLg),
              ),
              child: SvgPicture.asset(
                'assets/branding/mark.svg',
                width: _markSize,
                height: _markSize,
                colorFilter: ColorFilter.mode(
                  PulseTokens.onAccent,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final item in primaryItems) _tile(item),
          const Spacer(),
          for (final item in secondaryItems) _tile(item),
          if (footer != null) ...[const SizedBox(height: 10), footer!],
        ],
      ),
    );
  }
}

class _RailTile extends StatefulWidget {
  const _RailTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final PulseNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_RailTile> createState() => _RailTileState();
}

class _RailTileState extends State<_RailTile> with SafeHoverState {
  static const double _tileWidth = 60;
  static const double _labelSize = 11;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final background = selected
        ? PulseTokens.surfaceHover
        : hover
        ? PulseTokens.surfaceHover.withValues(alpha: 0.6)
        : Colors.transparent;
    final foreground = selected
        ? PulseTokens.textPrimary
        : PulseTokens.textSecondary;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Tooltip(
        message: widget.item.tooltip ?? widget.item.label,
        waitDuration: const Duration(milliseconds: 600),
        preferBelow: false,
        child: Semantics(
          button: true,
          selected: selected,
          label: widget.item.tooltip ?? widget.item.label,
          excludeSemantics: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onHover: setHovered,
              borderRadius: BorderRadius.circular(PulseTokens.radiusLg),
              mouseCursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: reduceMotion ? Duration.zero : PulseTokens.motionFast,
                curve: PulseTokens.motionCurve,
                width: _tileWidth,
                padding: const EdgeInsets.fromLTRB(0, 9, 0, 7),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(PulseTokens.radiusLg),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.item.icon,
                      size: PulseTokens.iconNav,
                      color: selected ? PulseTokens.accent : foreground,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.item.label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: _labelSize,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w500,
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
