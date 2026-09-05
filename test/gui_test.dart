// SPDX-License-Identifier: GPL-2.0-or-later
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vial_flutter/hid/hid_device.dart';
import 'package:vial_flutter/hid/vial_device.dart';
import 'package:vial_flutter/macro/macro_action.dart';
import 'package:vial_flutter/main.dart';
import 'package:vial_flutter/settings/qmk_settings.dart';
import 'package:vial_flutter/ui/app_settings.dart';
import 'package:vial_flutter/ui/autorefresh.dart';
import 'package:vial_flutter/ui/dialogs/about_keyboard_dialog.dart';
import 'package:vial_flutter/ui/main_window.dart';
import 'package:vial_flutter/ui/widgets/key_widget.dart';
import 'package:vial_flutter/ui/widgets/keyboard_widget.dart';
import 'package:vial_flutter/ui/widgets/spin_box.dart';
import 'package:vial_flutter/ui/widgets/square_button.dart';
import 'package:vial_flutter/ui/widgets/tab_strip.dart';
import 'package:vial_flutter/ui/widgets/tabbed_keycodes.dart';
import 'package:vial_flutter/util/bytes.dart';

// Port of vial-gui/src/main/python/test/test_gui.py: drives the real
// MainWindow against a virtual keyboard answering raw HID requests.

const fakeKeyboard = '''
{
  "matrix": {"rows": 2, "cols": 2},
  "layouts": {"keymap": [["0,0", "0,1"], ["1,0", "1,1"]]}
}
''';

const fakeInfo = HidDeviceInfo(
  path: '/magic/path/for/tests',
  vendorId: 0xDEAD,
  productId: 0xBEEF,
  serialNumber: 'vial:f64c2b3c',
  manufacturer: 'Vial Testing Ltd',
  product: 'Test Keyboard',
  usagePage: 0xFF60,
  usage: 0x61,
);

String _hex(List<int> d) =>
    d.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// The real plugin answers over a platform channel, which never completes
/// inside the FakeAsync zone of a widget test, so startup would hang forever.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.dir);

  final String dir;

  @override
  Future<String?> getApplicationSupportPath() async => dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir;

  @override
  Future<String?> getTemporaryPath() async => dir;
}

class VirtualKeyboard {
  VirtualKeyboard(
    String kbJson, {
    List<List<int>>? combos,
    List<List<int>>? tapDance,
    List<int>? macros,
  }) : combos = combos ?? [],
       tapDance = tapDance ?? [],
       definition = Uint8List.fromList(
         XZEncoder().encodeBytes(utf8.encode(kbJson)),
       ) {
    if (macros != null) macroBuffer.setAll(0, macros);
    for (var l = 0; l < layers; l++) {
      keymap.add([for (var r = 0; r < rows; r++) List.filled(cols, 0)]);
    }
  }

  final Uint8List definition;
  final int rows = 2;
  final int cols = 2;
  final int layers = 4;
  final List<List<List<int>>> keymap = [];
  final int macroCount = 8;
  final Uint8List macroBuffer = Uint8List(512);
  final List<List<int>> combos;
  final List<List<int>> tapDance;

  Uint8List keymapBuffer() {
    final w = ByteWriter();
    for (final layer in keymap) {
      for (final row in layer) {
        for (final kc in row) {
          w.u16be(kc);
        }
      }
    }
    return w.build();
  }

  Uint8List _entry(List<int> e) {
    final w = ByteWriter().u8(0);
    for (final v in e) {
      w.u16le(v);
    }
    return w.build();
  }

  List<int> _readEntry(Uint8List msg) => [
    for (var i = 0; i < 5; i++) readU16le(msg, 4 + i * 2),
  ];

  Uint8List _dynamic(Uint8List msg) {
    switch (msg[2]) {
      case 0x00:
        final out = Uint8List(32);
        out[0] = tapDance.length;
        out[1] = combos.length;
        out[31] = 0x03; // Caps Word + Layer Lock
        return out;
      case 0x01:
        return _entry(tapDance[msg[3]]);
      case 0x02:
        tapDance[msg[3]] = _readEntry(msg);
        return Uint8List(0);
      case 0x03:
        return _entry(combos[msg[3]]);
      case 0x04:
        combos[msg[3]] = _readEntry(msg);
        return Uint8List(0);
    }
    throw StateError('unsupported dynamic submsg ${_hex(msg)}');
  }

