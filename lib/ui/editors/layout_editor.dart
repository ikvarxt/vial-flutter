// SPDX-License-Identifier: GPL-2.0-or-later
import 'package:flutter/material.dart';

import '../../hid/vial_device.dart';
import '../../protocol/keyboard.dart';
import '../widgets/keyboard_widget.dart';
import 'basic_editor.dart';

abstract class _Choice {
  _Choice(this.label);

  final String label;

  int get width;
  int get value;
  String pack();
  void unpack(String bits);
}

class _BooleanChoice extends _Choice {
  _BooleanChoice(super.label);

  bool checked = false;

  @override
  int get width => 1;

  @override
  int get value => checked ? 1 : 0;

  @override
  String pack() => checked ? '1' : '0';

  @override
  void unpack(String bits) => checked = bits == '1';
}

class _SelectChoice extends _Choice {
  _SelectChoice(super.label, this.options);

  final List<String> options;
  int index = 0;

  @override
  int get width => (options.length - 1).bitLength;

  @override
  int get value => index;

  @override
  String pack() => index.toRadixString(2).padLeft(width, '0');

  @override
  void unpack(String bits) {
    final v = int.tryParse(bits, radix: 2) ?? 0;
    index = v.clamp(0, options.length - 1);
  }
}

/// Layout options tab: one checkbox / dropdown per entry of the keyboard's
/// `layouts.labels`, packed bitwise into `layout_options`.
class LayoutEditor extends BasicEditor {
  LayoutEditor() {
    preview.enabled = false;
    preview.scale = 0.7;
    preview.layoutChoice = getChoice;
  }

  final KeyboardWidgetController preview = KeyboardWidgetController();
  final List<_Choice> _choices = [];
  Keyboard? keyboard;

  /// Fired after the user changed an option.
  VoidCallback? onChanged;

  @override
  String get label => 'Layout';

  @override
  bool valid() {
    final d = device;
    return d is VialKeyboard && (d.keyboard?.layoutLabels?.isNotEmpty ?? false);
  }

  @override
  Future<void> rebuild(VialDevice? device) async {
    await super.rebuild(device);
    _choices.clear();
    keyboard = null;
    if (valid()) {
      final kb = (device as VialKeyboard).keyboard!;
      keyboard = kb;
      for (final item in kb.layoutLabels!) {
        if (item is String) {
          _choices.add(_BooleanChoice(item));
        } else if (item is List) {
          final l = item.cast<String>();
          _choices.add(_SelectChoice(l[0], l.sublist(1)));
        }
      }
      unpack(kb.layoutOptions);
      preview.setKeys(kb.keys, kb.encoders);
    }
    notifyListeners();
  }

  int pack() {
    final bits = _choices.map((c) => c.pack()).join();
    if (bits.isEmpty) return 0;
    return int.parse(bits, radix: 2);
  }

  void unpack(int value) {
    var bits = '0' * 100 + (value < 0 ? 0 : value).toRadixString(2);
    for (final choice in _choices.reversed) {
      final sz = choice.width;
      choice.unpack(bits.substring(bits.length - sz));
      bits = bits.substring(0, bits.length - sz);
    }
  }

  int getChoice(int index) =>
      index >= 0 && index < _choices.length ? _choices[index].value : 0;

  void _changed() {
    preview.updateLayout();
    onChanged?.call();
    notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Center(child: KeyboardWidget(controller: preview)),
          const SizedBox(height: 12),
          for (final c in _choices) _buildChoice(c),
        ],
      ),
    );
  }

  Widget _buildChoice(_Choice c) {
    final Widget control;
    if (c is _BooleanChoice) {
      control = Checkbox(
        value: c.checked,
        onChanged: (v) {
          c.checked = v ?? false;
          _changed();
        },
      );
    } else {
      final s = c as _SelectChoice;
      control = DropdownButton<int>(
        value: s.index,
        items: [
          for (var i = 0; i < s.options.length; i++)
            DropdownMenuItem(value: i, child: Text(s.options[i])),
        ],
        onChanged: (v) {
          if (v == null) return;
          s.index = v;
          _changed();
        },
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(c.label)),
          control,
        ],
      ),
    );
  }
}
