// SPDX-License-Identifier: GPL-2.0-or-later
import 'keymap_tables.dart';

/// Programmer Dvorak legends keyed by the QWERTY position's qmk id.
/// Display only: it never changes the keycode sent to the keyboard.
const Map<String, String> programmerDvorakKeymap = {
  "KC_GRAVE": "~\n\$",
  "KC_1": "%\n&",
  "KC_2": "7\n[",
  "KC_3": "5\n{",
  "KC_4": "3\n}",
  "KC_5": "1\n(",
  "KC_6": "9\n=",
  "KC_7": "0\n*",
  "KC_8": "2\n)",
  "KC_9": "4\n+",
  "KC_0": "6\n]",
  "KC_MINUS": "8\n!",
  "KC_EQUAL": "`\n#",
  "KC_Q": ":\n;",
  "KC_W": "<\n,",
  "KC_E": ">\n.",
  "KC_R": "P",
  "KC_T": "Y",
  "KC_Y": "F",
  "KC_U": "G",
  "KC_I": "C",
  "KC_O": "R",
  "KC_P": "L",
  "KC_LBRACKET": "?\n/",
  "KC_RBRACKET": "^\n@",
  "KC_A": "A",
  "KC_S": "O",
  "KC_D": "E",
  "KC_F": "U",
  "KC_G": "I",
  "KC_H": "D",
  "KC_J": "H",
  "KC_K": "T",
  "KC_L": "N",
  "KC_SCOLON": "S",
  "KC_QUOTE": "_\n-",
  "KC_Z": "\"\n'",
  "KC_X": "Q",
  "KC_C": "J",
  "KC_V": "K",
  "KC_B": "X",
  "KC_N": "B",
  "KC_M": "M",
  "KC_COMMA": "W",
  "KC_DOT": "V",
  "KC_SLASH": "Z",
};

/// Generated tables plus hand-written extras, kept out of the generated file
/// so `tool/gen_tables.py` can be re-run without losing them.
final List<(String, Map<String, String>)> allKeymapTables = [
  for (final entry in keymapTables) ...[
    entry,
    if (entry.$1 == 'Dvorak') ('Programmer Dvorak', programmerDvorakKeymap),
  ],
];