  Uint8List _vial(Uint8List msg) {
    switch (msg[1]) {
      case 0x00:
        return ByteWriter().u32le(6).u64le(0xF00DFACEDEADBEEF).build();
      case 0x01:
        return ByteWriter().u32le(definition.length).build();
      case 0x02:
        final page = readU16le(msg, 2);
        final start = page * 32;
        if (start >= definition.length) return Uint8List(0);
        final end = (start + 32).clamp(0, definition.length);
        return definition.sublist(start, end);
      case 0x05:
        return Uint8List.fromList([0, 0]);
      case 0x09:
        return Uint8List.fromList(List.filled(32, 0xFF));
      case 0x0D:
        return _dynamic(msg);
    }
    throw StateError('unknown Vial command ${_hex(msg)}');
  }

  Uint8List process(Uint8List msg) {
    switch (msg[0]) {
      case 0xFE:
        return _vial(msg);
      case 0x01:
        return ByteWriter().u8(msg[0]).u16be(9).build();
      case 0x05:
        keymap[msg[1]][msg[2]][msg[3]] = readU16be(msg, 4);
        return Uint8List(0);
      case 0x0C:
        return Uint8List.fromList([msg[0], macroCount]);
      case 0x0D:
        return ByteWriter().u8(msg[0]).u16be(macroBuffer.length).build();
      case 0x0E:
        final offset = readU16be(msg, 1);
        final size = msg[3];
        return Uint8List.fromList([
          ...msg.sublist(0, 4),
          ...macroBuffer.sublist(offset, offset + size),
        ]);
      case 0x11:
        return Uint8List.fromList([msg[0], layers]);
      case 0x12:
        final offset = readU16be(msg, 1);
        final size = msg[3];
        final buf = keymapBuffer();
        return Uint8List.fromList([
          msg[0],
          ...buf.sublist(offset, (offset + size).clamp(0, buf.length)),
        ]);
    }
    throw StateError('unknown VIA command ${_hex(msg)}');
  }
}

class MockDevice implements HidDevice {
  MockDevice(this.vk);

  final VirtualKeyboard vk;
  Uint8List _msg = Uint8List(0);

  @override
  HidDeviceInfo get info => fakeInfo;

  @override
  Future<void> write(Uint8List data) async {
    expect(data.length, msgLen);
    _msg = data;
  }

  @override
  Future<Uint8List> read(int length, {int timeoutMs = 0}) async {
    expect(length, msgLen);
    final resp = vk.process(_msg);
    expect(resp.length, lessThanOrEqualTo(msgLen));
    return padTo(resp, msgLen);
  }

  @override
  Future<void> close() async {}
}

class FakeBackend extends HidBackend {
  FakeBackend(this.vk);

  final VirtualKeyboard vk;

  @override
  Future<List<HidDeviceInfo>> enumerate() async => [fakeInfo];

  @override
  Future<HidDevice> open(HidDeviceInfo info) async {
    expect(info.path, fakeInfo.path);
    return MockDevice(vk);
  }
}

Future<VirtualKeyboard> prepare(
  WidgetTester tester, {
  List<List<int>>? combos,
  List<List<int>>? tapDance,
  List<int>? macros,
}) async {
  SharedPreferences.setMockInitialValues({});
  PathProviderPlatform.instance = _FakePathProvider(
    Directory.systemTemp.createTempSync('vial_gui_test').path,
  );
  QmkSettings.initialize();
  ensureKeycodesInitialized();
  await AppSettings.instance.load();

  final vk = VirtualKeyboard(
    fakeKeyboard,
    combos: combos,
    tapDance: tapDance,
    macros: macros,
  );
  final ar = Autorefresh.instance;
  await ar.currentDevice?.close();
  ar.currentDevice = null;
  ar.devices = [];
  ar.backend = FakeBackend(vk);
  addTearDown(ar.stop);
  KeycodeTray.instance.close();

  tester.view.physicalSize = const Size(1600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const VialApp());
  await tester.pumpAndSettle();
  expect(Autorefresh.instance.currentDevice, isA<VialKeyboard>());
  return vk;
}

VialKeyboard get currentKeyboard =>
    Autorefresh.instance.currentDevice! as VialKeyboard;

/// The keymap canvas is the first keyboard widget in the tree.
KeyboardWidgetController keymapController(WidgetTester tester) =>
    tester.widget<KeyboardWidget>(find.byType(KeyboardWidget).first).controller;

