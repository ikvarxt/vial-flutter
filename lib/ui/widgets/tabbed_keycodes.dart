import 'package:flutter/material.dart';

import '../../keycodes/keycode.dart';
import '../../keycodes/keycode_defs.dart';
import '../constants.dart';
import '../display_keyboard_defs.dart';
import '../keycode_display.dart';
import 'display_keyboard.dart';
import 'square_button.dart';

typedef KeycodeFilter = bool Function(String qmkId);

bool keycodeFilterAny(String kc) => true;

bool keycodeFilterMasked(String kc) => Keycode.isBasic(kc);

/// Something that can receive keycodes from the shared tray.
abstract class KeycodeTarget {
  void onKeycodeChanged(String keycode);
  void onAnykey();
  void deselect();
}

/// Singleton controller of the bottom keycode tray.
class KeycodeTray extends ChangeNotifier {
  KeycodeTray._();

  static final KeycodeTray instance = KeycodeTray._();

  KeycodeTarget? target;
  KeycodeFilter filter = keycodeFilterAny;
  bool visible = false;

  void open(KeycodeTarget newTarget, [KeycodeFilter? keycodeFilter]) {
    filter = keycodeFilter ?? keycodeFilterAny;
    visible = true;
    if (target != null && target != newTarget) target!.deselect();
    target = newTarget;
    notifyListeners();
  }

  void close() {
    target?.deselect();
    target = null;
    visible = false;
    notifyListeners();
  }

  void onKeycodeChanged(String kc) => target?.onKeycodeChanged(kc);

  void onAnykey() => target?.onAnykey();
}

class _Alternative {
  const _Alternative(this.kbdef, this.keycodes);
  final String? kbdef;
  final List<Keycode> keycodes;
}

class _TabDef {
  const _TabDef(this.label, this.alternatives, {this.anyButton = false});
  final String label;
  final List<_Alternative> alternatives;
  final bool anyButton;
}

List<Keycode> _cat(List<List<Keycode>> lists) => [for (final l in lists) ...l];

List<_TabDef> _buildTabDefs() => [
  _TabDef('Basic', [
    _Alternative(displayDefAnsi100, _cat([keycodesSpecial, keycodesShifted])),
    _Alternative(
      displayDefAnsi80,
      _cat([keycodesSpecial, keycodesBasicNumpad, keycodesShifted]),
    ),
    _Alternative(
      displayDefAnsi70,
      _cat([
        keycodesSpecial,
        keycodesBasicNumpad,
        keycodesBasicNav,
        keycodesShifted,
      ]),
    ),
    _Alternative(null, _cat([keycodesSpecial, keycodesBasic, keycodesShifted])),
  ], anyButton: true),
  _TabDef('ISO/JIS', [
    _Alternative(
      displayDefIso100,
      _cat([keycodesSpecial, keycodesShifted, keycodesIsoKr]),
    ),
    _Alternative(
      displayDefIso80,
      _cat([
        keycodesSpecial,
        keycodesBasicNumpad,
        keycodesShifted,
        keycodesIsoKr,
      ]),
    ),
    _Alternative(
      displayDefIso70,
      _cat([
        keycodesSpecial,
        keycodesBasicNumpad,
        keycodesBasicNav,
        keycodesShifted,
        keycodesIsoKr,
      ]),
    ),
    _Alternative(null, keycodesIso),
  ], anyButton: true),
  _TabDef('Layers', [_Alternative(null, keycodesLayers)]),
  _TabDef('Quantum', [
    _Alternative(displayDefMods, _cat([keycodesBoot, keycodesQuantum])),
    _Alternative(displayDefModsNarrow, _cat([keycodesBoot, keycodesQuantum])),
    _Alternative(
      null,
      _cat([keycodesBoot, keycodesModifiers, keycodesQuantum]),
    ),
  ]),
  _TabDef('Backlight', [_Alternative(null, keycodesBacklight)]),
  _TabDef('App, Media and Mouse', [_Alternative(null, keycodesMedia)]),
  _TabDef('MIDI', [_Alternative(null, keycodesMidi)]),
  _TabDef('Tap Dance', [_Alternative(null, keycodesTapDance)]),
  _TabDef('User', [_Alternative(null, keycodesUser)]),
  _TabDef('Macro', [_Alternative(null, keycodesMacro)]),
];

/// Tabbed keycode picker honoring a keycode filter.
class FilteredTabbedKeycodes extends StatefulWidget {
  const FilteredTabbedKeycodes({
    super.key,
    required this.filter,
    required this.onKeycodeChanged,
    required this.onAnykey,
    this.generation = 0,
  });

  final KeycodeFilter filter;
  final void Function(String keycode) onKeycodeChanged;
  final VoidCallback onAnykey;

  /// Bump to force button regeneration after keyboard keycodes changed.
  final int generation;

  @override
  State<FilteredTabbedKeycodes> createState() => _FilteredTabbedKeycodesState();
}

class _VisibleTab {
  _VisibleTab(this.def, this.buttons);
  final _TabDef def;

  /// Per alternative, the keycodes surviving hidden/filter checks.
  final List<List<Keycode>> buttons;

  bool get hasButtons => buttons.any((b) => b.isNotEmpty);
}

