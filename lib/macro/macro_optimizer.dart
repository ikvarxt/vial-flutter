import 'macro_key.dart';

/// Removes exact repetition, i.e. two Down or two Up of the same key.
List<BasicKey> removeRepeats(List<BasicKey> sequence) {
  final out = <BasicKey>[];
  for (final k in sequence) {
    if (out.isNotEmpty && (k is KeyDown || k is KeyUp) && k == out.last) {
      continue;
    }
    out.add(k);
  }
  return out;
}

/// Replaces a sequence of Down/Up with a Tap.
List<BasicKey> replaceWithTap(List<BasicKey> sequence) {
  final out = <BasicKey>[];
  var i = 0;
  while (i < sequence.length) {
    final a = sequence[i];
    if (i + 1 < sequence.length && a is KeyDown) {
      final b = sequence[i + 1];
      if (b is KeyUp && a.keycode == b.keycode) {
        out.add(KeyTap(a.keycode));
        i += 2;
        continue;
      }
    }
    out.add(a);
    i += 1;
  }
  return out;
}

bool isPrintableTap(BasicKey k) =>
    k is KeyTap && (k.keycode.printable ?? '').isNotEmpty;

String getPrintableChar(BasicKey k) => (k as KeyTap).keycode.printable!;

/// Replaces a sequence of printable taps with a sendstring.
List<BasicKey> replaceWithString(List<BasicKey> sequence) {
  final out = <BasicKey>[];
  var i = 0;
  while (i < sequence.length) {
    if (i + 1 < sequence.length &&
        isPrintableTap(sequence[i]) &&
        isPrintableTap(sequence[i + 1])) {
      final cur = StringBuffer()
        ..write(getPrintableChar(sequence[i]))
        ..write(getPrintableChar(sequence[i + 1]));
      i += 2;
      while (i < sequence.length && isPrintableTap(sequence[i])) {
        cur.write(getPrintableChar(sequence[i]));
        i += 1;
      }
      out.add(KeyString(cur.toString()));
    } else {
      out.add(sequence[i]);
      i += 1;
    }
  }
  return out;
}

List<BasicKey> macroOptimize(List<BasicKey> sequence) =>
    replaceWithString(replaceWithTap(removeRepeats(sequence)));
