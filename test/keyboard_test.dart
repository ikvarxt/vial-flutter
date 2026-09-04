import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vial_flutter/hid/hid_device.dart';
import 'package:vial_flutter/keycodes/keycode.dart';
import 'package:vial_flutter/protocol/keyboard.dart';
import 'package:vial_flutter/util/bytes.dart';

const layout2x2 = '''
{"name":"test","vendorId":"0x0000","productId":"0x1111","lighting":"none","matrix":{"rows":2,"cols":2},"layouts":{"keymap":[["0,0","0,1"],["1,0","1,1"]]}}
''';

const layoutEncoder = r'''
{"name":"test","vendorId":"0x0000","productId":"0x1111","lighting":"none","matrix":{"rows":1,"cols":1},"layouts":{"keymap":[["0,0\n\n\n\n\n\n\n\n\ne","0,1\n\n\n\n\n\n\n\n\ne"],["0,0"]]}}
''';

String s(int kc) => Keycode.serialize(kc);

Uint8List hex(String h) {
  final out = Uint8List(h.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(h.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

class SimulatedDevice {
  // sequence of keyboard communications, pairs of (request, response)
  final List<(Uint8List, Uint8List)> expectData = [];
  // current index in communications
  int expectIdx = 0;

  void expectRaw(Object inp, Object out) {
    final i = inp is String ? hex(inp) : Uint8List.fromList(inp as List<int>);
    final o = out is String ? hex(out) : Uint8List.fromList(out as List<int>);
    expectData.add((i, padTo(o, msgLen)));
  }

  void expectViaProtocol(int viaProtocol) {
    expectRaw('01', ByteWriter().u8(1).u16be(viaProtocol).build());
  }

  void expectKeyboardId(int kbid) {
    expectRaw('FE00', ByteWriter().u32le(0).u64le(kbid).build());
  }

  void expectLayout(String layout) {
    final compressed = XZEncoder().encodeBytes(utf8.encode(layout));
    expectRaw('FE01', ByteWriter().u32le(compressed.length).build());
    var idx = 0;
    for (final chunk in chunks(Uint8List.fromList(compressed), 32)) {
      expectRaw(ByteWriter().u8(0xFE).u8(0x02).u32le(idx).build(), chunk);
      idx++;
    }
  }

  void expectLayers(int layers) {
    expectRaw('11', [0x11, layers]);
  }

  void expectKeymap(List<List<List<int>>> keymap) {
    final buffer = ByteWriter();
    for (final layer in keymap) {
      for (final row in layer) {
        for (final col in row) {
          buffer.u16be(col);
        }
      }
    }
    // client will retrieve our keymap buffer in chunks of 28 bytes
    var x = 0;
    for (final chunk in chunks(buffer.build(), 28)) {
      final query = ByteWriter().u8(0x12).u16be(x).u8(chunk.length).build();
      expectRaw(query, [...query, ...chunk]);
      x++;
    }
  }

  void expectEncoders(List<List<(int, int)>> encoders) {
    for (var l = 0; l < encoders.length; l++) {
      for (var e = 0; e < encoders[l].length; e++) {
        final enc = encoders[l][e];
        expectRaw([
          0xFE,
          3,
          l,
          e,
        ], ByteWriter().u16be(enc.$1).u16be(enc.$2).build());
      }
    }
  }

  Future<Uint8List> simSend(Uint8List data, {int retries = 1}) async {
    if (expectIdx >= expectData.length) {
      throw StateError(
        'Trying to communicate more times (${expectIdx + 1}) than expected '
        '(${expectData.length}); got data=${_hex(data)}',
      );
    }
    final (inp, out) = expectData[expectIdx];
    if (!_eq(data, inp)) {
      throw StateError(
        'Got unexpected data at index $expectIdx: expected=${_hex(inp)} with '
        'result=${_hex(out)} got=${_hex(data)}',
      );
    }
    expectIdx++;
    return out;
  }

  void finish() {
    if (expectIdx != expectData.length) {
      throw StateError(
        "Didn't communicate all the way, remaining data = "
        '${expectData.sublist(expectIdx).map((e) => _hex(e.$1)).toList()}',
      );
    }
  }
}

String _hex(List<int> d) =>
    d.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

bool _eq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

Future<(Keyboard, SimulatedDevice)> prepareKeyboard(
  String layout,
  List<List<List<int>>> keymap, [
  List<List<(int, int)>>? encoders,
]) async {
  final dev = SimulatedDevice();
  dev.expectViaProtocol(9);
  dev.expectKeyboardId(0);
  dev.expectLayout(layout);
  dev.expectLayers(keymap.length);

  // macro count
  dev.expectRaw('0C', '0C00');
  // macro buffer size
  dev.expectRaw('0D', '0D0000');

  dev.expectKeymap(keymap);
  if (encoders != null) dev.expectEncoders(encoders);

  final kb = Keyboard(null, usbSend: dev.simSend);
  await kb.reload();

  return (kb, dev);
}

const keymap2x2 = [
  [
    [1, 2],
    [3, 4],
  ],
  [
    [5, 6],
    [7, 8],
  ],
];

const keymapEncoder = [
  [
    [1],
  ],
  [
    [2],
  ],
  [
    [3],
  ],
  [
    [4],
  ],
];

const encoders4 = [
  [(10, 11)],
  [(12, 13)],
  [(14, 15)],
  [(16, 17)],
];

void main() {
  setUpAll(Keycode.ensureInitialized);

  test('keyboard layout', () async {
    // Tests that loading a layout from a keyboard works
    final (kb, dev) = await prepareKeyboard(layout2x2, keymap2x2);
    expect(kb.layers, 2);
    expect(kb.layout[(0, 0, 0)], s(1));
    expect(kb.layout[(0, 0, 1)], s(2));
    expect(kb.layout[(0, 1, 0)], s(3));
    expect(kb.layout[(0, 1, 1)], s(4));
    expect(kb.layout[(1, 0, 0)], s(5));
    expect(kb.layout[(1, 0, 1)], s(6));
    expect(kb.layout[(1, 1, 0)], s(7));
    expect(kb.layout[(1, 1, 1)], s(8));
    dev.finish();
  });

  test('set key', () async {
    // Tests that setting a key works
    final (kb, dev) = await prepareKeyboard(layout2x2, keymap2x2);
    dev.expectRaw('050101000009', '');
    await kb.setKey(1, 1, 0, s(9));
    expect(kb.layout[(1, 1, 0)], s(9));

    dev.finish();
  });

  test('set key twice', () async {
    // Tests that setting a key twice is optimized (doesn't send 2 cmds)
    final (kb, dev) = await prepareKeyboard(layout2x2, keymap2x2);
    dev.expectRaw('050101000009', '');
    await kb.setKey(1, 1, 0, s(9));
    await kb.setKey(1, 1, 0, s(9));
    expect(kb.layout[(1, 1, 0)], s(9));

    dev.finish();
  });

  test('layout save restore', () async {
    // Tests that layout saving and restore works
    var (kb, dev) = await prepareKeyboard(layout2x2, keymap2x2);
    dev.expectRaw('05010100000A', '');
    await kb.setKey(1, 1, 0, Keycode.serialize(10));
    expect(kb.layout[(1, 1, 0)], Keycode.serialize(10));
    final data = kb.saveLayout();
    dev.finish();

    (kb, dev) = await prepareKeyboard(layout2x2, keymap2x2);
    dev.expectRaw('05010100000A', '');
    await kb.restoreLayout(data);
    expect(kb.layout[(1, 1, 0)], Keycode.serialize(10));
    dev.finish();
  });

  test('encoder simple', () async {
    // Tests that we try to retrieve encoder layout
    final (kb, dev) = await prepareKeyboard(
      layoutEncoder,
      keymapEncoder,
      encoders4,
    );
    expect(kb.encoderLayout[(0, 0, 0)], Keycode.serialize(10));
    expect(kb.encoderLayout[(0, 0, 1)], Keycode.serialize(11));
    expect(kb.encoderLayout[(1, 0, 0)], Keycode.serialize(12));
    expect(kb.encoderLayout[(1, 0, 1)], Keycode.serialize(13));
    expect(kb.encoderLayout[(2, 0, 0)], Keycode.serialize(14));
    expect(kb.encoderLayout[(2, 0, 1)], Keycode.serialize(15));
    expect(kb.encoderLayout[(3, 0, 0)], Keycode.serialize(16));
    expect(kb.encoderLayout[(3, 0, 1)], Keycode.serialize(17));
    dev.finish();
  });

  test('encoder change', () async {
    // Test that changing encoder works
    final (kb, dev) = await prepareKeyboard(
      layoutEncoder,
      keymapEncoder,
      encoders4,
    );
    expect(kb.encoderLayout[(1, 0, 0)], Keycode.serialize(12));
    expect(kb.encoderLayout[(1, 0, 1)], Keycode.serialize(13));
    dev.expectRaw('FE040100010020', '');
    await kb.setEncoder(1, 0, 1, Keycode.serialize(0x20));
    expect(kb.encoderLayout[(1, 0, 1)], Keycode.serialize(0x20));
    dev.finish();
  });

  test('uid keeps 64-bit precision in saved layout', () async {
    final (kb, dev) = await prepareKeyboard(layout2x2, keymap2x2);
    kb.keyboardId = BigInt.parse('BED2D31EC59A0BD8', radix: 16);
    final data = kb.saveLayout();
    expect(Keyboard.parseLayoutUid(data), kb.keyboardId);
    dev.finish();
  });
}
