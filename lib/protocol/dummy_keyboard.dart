// SPDX-License-Identifier: GPL-2.0-or-later
import 'dart:typed_data';

import 'keyboard.dart';

/// Keyboard backed by no hardware: mirrors the reference implementation's
/// DummyKeyboard used for offline layout editing and for tests.
class DummyKeyboard extends Keyboard {
  DummyKeyboard({super.usbSend}) : super(null) {
    supportedFeatures = {};
  }

  @override
  Future<void> reloadLayers() async {
    layers = 4;
  }

  @override
  Future<void> reloadKeymap() async {
    for (var layer = 0; layer < layers; layer++) {
      for (final (row, col) in rowcol) {
        layout[(layer, row, col)] = 'KC_NO';
      }
    }

    for (var layer = 0; layer < layers; layer++) {
      for (final idx in encoderpos) {
        encoderLayout[(layer, idx, 0)] = 'KC_NO';
        encoderLayout[(layer, idx, 1)] = 'KC_NO';
      }
    }

    if (layoutLabels != null && layoutLabels!.isNotEmpty) layoutOptions = 0;
  }

  @override
  Future<void> reloadMacrosEarly() async {
    macroCount = 16;
    macroMemory = 900;
  }

  @override
  Future<void> reloadMacrosLate() async {
    macro = Uint8List(macroCount);
  }

  @override
  Future<void> setKey(int layer, int row, int col, String code) async {
    layout[(layer, row, col)] = code;
  }

  @override
  Future<void> setEncoder(
    int layer,
    int index,
    int direction,
    String code,
  ) async {
    encoderLayout[(layer, index, direction)] = code;
  }

  @override
  Future<void> setLayoutOptions(int options) async {
    if (layoutOptions != -1 && layoutOptions != options) {
      layoutOptions = options;
    }
  }

  @override
  Future<void> setMacro(Uint8List data) async {
    if (data.length > macroMemory) {
      throw StateError(
        'the macro is too big: got ${data.length} max $macroMemory',
      );
    }
    macro = data;
  }

  @override
  Future<void> reset() async {}

  @override
  Future<Uint8List> getUid() async => Uint8List(8);

  @override
  Future<int> getUnlockStatus({int retries = 20}) async => 1;

  @override
  Future<int> getUnlockInProgress() async => 0;

  @override
  Future<List<(int, int)>> getUnlockKeys() async => [];

  @override
  Future<void> unlockStart() async {}

  @override
  Future<Uint8List> unlockPoll() async => Uint8List(0);

  @override
  Future<void> lock() async {}

  @override
  Future<void> reloadViaProtocol() async {}

  @override
  Future<void> reloadPersistentRgb() async {
    final lighting = definition?['lighting'];
    if (lighting != null) {
      lightingQmkRgblight =
          lighting == 'qmk_rgblight' || lighting == 'qmk_backlight_rgblight';
      lightingQmkBacklight =
          lighting == 'qmk_backlight' || lighting == 'qmk_backlight_rgblight';
      lightingVialrgb = lighting == 'vialrgb';
    }

    if (lightingVialrgb) {
      rgbVersion = 1;
      rgbMaximumBrightness = 128;
      rgbSupportedEffects = {0, 1, 2, 3};
    }
  }

  @override
  Future<void> reloadRgb() async {
    if (lightingQmkRgblight) {
      underglowBrightness = 128;
      underglowEffect = 1;
      underglowEffectSpeed = 5;
      underglowColor = (32, 64);
    }

    if (lightingQmkBacklight) {
      backlightBrightness = 42;
      backlightEffect = 0;
    }

    if (lightingVialrgb) {
      rgbMode = 2;
      rgbSpeed = 90;
      rgbHsv = (16, 32, 64);
    }
  }
}
