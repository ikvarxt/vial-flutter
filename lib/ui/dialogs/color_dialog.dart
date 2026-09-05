// SPDX-License-Identifier: GPL-2.0-or-later
import 'package:flutter/material.dart';

/// Minimal HSV colour picker replacing `QColorDialog`; returns null on cancel.
Future<HSVColor?> showColorDialog(BuildContext context, HSVColor initial) {
  return showDialog<HSVColor>(
    context: context,
    builder: (_) => _ColorDialog(initial: initial),
  );
}

class _ColorDialog extends StatefulWidget {
  const _ColorDialog({required this.initial});

  final HSVColor initial;

  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  late HSVColor _color = widget.initial;

  Widget _slider(
    String label,
    double value,
    double max,
    Gradient gradient,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(width: 28, child: Text(label)),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              Slider(
                value: value,
                max: max,
                onChanged: onChanged,
                activeColor: Colors.transparent,
                inactiveColor: Colors.transparent,
              ),
            ],
          ),
        ),
        SizedBox(width: 36, child: Text(value.round().toString())),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hueStops = [
      for (var i = 0; i <= 6; i++)
        HSVColor.fromAHSV(1, i * 60.0, 1, 1).toColor(),
    ];
    final c = _color;
    return AlertDialog(
      title: const Text('Select Color'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: c.toColor(),
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            _slider(
              'H',
              c.hue,
              360,
              LinearGradient(colors: hueStops),
              (v) => setState(() => _color = c.withHue(v)),
            ),
            _slider(
              'S',
              c.saturation * 255,
              255,
              LinearGradient(
                colors: [
                  c.withSaturation(0).toColor(),
                  c.withSaturation(1).toColor(),
                ],
              ),
              (v) => setState(() => _color = c.withSaturation(v / 255)),
            ),
            _slider(
              'V',
              c.value * 255,
              255,
              LinearGradient(
                colors: [c.withValue(0).toColor(), c.withValue(1).toColor()],
              ),
              (v) => setState(() => _color = c.withValue(v / 255)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_color),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
