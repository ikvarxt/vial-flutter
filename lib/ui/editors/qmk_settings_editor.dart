import 'package:flutter/material.dart';

import '../../hid/vial_device.dart';
import '../../protocol/constants.dart';
import '../../protocol/keyboard.dart';
import '../../settings/qmk_settings.dart';
import '../app_globals.dart';
import '../widgets/mods_ui.dart';
import '../widgets/spin_box.dart';
import '../widgets/tab_strip.dart';
import 'basic_editor.dart';

class _Option {
  _Option(this.field);

  final QmkSettingField field;
  int value = 0;

  void reload(int raw) {
    if (field.type == 'boolean') {
      value = raw & (1 << field.bit);
    } else {
      value = raw;
    }
  }
}

class _SettingsTab {
  _SettingsTab(this.name, this.options);

  final String name;
  final List<_Option> options;

  Map<int, int> get qsidValues {
    final out = <int, int>{};
    for (final o in options) {
      out[o.field.qsid] = (out[o.field.qsid] ?? 0) | o.value;
    }
    return out;
  }

  void reload(Map<int, int> settings) {
    for (final o in options) {
      o.reload(settings[o.field.qsid] ?? 0);
    }
  }
}

class QmkSettingsEditor extends BasicEditor {
  Keyboard? keyboard;
  final List<_SettingsTab> _tabs = [];
  int _current = 0;

  @override
  String get label => 'QMK Settings';

  @override
  bool valid() {
    final d = device;
    return d is VialKeyboard &&
        d.keyboard != null &&
        d.keyboard!.vialProtocol >= vialProtocolQmkSettings &&
        d.keyboard!.supportedSettings.isNotEmpty;
  }

  @override
  Future<void> rebuild(VialDevice? device) async {
    await super.rebuild(device);
    _tabs.clear();
    keyboard = null;
    if (valid()) {
      keyboard = (device as VialKeyboard).keyboard;
      _recreate();
      _current = 0;
    }
    notifyListeners();
  }

  void _recreate() {
    _tabs.clear();
    final supported = keyboard!.supportedSettings;
    for (final tab in QmkSettings.tabs) {
      final options = [
        for (final f in tab.fields)
          if (supported.contains(f.qsid)) _Option(f),
      ];
      if (options.isNotEmpty) _tabs.add(_SettingsTab(tab.name, options));
    }
    for (final t in _tabs) {
      t.reload(keyboard!.settings);
    }
  }

  bool _isModified(_SettingsTab tab) {
    final values = tab.qsidValues;
    for (final e in values.entries) {
      if (keyboard!.settings[e.key] != e.value) return true;
    }
    return false;
  }

  bool get _anyModified => _tabs.any(_isModified);

  Future<void> _onSave() async {
    final k = keyboard;
    if (k == null) return;
    for (final t in _tabs) {
      for (final e in t.qsidValues.entries) {
        if (k.settings[e.key] != e.value) {
          await k.qmkSettingsSet(e.key, e.value);
        }
      }
    }
    notifyListeners();
  }

  Future<void> _reloadSettings() async {
    final k = keyboard;
    if (k == null) return;
    await k.reloadSettings();
    _recreate();
    if (_current >= _tabs.length) _current = 0;
    notifyListeners();
  }

  Future<void> _onReset() async {
    if (!await showQuestion('Reset all settings to default values?')) return;
    await keyboard!.qmkSettingsReset();
    await _reloadSettings();
  }

  Widget _optionWidget(_Option o) {
    final f = o.field;
    if (f.type == 'boolean') {
      return CheckRow(
        label: f.title,
        value: o.value != 0,
        onChanged: (v) {
          o.value = v ? (1 << f.bit) : 0;
          notifyListeners();
        },
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(f.title)),
          SpinBox(
            value: o.value,
            min: f.min,
            max: f.max,
            width: 110,
            onChanged: (v) {
              o.value = v;
              notifyListeners();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_tabs.isEmpty) return const SizedBox.shrink();
    final tab = _tabs[_current];
    return Column(
      children: [
        TabStrip(
          labels: [
            for (final t in _tabs) '${t.name}${_isModified(t) ? '*' : ''}',
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final o in tab.options) _optionWidget(o)],
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
              OutlinedButton(
                onPressed: _anyModified ? _reloadSettings : null,
                child: const Text('Undo'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _onReset, child: const Text('Reset')),
            ],
          ),
        ),
      ],
    );
  }
}
