import 'package:flutter/material.dart';

import '../constants.dart';
import '../theme.dart';

/// Fixed-size button drawn as a miniature keycap, sized relative to the font
/// height like the reference `SquareButton`.
class SquareButton extends StatefulWidget {
  const SquareButton({
    super.key,
    required this.text,
    this.onPressed,
    this.relSize = 1.2,
    this.tooltip,
    this.wordWrap = false,
    this.checked = false,
    this.enabled = true,
    this.linkColor = false,
    this.width,
  });

  final String text;
  final VoidCallback? onPressed;
  final double relSize;
  final String? tooltip;
  final bool wordWrap;
  final bool checked;
  final bool enabled;

  /// Draw the label in the palette's Link color (keymap override marker).
  final bool linkColor;

  /// Overrides the width while keeping the height square-derived.
  final double? width;

  @override
  State<SquareButton> createState() => _SquareButtonState();
}

class _SquareButtonState extends State<SquareButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final size = (fontHeight * widget.relSize).roundToDouble();
    final interactive = widget.enabled && widget.onPressed != null;
    // A checked, non-interactive button is the current layer: keep it in the
    // accent even though it cannot be pressed.
    final dimmed = !widget.enabled && !widget.checked;
    final fg = dimmed
        ? p.disabledText
        : widget.checked
        ? p.onAccent
        : widget.linkColor
        ? p.link
        : p.keyLegend;
    final Color top;
    final Color side;
    if (widget.checked) {
      top = p.accent;
      side = Color.lerp(p.accent, Colors.black, 0.28)!;
    } else {
      top = _hover && interactive
          ? Color.lerp(p.keyTop, p.ink, 0.05)!
          : p.keyTop;
      side = p.keySide;
    }
    const lip = 2.0;
    final pressed = _down && interactive;
    final radius = BorderRadius.circular(VialRadius.keycap);

    Widget label = Text(
      widget.text,
      textAlign: TextAlign.center,
      softWrap: widget.wordWrap,
      overflow: TextOverflow.clip,
      maxLines: widget.wordWrap ? 3 : null,
      style: TextStyle(
        color: fg,
        fontSize: 11,
        height: 1.15,
        fontWeight: FontWeight.w500,
      ),
    );
    if (!widget.wordWrap) {
      label = FittedBox(fit: BoxFit.scaleDown, child: label);
    }

    Widget cap = DecoratedBox(
      decoration: BoxDecoration(
        color: side,
        borderRadius: radius,
        boxShadow: dimmed || pressed
            ? null
            : [
                BoxShadow(
                  color: p.keyShadow,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Padding(
        // Pressing sinks the top face into the side wall.
        padding: EdgeInsets.only(
          top: pressed ? lip - 1 : 0,
          bottom: pressed ? 1 : lip,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: dimmed ? Color.lerp(top, p.canvas, 0.5) : top,
            borderRadius: radius,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Center(child: label),
          ),
        ),
      ),
    );

    cap = MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: interactive ? (_) => setState(() => _down = true) : null,
        onTapUp: interactive ? (_) => setState(() => _down = false) : null,
        onTapCancel: interactive ? () => setState(() => _down = false) : null,
        onTap: interactive ? widget.onPressed : null,
        child: cap,
      ),
    );
    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      cap = Tooltip(message: widget.tooltip!, child: cap);
    }
    return SizedBox(width: widget.width ?? size, height: size, child: cap);
  }
}
