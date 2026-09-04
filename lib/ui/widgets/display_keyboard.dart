import 'dart:convert';

import 'package:flutter/material.dart';

import '../../keycodes/keycode.dart';
import '../../kle/kle_serial.dart';
import '../constants.dart';
import '../keycode_display.dart';
import 'square_button.dart';

/// Grid pitch of one keyboard unit inside a [DisplayKeyboard].
const double displayKeyboardUnit = fontHeight * keycodeBtnRatio + 4;

class _DisplayKey {
  _DisplayKey(this.key, this.keycode);
  final KleKey key;
  final Keycode keycode;
}

/// Static keyboard picture made of keycode buttons (used by the Basic/ISO/
/// Quantum picker tabs).
class DisplayKeyboard extends StatelessWidget {
  DisplayKeyboard({super.key, required String kbdef, required this.onKeycode})
    : _keys = _parse(kbdef);

  final void Function(String qmkId) onKeycode;
  final List<_DisplayKey> _keys;

  static final Map<String, List<_DisplayKey>> _cache = {};

  static List<_DisplayKey> _parse(String kbdef) =>
      _cache.putIfAbsent(kbdef, () {
        final keymap = KleSerial().deserialize(jsonDecode(kbdef) as List);
        final out = <_DisplayKey>[];
        for (final key in keymap.keys) {
          final kc = Keycode.findByQmkId(key.labels[0] ?? '');
          if (kc != null) out.add(_DisplayKey(key, kc));
        }
        return out;
      });

  static double requiredWidth(String kbdef) {
    var w = 0.0;
    for (final k in _parse(kbdef)) {
      final r = (k.key.x + k.key.width) * displayKeyboardUnit;
      if (r > w) w = r;
    }
    return w;
  }

  @override
  Widget build(BuildContext context) {
    var w = 0.0, h = 0.0;
    for (final k in _keys) {
      final r = (k.key.x + k.key.width) * displayKeyboardUnit;
      final b = (k.key.y + k.key.height) * displayKeyboardUnit;
      if (r > w) w = r;
      if (b > h) h = b;
    }
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          for (final k in _keys)
            Positioned(
              left: k.key.x * displayKeyboardUnit,
              top: k.key.y * displayKeyboardUnit,
              width: k.key.width * displayKeyboardUnit - 4,
              height: k.key.height * displayKeyboardUnit - 4,
              child: Builder(
                builder: (context) {
                  final (label, link) = KeycodeDisplay.buttonLabel(k.keycode);
                  return SquareButton(
                    text: label,
                    relSize: keycodeBtnRatio,
                    width: k.key.width * displayKeyboardUnit - 4,
                    tooltip: Keycode.tooltipOf(k.keycode.qmkId),
                    linkColor: link,
                    onPressed: () => onKeycode(k.keycode.qmkId),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
