import 'package:flutter_test/flutter_test.dart';
import 'package:vial_flutter/keycodes/keycode.dart';

class FakeKeyboard implements KeycodeKeyboardInfo {
  FakeKeyboard(this.vialProtocol)
    : supportedFeatures = vialProtocol >= 6
          ? {
              'persistent_default_layer',
              'caps_word',
              'layer_lock',
              'repeat_key',
            }
          : {};

  @override
  final int vialProtocol;
  @override
  int get layers => 4;
  @override
  int get macroCount => 16;
  @override
  List<Map<String, dynamic>>? get customKeycodes => null;
  @override
  int get tapDanceCount => 0;
  @override
  String? get midi => null;
  @override
  final Set<String> supportedFeatures;
}

void testSerializeProtocol(int protocol) {
  recreateKeyboardKeycodes(FakeKeyboard(protocol));
  var covered = 0;

  // at a minimum, we should be able to deserialize/serialize everything
  for (var x = 0; x < 1 << 16; x++) {
    final s = Keycode.serialize(x);
    final d = Keycode.deserialize(s);
    expect(d, x, reason: '$x serialized into $s deserialized into $d');
    if (s != Keycode.hexOf(x)) covered += 1;
  }
  // ignore: avoid_print
  print(
    '[protocol=$protocol] $covered/${1 << 16} covered keycodes, which is '
    '${(100 * covered / (1 << 16)).toStringAsFixed(4)}%',
  );
}

void main() {
  setUpAll(Keycode.ensureInitialized);

  test('serialize v5', () => testSerializeProtocol(5));
  test('serialize v6', () => testSerializeProtocol(6));
}
