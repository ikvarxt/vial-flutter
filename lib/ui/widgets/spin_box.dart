import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Integer entry with ▲/▼ steppers, standing in for `QSpinBox`.
class SpinBox extends StatefulWidget {
  const SpinBox({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.width = 90,
    this.enabled = true,
  });

  final int value;
  final int min;
  final int max;
  final double width;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  State<SpinBox> createState() => _SpinBoxState();
}

class _SpinBoxState extends State<SpinBox> {
  late final TextEditingController _ctrl;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.value}');
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit(_ctrl.text);
    });
  }

  @override
  void didUpdateWidget(covariant SpinBox old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !_focus.hasFocus) {
      _ctrl.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _set(int v) {
    final c = v.clamp(widget.min, widget.max);
    _ctrl.text = '$c';
    if (c != widget.value) widget.onChanged(c);
  }

  void _commit(String text) {
    final v = int.tryParse(text.trim());
    _set(v ?? widget.value);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
              ),
              onSubmitted: _commit,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Stepper(
                icon: Icons.arrow_drop_up,
                onTap: widget.enabled ? () => _set(widget.value + 1) : null,
              ),
              _Stepper(
                icon: Icons.arrow_drop_down,
                onTap: widget.enabled ? () => _set(widget.value - 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        width: 20,
        height: 15,
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? p.disabledText : p.muted,
        ),
      ),
    );
  }
}
