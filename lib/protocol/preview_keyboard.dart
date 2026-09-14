// SPDX-License-Identifier: GPL-2.0-or-later
import 'dart:convert';
import 'dart:typed_data';

import '../settings/qmk_settings.dart';
import 'dummy_keyboard.dart';
import 'dynamic_entries.dart';
import 'keyboard.dart';

/// Offline keyboard showing a saved `.vil` layout on top of a keyboard
/// definition, with no hardware behind it.
///
/// A layout file only carries what the user configured (layers, macros, tap
/// dance, combos, key overrides, alt repeat keys, QMK settings), so the
/// capacities that a real device would report are derived from the file and
/// every write lands in memory. This lets the regular editor tabs render the
/// file exactly as they would for the keyboard it came from.
class PreviewKeyboard extends DummyKeyboard {
  PreviewKeyboard(this.layoutFile, {super.usbSend})
    : data = jsonDecode(utf8.decode(layoutFile)) as Map<String, dynamic>;

  final Uint8List layoutFile;
  final Map<String, dynamic> data;

  int _count(String key) {
    final v = data[key];
    return v is List ? v.length : 0;
  }

  /// Loads the definition, then replays the layout file into memory.
  Future<void> loadPreview(Map<String, dynamic> definition) async {
    await reload(definition);
    await restoreLayout(layoutFile);
  }

  @override
  Future<void> reloadViaProtocol() async {
    // Advertise the newest protocols so every tab the file could populate is
    // shown; nothing is ever sent, so there is no device to disagree.
    viaProtocol = supportedViaProtocol.last;
    vialProtocol = supportedVialProtocol.last;
    keyboardId = Keyboard.parseLayoutUid(layoutFile) ?? BigInt.from(-1);
  }

  @override
  Future<void> reloadLayers() async {
    final n = _count('layout');
    layers = n > 0 ? n : 1;
  }

  @override
  Future<void> reloadMacrosEarly() async {
    macroCount = _count('macro');
    // Generous enough for any file; a real device would reject the excess.
    macroMemory = 65535;
  }

  @override
  Future<void> reloadSettings() async {
    settings = {};
    supportedSettings = {};
    final s = data['settings'];
    if (s is! Map) return;
    for (final e in s.entries) {
      final qsid = int.tryParse(e.key as String);
      if (qsid == null || !QmkSettings.isQsidSupported(qsid)) continue;
      supportedSettings.add(qsid);
      settings[qsid] = (e.value as num).toInt();
    }
  }

  @override
  Future<int> qmkSettingsSet(int qsid, int value) async {
    settings[qsid] = value;
    return 0;
  }

  @override
  Future<void> reloadDynamic() async {
    supportedFeatures = {};
    tapDanceCount = _count('tap_dance');
    comboCount = _count('combo');
    keyOverrideCount = _count('key_override');
    altRepeatKeyCount = _count('alt_repeat_key');
    supportedFeatures.add('persistent_default_layer');
    if (altRepeatKeyCount > 0) supportedFeatures.add('repeat_key');
  }

  @override
  Future<void> reloadTapDance() async {
    tapDanceEntries = [
      for (var i = 0; i < tapDanceCount; i++)
        ('KC_NO', 'KC_NO', 'KC_NO', 'KC_NO', 0),
    ];
  }

  @override
  Future<void> tapDanceSet(int idx, TapDanceEntry entry) async {
    tapDanceEntries[idx] = entry;
  }

  @override
  Future<void> reloadCombo() async {
    comboEntries = [
      for (var i = 0; i < comboCount; i++)
        ('KC_NO', 'KC_NO', 'KC_NO', 'KC_NO', 'KC_NO'),
    ];
  }

  @override
  Future<void> comboSet(int idx, ComboEntry entry) async {
    comboEntries[idx] = entry;
  }

  @override
  Future<void> reloadKeyOverride() async {
    keyOverrideEntries = [
      for (var i = 0; i < keyOverrideCount; i++) KeyOverrideEntry.empty(),
    ];
  }

  @override
  Future<void> keyOverrideSet(int idx, KeyOverrideEntry entry) async {
    keyOverrideEntries[idx] = entry;
  }

  @override
  Future<void> reloadAltRepeatKey() async {
    altRepeatKeyEntries = [
      for (var i = 0; i < altRepeatKeyCount; i++) AltRepeatKeyEntry.empty(),
    ];
  }

  @override
  Future<void> altRepeatKeySet(int idx, AltRepeatKeyEntry entry) async {
    altRepeatKeyEntries[idx] = entry;
  }
}
