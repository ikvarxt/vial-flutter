import 'dart:convert';
import 'dart:typed_data';

import '../keycodes/keycode.dart';
import '../protocol/constants.dart';
import '../util/bytes.dart';

const int ssQmkPrefix = 1;

const int ssTapCode = 1;
const int ssDownCode = 2;
const int ssUpCode = 3;
const int ssDelayCode = 4;
const int vialMacroExtTap = 5;
const int vialMacroExtDown = 6;
const int vialMacroExtUp = 7;

abstract class BasicAction {
  String get tag;

  Uint8List serialize(int vialProtocol);

  List<Object> save() => [tag];

  void restore(List<Object?> act) {
    if (tag != act[0]) {
      throw StateError(
        'cannot restore $this: expected tag=$tag got tag=${act[0]}',
      );
    }
  }

  @override
  bool operator ==(Object other) => other is BasicAction && tag == other.tag;

  @override
  int get hashCode => tag.hashCode;
}

class ActionText extends BasicAction {
  ActionText([this.text = '']);

  String text;

  @override
  String get tag => 'text';

  @override
  Uint8List serialize(int vialProtocol) =>
      Uint8List.fromList(utf8.encode(text));

  @override
  List<Object> save() => [...super.save(), text];

  @override
  void restore(List<Object?> act) {
    super.restore(act);
    text = act[1] as String;
  }

  @override
  bool operator ==(Object other) => other is ActionText && text == other.text;

  @override
  int get hashCode => Object.hash(tag, text);

  @override
  String toString() => '$tag<$text>';
}

abstract class ActionSequence extends BasicAction {
  ActionSequence([List<String>? sequence]) : sequence = sequence ?? [];

  /// Keycodes in their string (qmk_id) form.
  List<String> sequence;

  int serializePrefix(int kc);

  @override
  Uint8List serialize(int vialProtocol) {
    final out = ByteWriter();
    for (final s in sequence) {
      if (vialProtocol >= vialProtocolAdvancedMacros) out.u8(ssQmkPrefix);
      var kc = Keycode.deserialize(s);
      out.u8(serializePrefix(kc));
      if (kc < 256) {
        out.u8(kc);
      } else {
        // see decode_keycode() in qmk
        if (kc % 256 == 0) kc = 0xFF00 | (kc >> 8);
        out.u16le(kc);
      }
    }
    return out.build();
  }

  @override
  List<Object> save() => [...super.save(), ...sequence];

