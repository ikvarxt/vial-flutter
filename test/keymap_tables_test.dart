import 'package:flutter_test/flutter_test.dart';
import 'package:vial_flutter/keycodes/keycode.dart';
import 'package:vial_flutter/keymaps/extra_keymaps.dart';
import 'package:vial_flutter/keymaps/keymap_tables.dart';
import 'package:vial_flutter/ui/keycode_display.dart';

void main() {
  setUpAll(Keycode.ensureInitialized);
  tearDown(() => KeycodeDisplay.setKeymapOverride(keymapTables[0].$2));

  test('Programmer Dvorak sits right after Dvorak in the layout list', () {
    final names = [for (final (name, _) in allKeymapTables) name];
    expect(names.length, keymapTables.length + 1);
    expect(names.indexOf('Programmer Dvorak'), names.indexOf('Dvorak') + 1);
    expect(names.toSet().length, names.length);
  });

  test('Programmer Dvorak only relabels, keycodes stay untouched', () {
    for (final id in programmerDvorakKeymap.keys) {
      expect(Keycode.findOuterKeycode(id), isNotNull, reason: id);
    }
    KeycodeDisplay.setKeymapOverride(programmerDvorakKeymap);
    expect(KeycodeDisplay.getLabel('KC_1'), '%\n&');
    expect(KeycodeDisplay.getLabel('KC_Q'), ':\n;');
    expect(KeycodeDisplay.getLabel('KC_SPACE'), Keycode.labelOf('KC_SPACE'));
    expect(Keycode.deserialize('KC_1'), 0x1E);
  });
}
