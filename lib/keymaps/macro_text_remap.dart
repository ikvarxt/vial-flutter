// SPDX-License-Identifier: GPL-2.0-or-later

/// Translates macro text between what the firmware sends and what the
/// operating system types under a non-QWERTY layout.
///
/// QMK's `send_string` turns each character into a keycode via the US QWERTY
/// ASCII table, so with the OS set to, say, Programmer Dvorak the macro text
/// "hello" comes out as "d.nnr". Given the display keymap's legends this
/// class maps stored text to what the user will actually see ([toDisplay])
/// and typed text back to what must be stored ([toFirmware]).
class MacroTextRemap {
  MacroTextRemap(Map<String, String> table) {
    for (var i = 0; i < _keys.length; i++) {
      final legend = table[_keys[i]];
      if (legend == null) continue;
      final (shifted, unshifted) = _parseLegend(legend);
      if (unshifted != null) _bind(i, false, unshifted);
      if (shifted != null) _bind(i, true, shifted);
    }
  }

  /// Identity mapping used for QWERTY and tables without legends.
  static final MacroTextRemap identity = MacroTextRemap(const {});

  /// US QWERTY keys that `send_string` reaches through printable ASCII, in
  /// the order of [_unshifted] / [_shifted].
  static const List<String> _keys = [
    'KC_GRAVE', 'KC_1', 'KC_2', 'KC_3', 'KC_4', 'KC_5', 'KC_6', 'KC_7', //
    'KC_8', 'KC_9', 'KC_0', 'KC_MINUS', 'KC_EQUAL', //
    'KC_Q', 'KC_W', 'KC_E', 'KC_R', 'KC_T', 'KC_Y', 'KC_U', 'KC_I', 'KC_O', //
    'KC_P', 'KC_LBRACKET', 'KC_RBRACKET', 'KC_BSLASH', //
    'KC_A', 'KC_S', 'KC_D', 'KC_F', 'KC_G', 'KC_H', 'KC_J', 'KC_K', 'KC_L', //
    'KC_SCOLON', 'KC_QUOTE', //
    'KC_Z', 'KC_X', 'KC_C', 'KC_V', 'KC_B', 'KC_N', 'KC_M', 'KC_COMMA', //
    'KC_DOT', 'KC_SLASH',
  ];
  static const String _unshifted =
      r"`1234567890-=qwertyuiop[]\asdfghjkl;'zxcvbnm,./";
  static const String _shifted =
      r'~!@#$%^&*()_+QWERTYUIOP{}|ASDFGHJKL:"ZXCVBNM<>?';

  /// (key index, shifted) encoded as index * 2 + shift -> character.
  final Map<int, String> _display = {};
  final Map<String, int> _displayInverse = {};

  void _bind(int index, bool shifted, String char) {
    final slot = index * 2 + (shifted ? 1 : 0);
    _display[slot] = char;
    _displayInverse.putIfAbsent(char, () => slot);
  }

  /// Legends are "shifted\nunshifted", or a single letter standing for both
  /// cases, or a lone symbol; anything else (e.g. "Esc") carries no
  /// character and is ignored.
  static (String?, String?) _parseLegend(String legend) {
    final lines = legend.split('\n');
    if (lines.length == 2 && lines[0].length == 1 && lines[1].length == 1) {
      return (lines[0], lines[1]);
    }
    if (lines.length == 1 && legend.length == 1) {
      final lower = legend.toLowerCase();
      final upper = legend.toUpperCase();
      if (lower != upper) return (upper, lower);
      return (null, legend);
    }
    return (null, null);
  }

  static int? _usSlot(String char) {
    var i = _unshifted.indexOf(char);
    if (i >= 0) return i * 2;
    i = _shifted.indexOf(char);
    if (i >= 0) return i * 2 + 1;
    return null;
  }

  static String _usChar(int slot) =>
      slot.isEven ? _unshifted[slot ~/ 2] : _shifted[slot ~/ 2];

  /// What the OS types when the firmware sends [firmwareText].
  String toDisplay(String firmwareText) => _map(firmwareText, (c) {
    final slot = _usSlot(c);
    return slot == null ? c : _display[slot] ?? c;
  });

  /// What to store so the OS types [displayText].
  String toFirmware(String displayText) => _map(displayText, (c) {
    final slot = _displayInverse[c];
    return slot == null ? c : _usChar(slot);
  });

  static String _map(String text, String Function(String) f) {
    final b = StringBuffer();
    for (final rune in text.runes) {
      b.write(f(String.fromCharCode(rune)));
    }
    return b.toString();
  }
}
