// SPDX-License-Identifier: GPL-2.0-or-later
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vial_flutter/hid/vial_device.dart';
import 'package:vial_flutter/protocol/keyboard.dart';
import 'package:vial_flutter/protocol/preview_keyboard.dart';

const definition2x2 =
    '{"name":"test","vendorId":"0x0000","productId":"0x1111",'
    '"lighting":"none","matrix":{"rows":2,"cols":2},'
    '"layouts":{"keymap":[["0,0","0,1"],["1,0","1,1"]]}}';

const layoutFile = '''
{
  "version": 1,
  "uid": 1234567890123456789,
  "layout": [
    [["KC_A", "KC_B"], ["KC_C", "KC_D"]],
    [["KC_1", "KC_2"], ["KC_3", "KC_4"]],
    [["KC_NO", "KC_NO"], ["KC_NO", "KC_TRNS"]]
  ],
  "encoder_layout": [[], [], []],
  "layout_options": -1,
  "macro": [[["tap", "KC_H", "KC_I"]], []],
  "vial_protocol": 6,
  "via_protocol": 9,
  "tap_dance": [["KC_ESC", "KC_GRV", "KC_NO", "KC_NO", 200]],
  "combo": [["KC_J", "KC_K", "KC_NO", "KC_NO", "KC_ESC"]],
  "key_override": [],
  "alt_repeat_key": [],
  "settings": {"21": 5, "9999": 1}
}
''';

Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

Future<Uint8List> noUsb(Uint8List msg, {int retries = 1}) =>
    throw StateError('usb_send must not be called for a preview');

void main() {
  Future<PreviewKeyboard> load() async {
    final kb = PreviewKeyboard(bytes(layoutFile), usbSend: noUsb);
    await kb.loadPreview(jsonDecode(definition2x2) as Map<String, dynamic>);
    return kb;
  }

  test('capacities and protocol come from the file', () async {
    final kb = await load();
    expect(kb.layers, 3);
    expect(kb.macroCount, 2);
    expect(kb.tapDanceCount, 1);
    expect(kb.comboCount, 1);
    expect(kb.keyOverrideCount, 0);
    expect(kb.altRepeatKeyCount, 0);
    expect(kb.viaProtocol, supportedViaProtocol.last);
    expect(kb.vialProtocol, supportedVialProtocol.last);
    expect(kb.keyboardId, BigInt.parse('1234567890123456789'));
  });

  test('keymap, dynamic entries and settings are restored', () async {
    final kb = await load();
    expect(kb.layout[(0, 0, 0)], 'KC_A');
    expect(kb.layout[(0, 1, 1)], 'KC_D');
    expect(kb.layout[(1, 0, 1)], 'KC_2');
    expect(kb.layout[(2, 1, 1)], 'KC_TRNS');
    expect(kb.tapDanceEntries, [('KC_ESC', 'KC_GRV', 'KC_NO', 'KC_NO', 200)]);
    expect(kb.comboEntries, [('KC_J', 'KC_K', 'KC_NO', 'KC_NO', 'KC_ESC')]);
    expect(kb.settings, {21: 5});
    expect(kb.supportedSettings, {21});
  });

  test('saveLayout round-trips the previewed file', () async {
    final kb = await load();
    final saved = jsonDecode(utf8.decode(kb.saveLayout()));
    final orig = jsonDecode(layoutFile);
    expect(saved['uid'], orig['uid']);
    expect(saved['layout'], orig['layout']);
    expect(saved['tap_dance'], orig['tap_dance']);
    expect(saved['combo'], orig['combo']);
    expect(saved['macro'], orig['macro']);
    expect(saved['settings'], {'21': 5});
  });

  test('VialPreviewKeyboard opens without a backend', () async {
    final dev = VialPreviewKeyboard(
      'friend.vil',
      jsonDecode(definition2x2) as Map<String, dynamic>,
      bytes(layoutFile),
    );
    expect(dev.title, '[Preview] friend.vil');
    expect(dev.desc.path, '/preview/friend.vil');
    expect(dev.sideload, isFalse);
    await dev.open();
    expect(dev.keyboard, isA<PreviewKeyboard>());
    expect(dev.keyboard!.layout[(0, 0, 0)], 'KC_A');
    await dev.close();
  });
}
