import 'package:flutter/material.dart';

import '../../keycodes/keycode.dart';

/// Lets the user type an arbitrary keycode expression; resolves to the
/// serialized keycode or null when cancelled.
Future<String?> showAnyKeycodeDialog(BuildContext context, String initial) {
  return showDialog<String>(
    context: context,
    builder: (_) => _AnyKeycodeDialog(initial: initial),
  );
}

class _AnyKeycodeDialog extends StatefulWidget {
  const _AnyKeycodeDialog({required this.initial});

  final String initial;

  @override
  State<_AnyKeycodeDialog> createState() => _AnyKeycodeDialogState();
}

class _AnyKeycodeDialogState extends State<_AnyKeycodeDialog> {
  late final TextEditingController _ctl;
  String _value = '';
  String _computed = '';

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.initial);
    _ctl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );
    _value = widget.initial;
    _onChange();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _onChange() {
    final text = _ctl.text;
    int? value;
    String? err;
    try {
      value = Keycode.deserialize(text, reraise: true);
    } catch (e) {
      err = e.toString();
    }
    setState(() {
      if (text.isEmpty) {
        _value = '';
        _computed = 'Enter an expression';
      } else if (err != null) {
        _value = '';
        _computed = 'Invalid input: $err';
      } else {
        _value = Keycode.serialize(value!);
        _computed =
            'Computed value: 0x${value.toRadixString(16).toUpperCase()}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter an arbitrary keycode'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _ctl,
              autofocus: true,
              onChanged: (_) => _onChange(),
              onSubmitted: (_) {
                if (_value.isNotEmpty) Navigator.pop(context, _value);
              },
            ),
            const SizedBox(height: 8),
            Text(_computed),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _value.isEmpty
              ? null
              : () => Navigator.pop(context, _value),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