/// Taps [key] (or its inner mask) drawn on the canvas found by [kbFinder].
Future<void> tapKey(
  WidgetTester tester,
  Finder kbFinder,
  KeyModel key, {
  bool mask = false,
}) async {
  final canvas = find
      .descendant(of: kbFinder, matching: find.byType(CustomPaint))
      .first;
  final origin = tester.getTopLeft(canvas);
  // Same spots as the reference test: the outer key is hit at its first
  // polygon point (nudged inside), the mask at mid-X, 4/5 down the key.
  Offset target;
  if (mask) {
    final xs = key.bbox.map((p) => p.dx);
    final ys = key.bbox.map((p) => p.dy);
    final minX = xs.reduce(min), maxX = xs.reduce(max);
    final minY = ys.reduce(min), maxY = ys.reduce(max);
    target = Offset((minX + maxX) / 2, minY + (maxY - minY) * 4 / 5);
  } else {
    target = key.bbox[0] + const Offset(2, 2);
  }
  await tester.tapAt(origin + target);
  await tester.pumpAndSettle();
  // Keep consecutive taps apart so they never register as a double click.
  await tester.pump(const Duration(milliseconds: 500));
}

/// Taps the top-most on-screen square button labelled [text].
Future<void> tapButton(WidgetTester tester, String text) async {
  final size = tester.view.physicalSize;
  Element? best;
  var bestY = double.infinity;
  for (final e in find.widgetWithText(SquareButton, text).evaluate()) {
    final r = tester.getRect(find.byWidget(e.widget));
    if (r.top < 0 || r.bottom > size.height || r.right > size.width) continue;
    if (r.top < bestY) {
      bestY = r.top;
      best = e;
    }
  }
  expect(best, isNotNull, reason: 'no visible key button with text=$text');
  await tester.tap(find.byWidget(best!.widget));
  await tester.pumpAndSettle();
}

Future<void> switchPickerTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(Tab), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

/// Label inside the combo / tap dance entry strip (keycode buttons and layer
/// buttons carry the same digits).
Finder stripLabel(String text) =>
    find.descendant(of: find.byType(TabStrip), matching: find.text(text));

Future<void> switchMainTab(WidgetTester tester, String label) async {
  // The keycode picker has tabs with the same names (e.g. "Tap Dance"), so
  // only consider labels that are not inside a picker [Tab].
  final candidates = find
      .text(label)
      .evaluate()
      .where(
        (e) => find
            .ancestor(of: find.byWidget(e.widget), matching: find.byType(Tab))
            .evaluate()
            .isEmpty,
      );
  await tester.tap(find.byWidget(candidates.single.widget));
  await tester.pumpAndSettle();
}

List<KeyWidgetController> keyWidgets(WidgetTester tester) => [
  for (final e in find.byType(KeyWidget).evaluate())
    (e.widget as KeyWidget).controller,
];

