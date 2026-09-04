import 'package:flutter/material.dart';

import '../constants.dart';
import '../theme.dart';

/// Fixed-size square push button sized relative to the font height, matching
/// the reference `SquareButton`.
class SquareButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final p = context.palette;
    final size = (fontHeight * relSize).roundToDouble();
    final fg = !enabled
        ? p.disabledText
        : linkColor
        ? p.link
        : checked
        ? p.highlightedText
        : p.buttonText;
    final bg = checked ? p.highlight : p.button;
    Widget child = Text(
      text,
      textAlign: TextAlign.center,
      softWrap: wordWrap,
      overflow: TextOverflow.clip,
      maxLines: wordWrap ? 3 : null,
      style: TextStyle(color: fg, fontSize: 11, height: 1.15),
    );
    if (!wordWrap) {
      child = FittedBox(fit: BoxFit.scaleDown, child: child);
    }
    Widget btn = Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: BorderSide(color: p.disabledText.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(3),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Center(child: child),
        ),
      ),
    );
    if (tooltip != null && tooltip!.isNotEmpty) {
      btn = Tooltip(
        message: tooltip!,
        waitDuration: const Duration(milliseconds: 600),
        child: btn,
      );
    }
    return SizedBox(width: width ?? size, height: size, child: btn);
  }
}
