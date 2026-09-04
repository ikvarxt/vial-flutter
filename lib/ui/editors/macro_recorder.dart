import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../hid/vial_device.dart';
import '../../macro/macro_action.dart';
import '../../protocol/constants.dart';
import '../../protocol/keyboard.dart';
import '../dialogs/textbox_dialog.dart';
import '../dialogs/unlocker_dialog.dart';
import '../widgets/key_widget.dart';
import '../widgets/spin_box.dart';
import '../widgets/tab_strip.dart';
import '../widgets/tabbed_keycodes.dart';
import 'basic_editor.dart';

/// One macro action row: UI state for a [BasicAction].
class _ActionUi {
  _ActionUi(this.act, this.onChanged) {
    _recreate();
  }

  BasicAction act;
  final VoidCallback onChanged;
  final List<KeyWidgetController> keys = [];
  KeycodeFilter? _filter;

  String get tag => act.tag;

  void setKeycodeFilter(KeycodeFilter? filter) {
    if (_filter == filter) return;
    _filter = filter;
    for (final k in keys) {
      k.setKeycodeFilter(filter);
    }
  }

  void _recreate() {
    KeycodeTray.instance.close();
    for (final k in keys) {
      k.dispose();
    }
    keys.clear();
    final a = act;
    if (a is ActionSequence) {
      for (final kc in a.sequence) {
        final c = KeyWidgetController(
          keycodeFilter: _filter,
          onChanged: _onSequenceChanged,
        );
        c.setKeycode(kc);
        keys.add(c);
      }
    }
  }

  void _onSequenceChanged() {
    final a = act as ActionSequence;
    for (var x = 0; x < a.sequence.length; x++) {
      final kc = keys[x].keycode;
      if (kc == 'KC_NO') {
        a.sequence.removeAt(x);
        _recreate();
        break;
      }
      a.sequence[x] = kc;
    }
    onChanged();
  }

  void addKey() {
    (act as ActionSequence).sequence.add('KC_TRNS');
    _recreate();
    onChanged();
  }

  /// Switches the action type from the row's dropdown, keeping the sequence
  /// when moving between Down/Up/Tap.
  void changeType(String newTag) {
    if (newTag == tag) return;
    final old = act;
    final created = tagToAction[newTag]!();
    if (old is ActionSequence && created is ActionSequence) {
      created.sequence = List.of(old.sequence);
    }
    act = created;
    _recreate();
    onChanged();
  }

  void dispose() {
    for (final k in keys) {
      k.dispose();
    }
  }
}

class _MacroTab {
  final List<_ActionUi> lines = [];

  List<BasicAction> get actions => [for (final l in lines) l.act];

  void clear() {
    for (final l in lines) {
      l.dispose();
    }
    lines.clear();
  }
}

class MacroRecorder extends BasicEditor {
  Keyboard? keyboard;
  final List<_MacroTab> _tabs = [];
  int _current = 0;
  bool _suppressChange = false;

  @override
  String get label => 'Macros';

  @override
  bool valid() =>
      device is VialKeyboard && (device as VialKeyboard).keyboard != null;

  @override
  Future<void> rebuild(VialDevice? device) async {
    await super.rebuild(device);
    for (final t in _tabs) {
      t.clear();
    }
    _tabs.clear();
    keyboard = null;
    if (!valid()) {
      notifyListeners();
      return;
    }
    keyboard = (device as VialKeyboard).keyboard;
    for (var x = 0; x < keyboard!.macroCount; x++) {
      _tabs.add(_MacroTab());
    }
    _current = 0;
    _deserialize(keyboard!.macro);
    notifyListeners();
  }

  void _onChange() {
    if (_suppressChange) return;
    notifyListeners();
  }

  Uint8List _serialize() =>
      keyboard!.macrosSerialize([for (final t in _tabs) t.actions]);

  void _deserialize(Uint8List data) {
    _suppressChange = true;
    final macros = keyboard!.macrosDeserialize(data);
    for (var x = 0; x < _tabs.length && x < macros.length; x++) {
      _tabs[x].clear();
      for (final act in macros[x]) {
        _addAction(_tabs[x], act);
      }
    }
    _suppressChange = false;
  }

  void _addAction(_MacroTab tab, BasicAction act) {
    final ui = _ActionUi(act, _onChange);
    if (keyboard!.vialProtocol < vialProtocolExtMacros) {
      ui.setKeycodeFilter(keycodeFilterMasked);
    }
    tab.lines.add(ui);
    _onChange();
  }

  void _remove(_MacroTab tab, _ActionUi line) {
    KeycodeTray.instance.close();
    line.dispose();
    tab.lines.remove(line);
    _onChange();
  }

  void _move(_MacroTab tab, _ActionUi line, int offset) {
    final index = tab.lines.indexOf(line);
    final other = index + offset;
    if (other < 0 || other >= tab.lines.length) return;
    tab.lines[index] = tab.lines[other];
    tab.lines[other] = line;
    _onChange();
  }