Future<void> enterSpinBox(WidgetTester tester, int value) async {
  final field = find.descendant(
    of: find.byType(SpinBox),
    matching: find.byType(TextField),
  );
  await tester.enterText(field, '$value');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

int spinBoxValue(WidgetTester tester) =>
    tester.widget<SpinBox>(find.byType(SpinBox)).value;

bool saveEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
        .onPressed !=
    null;

void main() {
  testWidgets('gui startup', (tester) async {
    await prepare(tester);
    expect(Autorefresh.instance.devices, hasLength(1));
    expect(currentKeyboard.title, 'Vial Testing Ltd Test Keyboard');
    expect(find.text('Vial Testing Ltd Test Keyboard'), findsWidgets);
  });

  testWidgets('about keyboard', (tester) async {
    await prepare(tester);
    expect(
      aboutKeyboardText(currentKeyboard),
      'Manufacturer: Vial Testing Ltd\n'
      'Product: Test Keyboard\n'
      'VID: DEAD\n'
      'PID: BEEF\n'
      'Device: /magic/path/for/tests\n'
      '\n'
      'VIA protocol: 9\n'
      'Vial protocol: 6\n'
      'Vial keyboard ID: F00DFACEDEADBEEF\n'
      '\n'
      'Macro entries: 8\n'
      'Macro memory: 512 bytes\n'
      'Macro delays: yes\n'
      'Complex (2-byte) macro keycodes: yes\n'
      '\n'
      'Tap Dance entries: unsupported - disabled in firmware\n'
      'Combo entries: unsupported - disabled in firmware\n'
      'Key Override entries: unsupported - disabled in firmware\n'
      'Alt Repeat Key entries: unsupported - disabled in firmware\n'
      'Caps Word: yes\n'
      'Layer Lock: yes\n'
      '\n'
      'QMK Settings: disabled in firmware\n',
    );
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About Vial Testing Ltd Test Keyboard...'));
    await tester.pumpAndSettle();
    expect(find.text('About Vial Testing Ltd Test Keyboard'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  });

  testWidgets('key change', (tester) async {
    final vk = await prepare(tester);
    final c = keymapController(tester);
    final kbFinder = find.byType(KeyboardWidget).first;

    expect(c.activeKey, isNull);
    expect(vk.keymap[0][0][0], 0);

    await tapKey(tester, kbFinder, c.widgets[0]);
    expect(c.activeKey, same(c.widgets[0]));
    expect(c.activeMask, isFalse);

    // Change current key to B, check we moved on to the next key.
    await tapButton(tester, 'B');
    expect(vk.keymap[0][0][0], 5);
    expect(c.activeKey, same(c.widgets[1]));

    // Masked LCTL() from the Quantum tab.
    await switchPickerTab(tester, 'Quantum');
    await tapButton(tester, 'LCtl\n(kc)');
    expect(vk.keymap[0][0][1], 0x100);
    expect(c.activeKey, same(c.widgets[2]));

    // Click back on the second key: outer selected, not the mask.
    await tapKey(tester, kbFinder, c.widgets[1]);
    expect(c.activeKey, same(c.widgets[1]));
    expect(c.activeMask, isFalse);

    // Click the inner mask; only basic keycodes are offered now.
    await tapKey(tester, kbFinder, c.widgets[1], mask: true);
    expect(c.activeKey, same(c.widgets[1]));
    expect(c.activeMask, isTrue);
    expect(find.widgetWithText(SquareButton, 'LCtl\n(kc)'), findsNothing);

    await tapButton(tester, 'C');
    expect(vk.keymap[0][0][1], 0x106);
    expect(c.activeKey, same(c.widgets[2]));
    expect(c.activeMask, isFalse);
  });

  testWidgets('keymap zoom', (tester) async {
    await prepare(tester);
    final c = keymapController(tester);
    final initial = c.scale;

    await tapButton(tester, '+');
    expect(c.scale, greaterThan(initial));
    await tapButton(tester, '-');
    expect((c.scale - initial).abs(), lessThan(0.01));
    await tapButton(tester, '-');
    expect(c.scale, lessThan(initial));
  });

  testWidgets('layer switch', (tester) async {
    final vk = await prepare(tester);
    final c = keymapController(tester);
    final kbFinder = find.byType(KeyboardWidget).first;

    await tapKey(tester, kbFinder, c.widgets[0]);
    await tapButton(tester, 'Z');
    expect(vk.keymap[0][0][0], 0x1D);
    expect(vk.keymap[1][0][0], 0);
    expect(c.widgets[0].text, 'Z');
    expect(c.activeKey, same(c.widgets[1]));

    await tapButton(tester, '1');
    expect(c.activeKey, isNull);
    expect(c.activeMask, isFalse);
    expect(c.widgets[0].text, '');

    await tapKey(tester, kbFinder, c.widgets[0]);
    expect(c.activeKey, same(c.widgets[0]));
    await tapButton(tester, 'Y');
    expect(vk.keymap[0][0][0], 0x1D);
    expect(vk.keymap[1][0][0], 0x1C);
    expect(c.widgets[0].text, 'Y');

    await tapButton(tester, '0');
    expect(c.widgets[0].text, 'Z');
  });

  testWidgets('combos', (tester) async {
    final vk = await prepare(
      tester,
      combos: [
        [0, 0, 0, 0, 0],
        [4, 5, 6, 7, 8],
        [0, 0x106, 0, 0, 0],
      ],
    );
    await switchMainTab(tester, 'Combos');

    Future<void> checkTab(int idx, List<String> keys) async {
      await tester.tap(stripLabel('${idx + 1}'));
      await tester.pumpAndSettle();
      final w = keyWidgets(tester);
      expect(w, hasLength(5));
      for (var x = 0; x < 5; x++) {
        expect(w[x].keycode, keys[x], reason: 'tab $idx position $x');
      }
    }

    await checkTab(0, ['KC_NO', 'KC_NO', 'KC_NO', 'KC_NO', 'KC_NO']);
    await checkTab(1, ['KC_A', 'KC_B', 'KC_C', 'KC_D', 'KC_E']);
    await checkTab(2, ['KC_NO', 'LCTL(KC_C)', 'KC_NO', 'KC_NO', 'KC_NO']);

    // Still on the third combo: change "Key 1" to A through the tray.
    expect(KeycodeTray.instance.target, isNull);
    var w = keyWidgets(tester);
    final kw = find.byType(KeyWidget);
    await tapKey(tester, kw.at(0), w[0].kb.widgets[0]);
    expect(KeycodeTray.instance.target, same(w[0]));
    await tapButton(tester, 'A');
    expect(vk.combos[2], [4, 0x106, 0, 0, 0]);

    // "Output key" to B.
    await tapKey(tester, kw.at(4), w[4].kb.widgets[0]);
    await tapButton(tester, 'B');
    expect(vk.combos[2], [4, 0x106, 0, 0, 5]);

    // "Key 4" to LSft(D): the modifier first, then D inside the mask.
    await tapKey(tester, kw.at(3), w[3].kb.widgets[0]);
    await switchPickerTab(tester, 'Quantum');
    await tapButton(tester, 'LSft\n(kc)');
    expect(vk.combos[2], [4, 0x106, 0, 0x200, 5]);
    await tapKey(tester, kw.at(3), w[3].kb.widgets[0], mask: true);
    expect(find.widgetWithText(SquareButton, 'LSft\n(kc)'), findsNothing);
    await tapButton(tester, 'D');
    expect(vk.combos[2], [4, 0x106, 0, 0x207, 5]);

    // "Key 2" to E.
    await tapKey(tester, kw.at(1), w[1].kb.widgets[0]);
    await switchPickerTab(tester, 'Basic');
    await tapButton(tester, 'E');
    expect(vk.combos[2], [4, 8, 0, 0x207, 5]);

    await checkTab(2, ['KC_A', 'KC_E', 'KC_NO', 'LSFT(KC_D)', 'KC_B']);
  });

  testWidgets('macros with key sequences', (tester) async {
    // M0 taps A then B, M1 holds LCtrl: the recorder must rebuild these rows
    // without touching key controllers that are not in place yet.
    await prepare(
      tester,
      macros: [
        ssQmkPrefix, ssTapCode, 4, ssQmkPrefix, ssTapCode, 5, 0, //
        ssQmkPrefix, ssDownCode, 0xE0, 0,
      ],
    );
    await switchMainTab(tester, 'Macros');

    var w = keyWidgets(tester);
    expect(w, hasLength(2));
    expect(w[0].keycode, 'KC_A');
    expect(w[1].keycode, 'KC_B');

    await tester.tap(stripLabel('M1'));
    await tester.pumpAndSettle();
    w = keyWidgets(tester);
    expect(w, hasLength(1));
    expect(w[0].keycode, 'KC_LCTRL');
  });

  testWidgets('tap dance', (tester) async {
    final vk = await prepare(
      tester,
      tapDance: [
        [0, 0, 0, 0, 200],
        [4, 5, 6, 7, 200],
        [0, 0x106, 0, 0, 500],
      ],
    );
    await switchMainTab(tester, 'Tap Dance');

    Future<void> checkTab(int idx, List<String> keys, int timeout) async {
      await tester.tap(stripLabel('$idx'));
      await tester.pumpAndSettle();
      final w = keyWidgets(tester);
      expect(w, hasLength(4));
      for (var x = 0; x < 4; x++) {
        expect(w[x].keycode, keys[x], reason: 'tab $idx position $x');
      }
      expect(spinBoxValue(tester), timeout);
    }

    await checkTab(0, ['KC_NO', 'KC_NO', 'KC_NO', 'KC_NO'], 200);
    await checkTab(1, ['KC_A', 'KC_B', 'KC_C', 'KC_D'], 200);
    await checkTab(2, ['KC_NO', 'LCTL(KC_C)', 'KC_NO', 'KC_NO'], 500);

    // Keycode changes are written immediately, the timeout is not.
    final w = keyWidgets(tester);
    await tapKey(tester, find.byType(KeyWidget).at(0), w[0].kb.widgets[0]);
    expect(KeycodeTray.instance.target, same(w[0]));
    await tapButton(tester, 'A');
    expect(vk.tapDance[2], [4, 0x106, 0, 0, 500]);

    await enterSpinBox(tester, 123);
    expect(vk.tapDance[2], [4, 0x106, 0, 0, 500]);
    expect(stripLabel('2*'), findsOneWidget);
    await enterSpinBox(tester, 500);
    expect(stripLabel('2*'), findsNothing);
    expect(stripLabel('2'), findsOneWidget);

    // Commit the change.
    await enterSpinBox(tester, 123);
    expect(stripLabel('2*'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(stripLabel('2*'), findsNothing);
    expect(vk.tapDance[2], [4, 0x106, 0, 0, 123]);

    // Reverting restores the saved timeout.
    expect(saveEnabled(tester), isFalse);
    await enterSpinBox(tester, 321);
    expect(saveEnabled(tester), isTrue);
    expect(stripLabel('2*'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Revert'));
    await tester.pumpAndSettle();
    expect(saveEnabled(tester), isFalse);
    expect(stripLabel('2*'), findsNothing);
    expect(spinBoxValue(tester), 123);
  });
}
