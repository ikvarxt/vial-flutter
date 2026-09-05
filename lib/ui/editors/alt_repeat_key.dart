// SPDX-License-Identifier: GPL-2.0-or-later
import 'package:flutter/material.dart';

import '../../hid/vial_device.dart';
import '../../protocol/constants.dart';
import '../../protocol/dynamic_entries.dart';
import '../../protocol/keyboard.dart';
import '../widgets/key_widget.dart';
import '../widgets/mods_ui.dart';
import '../widgets/tab_strip.dart';
import 'basic_editor.dart';

class _AltRepeatKeyUi {
  _AltRepeatKeyUi(VoidCallback onKey)
    : lastKey = KeyWidgetController(onChanged: onKey),
      altKey = KeyWidgetController(onChanged: onKey);

  final KeyWidgetController lastKey;
  final KeyWidgetController altKey;
  int allowedMods = 0;
  List<bool> options = List.filled(3, false);
  bool enabled = false;

  AltRepeatKeyEntry get entry {
    var opt = 0;
    for (var i = 0; i < 3; i++) {
      if (options[i]) opt |= 1 << i;
    }
    if (enabled) opt |= 1 << 3;
    return AltRepeatKeyEntry(
      keycode: lastKey.keycode,
      altKeycode: altKey.keycode,
      allowedMods: allowedMods,
      options: opt,
    );
  }

  void load(AltRepeatKeyEntry e) {
    lastKey.setKeycode(e.keycode);
    altKey.setKeycode(e.altKeycode);
    allowedMods = e.allowedMods;
    options = [
      e.options.defaultToThisAltKey,
      e.options.bidirectional,
      e.options.ignoreModHandedness,
    ];
    enabled = e.options.enabled;
  }

  void dispose() {
    lastKey.dispose();
    altKey.dispose();
  }
}

const List<String> _optionLabels = [
  'Default to this alt key',
  'Bidirectional',
  'Ignore mod handedness',
];

class AltRepeatKey extends BasicEditor {
  Keyboard? keyboard;
  final List<_AltRepeatKeyUi> _entries = [];
  int _current = 0;

  @override
  String get label => 'Alt Repeat Key';

  @override
  bool valid() {
    final d = device;
    return d is VialKeyboard &&
        d.keyboard != null &&
        d.keyboard!.vialProtocol >= vialProtocolDynamic &&
        d.keyboard!.altRepeatKeyCount > 0;
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
      for (var i = 0; i < keyboard!.altRepeatKeyCount; i++) {
        _entries.add(_AltRepeatKeyUi(_onChange));
      }
      _current = 0;
      _reload();
    }
    notifyListeners();
  }

  void _reload() {
    final k = keyboard!;
    for (var i = 0; i < _entries.length; i++) {
      _entries[i].load(k.altRepeatKeyEntries[i]);
    }
    notifyListeners();
  }

  Future<void> _onChange() async {
    final k = keyboard;
    if (k == null) return;
    for (var i = 0; i < _entries.length; i++) {
      await k.altRepeatKeySet(i, _entries[i].entry);
    }
    notifyListeners();
  }

  Widget _row(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(label),
            ),
          ),
          child,
        ],
      ),
    );
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row(
                  'Enable',
                  Checkbox(
                    value: e.enabled,
                    onChanged: (v) {
                      e.enabled = v ?? false;
                      _onChange();
                    },
                  ),
                ),
                _row('Last key', KeyWidget(controller: e.lastKey)),
                _row('Alt key', KeyWidget(controller: e.altKey)),
                _row(
                  'Allowed mods',
                  ModsUI(
                    value: e.allowedMods,
                    onChanged: (v) {
                      e.allowedMods = v;
                      _onChange();
                    },
                  ),
                ),
                _row(
                  'Options',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < 3; i++)
                        CheckRow(
                          label: _optionLabels[i],
                          value: e.options[i],
                          onChanged: (v) {
                            e.options[i] = v;
                            _onChange();
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
