import 'package:flutter/material.dart';

import '../../hid/vial_device.dart';
import '../../protocol/constants.dart';
import '../../protocol/keyboard.dart';
import '../theme.dart';

String _hex(int v, int width) =>
    v.toRadixString(16).toUpperCase().padLeft(width, '0');

String aboutKeyboardText(VialKeyboard device) {
  final kb = device.keyboard!;
  final desc = device.desc;

  String wantMinVialFw(int ver) {
    if (kb.sideload) return 'unsupported - sideloaded keyboard';
    if (kb.vialProtocol < 0) return 'unsupported - VIA keyboard';
    if (kb.vialProtocol < ver) return 'unsupported - Vial firmware too old';
    return 'unsupported - disabled in firmware';
  }

  String countOr(int count, int ver) =>
      count > 0 ? '$count' : wantMinVialFw(ver);
  String yesOr(int ver) => kb.vialProtocol >= ver ? 'yes' : wantMinVialFw(ver);
  String feature(String name) => kb.supportedFeatures.contains(name)
      ? 'yes'
      : wantMinVialFw(vialProtocolDynamic);
  String qmkSettings() {
    if (kb.vialProtocol >= vialProtocolQmkSettings) {
      return kb.supportedSettings.isEmpty ? 'disabled in firmware' : 'yes';
    }
    return wantMinVialFw(vialProtocolQmkSettings);
  }

  final b = StringBuffer();
  b.writeln('Manufacturer: ${desc.manufacturer}');
  b.writeln('Product: ${desc.product}');
  b.writeln('VID: ${_hex(desc.vendorId, 4)}');
  b.writeln('PID: ${_hex(desc.productId, 4)}');
  b.writeln('Device: ${desc.path}');
  b.writeln();
  if (kb.sideload) {
    b.writeln('Sideloaded JSON, Vial functionality is disabled\n');
  } else if (kb.vialProtocol < 0) {
    b.writeln('VIA keyboard, Vial functionality is disabled\n');
  }
  b.writeln('VIA protocol: ${kb.viaProtocol}');
  b.writeln('Vial protocol: ${kb.vialProtocol}');
  b.writeln(
    'Vial keyboard ID: '
    '${kb.keyboardId.toUnsigned(64).toRadixString(16).toUpperCase().padLeft(8, '0')}',
  );
  b.writeln();
  b.writeln('Macro entries: ${kb.macroCount}');
  b.writeln('Macro memory: ${kb.macroMemory} bytes');
  b.writeln('Macro delays: ${yesOr(vialProtocolAdvancedMacros)}');
  b.writeln('Complex (2-byte) macro keycodes: ${yesOr(vialProtocolExtMacros)}');
  b.writeln();
  b.writeln(
    'Tap Dance entries: ${countOr(kb.tapDanceCount, vialProtocolDynamic)}',
  );
  b.writeln('Combo entries: ${countOr(kb.comboCount, vialProtocolDynamic)}');
  b.writeln(
    'Key Override entries: '
    '${countOr(kb.keyOverrideCount, vialProtocolKeyOverride)}',
  );
  b.writeln(
    'Alt Repeat Key entries: '
    '${countOr(kb.altRepeatKeyCount, vialProtocolKeyOverride)}',
  );
  b.writeln('Caps Word: ${feature('caps_word')}');
  b.writeln('Layer Lock: ${feature('layer_lock')}');
  b.writeln();
  b.writeln('QMK Settings: ${qmkSettings()}');
  return b.toString();
}

Future<void> showAboutKeyboardDialog(
  BuildContext context,
  VialKeyboard device,
) {
  final Keyboard? kb = device.keyboard;
  if (kb == null) return Future.value();
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('About ${device.title}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: SelectableText(
            aboutKeyboardText(device),
            style: const TextStyle(fontFamily: monoFontFamily, fontSize: 12.5),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
