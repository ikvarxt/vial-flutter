import '../keycodes/keycode.dart';

/// Recorded key events, as produced by the macro recorder before
/// optimisation into [BasicAction]s.
abstract class BasicKey {}

abstract class BasicKeycode extends BasicKey {
  BasicKeycode(this.keycode);

  final Keycode keycode;
}

class KeyDown extends BasicKeycode {
  KeyDown(super.keycode);

  @override
  String toString() => 'Down(${Keycode.labelOf(keycode.qmkId)})';

  @override
  bool operator ==(Object other) =>
      other is KeyDown && other.keycode == keycode;

  @override
  int get hashCode => Object.hash('down', keycode);
}

class KeyUp extends BasicKeycode {
  KeyUp(super.keycode);

  @override
  String toString() => 'Up(${Keycode.labelOf(keycode.qmkId)})';

  @override
  bool operator ==(Object other) => other is KeyUp && other.keycode == keycode;

  @override
  int get hashCode => Object.hash('up', keycode);
}

class KeyTap extends BasicKeycode {
  KeyTap(super.keycode);

  @override
  String toString() => 'Tap(${Keycode.labelOf(keycode.qmkId)})';

  @override
  bool operator ==(Object other) => other is KeyTap && other.keycode == keycode;

  @override
  int get hashCode => Object.hash('tap', keycode);
}

class KeyString extends BasicKey {
  KeyString(this.string);

  final String string;

  @override
  String toString() => 'SendString($string)';

  @override
  bool operator ==(Object other) =>
      other is KeyString && other.string == string;

  @override
  int get hashCode => Object.hash('string', string);
}
