import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../hid/vial_device.dart';
import '../keycodes/keycode.dart';
import '../keymaps/keymap_tables.dart';
import '../protocol/constants.dart';
import '../protocol/keyboard.dart';
import 'app_globals.dart';
import 'app_settings.dart';
import 'autorefresh.dart';
import 'dialogs/about_keyboard_dialog.dart';
import 'dialogs/unlocker_dialog.dart';
import 'editors/alt_repeat_key.dart';
import 'editors/basic_editor.dart';
import 'editors/combos.dart';
import 'editors/firmware_flasher.dart';
import 'editors/key_override.dart';
import 'editors/keymap_editor.dart';
import 'editors/layout_editor.dart';
import 'editors/macro_recorder.dart';
import 'editors/matrix_test.dart';
import 'editors/qmk_settings_editor.dart';
import 'editors/rgb_configurator.dart';
import 'editors/tap_dance.dart';
import 'file_io.dart';
import 'keycode_display.dart';
import 'platform/platform_support.dart';
import 'theme.dart';
import 'widgets/tabbed_keycodes.dart';

const String vialVersion = '0.7.5';

class MainWindow extends StatefulWidget {
  const MainWindow({super.key});

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> {
  final Autorefresh autorefresh = Autorefresh.instance;

  late final LayoutEditor layoutEditor;
  late final KeymapEditor keymapEditor;
  late final List<BasicEditor> editors;

  List<BasicEditor> _tabs = [];
  BasicEditor? _current;
  List<VialDevice> _devices = [];
  int _selectedDevice = -1;
  bool _busy = false;

  VialDevice? get currentDevice => autorefresh.currentDevice;

  Keyboard? get _keyboard {
    final d = currentDevice;
    return d is VialKeyboard ? d.keyboard : null;
  }

  @override
  void initState() {
    super.initState();
    layoutEditor = LayoutEditor();
    keymapEditor = KeymapEditor(layoutEditor);
    editors = [
      keymapEditor,
      layoutEditor,
      MacroRecorder(),
      RgbConfigurator(),
      TapDance(),
      Combos(),
      KeyOverride(),
      AltRepeatKey(),
      QmkSettingsEditor(),
      MatrixTest(layoutEditor),
      if (!kIsWeb) FirmwareFlasher(onDone: onClickRefresh),
    ];
    Unlocker.layoutChoice = layoutEditor.getChoice;
    autorefresh.onDevicesUpdated = _onDevicesUpdated;
    UiLock.instance.addListener(_onLockChanged);
    _applyKeymapSetting();
    _startup();
  }

  @override
  void dispose() {
    UiLock.instance.removeListener(_onLockChanged);
    autorefresh.onDevicesUpdated = null;
    super.dispose();
  }

  void _applyKeymapSetting() {
    final name = AppSettings.instance.keymap;
    for (final (n, table) in keymapTables) {
      if (n == name) {
        KeycodeDisplay.setKeymapOverride(table);
        return;
      }
    }
  }

  Future<void> _startup() async {
    try {
      final cached = await loadCachedViaStack();
      if (cached != null) autorefresh.loadViaStack(cached);
    } catch (_) {
      // a corrupt cache just disables VIA support until re-downloaded
    }
    autorefresh.start();
    await onClickRefresh();
    await _loadStartupDummy();
  }

  /// Development aid: `--dart-define=VIAL_DUMMY_JSON=/path/to/via.json` (or
  /// `?dummy=<same-origin url>` on the web) loads a dummy keyboard without
  /// going through the file picker.
  Future<void> _loadStartupDummy() async {
    var path = const String.fromEnvironment('VIAL_DUMMY_JSON');
    if (path.isEmpty && kIsWeb) {
      path = Uri.base.queryParameters['dummy'] ?? '';
    }
    if (path.isEmpty) return;
    final data = await readLocalFile(path);
    if (data == null) return;
    await _guard(() => autorefresh.loadDummy(data));
  }

  void _onLockChanged() {
    if (UiLock.instance.locked) {
      autorefresh.lock();
    } else {
      autorefresh.unlock();
    }
    if (mounted) setState(() {});
  }

  Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
    } catch (e, st) {
      await showWarning('$e\n\n$st');
    }
  }

  Future<void> onClickRefresh() =>
      _guard(() => autorefresh.update(quiet: false, hard: true));

  Future<void> _onConnect() => _guard(autorefresh.requestDevices);

  void _onDevicesUpdated(List<VialDevice> devices, bool hard) {
    var idx = devices.isEmpty ? -1 : 0;
    final cur = currentDevice;
    if (cur != null) {
      for (var i = 0; i < devices.length; i++) {
        if (devices[i].desc.path == cur.desc.path) idx = i;
      }
    }
    setState(() {
      _devices = devices;
      _selectedDevice = idx;
    });
    if (hard) onDeviceSelected(idx);
  }

  Future<void> onDeviceSelected(int idx) async {
    if (_busy) return;
    _busy = true;
    setState(() => _selectedDevice = idx);
    try {
      try {
        await autorefresh.selectDevice(idx);
      } on ProtocolError {
        await showWarning(
          'Unsupported protocol version!\n'
          'Please download latest Vial from https://get.vial.today/',
        );
      } catch (e) {
        await showWarning('Failed to open the device:\n$e');
      }
      final kb = _keyboard;
      if (kb != null && isExampleKeyboardUid(kb.keyboardId)) {
        await showWarning(
          'An example keyboard UID was detected.\n'
          'Please change your keyboard UID to be unique before you ship!',
        );
      }
      await rebuild();
    } finally {
      _busy = false;
    }
  }

  Future<void> rebuild() async {
    final dev = currentDevice;
    for (final e in editors) {
      try {
        await e.rebuild(dev);
      } catch (err, st) {
        await showWarning('${e.label}: $err\n\n$st');
      }
    }
    refreshTabs();
  }

  void refreshTabs() {
    final tabs = editors.where((e) => e.valid()).toList();
    BasicEditor? next;
    if (_current != null && tabs.contains(_current)) {
      next = _current;
    } else if (tabs.isNotEmpty) {
      next = tabs.first;
    }
    setState(() => _tabs = tabs);
    _switchTab(next);
  }

  void _switchTab(BasicEditor? next) {
    if (next == _current) return;
    KeycodeTray.instance.close();
    _current?.deactivate();
    setState(() => _current = next);
    next?.activate();
  }

  // ---- File menu -----------------------------------------------------------

  Future<void> _onLayoutLoad() => _guard(() async {
    final f = await pickFile(extension: 'vil', dialogTitle: 'Vial layout');
    if (f == null) return;
    await keymapEditor.restoreLayout(f.bytes);
    await rebuild();
  });

  Future<void> _onLayoutSave() => _guard(() async {
    if (_keyboard == null) return;
    await saveFile(
      fileName: 'layout.vil',
      bytes: keymapEditor.saveLayout(),
      extension: 'vil',
      dialogTitle: 'Vial layout',
    );
  });

  Future<void> _onSideloadJson() => _guard(() async {
    final f = await pickFile(extension: 'json', dialogTitle: 'VIA layout JSON');
    if (f == null) return;
    await autorefresh.sideloadViaJson(utf8.decode(f.bytes));
  });

  Future<void> _onLoadDummy() => _guard(() async {
    final f = await pickFile(extension: 'json', dialogTitle: 'VIA layout JSON');
    if (f == null) return;
    await autorefresh.loadDummy(utf8.decode(f.bytes));
  });

  Future<void> _onDownloadViaStack() => _guard(() async {
    final data = await downloadViaStack();
    await saveCachedViaStack(data);
    autorefresh.loadViaStack(data);
    await autorefresh.update(quiet: false, hard: true);
  });

  // ---- Security menu -------------------------------------------------------

  Future<void> _unlock() => _guard(() async {
    final kb = _keyboard;
    if (kb != null) await Unlocker.unlock(kb);
  });

  Future<void> _lock() => _guard(() async {
    await _keyboard?.lock();
  });

  Future<void> _rebootToBootloader() => _guard(() async {
    final kb = _keyboard;
    if (kb == null) return;
    await Unlocker.unlock(kb);
    await kb.reset();
  });

  // ---- Other menus ---------------------------------------------------------

  void _changeKeyboardLayout(String name) {
    AppSettings.instance.keymap = name;
    _applyKeymapSetting();
    setState(() {});
  }

  void _setTheme(String name) {
    AppSettings.instance.theme = name;
    VialTheme.instance.setTheme(name);
    setState(() {});
  }

  Future<void> _aboutKeyboard() async {
    final d = currentDevice;
    if (d is VialKeyboard) await showAboutKeyboardDialog(context, d);
  }

  Future<void> _aboutVial() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('About Vial'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vial $vialVersion'),
            const SizedBox(height: 12),
            const Text('Flutter port of the Vial GUI'),
            const SizedBox(height: 12),
            const Text(
              'Licensed under the terms of the\n'
              'GNU General Public License (version 2 or later)',
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => launchUrl(Uri.parse('https://get.vial.today/')),
              child: Text(
                'https://get.vial.today/',
                style: TextStyle(
                  color: ctx.palette.link,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ---- UI ------------------------------------------------------------------

  SingleActivator _shortcut(LogicalKeyboardKey key) {
    final mac = !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
    return SingleActivator(key, meta: mac, control: !mac);
  }

  Widget _buildMenuBar() {
    final isVial = currentDevice is VialKeyboard;
    final locked = UiLock.instance.locked;
    final keymap = AppSettings.instance.keymap;
    final theme = VialTheme.instance.theme;
    return MenuBar(
      children: [
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              onPressed: locked ? null : _onLayoutLoad,
              shortcut: _shortcut(LogicalKeyboardKey.keyO),
              child: const Text('Load saved layout...'),
            ),
            MenuItemButton(
              onPressed: locked ? null : _onLayoutSave,
              shortcut: _shortcut(LogicalKeyboardKey.keyS),
              child: const Text('Save current layout...'),
            ),
            const Divider(),
            MenuItemButton(
              onPressed: locked ? null : _onSideloadJson,
              child: const Text('Sideload VIA JSON...'),
            ),
            if (!kIsWeb)
              MenuItemButton(
                onPressed: locked ? null : _onDownloadViaStack,
                child: const Text('Download VIA definitions'),
              ),
            MenuItemButton(
              onPressed: locked ? null : _onLoadDummy,
              child: const Text('Load dummy JSON...'),
            ),
            if (!kIsWeb) ...[
              const Divider(),
              MenuItemButton(
                onPressed: exitApp,
                shortcut: _shortcut(LogicalKeyboardKey.keyQ),
                child: const Text('Exit'),
              ),
            ],
          ],
          child: const Text('File'),
        ),
        SubmenuButton(
          menuChildren: [
            for (final (name, _) in keymapTables)
              MenuItemButton(
                onPressed: () => _changeKeyboardLayout(name),
                leadingIcon: Icon(
                  name == keymap
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 16,
                ),
                child: Text(name),
              ),
          ],
          child: const Text('Keyboard layout'),
        ),
        if (isVial)
          SubmenuButton(
            menuChildren: [
              MenuItemButton(
                onPressed: locked ? null : _unlock,
                shortcut: _shortcut(LogicalKeyboardKey.keyU),
                child: const Text('Unlock'),
              ),
              MenuItemButton(
                onPressed: locked ? null : _lock,
                shortcut: _shortcut(LogicalKeyboardKey.keyL),
                child: const Text('Lock'),
              ),
              const Divider(),
              MenuItemButton(
                onPressed: locked ? null : _rebootToBootloader,
                shortcut: _shortcut(LogicalKeyboardKey.keyB),
                child: const Text('Reboot to bootloader'),
              ),
            ],
            child: const Text('Security'),
          ),
        SubmenuButton(
          menuChildren: [
            for (final name in ['System', ...themes.map((t) => t.$1)])
              MenuItemButton(
                onPressed: () => _setTheme(name),
                leadingIcon: Icon(
                  name == theme
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 16,
                ),
                child: Text(name),
              ),
          ],
          child: const Text('Theme'),
        ),
        SubmenuButton(
          menuChildren: [
            if (isVial)
              MenuItemButton(
                onPressed: _aboutKeyboard,
                child: Text('About ${currentDevice!.title}...'),
              ),
            MenuItemButton(
              onPressed: _aboutVial,
              child: const Text('About Vial...'),
            ),
          ],
          child: const Text('About'),
        ),
      ],
    );
  }

  Widget _buildDeviceRow() {
    final locked = UiLock.instance.locked;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<int>(
              isExpanded: true,
              value: _selectedDevice >= 0 && _selectedDevice < _devices.length
                  ? _selectedDevice
                  : null,
              items: [
                for (var i = 0; i < _devices.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(
                      _devices[i].title,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: locked
                  ? null
                  : (v) {
                      if (v != null) onDeviceSelected(v);
                    },
            ),
          ),
          const SizedBox(width: 8),
          if (autorefresh.pollsAutomatically)
            OutlinedButton(
              onPressed: locked ? null : onClickRefresh,
              child: const Text('Refresh'),
            )
          else
            OutlinedButton(
              onPressed: locked ? null : _onConnect,
              child: const Text('Connect device'),
            ),
        ],
      ),
    );
  }

  Widget _buildNoDevices() {
    final hint = autorefresh.pollsAutomatically
        ? 'No devices detected. Connect a Vial-compatible device and press '
              '"Refresh"\nor select "File" → "Download VIA definitions" in '
              'order to enable support for VIA keyboards.'
        : 'No devices detected. Connect a Vial-compatible device and press '
              '"Connect device".';
    return Center(child: Text(hint, textAlign: TextAlign.center));
  }

  Widget _buildTabStrip() {
    final p = context.palette;
    final locked = UiLock.instance.locked;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final e in _tabs)
            InkWell(
              onTap: locked ? null : () => _switchTab(e),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: e == _current ? p.highlight : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  e.label,
                  style: TextStyle(
                    color: locked ? p.disabledText : p.windowText,
                    fontWeight: e == _current
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditor(BasicEditor e) {
    return AnimatedBuilder(
      animation: e,
      builder: (ctx, _) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: e.onContainerClicked,
        child: e.build(ctx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cur = _current;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMenuBar(),
          _buildDeviceRow(),
          if (_devices.isEmpty)
            Expanded(child: _buildNoDevices())
          else ...[
            _buildTabStrip(),
            const Divider(height: 1),
            Expanded(
              child: cur == null ? const SizedBox.shrink() : _buildEditor(cur),
            ),
          ],
          const KeycodeTrayWidget(),
        ],
      ),
    );
  }
}

/// Exposed for tests and for the unlocker preview so the keycode helpers are
/// initialised before any editor renders.
void ensureKeycodesInitialized() => Keycode.ensureInitialized();
