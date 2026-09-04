import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../file_io.dart';

/// Multi-line text editor dialog with copy/paste and Ctrl+O / Ctrl+S
/// import/export. Returns the text on Apply, null on Cancel.
Future<String?> showTextboxDialog(
  BuildContext context, {
  String text = '',
  String fileExtension = 'txt',
  String fileType = 'Text file',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextboxDialog(
      text: text,
      fileExtension: fileExtension,
      fileType: fileType,
    ),
  );
}

class _TextboxDialog extends StatefulWidget {
  const _TextboxDialog({
    required this.text,
    required this.fileExtension,
    required this.fileType,
  });

  final String text;
  final String fileExtension;
  final String fileType;

  @override
  State<_TextboxDialog> createState() => _TextboxDialogState();
}

class _TextboxDialogState extends State<_TextboxDialog> {
  late final TextEditingController _ctl;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.text);
    _ctl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.text.length,
    );
  }

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    final sel = _ctl.selection;
    final text = sel.isValid && !sel.isCollapsed
        ? sel.textInside(_ctl.text)
        : _ctl.text;
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text;
    if (t == null) return;
    final sel = _ctl.selection;
    final base = sel.isValid ? sel.start : _ctl.text.length;
    final ext = sel.isValid ? sel.end : _ctl.text.length;
    final newText = _ctl.text.replaceRange(base, ext, t);
    _ctl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: base + t.length),
    );
  }

  Future<void> _export() async {
    await saveFile(
      fileName: 'export.${widget.fileExtension}',
      bytes: Uint8List.fromList(utf8.encode(_ctl.text)),
      extension: widget.fileExtension,
      dialogTitle: widget.fileType,
    );
  }

  Future<void> _import() async {
    final f = await pickFile(
      extension: widget.fileExtension,
      dialogTitle: widget.fileType,
    );
    if (f == null) return;
    _ctl.text = utf8.decode(f.bytes, allowMalformed: true);
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.keyO, control: true):
            const _ImportIntent(),
        const SingleActivator(LogicalKeyboardKey.keyO, meta: true):
            const _ImportIntent(),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            const _ExportIntent(),
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
            const _ExportIntent(),
      },
      child: Actions(
        actions: {
          _ImportIntent: CallbackAction<_ImportIntent>(
            onInvoke: (_) => _import(),
          ),
          _ExportIntent: CallbackAction<_ExportIntent>(
            onInvoke: (_) => _export(),
          ),
        },
        child: Dialog(
          child: SizedBox(
            width: 640,
            height: 480,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctl,
                      focusNode: _focus,
                      autofocus: true,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: _copy,
                        child: const Text('Copy'),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        onPressed: _paste,
                        child: const Text('Paste'),
                      ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context, _ctl.text),
                        child: const Text('Apply'),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImportIntent extends Intent {
  const _ImportIntent();
}

class _ExportIntent extends Intent {
  const _ExportIntent();
}
