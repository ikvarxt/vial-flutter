// SPDX-License-Identifier: GPL-2.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';

import '../../hid/vial_device.dart';
import '../../protocol/constants.dart';
import '../../protocol/keyboard.dart';
import '../dialogs/unlocker_dialog.dart';
import '../widgets/keyboard_widget.dart';
import 'basic_editor.dart';
import 'layout_editor.dart';

/// Matrix tester tab: polls the switch matrix and lights up pressed keys.
class MatrixTest extends BasicEditor {
  MatrixTest(this.layoutEditor) {
    kb = KeyboardWidgetController(layoutChoice: layoutEditor.getChoice);
    kb.enabled = false;
  }

  final LayoutEditor layoutEditor;
  late final KeyboardWidgetController kb;
  Keyboard? keyboard;
  Timer? _timer;
  bool _polling = false;
  bool _unlockVisible = false;

  @override
  String get label => 'Matrix tester';

  @override
  bool valid() {
    final d = device;
    if (d is! VialKeyboard || d.keyboard == null) return false;
    final k = d.keyboard!;
    return k.vialProtocol >= vialProtocolMatrixTester &&
        (k.cols ~/ 8 + 1) * k.rows <= 28;
  }

  @override
  Future<void> rebuild(VialDevice? device) async {
    await super.rebuild(device);
    if (valid()) {
      keyboard = (device as VialKeyboard).keyboard;
      kb.setKeys(keyboard!.keys, keyboard!.encoders);
    } else {
      keyboard = null;
    }
    notifyListeners();
  }

  @override
  void activate() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 20), (_) => _poll());
  }

  @override
  void deactivate() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    final k = keyboard;
    if (k == null || _polling) return;
    _polling = true;
    try {
      final unlocked = await k.getUnlockStatus(retries: 3);
      if (unlocked != 1) {
        if (!_unlockVisible) {
          _unlockVisible = true;
          notifyListeners();
        }
        return;
      }
      if (_unlockVisible) {
        _unlockVisible = false;
        notifyListeners();
      }
      final raw = await k.matrixPoll();
      if (raw == null) return;
      final data = raw.sublist(2);
      final rowSize = (k.cols / 8).ceil();
      for (final w in kb.widgets) {
        final row = w.desc.row;
        final col = w.desc.col;
        if (row == null || col == null) continue;
        final start = row * rowSize;
        if (start + rowSize > data.length) continue;
        final rowData = data.sublist(start, start + rowSize);
        final colByte = rowData.length - 1 - col ~/ 8;
        if (colByte < 0) continue;
        final bit = (rowData[colByte] >> (col % 8)) & 1;
        w.pressed = bit == 1;
        if (bit == 1) w.on = true;
      }
      kb.refresh();
    } catch (_) {
      deactivate();
    } finally {
      _polling = false;
    }
  }

  void _reset() {
    for (final w in kb.widgets) {
      w.pressed = false;
      w.on = false;
    }
    kb.refresh();
  }

  Future<void> _unlock() async {
    final k = keyboard;
    if (k == null) return;
    await Unlocker.unlock(k);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Center(child: KeyboardWidget(controller: kb)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_unlockVisible) ...[
                const Text('Unlock the keyboard before testing:'),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: _unlock, child: const Text('Unlock')),
                const SizedBox(width: 8),
              ],
              OutlinedButton(onPressed: _reset, child: const Text('Reset')),
            ],
          ),
        ),
      ],
    );
  }
}
