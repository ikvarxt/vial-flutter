// SPDX-License-Identifier: GPL-2.0-or-later
import 'package:flutter/foundation.dart';

import '../keycodes/keycode.dart';
import '../keymaps/keymap_tables.dart';

/// Per-key legend state shared by the keyboard canvas and its callers.
class KeyLegend {
  bool masked = false;
  String text = '';
  String maskText = '';
  String tooltip = '';
  bool colorOverride = false;
  bool maskColorOverride = false;
}

/// Applies the country-specific keymap override on top of keycode labels and
/// notifies listeners whenever the override changes.
class KeycodeDisplay {
  KeycodeDisplay._();

  static Map<String, String> keymapOverride = keymapTables[0].$2;

  static final ChangeNotifier notifier = _Notifier();

  /// Get label for a specific keycode.
  static String getLabel(String code) {
    if (codeIsOverriden(code)) {
      return keymapOverride[Keycode.findOuterKeycode(code)!.qmkId]!;
    }
    return Keycode.labelOf(code);
  }

  /// Check whether a country-specific keymap overrides a code.
  static bool codeIsOverriden(String code) {
    final key = Keycode.findOuterKeycode(code);
    return key != null && keymapOverride.containsKey(key.qmkId);
  }

  static void displayKeycode(KeyLegend widget, String code) {
    var text = getLabel(code);
    final tooltip = Keycode.tooltipOf(code) ?? '';
    final mask = Keycode.isMask(code);
    var maskText = '';
    final inner = Keycode.findInnerKeycode(code);
    if (inner != null) maskText = getLabel(inner.qmkId);
    if (mask) text = text.split('\n')[0];
    widget.masked = mask;
    widget.text = text;
    widget.maskText = maskText;
    widget.tooltip = tooltip;
    widget.colorOverride = codeIsOverriden(code);
    widget.maskColorOverride =
        inner != null && mask && codeIsOverriden(inner.qmkId);
  }

  static void setKeymapOverride(Map<String, String> override) {
    keymapOverride = override;
    (notifier as _Notifier).fire();
  }

  /// Label for a keycode button in the tabbed keycode picker; the second
  /// element is whether the override color applies.
  static (String, bool) buttonLabel(Keycode keycode) {
    final o = keymapOverride[keycode.qmkId];
    if (o != null) return (o, true);
    return (keycode.label, false);
  }
}

class _Notifier extends ChangeNotifier {
  void fire() => notifyListeners();
}
