// SPDX-License-Identifier: GPL-2.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';

import '../../protocol/keyboard.dart';
import '../app_globals.dart';
import '../theme.dart';
import '../widgets/keyboard_widget.dart';

/// Modal that guides the user through the physical unlock combination.
class Unlocker {
  Unlocker._();

  /// Supplies the layout option chooser so the reference picture matches the
  /// keymap editor; set by the layout editor.
  static int Function(int layoutIndex)? layoutChoice;

  /// Installed as [Keyboard.unlocker]; resolves once unlocked.
  static Future<void> unlock(Keyboard keyboard) async {
    if (await keyboard.getUnlockStatus() == 1) return;
    UiLock.instance.lock();
    try {
      final ctx = rootContext;
      if (!ctx.mounted) return;
      await showDialog<void>(
        context: ctx,
        barrierDismissible: false,
        builder: (_) => _UnlockerDialog(keyboard: keyboard),
      );
    } finally {
      UiLock.instance.unlock();
    }
  }
}

class _UnlockerDialog extends StatefulWidget {
  const _UnlockerDialog({required this.keyboard});

  final Keyboard keyboard;

  @override
  State<_UnlockerDialog> createState() => _UnlockerDialogState();
}

class _UnlockerDialogState extends State<_UnlockerDialog> {
  final KeyboardWidgetController _ref = KeyboardWidgetController(
    layoutChoice: Unlocker.layoutChoice,
  );
  Timer? _timer;
  int _max = 1;
  int _value = 0;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _ref.enabled = false;
    _ref.scale = 0.5;
    _updateReference();
    _performUnlock();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ref.dispose();
    super.dispose();
  }

  Future<void> _updateReference() async {
    _ref.setKeys(widget.keyboard.keys, widget.keyboard.encoders);
    final lockKeys = await widget.keyboard.getUnlockKeys();
    for (final w in _ref.widgets) {
      if (lockKeys.contains((w.desc.row ?? -1, w.desc.col ?? -1))) {
        w.on = true;
      }
    }
    _ref.updateLayout();
  }

  Future<void> _performUnlock() async {
    _max = 1;
    _value = 0;
    await widget.keyboard.unlockStart();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) => _poll());
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final data = await widget.keyboard.unlockPoll();
      final unlocked = data[0];
      final counter = data[2];
      if (!mounted) return;
      setState(() {
        if (counter > _max) _max = counter;
        _value = _max - counter;
      });
      if (unlocked == 1) {
        _timer?.cancel();
        if (mounted) Navigator.of(context).pop();
      }
    } catch (_) {
      // transient HID errors: keep polling
    } finally {
      _polling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: lighter(p.button, 130),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'In order to proceed, the keyboard must be set into unlocked mode.\n'
                'You should only perform this operation on computers that you trust.',
              ),
              const SizedBox(height: 8),
              const Text(
                'To exit this mode, you will need to replug the keyboard\n'
                'or select Security->Lock from the menu.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Press and hold the following keys until the progress bar below fills up:',
              ),
              const SizedBox(height: 12),
              Center(child: KeyboardWidget(controller: _ref)),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _max == 0 ? 0 : (_value / _max).clamp(0, 1),
                minHeight: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
