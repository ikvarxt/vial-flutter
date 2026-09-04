import 'package:flutter/material.dart';

const List<String> _modNames = [
  'LCtrl',
  'LShift',
  'LAlt',
  'LGui',
  'RCtrl',
  'RShift',
  'RAlt',
  'RGui',
];

/// Eight modifier checkboxes in two rows, packed into a QMK mod bitmask.
class ModsUI extends StatelessWidget {
  const ModsUI({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var row = 0; row < 2; row++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = row * 4; i < row * 4 + 4; i++)
                _CheckLabel(
                  label: _modNames[i],
                  value: value & (1 << i) != 0,
                  onChanged: (v) =>
                      onChanged(v ? value | (1 << i) : value & ~(1 << i)),
                ),
            ],
          ),
      ],
    );
  }
}

/// Sixteen layer checkboxes plus enable/disable all buttons.
class LayersUI extends StatelessWidget {
  const LayersUI({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var row = 0; row < 2; row++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = row * 8; i < row * 8 + 8; i++)
                _CheckLabel(
                  label: '$i',
                  value: value & (1 << i) != 0,
                  onChanged: (v) =>
                      onChanged(v ? value | (1 << i) : value & ~(1 << i)),
                ),
            ],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              onPressed: () => onChanged(0xFFFF),
              child: const Text('Enable all'),
            ),
            const SizedBox(width: 6),
            OutlinedButton(
              onPressed: () => onChanged(0),
              child: const Text('Disable all'),
            ),
          ],
        ),
      ],
    );
  }
}

class _CheckLabel extends StatelessWidget {
  const _CheckLabel({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            visualDensity: VisualDensity.compact,
          ),
          Text(label),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

/// Labelled checkbox row used by the option lists of several editors.
class CheckRow extends StatelessWidget {
  const CheckRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) =>
      _CheckLabel(label: label, value: value, onChanged: onChanged);
}