class _FilteredTabbedKeycodesState extends State<FilteredTabbedKeycodes>
    with TickerProviderStateMixin {
  List<_VisibleTab> _tabs = [];
  TabController? _tabController;
  String _currentLabel = '';

  @override
  void initState() {
    super.initState();
    KeycodeDisplay.notifier.addListener(_relabel);
    _recreate();
  }

  @override
  void didUpdateWidget(covariant FilteredTabbedKeycodes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.generation != widget.generation ||
        oldWidget.filter != widget.filter) {
      _recreate();
    }
  }

  @override
  void dispose() {
    KeycodeDisplay.notifier.removeListener(_relabel);
    _tabController?.dispose();
    super.dispose();
  }

  void _relabel() {
    if (mounted) setState(() {});
  }

  void _recreate() {
    final prev = _currentLabel;
    final tabs = <_VisibleTab>[];
    for (final def in _buildTabDefs()) {
      final buttons = <List<Keycode>>[];
      for (final alt in def.alternatives) {
        buttons.add([
          for (final kc in alt.keycodes)
            if (!kc.hidden && widget.filter(kc.qmkId)) kc,
        ]);
      }
      final vt = _VisibleTab(def, buttons);
      if (vt.hasButtons) tabs.add(vt);
    }
    var index = tabs.indexWhere((t) => t.def.label == prev);
    if (index < 0) index = 0;
    _tabController?.dispose();
    _tabController = TabController(
      length: tabs.length,
      vsync: this,
      initialIndex: tabs.isEmpty ? 0 : index,
    );
    _tabController!.addListener(() {
      if (_tabController!.indexIsChanging) return;
      _currentLabel = _tabs[_tabController!.index].def.label;
    });
    _tabs = tabs;
    _currentLabel = tabs.isEmpty ? '' : tabs[index].def.label;
    setState(() {});
  }

  void _emit(String code) {
    if (code == 'Any') {
      widget.onAnykey();
    } else {
      widget.onKeycodeChanged(Keycode.normalize(code));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tabs.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelPadding: const EdgeInsets.symmetric(horizontal: 12),
          tabs: [for (final t in _tabs) Tab(height: 32, text: t.def.label)],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              for (final t in _tabs) _KeycodeTab(tab: t, onKeycode: _emit),
            ],
          ),
        ),
      ],
    );
  }
}

class _KeycodeTab extends StatelessWidget {
  const _KeycodeTab({required this.tab, required this.onKeycode});

  final _VisibleTab tab;
  final void Function(String) onKeycode;

  static const double _scrollbarWidth = 14;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final avail = constraints.maxWidth - _scrollbarWidth;
        var chosen = -1;
        for (var i = 0; i < tab.def.alternatives.length; i++) {
          final kb = tab.def.alternatives[i].kbdef;
          final required = kb == null ? 0.0 : DisplayKeyboard.requiredWidth(kb);
          if (avail > required) {
            chosen = i;
            break;
          }
        }
        if (chosen < 0) return const SizedBox.shrink();
        final alt = tab.def.alternatives[chosen];
        final buttons = tab.buttons[chosen];
        final controller = ScrollController();
        return Scrollbar(
          controller: controller,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(4, 6, _scrollbarWidth, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (alt.kbdef != null)
                  Center(
                    child: DisplayKeyboard(
                      kbdef: alt.kbdef!,
                      onKeycode: onKeycode,
                    ),
                  ),
                if (alt.kbdef != null) const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (tab.def.anyButton)
                      SquareButton(
                        text: 'Any',
                        relSize: keycodeBtnRatio,
                        onPressed: () => onKeycode('Any'),
                      ),
                    for (final kc in buttons)
                      Builder(
                        builder: (context) {
                          final (label, link) = KeycodeDisplay.buttonLabel(kc);
                          return SquareButton(
                            text: label,
                            relSize: keycodeBtnRatio,
                            tooltip: Keycode.tooltipOf(kc.qmkId),
                            linkColor: link,
                            wordWrap: true,
                            onPressed: () => onKeycode(kc.qmkId),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Keycode picker that switches between the full set and the basic-only set
/// depending on the active filter.
class TabbedKeycodes extends StatelessWidget {
  const TabbedKeycodes({
    super.key,
    required this.filter,
    required this.onKeycodeChanged,
    required this.onAnykey,
    this.generation = 0,
  });

  final KeycodeFilter filter;
  final void Function(String keycode) onKeycodeChanged;
  final VoidCallback onAnykey;
  final int generation;

  @override
  Widget build(BuildContext context) {
    final masked = filter == keycodeFilterMasked;
    return FilteredTabbedKeycodes(
      key: ValueKey(masked),
      filter: masked ? keycodeFilterMasked : keycodeFilterAny,
      onKeycodeChanged: onKeycodeChanged,
      onAnykey: onAnykey,
      generation: generation,
    );
  }
}

/// The bottom tray driven by [KeycodeTray.instance].
class KeycodeTrayWidget extends StatefulWidget {
  const KeycodeTrayWidget({super.key, this.generation = 0});

  final int generation;

  @override
  State<KeycodeTrayWidget> createState() => _KeycodeTrayWidgetState();
}

class _KeycodeTrayWidgetState extends State<KeycodeTrayWidget> {
  @override
  void initState() {
    super.initState();
    KeycodeTray.instance.addListener(_changed);
  }

  @override
  void dispose() {
    KeycodeTray.instance.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tray = KeycodeTray.instance;
    if (!tray.visible) return const SizedBox.shrink();
    return SizedBox(
      height: 260,
      child: TabbedKeycodes(
        filter: tray.filter,
        onKeycodeChanged: tray.onKeycodeChanged,
        onAnykey: tray.onAnykey,
        generation: widget.generation,
      ),
    );
  }
}
