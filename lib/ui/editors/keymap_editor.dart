// SPDX-License-Identifier: GPL-2.0-or-later
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../hid/vial_device.dart';
import '../../keycodes/keycode.dart';
import '../../protocol/keyboard.dart';
import '../app_globals.dart';
import '../dialogs/any_keycode_dialog.dart';
import '../keycode_display.dart';
import '../widgets/keyboard_widget.dart';
import '../widgets/square_button.dart';
import '../widgets/tabbed_keycodes.dart';
import 'basic_editor.dart';
import 'layout_editor.dart';

/// The main keymap tab: layer selector, keyboard canvas and the embedded
/// keycode picker underneath.
class KeymapEditor extends BasicEditor {
  KeymapEditor(this.layoutEditor) {
    kb = KeyboardWidgetController(layoutChoice: layoutEditor.getChoice);
    kb.onClicked = _onKeyClicked;
    kb.onDeselected = _onKeyDeselected;
    kb.onAnykey = onAnyKeycode;
    layoutEditor.onChanged = onLayoutChanged;
    KeycodeDisplay.notifier.addListener(refreshLayerDisplay);
  }

  final LayoutEditor layoutEditor;
  late final KeyboardWidgetController kb;
  Keyboard? keyboard;
  int currentLayer = 0;
  KeycodeFilter _filter = keycodeFilterAny;
  int _generation = 0;

  @override
  String get label => 'Keymap';

  @override
  void dispose() {
    KeycodeDisplay.notifier.removeListener(refreshLayerDisplay);
    kb.dispose();
    super.dispose();
  }

  @override
  bool valid() => device is VialKeyboard;

  @override
  Future<void> rebuild(VialDevice? device) async {
    await super.rebuild(device);
    if (valid()) {
      keyboard = (device as VialKeyboard).keyboard;
      kb.setKeys(keyboard!.keys, keyboard!.encoders);
      currentLayer = 0;
      onLayoutChanged();
      _generation++;
    } else {
      keyboard = null;
    }
    notifyListeners();
  }

  @override
  void onContainerClicked() {
    kb.deselect();
    kb.refresh();
  }

  void switchLayer(int idx) {
    kb.deselect();
    currentLayer = idx;
    refreshLayerDisplay();
  }

  void adjustSize(bool minus) {
    final s = kb.scale + (minus ? -0.1 : 0.1);
    kb.setScale(s < 0.1 ? 0.1 : s);
    refreshLayerDisplay();
  }

  String codeForWidget(KeyModel widget) {
    final d = widget.desc;
    if (d.row != null) {
      return keyboard!.layout[(currentLayer, d.row!, d.col!)] ?? 'KC_NO';
    }
    return keyboard!.encoderLayout[(
          currentLayer,
          d.encoderIdx!,
          d.encoderDir!,
        )] ??
        'KC_NO';
  }

  /// Refresh text on key widgets to display data of the current layer.
  void refreshLayerDisplay() {
    if (keyboard == null) return;
    kb.updateLayout();
    for (final w in [...kb.commonWidgets, ...kb.widgetsForLayout]) {
      KeycodeDisplay.displayKeycode(w, codeForWidget(w));
    }
    kb.refresh();
    notifyListeners();
  }

  Future<void> setKey(String keycode) async {
    final active = kb.activeKey;
    if (keyboard == null || active == null) return;
    final l = currentLayer;
    final d = active.desc;
    if (active is EncoderModel) {
      await keyboard!.setEncoder(l, d.encoderIdx!, d.encoderDir!, keycode);
    } else if (d.row != null && d.col != null) {
      var kc = keycode;
      if (kb.activeMask) {
        final outer = Keycode.findOuterKeycode(codeForWidget(active));
        if (outer == null) return;
        kc = outer.qmkId.replaceAll('(kc)', '($keycode)');
      }
      await keyboard!.setKey(l, d.row!, d.col!, kc);
    }
    refreshLayerDisplay();
    kb.selectNext();
  }

  void onKeycodeChanged(String code) => setKey(code);

  Future<void> onAnyKeycode() async {
    final active = kb.activeKey;
    if (active == null) return;
    var current = codeForWidget(active);
    if (kb.activeMask) {
      current = Keycode.findInnerKeycode(current)?.qmkId ?? current;
    }
    final result = await showAnyKeycodeDialog(rootContext, current);
    if (result != null) await setKey(result);
  }

  void _onKeyClicked() {
    refreshLayerDisplay();
    _filter = kb.activeMask ? keycodeFilterMasked : keycodeFilterAny;
    notifyListeners();
  }

  void _onKeyDeselected() {
    _filter = keycodeFilterAny;
    notifyListeners();
  }

  void onLayoutChanged() {
    final k = keyboard;
    if (k == null) return;
    refreshLayerDisplay();
    k.setLayoutOptions(layoutEditor.pack());
  }

  Uint8List saveLayout() => keyboard!.saveLayout();

  Future<void> restoreLayout(Uint8List data) async {
    final k = keyboard;
    if (k == null) return;
    final uid = Keyboard.parseLayoutUid(data);
    if (uid != k.keyboardId) {
      final ok = await showQuestion(
        'Saved keymap belongs to a different keyboard,'
        ' are you sure you want to continue?',
      );
      if (!ok) return;
    }
    await k.restoreLayout(data);
  }

  @override
  Widget build(BuildContext context) {
    final k = keyboard;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 7, right: 10),
                        child: Text(
                          'Layer',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (var x = 0; x < (k?.layers ?? 0); x++)
                              SquareButton(
                                text: '$x',
                                relSize: 1.667,
                                checked: x == currentLayer,
                                enabled: x != currentLayer,
                                onPressed: () => switchLayer(x),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SquareButton(
                        text: '-',
                        relSize: 1.667,
                        tooltip: 'Zoom out',
                        onPressed: () => adjustSize(true),
                      ),
                      const SizedBox(width: 4),
                      SquareButton(
                        text: '+',
                        relSize: 1.667,
                        tooltip: 'Zoom in',
                        onPressed: () => adjustSize(false),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Center(child: KeyboardWidget(controller: kb)),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: keycodePickerHeight(constraints.maxHeight),
            child: TabbedKeycodes(
              filter: _filter,
              onKeycodeChanged: onKeycodeChanged,
              onAnykey: onAnyKeycode,
              generation: _generation,
            ),
          ),
        ],
      ),
    );
  }
}
