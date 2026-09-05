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

class _KeyOverrideUi {
  _KeyOverrideUi(VoidCallback onKey)
    : trigger = KeyWidgetController(onChanged: onKey),
      replacement = KeyWidgetController(onChanged: onKey);

  final KeyWidgetController trigger;
  final KeyWidgetController replacement;
  int layers = 0;
  int triggerMods = 0;
  int negativeModMask = 0;
  int suppressedMods = 0;
  List<bool> options = List.filled(6, false);
  bool enabled = false;

  KeyOverrideEntry get entry {
    var opt = 0;
    for (var i = 0; i < 6; i++) {
      if (options[i]) opt |= 1 << i;
    }
    if (enabled) opt |= 1 << 7;
    return KeyOverrideEntry(
      trigger: trigger.keycode,
      replacement: replacement.keycode,
      layers: layers,
      triggerMods: triggerMods,
      negativeModMask: negativeModMask,
      suppressedMods: suppressedMods,
      options: opt,
    );
  }

  void load(KeyOverrideEntry e) {
    trigger.setKeycode(e.trigger);
    replacement.setKeycode(e.replacement);
    layers = e.layers;
    triggerMods = e.triggerMods;
    negativeModMask = e.negativeModMask;
    suppressedMods = e.suppressedMods;
    final o = e.options;
    options = [
      o.activationTriggerDown,
      o.activationRequiredModDown,
      o.activationNegativeModUp,
      o.oneMod,
      o.noReregisterTrigger,
      o.noUnregisterOnOtherKeyDown,
    ];
    enabled = o.enabled;
  }

  void dispose() {
    trigger.dispose();
    replacement.dispose();
  }
}

const List<String> _optionLabels = [
  'Activate when the trigger key is pressed down',
  'Activate when a necessary modifier is pressed down',
  'Activate when a negative modifier is released',
  'Activate on one modifier',
  "Don't deactivate when another key is pressed down",
  "Don't register the trigger key again after the override is deactivated",
];

class KeyOverride extends BasicEditor {
  Keyboard? keyboard;
  final List<_KeyOverrideUi> _entries = [];
  int _current = 0;

  @override
  String get label => 'Key Overrides';

  @override
  bool valid() {
    final d = device;
    return d is VialKeyboard &&
        d.keyboard != null &&
        d.keyboard!.vialProtocol >= vialProtocolKeyOverride &&
        d.keyboard!.keyOverrideCount > 0;
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
      for (var i = 0; i < keyboard!.keyOverrideCount; i++) {
        _entries.add(_KeyOverrideUi(_onChange));
      }
      _current = 0;
      _reload();
    }
    notifyListeners();
  }

  void _reload() {
    final k = keyboard!;
    for (var i = 0; i < _entries.length; i++) {
      _entries[i].load(k.keyOverrideEntries[i]);
    }
    notifyListeners();
  }

  Future<void> _onChange() async {
    final k = keyboard;
    if (k == null) return;
    for (var i = 0; i < _entries.length; i++) {
      await k.keyOverrideSet(i, _entries[i].entry);
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
                _row(
                  'Enable on layers',
                  LayersUI(
                    value: e.layers,
                    onChanged: (v) {
                      e.layers = v;
                      _onChange();
                    },
                  ),
                ),
                _row('Trigger', KeyWidget(controller: e.trigger)),
                _row(
                  'Trigger mods',
                  ModsUI(
                    value: e.triggerMods,
                    onChanged: (v) {
                      e.triggerMods = v;
                      _onChange();
                    },
                  ),
                ),
                _row(
                  'Negative mods',
                  ModsUI(
                    value: e.negativeModMask,
                    onChanged: (v) {
                      e.negativeModMask = v;
                      _onChange();
                    },
                  ),
                ),
                _row(
                  'Suppressed mods',
                  ModsUI(
                    value: e.suppressedMods,
                    onChanged: (v) {
                      e.suppressedMods = v;
                      _onChange();
                    },
                  ),
                ),
                _row('Replacement', KeyWidget(controller: e.replacement)),
                _row(
                  'Options',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < 6; i++)
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
