import 'package:flutter/material.dart';

import '../theme.dart';

/// Horizontal, scrollable list of tab titles (QTabWidget header).
class TabStrip extends StatelessWidget {
  const TabStrip({
    super.key,
    required this.labels,
    required this.current,
    required this.onSelected,
    this.enabled = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
  });

  final List<String> labels;
  final int current;
  final ValueChanged<int> onSelected;
  final bool enabled;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            _TabItem(
              label: labels[i],
              selected: i == current,
              enabled: enabled,
              padding: padding,
              onTap: () => onSelected(i),
              palette: p,
            ),
        ],
      ),
    );
  }
}

class _TabItem extends StatefulWidget {
  const _TabItem({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.padding,
    required this.onTap,
    required this.palette,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final EdgeInsets padding;
  final VoidCallback onTap;
  final VialPalette palette;

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final color = !widget.enabled
        ? p.disabledText
        : widget.selected || _hover
        ? p.ink
        : p.muted;
    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Padding(
              padding: widget.padding,
              child: Text(
                widget.label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
            Positioned(
              left: widget.padding.left,
              right: widget.padding.right,
              bottom: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: widget.selected ? p.ink : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
