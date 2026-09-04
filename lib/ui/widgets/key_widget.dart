import 'package:flutter/material.dart';

import '../../keycodes/keycode.dart';
import '../../kle/kle_serial.dart';
import '../app_globals.dart';
import '../dialogs/any_keycode_dialog.dart';
import '../keycode_display.dart';
import 'keyboard_widget.dart';
import 'tabbed_keycodes.dart';

/// Single-key picker: click opens the shared keycode tray, double click opens
/// the arbitrary keycode dialog.
class KeyWidgetController extends ChangeNotifier implements KeycodeTarget {
  KeyWidgetController({KeycodeFilter? keycodeFilter, this.onChanged})
    : keycodeFilter = keycodeFilter ?? keycodeFilterAny {
    kb.padding = 1;
    final key = KleKey()
      ..row = 0
      ..col = 0
      ..layoutIndex = -1
      ..layoutOption = -1;
    kb.setKeys([key], []);
    kb.onClicked = _onClicked;
    kb.onDeselected = _onDeselected;
    kb.onAnykey = onAnykey;
    _override = KeycodeDisplay.notifier;
    _override.addListener(updateDisplay);
    updateDisplay();
  }

  final KeyboardWidgetController kb = KeyboardWidgetController();
  KeycodeFilter keycodeFilter;
  VoidCallback? onChanged;
  String keycode = 'KC_NO';
  late final ChangeNotifier _override;

  @override
  void dispose() {
    _override.removeListener(updateDisplay);
    kb.dispose();
    super.dispose();
  }

  void _onClicked() {
    var filter = keycodeFilter;
    if (kb.activeMask) filter = keycodeFilterMasked;
    KeycodeTray.instance.open(this, filter);
  }

  void _onDeselected() {
    if (KeycodeTray.instance.target == this) KeycodeTray.instance.close();
  }

  /// Unlike [setKeycode], this handles setting masked keycode inside the mask.
  @override
  void onKeycodeChanged(String newKeycode) {
    var kc = newKeycode;
    if (kb.activeMask) {
      if (!Keycode.isBasic(kc)) return;
      final outer = Keycode.findOuterKeycode(keycode);
      if (outer == null) return;
      kc = outer.qmkId.replaceAll('(kc)', '($kc)');
    }
    setKeycode(kc);
  }

  @override
  Future<void> onAnykey() async {
    if (kb.activeKey == null) return;
    final String kc;
    if (kb.activeMask) {
      kc = Keycode.findInnerKeycode(keycode)?.qmkId ?? keycode;
    } else {
      kc = keycode;
    }
    final result = await showAnyKeycodeDialog(rootContext, kc);
    if (result != null) onKeycodeChanged(result);
  }

  @override
  void deselect() {
    if (kb.activeKey != null) {
      kb.activeKey = null;
      kb.refresh();
    }
  }

  void updateDisplay() {
    if (kb.widgets.isNotEmpty) {
      KeycodeDisplay.displayKeycode(kb.widgets[0], keycode);
    }
    kb.refresh();
  }

  void setKeycode(String kc) {
    if (kc == keycode) return;
    if (!keycodeFilter(kc)) return;
    keycode = kc;
    updateDisplay();
    onChanged?.call();
    notifyListeners();
  }

  void setKeycodeFilter(KeycodeFilter? filter) {
    keycodeFilter = filter ?? keycodeFilterAny;
  }
}

class KeyWidget extends StatelessWidget {
  const KeyWidget({super.key, required this.controller});

  final KeyWidgetController controller;

  @override
  Widget build(BuildContext context) =>
      KeyboardWidget(controller: controller.kb);
}
