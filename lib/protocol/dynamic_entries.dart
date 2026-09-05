// SPDX-License-Identifier: GPL-2.0-or-later
import 'dart:typed_data';

import '../keycodes/keycode.dart';
import '../util/bytes.dart';

/// (on_tap, on_hold, on_double_tap, on_tap_hold, tapping_term)
typedef TapDanceEntry = (String, String, String, String, int);

/// (key1, key2, key3, key4, output)
typedef ComboEntry = (String, String, String, String, String);

class KeyOverrideOptions {
  KeyOverrideOptions([int data = 0])
    : activationTriggerDown = data & (1 << 0) != 0,
      activationRequiredModDown = data & (1 << 1) != 0,
      activationNegativeModUp = data & (1 << 2) != 0,
      oneMod = data & (1 << 3) != 0,
      noReregisterTrigger = data & (1 << 4) != 0,
      noUnregisterOnOtherKeyDown = data & (1 << 5) != 0,
      enabled = data & (1 << 7) != 0;

  bool activationTriggerDown;
  bool activationRequiredModDown;
  bool activationNegativeModUp;
  bool oneMod;
  bool noReregisterTrigger;
  bool noUnregisterOnOtherKeyDown;
  bool enabled;

  int serialize() =>
      (activationTriggerDown ? 1 : 0) << 0 |
      (activationRequiredModDown ? 1 : 0) << 1 |
      (activationNegativeModUp ? 1 : 0) << 2 |
      (oneMod ? 1 : 0) << 3 |
      (noReregisterTrigger ? 1 : 0) << 4 |
      (noUnregisterOnOtherKeyDown ? 1 : 0) << 5 |
      (enabled ? 1 : 0) << 7;

  @override
  String toString() => 'KeyOverrideOptions<${serialize()}>';
}

class KeyOverrideEntry {
  KeyOverrideEntry({
    this.trigger = 'KC_NO',
    this.replacement = 'KC_NO',
    this.layers = 0,
    this.triggerMods = 0,
    this.negativeModMask = 0,
    this.suppressedMods = 0,
    int options = 0,
  }) : options = KeyOverrideOptions(options);

  KeyOverrideEntry.empty() : this(trigger: '0x0', replacement: '0x0');

  String trigger;
  String replacement;
  int layers;
  int triggerMods;
  int negativeModMask;
  int suppressedMods;
  KeyOverrideOptions options;

  /// Serializes into a vial_key_override_entry_t object.
  Uint8List serialize() => packLe('HHHBBBB', [
    Keycode.deserialize(trigger),
    Keycode.deserialize(replacement),
    layers,
    triggerMods,
    negativeModMask,
    suppressedMods,
    options.serialize(),
  ]);

  @override
  String toString() =>
      'KeyOverride<trigger=$trigger replacement=$replacement layers=$layers '
      'trigger_mods=$triggerMods negative_mod_mask=$negativeModMask '
      'suppresed_mods=$suppressedMods options=$options>';

  @override
  bool operator ==(Object other) =>
      other is KeyOverrideEntry && _bytesEq(serialize(), other.serialize());

  @override
  int get hashCode => Object.hashAll(serialize());

  /// Serializes into Vial layout file.
  Map<String, dynamic> save() => {
    'trigger': trigger,
    'replacement': replacement,
    'layers': layers,
    'trigger_mods': triggerMods,
    'negative_mod_mask': negativeModMask,
    'suppressed_mods': suppressedMods,
    'options': options.serialize(),
  };

  /// Restores from a Vial layout file.
  void restore(Map<String, dynamic> data) {
    trigger = _kc(data['trigger']);
    replacement = _kc(data['replacement']);
    layers = data['layers'] as int;
    triggerMods = data['trigger_mods'] as int;
    negativeModMask = data['negative_mod_mask'] as int;
    suppressedMods = data['suppressed_mods'] as int;
    options = KeyOverrideOptions(data['options'] as int);
  }
}

class AltRepeatKeyOptions {
  AltRepeatKeyOptions([int data = 0])
    : defaultToThisAltKey = data & (1 << 0) != 0,
      bidirectional = data & (1 << 1) != 0,
      ignoreModHandedness = data & (1 << 2) != 0,
      enabled = data & (1 << 3) != 0;

  bool defaultToThisAltKey;
  bool bidirectional;
  bool ignoreModHandedness;
  bool enabled;

  int serialize() =>
      (defaultToThisAltKey ? 1 : 0) << 0 |
      (bidirectional ? 1 : 0) << 1 |
      (ignoreModHandedness ? 1 : 0) << 2 |
      (enabled ? 1 : 0) << 3;

  @override
  String toString() => 'AltRepeatKeyOptions<${serialize()}>';
}

class AltRepeatKeyEntry {
  AltRepeatKeyEntry({
    this.keycode = 'KC_NO',
    this.altKeycode = 'KC_NO',
    this.allowedMods = 0,
    int options = 0,
  }) : options = AltRepeatKeyOptions(options);

  AltRepeatKeyEntry.empty() : this(keycode: '0x0', altKeycode: '0x0');

  String keycode;
  String altKeycode;
  int allowedMods;
  AltRepeatKeyOptions options;

  /// Serializes into a vial_alt_repeat_key_entry_t object.
  Uint8List serialize() => packLe('HHBB', [
    Keycode.deserialize(keycode),
    Keycode.deserialize(altKeycode),
    allowedMods,
    options.serialize(),
  ]);

  @override
  String toString() =>
      'AltRepeatKey<keycode=$keycode alt_keycode=$altKeycode '
      'allowed_mods=$allowedMods options=$options>';

  @override
  bool operator ==(Object other) =>
      other is AltRepeatKeyEntry && _bytesEq(serialize(), other.serialize());

  @override
  int get hashCode => Object.hashAll(serialize());

  Map<String, dynamic> save() => {
    'keycode': keycode,
    'alt_keycode': altKeycode,
    'allowed_mods': allowedMods,
    'options': options.serialize(),
  };

  void restore(Map<String, dynamic> data) {
    keycode = _kc(data['keycode']);
    altKeycode = _kc(data['alt_keycode']);
    allowedMods = data['allowed_mods'] as int;
    options = AltRepeatKeyOptions(data['options'] as int);
  }
}

String _kc(Object? v) => v is int ? Keycode.serialize(v) : v as String;

bool _bytesEq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
