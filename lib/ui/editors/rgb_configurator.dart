// SPDX-License-Identifier: GPL-2.0-or-later
import 'package:flutter/material.dart';

import '../../hid/vial_device.dart';
import '../../protocol/keyboard.dart';
import '../dialogs/color_dialog.dart';
import 'basic_editor.dart';

class _Effect {
  const _Effect(this.idx, this.name, this.colorPicker);

  final int idx;
  final String name;
  final bool colorPicker;
}

const List<_Effect> _qmkRgblightEffects = [
  _Effect(0, 'All Off', false),
  _Effect(1, 'Solid Color', true),
  _Effect(2, 'Breathing 1', true),
  _Effect(3, 'Breathing 2', true),
  _Effect(4, 'Breathing 3', true),
  _Effect(5, 'Breathing 4', true),
  _Effect(6, 'Rainbow Mood 1', false),
  _Effect(7, 'Rainbow Mood 2', false),
  _Effect(8, 'Rainbow Mood 3', false),
  _Effect(9, 'Rainbow Swirl 1', false),
  _Effect(10, 'Rainbow Swirl 2', false),
  _Effect(11, 'Rainbow Swirl 3', false),
  _Effect(12, 'Rainbow Swirl 4', false),
  _Effect(13, 'Rainbow Swirl 5', false),
  _Effect(14, 'Rainbow Swirl 6', false),
  _Effect(15, 'Snake 1', true),
  _Effect(16, 'Snake 2', true),
  _Effect(17, 'Snake 3', true),
  _Effect(18, 'Snake 4', true),
  _Effect(19, 'Snake 5', true),
  _Effect(20, 'Snake 6', true),
  _Effect(21, 'Knight 1', true),
  _Effect(22, 'Knight 2', true),
  _Effect(23, 'Knight 3', true),
  _Effect(24, 'Christmas', true),
  _Effect(25, 'Gradient 1', true),
  _Effect(26, 'Gradient 2', true),
  _Effect(27, 'Gradient 3', true),
  _Effect(28, 'Gradient 4', true),
  _Effect(29, 'Gradient 5', true),
  _Effect(30, 'Gradient 6', true),
  _Effect(31, 'Gradient 7', true),
  _Effect(32, 'Gradient 8', true),
  _Effect(33, 'Gradient 9', true),
  _Effect(34, 'Gradient 10', true),
  _Effect(35, 'RGB Test', true),
  _Effect(36, 'Alternating', true),
];

const List<String> _vialrgbEffectNames = [
  'Disable',
  'Direct Control',
  'Solid Color',
  'Alphas Mods',
  'Gradient Up Down',
  'Gradient Left Right',
  'Breathing',
  'Band Sat',
  'Band Val',
  'Band Pinwheel Sat',
  'Band Pinwheel Val',
  'Band Spiral Sat',
  'Band Spiral Val',
  'Cycle All',
  'Cycle Left Right',
  'Cycle Up Down',
  'Rainbow Moving Chevron',
  'Cycle Out In',
  'Cycle Out In Dual',
  'Cycle Pinwheel',
  'Cycle Spiral',
  'Dual Beacon',
  'Rainbow Beacon',
  'Rainbow Pinwheels',
  'Raindrops',
  'Jellybean Raindrops',
  'Hue Breathing',
  'Hue Pendulum',
  'Hue Wave',
  'Typing Heatmap',
  'Digital Rain',
  'Solid Reactive Simple',
  'Solid Reactive',
  'Solid Reactive Wide',
  'Solid Reactive Multiwide',
  'Solid Reactive Cross',
  'Solid Reactive Multicross',
  'Solid Reactive Nexus',
  'Solid Reactive Multinexus',
  'Splash',
  'Multisplash',
  'Solid Splash',
  'Solid Multisplash',
  'Pixel Rain',
  'Pixel Fractal',
];

final List<_Effect> _vialrgbEffects = [
  for (var i = 0; i < _vialrgbEffectNames.length; i++)
    _Effect(i, _vialrgbEffectNames[i], true),
];

class RgbConfigurator extends BasicEditor {
  Keyboard? keyboard;

  @override
  String get label => 'Lighting';

  @override
  bool valid() {
    final d = device;
    if (d is! VialKeyboard || d.keyboard == null) return false;
    final k = d.keyboard!;
    return k.lightingQmkRgblight || k.lightingQmkBacklight || k.lightingVialrgb;
  }

  @override
  Future<void> rebuild(VialDevice? device) async {
    await super.rebuild(device);
    keyboard = valid() ? (device as VialKeyboard).keyboard : null;
    if (keyboard != null) await keyboard!.reloadRgb();
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() body) async {
    await body();
    notifyListeners();
  }