  @override
  void restore(List<Object?> act) {
    super.restore(act);
    for (final kc in act.sublist(1)) {
      sequence.add(kc is int ? Keycode.serialize(kc) : kc as String);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ActionSequence &&
      tag == other.tag &&
      _listEq(sequence, other.sequence);

  @override
  int get hashCode => Object.hash(tag, Object.hashAll(sequence));

  @override
  String toString() => '$tag<$sequence>';
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class ActionDown extends ActionSequence {
  ActionDown([super.sequence]);

  @override
  String get tag => 'down';

  @override
  int serializePrefix(int kc) => kc >= 256 ? 0x06 : 0x02;
}

class ActionUp extends ActionSequence {
  ActionUp([super.sequence]);

  @override
  String get tag => 'up';

  @override
  int serializePrefix(int kc) => kc >= 256 ? 0x07 : 0x03;
}

class ActionTap extends ActionSequence {
  ActionTap([super.sequence]);

  @override
  String get tag => 'tap';

  @override
  int serializePrefix(int kc) => kc >= 256 ? 0x05 : 0x01;
}

class ActionDelay extends BasicAction {
  ActionDelay([this.delay = 0]);

  int delay;

  @override
  String get tag => 'delay';

  @override
  Uint8List serialize(int vialProtocol) {
    if (vialProtocol < vialProtocolAdvancedMacros) {
      throw StateError('ActionDelay can only be used with vial_protocol>=2');
    }
    return packBytes([
      ssQmkPrefix,
      ssDelayCode,
      (delay % 255) + 1,
      (delay ~/ 255) + 1,
    ]);
  }

  @override
  List<Object> save() => [...super.save(), delay];

  @override
  void restore(List<Object?> act) {
    super.restore(act);
    delay = (act[1] as num).toInt();
  }

  @override
  bool operator ==(Object other) =>
      other is ActionDelay && delay == other.delay;

  @override
  int get hashCode => Object.hash(tag, delay);

  @override
  String toString() => '$tag<$delay>';
}

final Map<String, BasicAction Function()> tagToAction = {
  'down': ActionDown.new,
  'up': ActionUp.new,
  'tap': ActionTap.new,
  'text': ActionText.new,
  'delay': ActionDelay.new,
};

/// Deserialize a single macro, protocol version 1.
List<BasicAction> macroDeserializeV1(List<int> input) {
  final out = <BasicAction>[];
  final sequence = <Object>[];
  var i = 0;
  while (i < input.length) {
    final b = input[i];
    if (b == ssTapCode || b == ssDownCode || b == ssUpCode) {
      if (input.length - i < 2) break;
      final last = sequence.isEmpty ? null : sequence.last;
      if (last is _KcRun && last.code == b) {
        last.keycodes.add(input[i + 1]);
      } else {
        sequence.add(_KcRun(b, [input[i + 1]]));
      }
      i += 2;
    } else {
      final ch = String.fromCharCode(b);
      final last = sequence.isEmpty ? null : sequence.last;
      if (last is StringBuffer) {
        last.write(ch);
      } else {
        sequence.add(StringBuffer(ch));
      }
      i += 1;
    }
  }
  for (final s in sequence) {
    if (s is StringBuffer) {
      out.add(ActionText(s.toString()));
    } else {
      final run = s as _KcRun;
      final codes = [for (final kc in run.keycodes) Keycode.serialize(kc)];
      out.add(_sequenceFor(run.code, codes));
    }
  }
  return out;
}

class _KcRun {
  _KcRun(this.code, this.keycodes);

  final int code;
  final List<int> keycodes;
}

ActionSequence _sequenceFor(int code, List<String> codes) => switch (code) {
  ssTapCode => ActionTap(codes),
  ssDownCode => ActionDown(codes),
  ssUpCode => ActionUp(codes),
  _ => throw ArgumentError('bad sequence code $code'),
};

/// Deserialize a single macro, protocol version 2.
List<BasicAction> macroDeserializeV2(List<int> input) {
  final out = <BasicAction>[];
  final sequence = <Object>[];
  var i = 0;
  while (i < input.length) {
    if (input[i] == ssQmkPrefix) {
      if (input.length - i < 2) break;
      var act = input[i + 1];
      if (act == ssTapCode ||
          act == ssDownCode ||
          act == ssUpCode ||
          act == vialMacroExtTap ||
          act == vialMacroExtDown ||
          act == vialMacroExtUp) {
        int length;
        int kc;
        if (act == ssTapCode || act == ssDownCode || act == ssUpCode) {
          if (input.length - i < 3) break;
          length = 3;
          kc = input[i + 2];
        } else {
          act = switch (act) {
            vialMacroExtTap => ssTapCode,
            vialMacroExtDown => ssDownCode,
            _ => ssUpCode,
          };
          if (input.length - i < 4) break;
          length = 4;
          kc = readU16le(input, i + 2);
          // see decode_keycode() in qmk
          if (kc > 0xFF00) kc = (kc & 0xFF) << 8;
        }
        final last = sequence.isEmpty ? null : sequence.last;
        if (last is _KcRun && last.code == act) {
          last.keycodes.add(kc);
        } else {
          sequence.add(_KcRun(act, [kc]));
        }
        i += length;
      } else if (act == ssDelayCode) {
        if (input.length - i < 4) break;
        final delay = (input[i + 2] - 1) + (input[i + 3] - 1) * 255;
        sequence.add(_Delay(delay));
        i += 4;
      } else {
        // it is clearly malformed, just skip this byte and hope for the best
        i += 2;
      }
    } else {
      final ch = String.fromCharCode(input[i]);
      final last = sequence.isEmpty ? null : sequence.last;
      if (last is StringBuffer) {
        last.write(ch);
      } else {
        sequence.add(StringBuffer(ch));
      }
      i += 1;
    }
  }
  for (final s in sequence) {
    if (s is StringBuffer) {
      out.add(ActionText(s.toString()));
    } else if (s is _KcRun) {
      final codes = [for (final kc in s.keycodes) Keycode.serialize(kc)];
      out.add(_sequenceFor(s.code, codes));
    } else if (s is _Delay) {
      out.add(ActionDelay(s.delay));
    }
  }
  return out;
}

class _Delay {
  _Delay(this.delay);

  final int delay;
}
