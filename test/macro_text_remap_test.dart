// SPDX-License-Identifier: GPL-2.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:vial_flutter/keymaps/extra_keymaps.dart';
import 'package:vial_flutter/keymaps/keymap_tables.dart';
import 'package:vial_flutter/keymaps/macro_text_remap.dart';

void main() {
  final dvp = MacroTextRemap(programmerDvorakKeymap);

  test('QWERTY is the identity', () {
    final q = MacroTextRemap(keymapTables[0].$2);
    const s = 'Hello, World! 42 {}\n\t';
    expect(q.toDisplay(s), s);
    expect(q.toFirmware(s), s);
  });

  test('Programmer Dvorak letters', () {
    expect(dvp.toFirmware('hello'), 'jdpps');
    expect(dvp.toDisplay('jdpps'), 'hello');
    expect(dvp.toFirmware('Hello'), 'Jdpps');
    expect(dvp.toDisplay('Jdpps'), 'Hello');
  });

  test('Programmer Dvorak symbols and digits', () {
    // DVP number row: unshifted &[{}(=*)+] , shifted %7531902468
    expect(dvp.toFirmware('a[1]'), 'a2%0');
    expect(dvp.toDisplay('a2%0'), 'a[1]');
    expect(dvp.toFirmware('%'), '!');
    expect(dvp.toFirmware(r'$'), '`');
    expect(dvp.toFirmware('~'), '~');
    expect(dvp.toFirmware(';:'), 'qQ');
    expect(dvp.toDisplay("'\""), '-_');
  });

  test('characters outside the table pass through', () {
    expect(dvp.toFirmware('\n\t 中'), '\n\t 中');
    expect(dvp.toDisplay('\n\t 中'), '\n\t 中');
  });

  test('round trip', () {
    for (final s in ['The quick brown fox', 'p@ss-W0rd_!#', 'a\nb c']) {
      expect(dvp.toDisplay(dvp.toFirmware(s)), s);
      expect(dvp.toFirmware(dvp.toDisplay(s)), s);
    }
  });
}
