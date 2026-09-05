// SPDX-License-Identifier: GPL-2.0-or-later
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vial_flutter/keycodes/keycode.dart';
import 'package:vial_flutter/macro/macro_action.dart';
import 'package:vial_flutter/macro/macro_key.dart';
import 'package:vial_flutter/macro/macro_optimizer.dart';
import 'package:vial_flutter/protocol/dummy_keyboard.dart';

Uint8List b(List<int> v) => Uint8List.fromList(v);

Uint8List bs(String text, [List<int> tail = const []]) =>
    b([...text.codeUnits, ...tail]);

void main() {
  late Keycode kcA;
  late Keycode kcB;
  late Keycode kcC;

  setUpAll(() {
    Keycode.ensureInitialized();
    kcA = Keycode.findByQmkId('KC_A')!;
    kcB = Keycode.findByQmkId('KC_B')!;
    kcC = Keycode.findByQmkId('KC_C')!;
  });

  test('remove repeats', () {
    expect(removeRepeats([KeyDown(kcA), KeyDown(kcA)]), [KeyDown(kcA)]);
    expect(
      removeRepeats([
        KeyDown(kcA),
        KeyDown(kcB),
        KeyDown(kcB),
        KeyDown(kcC),
        KeyDown(kcC),
      ]),
      [KeyDown(kcA), KeyDown(kcB), KeyDown(kcC)],
    );

    // don't remove repeated taps
    expect(removeRepeats([KeyTap(kcA), KeyTap(kcA)]), [
      KeyTap(kcA),
      KeyTap(kcA),
    ]);
  });

  test('replace tap', () {
    expect(replaceWithTap([KeyDown(kcA)]), [KeyDown(kcA)]);
    expect(replaceWithTap([KeyDown(kcA), KeyUp(kcA)]), [KeyTap(kcA)]);
    expect(replaceWithTap([KeyUp(kcA), KeyDown(kcA)]), [
      KeyUp(kcA),
      KeyDown(kcA),
    ]);
  });

  test('replace string', () {
    expect(replaceWithString([KeyTap(kcA), KeyTap(kcB)]), [KeyString('ab')]);
  });

  test('serialize v1', () {
    final kb = DummyKeyboard()..vialProtocol = 1;
    final data = kb.macroSerialize([
      ActionText('Hello'),
      ActionTap(['KC_A', 'KC_B', 'KC_C']),
      ActionText('World'),
      ActionDown(['KC_C', 'KC_B', 'KC_A']),
    ]);
    expect(
      data,
      bs('Hello', [1, 4, 1, 5, 1, 6, ...'World'.codeUnits, 2, 6, 2, 5, 2, 4]),
    );
  });

  test('deserialize v1', () {
    final kb = DummyKeyboard()..vialProtocol = 1;
    final macro = kb.macroDeserialize(
      bs('Hello', [1, 4, 1, 5, 1, 6, ...'World'.codeUnits, 2, 6, 2, 5, 2, 4]),
    );
    expect(macro, [
      ActionText('Hello'),
      ActionTap(['KC_A', 'KC_B', 'KC_C']),
      ActionText('World'),
      ActionDown(['KC_C', 'KC_B', 'KC_A']),
    ]);
  });

  Uint8List v2Body(List<int> delay) => bs('Hello', [
    1, 1, 4, 1, 1, 5, 1, 1, 6, //
    ...'World'.codeUnits,
    1, 2, 6, 1, 2, 5, 1, 2, 4, //
    1, 4, ...delay,
  ]);

  List<BasicAction> v2Actions(int delay) => [
    ActionText('Hello'),
    ActionTap(['KC_A', 'KC_B', 'KC_C']),
    ActionText('World'),
    ActionDown(['KC_C', 'KC_B', 'KC_A']),
    ActionDelay(delay),
  ];

  test('serialize v2', () {
    final kb = DummyKeyboard()..vialProtocol = 2;
    expect(kb.macroSerialize(v2Actions(1000)), v2Body([0xEC, 0x04]));
    expect(kb.macroSerialize(v2Actions(0)), v2Body([0x01, 0x01]));
    expect(kb.macroSerialize(v2Actions(1)), v2Body([0x02, 0x01]));
    expect(kb.macroSerialize(v2Actions(256)), v2Body([0x02, 0x02]));
  });

  test('deserialize v2', () {
    final kb = DummyKeyboard()..vialProtocol = 2;
    expect(kb.macroDeserialize(v2Body([0xEC, 0x04])), v2Actions(1000));
    expect(kb.macroDeserialize(v2Body([0x01, 0x01])), v2Actions(0));
    expect(kb.macroDeserialize(v2Body([0x02, 0x01])), v2Actions(1));
    expect(kb.macroDeserialize(v2Body([0x02, 0x02])), v2Actions(256));
  });

  test('save', () {
    expect(ActionDown(['KC_A', 'KC_B', 'CMB_TOG']).save(), [
      'down',
      'KC_A',
      'KC_B',
      'CMB_TOG',
    ]);
    expect(ActionTap(['CMB_TOG', 'KC_B', 'KC_A']).save(), [
      'tap',
      'CMB_TOG',
      'KC_B',
      'KC_A',
    ]);
    expect(ActionText('Hello world').save(), ['text', 'Hello world']);
    expect(ActionDelay(123).save(), ['delay', 123]);
  });

  test('restore', () {
    final down = ActionDown()..restore(['down', 'KC_A', 'KC_B', 'CMB_TOG']);
    expect(down, ActionDown(['KC_A', 'KC_B', 'CMB_TOG']));
    final tap = ActionTap()..restore(['tap', 'CMB_TOG', 'KC_B', 'KC_A']);
    expect(tap, ActionTap(['CMB_TOG', 'KC_B', 'KC_A']));
    final text = ActionText()..restore(['text', 'Hello world']);
    expect(text, ActionText('Hello world'));
    final delay = ActionDelay()..restore(['delay', 123]);
    expect(delay, ActionDelay(123));
  });

  test('twobyte keycodes', () {
    final kb = DummyKeyboard()
      ..vialProtocol = 2
      ..tapDanceCount = 0;
    recreateKeyboardKeycodes(kb);

    expect(
      kb.macroSerialize([
        ActionTap(['CMB_TOG', 'KC_A']),
      ]),
      b([1, 5, 0xF9, 0x5C, 1, 1, 4]),
    );
    expect(
      kb.macroSerialize([
        ActionDown(['CMB_TOG', 'KC_A']),
      ]),
      b([1, 6, 0xF9, 0x5C, 1, 2, 4]),
    );
    expect(
      kb.macroSerialize([
        ActionUp(['CMB_TOG', 'KC_A']),
      ]),
      b([1, 7, 0xF9, 0x5C, 1, 3, 4]),
    );

    expect(kb.macroDeserialize(b([1, 5, 0xF9, 0x5C, 1, 1, 4])), [
      ActionTap(['CMB_TOG', 'KC_A']),
    ]);
    expect(kb.macroDeserialize(b([1, 6, 0xF9, 0x5C, 1, 2, 4])), [
      ActionDown(['CMB_TOG', 'KC_A']),
    ]);
    expect(kb.macroDeserialize(b([1, 7, 0xF9, 0x5C, 1, 3, 4])), [
      ActionUp(['CMB_TOG', 'KC_A']),
    ]);
  });

  test('twobyte with zeroes', () {
    final kb = DummyKeyboard()..vialProtocol = 2;
    final data = kb.macroSerialize([
      ActionTap([
        Keycode.serialize(0xA000),
        Keycode.serialize(0xB100),
        Keycode.serialize(0xC200),
      ]),
    ]);
    expect(data, b([1, 5, 0xA0, 0xFF, 1, 5, 0xB1, 0xFF, 1, 5, 0xC2, 0xFF]));

    final macro = kb.macroDeserialize(
      b([1, 5, 0xC2, 0xFF, 1, 5, 0xB1, 0xFF, 1, 5, 0xA0, 0xFF]),
    );
    expect(macro, [
      ActionTap([
        Keycode.serialize(0xC200),
        Keycode.serialize(0xB100),
        Keycode.serialize(0xA000),
      ]),
    ]);
  });
}