  Widget _sliderRow(
    String label,
    int value,
    int max,
    ValueChanged<int> onChanged,
  ) {
    final safeMax = max <= 0 ? 1 : max;
    return Row(
      children: [
        SizedBox(width: 120, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(0, safeMax).toDouble(),
            max: safeMax.toDouble(),
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(width: 40, child: Text('${value.clamp(0, safeMax)}')),
      ],
    );
  }

  Widget _effectRow(
    String label,
    List<_Effect> effects,
    int current,
    ValueChanged<_Effect> onChanged,
    Widget? colorButton,
  ) {
    final selected = effects.any((e) => e.idx == current) ? current : null;
    return Row(
      children: [
        SizedBox(width: 120, child: Text(label)),
        Expanded(
          child: DropdownButton<int>(
            isExpanded: true,
            value: selected,
            items: [
              for (final e in effects)
                DropdownMenuItem(value: e.idx, child: Text(e.name)),
            ],
            onChanged: (v) {
              if (v == null) return;
              onChanged(effects.firstWhere((e) => e.idx == v));
            },
          ),
        ),
        if (colorButton != null) ...[const SizedBox(width: 8), colorButton],
      ],
    );
  }

  Widget _colorButton(
    BuildContext context,
    HSVColor color,
    Future<void> Function(HSVColor) onPicked,
  ) {
    return InkWell(
      onTap: () async {
        final picked = await showColorDialog(context, color);
        if (picked != null) await _run(() => onPicked(picked));
      },
      child: Container(
        width: 48,
        height: 28,
        decoration: BoxDecoration(
          color: color.toColor(),
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }

  List<Widget> _qmkRgblight(BuildContext context) {
    final k = keyboard!;
    final effect = _qmkRgblightEffects.firstWhere(
      (e) => e.idx == k.underglowEffect,
      orElse: () => _qmkRgblightEffects[0],
    );
    return [
      _sliderRow(
        'Underglow Brightness',
        k.underglowBrightness,
        255,
        (v) => _run(() => k.setQmkRgblightBrightness(v)),
      ),
      _effectRow(
        'Underglow Effect',
        _qmkRgblightEffects,
        k.underglowEffect,
        (e) => _run(() => k.setQmkRgblightEffect(e.idx)),
        effect.colorPicker
            ? _colorButton(
                context,
                HSVColor.fromAHSV(
                  1,
                  k.underglowColor.$1 / 255 * 360,
                  k.underglowColor.$2 / 255,
                  k.underglowBrightness / 255,
                ),
                (c) => k.setQmkRgblightColor(
                  (c.hue / 360 * 255).round().clamp(0, 255),
                  (c.saturation * 255).round(),
                  (c.value * 255).round(),
                ),
              )
            : null,
      ),
      _sliderRow(
        'Underglow Effect Speed',
        k.underglowEffectSpeed,
        3,
        (v) => _run(() => k.setQmkRgblightEffectSpeed(v)),
      ),
    ];
  }

  List<Widget> _qmkBacklight() {
    final k = keyboard!;
    return [
      _sliderRow(
        'Backlight Brightness',
        k.backlightBrightness,
        255,
        (v) => _run(() => k.setQmkBacklightBrightness(v)),
      ),
      Row(
        children: [
          const SizedBox(width: 120, child: Text('Backlight Breathing')),
          Checkbox(
            value: k.backlightEffect == 1,
            onChanged: (v) =>
                _run(() => k.setQmkBacklightEffect(v == true ? 1 : 0)),
          ),
        ],
      ),
    ];
  }

  List<Widget> _vialrgb(BuildContext context) {
    final k = keyboard!;
    final effects = [
      for (final e in _vialrgbEffects)
        if (k.rgbSupportedEffects.contains(e.idx)) e,
    ];
    return [
      _sliderRow(
        'RGB Brightness',
        k.rgbHsv.$3,
        k.rgbMaximumBrightness,
        (v) => _run(() => k.setVialrgbBrightness(v)),
      ),
      _sliderRow(
        'RGB Effect Speed',
        k.rgbSpeed,
        255,
        (v) => _run(() => k.setVialrgbSpeed(v)),
      ),
      _effectRow(
        'RGB Effect',
        effects,
        k.rgbMode,
        (e) => _run(() => k.setVialrgbMode(e.idx)),
        _colorButton(
          context,
          HSVColor.fromAHSV(1, k.rgbHsv.$1 / 255 * 360, k.rgbHsv.$2 / 255, 1),
          (c) => k.setVialrgbColor(
            (c.hue / 360 * 255).round().clamp(0, 255),
            (c.saturation * 255).round(),
            k.rgbHsv.$3,
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final k = keyboard;
    if (k == null) return const SizedBox.shrink();
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (k.lightingQmkRgblight)
                  _section('QMK RGBLIGHT', _qmkRgblight(context)),
                if (k.lightingQmkBacklight)
                  _section('QMK Backlight', _qmkBacklight()),
                if (k.lightingVialrgb) _section('VialRGB', _vialrgb(context)),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton(
                onPressed: () => _run(k.saveRgb),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