  bool _tabModified(int x) {
    final macros = _splitNul(keyboard!.macro);
    final current = keyboard!.macroSerialize(_tabs[x].actions);
    final saved = x < macros.length ? macros[x] : <int>[];
    return !_bytesEq(saved, current);
  }

  Future<void> _onTextWindow(BuildContext context, _MacroTab tab) async {
    final macroText = jsonEncode([for (final a in tab.actions) a.save()]);
    var result = await showTextboxDialog(
      context,
      text: macroText,
      fileExtension: 'vim',
      fileType: 'Vial macro',
    );
    if (result == null) return;
    if (result.length < 6) result = '[]';
    final loaded = jsonDecode(result);
    if (loaded is! List) return;
    tab.clear();
    for (final act in loaded) {
      if (act is! List || act.isEmpty) continue;
      final factory = tagToAction[act[0]];
      if (factory == null) continue;
      final obj = factory();
      obj.restore(act.cast<Object?>());
      _addAction(tab, obj);
    }
  }

  Future<void> _onRevert() async {
    final k = keyboard;
    if (k == null) return;
    await k.reloadMacros();
    _deserialize(k.macro);
    _onChange();
  }

  Future<void> _onSave() async {
    final k = keyboard;
    if (k == null) return;
    await Unlocker.unlock(k);
    await k.setMacro(_serialize());
    _onChange();
  }

  List<String> get _typeTags => [
    'text',
    'down',
    'up',
    'tap',
    if (keyboard!.vialProtocol >= vialProtocolAdvancedMacros) 'delay',
  ];

  static const Map<String, String> _typeLabels = {
    'text': 'Text',
    'down': 'Down',
    'up': 'Up',
    'tap': 'Tap',
    'delay': 'Delay (ms)',
  };

  Widget _lineWidget(BuildContext context, _MacroTab tab, _ActionUi line) {
    final a = line.act;
    Widget body;
    if (a is ActionText) {
      body = TextFormField(
        key: ValueKey(line),
        initialValue: a.text,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        onChanged: (v) {
          a.text = v;
          _onChange();
        },
      );
    } else if (a is ActionSequence) {
      body = Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final k in line.keys) KeyWidget(controller: k),
          SizedBox(
            width: 40,
            height: 40,
            child: OutlinedButton(
              onPressed: line.addKey,
              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
              child: const Text('+'),
            ),
          ),
        ],
      );
    } else if (a is ActionDelay) {
      body = Align(
        alignment: Alignment.centerLeft,
        child: SpinBox(
          value: a.delay,
          min: 0,
          max: 64000,
          width: 110,
          onChanged: (v) {
            a.delay = v;
            _onChange();
          },
        ),
      );
    } else {
      body = Text(a.toString());
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _iconBtn(Icons.arrow_drop_up, () => _move(tab, line, -1)),
              _iconBtn(Icons.arrow_drop_down, () => _move(tab, line, 1)),
            ],
          ),
          const SizedBox(width: 4),
          DropdownButton<String>(
            value: line.tag,
            isDense: true,
            items: [
              for (final t in _typeTags)
                DropdownMenuItem(value: t, child: Text(_typeLabels[t]!)),
            ],
            onChanged: (v) {
              if (v != null) line.changeType(v);
            },
          ),
          const SizedBox(width: 8),
          Expanded(child: body),
          const SizedBox(width: 4),
          _iconBtn(Icons.close, () => _remove(tab, line)),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: SizedBox(width: 22, height: 18, child: Icon(icon, size: 18)),
  );

  @override
  Widget build(BuildContext context) {
    final k = keyboard;
    if (k == null || _tabs.isEmpty) return const SizedBox.shrink();
    final data = _serialize();
    final memory = data.length;
    final overflow = memory > k.macroMemory;
    final canSave = !_bytesEq(data, k.macro) && !overflow;
    final tab = _tabs[_current];
    return Column(
      children: [
        TabStrip(
          labels: [
            for (var x = 0; x < _tabs.length; x++)
              'M$x${_tabModified(x) ? '*' : ''}',
          ],
          current: _current,
          onSelected: (i) {
            KeycodeTray.instance.close();
            _current = i;
            notifyListeners();
          },
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final line in tab.lines) _lineWidget(context, tab, line),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: () => _onTextWindow(context, tab),
                child: const Text('Open Text Editor...'),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () => _addAction(tab, ActionText()),
                child: const Text('Add action'),
              ),
              OutlinedButton(
                onPressed: () => _addAction(tab, ActionTap(['KC_ENTER'])),
                child: const Text('Tap Enter'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Text(
                'Memory used by macros: $memory/${k.macroMemory}',
                style: overflow ? const TextStyle(color: Colors.red) : null,
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: canSave ? _onSave : null,
                child: const Text('Save'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _onRevert, child: const Text('Revert')),
            ],
          ),
        ),
      ],
    );
  }
}

List<List<int>> _splitNul(Uint8List data) {
  final out = <List<int>>[];
  var start = 0;
  for (var i = 0; i < data.length; i++) {
    if (data[i] == 0) {
      out.add(data.sublist(start, i));
      start = i + 1;
    }
  }
  out.add(data.sublist(start));
  return out;
}

bool _bytesEq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
