import 'package:flutter/material.dart';

import '../../hid/vial_device.dart';
import '../../protocol/constants.dart';
import '../../protocol/dynamic_entries.dart';
import '../../protocol/keyboard.dart';
import '../widgets/key_widget.dart';
import '../widgets/spin_box.dart';
import '../widgets/tab_strip.dart';
import 'basic_editor.dart';
import '../theme.dart';

class _TapDanceUi {
  _TapDanceUi(VoidCallback onKey) {
    for (var i = 0; i < 4; i++) {
      keys.add(KeyWidgetController(onChanged: onKey));
    }
  }

  final List<KeyWidgetController> keys = [];
  int tappingTerm = 0;

  TapDanceEntry get entry => (
    keys[0].keycode,
    keys[1].keycode,
    keys[2].keycode,
    keys[3].keycode,
    tappingTerm,
  );

  void load(TapDanceEntry e) {
    keys[0].setKeycode(e.$1);
    keys[1].setKeycode(e.$2);
    keys[2].setKeycode(e.$3);
    keys[3].setKeycode(e.$4);
    tappingTerm = e.$5;
  }

  void dispose() {
    for (final k in keys) {
      k.dispose();
    }
  }
}

const List<String> _tapDanceLabels = [
  'On tap',
  'On hold',
  'On double tap',
  'On tap + hold',
];

class TapDance extends BasicEditor {
  Keyboard? keyboard;
  final List<_TapDanceUi> _entries = [];
  int _current = 0;

  @override
  String get label => 'Tap Dance';

  @override
  bool valid() {
    final d = device;
    return d is VialKeyboard &&
        d.keyboard != null &&
        d.keyboard!.vialProtocol >= vialProtocolDynamic &&
        d.keyboard!.tapDanceCount > 0;
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
      for (var i = 0; i < keyboard!.tapDanceCount; i++) {
        _entries.add(_TapDanceUi(_onKeyChanged));
      }
      _current = 0;
      _reload();
    }
    notifyListeners();
  }

  void _reload() {
    final k = keyboard!;
    for (var i = 0; i < _entries.length; i++) {
      _entries[i].load(k.tapDanceEntries[i]);
    }
    notifyListeners();
  }

  bool _isModified(int i) => _entries[i].entry != keyboard!.tapDanceEntries[i];

  bool get _anyModified {
    for (var i = 0; i < _entries.length; i++) {
      if (_isModified(i)) return true;
    }
    return false;
  }

  void _onKeyChanged() => _onSave();

  Future<void> _onSave() async {
    final k = keyboard;
    if (k == null) return;
    for (var i = 0; i < _entries.length; i++) {
      await k.tapDanceSet(i, _entries[i].entry);
    }
    notifyListeners();
  }

  Future<void> _onRevert() async {
    final k = keyboard;
    if (k == null) return;
    await k.reloadDynamic();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_entries.isEmpty) return const SizedBox.shrink();
    final e = _entries[_current];
    return Column(
      children: [
        TabStrip(
          labels: [
            for (var i = 0; i < _entries.length; i++)
              '$i${_isModified(i) ? '*' : ''}',
          ],
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      for (var i = 0; i < 4; i++)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_tapDanceLabels[i]),
                            const SizedBox(height: 4),
                            KeyWidget(controller: e.keys[i]),
                          ],
                        ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Tapping term (ms)'),
                          const SizedBox(height: 4),
                          SpinBox(
                            value: e.tappingTerm,
                            min: 0,
                            max: 10000,
                            onChanged: (v) {
                              e.tappingTerm = v;
                              notifyListeners();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Use '),
                        TextSpan(
                          text: 'TD($_current)',
                          style: const TextStyle(fontFamily: monoFontFamily),
                        ),
                        const TextSpan(
                          text: ' to set up this action in the keymap.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton(
                onPressed: _anyModified ? _onSave : null,
                child: const Text('Save'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _onRevert, child: const Text('Revert')),
            ],
          ),
        ),
      ],
    );
  }
}
