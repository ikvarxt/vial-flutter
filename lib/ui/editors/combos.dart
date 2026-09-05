// SPDX-License-Identifier: GPL-2.0-or-later
import 'package:flutter/material.dart';

import '../../hid/vial_device.dart';
import '../../protocol/constants.dart';
import '../../protocol/dynamic_entries.dart';
import '../../protocol/keyboard.dart';
import '../widgets/key_widget.dart';
import '../widgets/tab_strip.dart';
import 'basic_editor.dart';

class _ComboUi {
  _ComboUi(VoidCallback onKey) {
    for (var i = 0; i < 5; i++) {
      keys.add(KeyWidgetController(onChanged: onKey));
    }
  }

  final List<KeyWidgetController> keys = [];

  ComboEntry get entry => (
    keys[0].keycode,
    keys[1].keycode,
    keys[2].keycode,
    keys[3].keycode,
    keys[4].keycode,
  );

  void load(ComboEntry e) {
    keys[0].setKeycode(e.$1);
    keys[1].setKeycode(e.$2);
    keys[2].setKeycode(e.$3);
    keys[3].setKeycode(e.$4);
    keys[4].setKeycode(e.$5);
  }

  void dispose() {
    for (final k in keys) {
      k.dispose();
    }
  }
}

const List<String> _comboLabels = [
  'Key 1',
  'Key 2',
  'Key 3',
  'Key 4',
  'Output key',
];

class Combos extends BasicEditor {
  Keyboard? keyboard;
  final List<_ComboUi> _entries = [];
  int _current = 0;

  @override
  String get label => 'Combos';

  @override
  bool valid() {
    final d = device;
    return d is VialKeyboard &&
        d.keyboard != null &&
        d.keyboard!.vialProtocol >= vialProtocolDynamic &&
        d.keyboard!.comboCount > 0;
  }

  @override
  Future<void> rebuild(VialDevice? device) async {
    await super.rebuild(device);
    for (final e in _entries) {
      e.dispose();
    }
    _entries.clear();
    keyboard = null;
    if (valid()) {
      keyboard = (device as VialKeyboard).keyboard;
      for (var i = 0; i < keyboard!.comboCount; i++) {
        _entries.add(_ComboUi(_onChange));
      }
      _current = 0;
      _reload();
    }
    notifyListeners();
  }

  void _reload() {
    final k = keyboard!;
    for (var i = 0; i < _entries.length; i++) {
      _entries[i].load(k.comboEntries[i]);
    }
    notifyListeners();
  }

  Future<void> _onChange() async {
    final k = keyboard;
    if (k == null) return;
    for (var i = 0; i < _entries.length; i++) {
      await k.comboSet(i, _entries[i].entry);
    }
    notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    if (_entries.isEmpty) return const SizedBox.shrink();
    final e = _entries[_current];
    return Column(
      children: [
        TabStrip(
          labels: [for (var i = 0; i < _entries.length; i++) '${i + 1}'],
          current: _current,
          onSelected: (i) {
            _current = i;
            notifyListeners();
          },
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < 5; i++)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_comboLabels[i]),
                        const SizedBox(height: 4),
                        KeyWidget(controller: e.keys[i]),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
