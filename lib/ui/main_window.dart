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
import 'widgets/tab_strip.dart';
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
    autorefresh.stop();
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

  bool get _isMac => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  SingleActivator _shortcut(LogicalKeyboardKey key) =>
      SingleActivator(key, meta: _isMac, control: !_isMac);

  static String _check(bool on, String label) => '${on ? '✓' : '   '} $label';

  /// Native macOS menu bar; the in-window bar is only used elsewhere.
  List<PlatformMenu> _buildPlatformMenus() {
    final isVial = currentDevice is VialKeyboard;
    final locked = UiLock.instance.locked;
    final keymap = AppSettings.instance.keymap;
    final theme = VialTheme.instance.theme;
    return [
      PlatformMenu(
        label: 'Vial',
        menus: [
          PlatformMenuItem(label: 'About Vial', onSelected: _aboutVial),
          if (isVial)
            PlatformMenuItem(
              label: 'About ${currentDevice!.title}',
              onSelected: _aboutKeyboard,
            ),
          const PlatformMenuItemGroup(
            members: [
              PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit),
            ],
          ),
        ],
      ),
      PlatformMenu(
        label: 'File',
        menus: [
          PlatformMenuItem(
            label: 'Load Saved Layout…',
            shortcut: _shortcut(LogicalKeyboardKey.keyO),
            onSelected: locked ? null : _onLayoutLoad,
          ),
          PlatformMenuItem(
            label: 'Save Current Layout…',
            shortcut: _shortcut(LogicalKeyboardKey.keyS),
            onSelected: locked ? null : _onLayoutSave,
          ),
          PlatformMenuItemGroup(
            members: [
              PlatformMenuItem(
                label: 'Sideload VIA JSON…',
                onSelected: locked ? null : _onSideloadJson,
              ),
              PlatformMenuItem(
                label: 'Download VIA Definitions',
                onSelected: locked ? null : _onDownloadViaStack,
              ),
              PlatformMenuItem(
                label: 'Load Dummy JSON…',
                onSelected: locked ? null : _onLoadDummy,
              ),
            ],
          ),
        ],
      ),
      PlatformMenu(
        label: 'Keyboard Layout',
        menus: [
          for (final (name, _) in keymapTables)
            PlatformMenuItem(
              label: _check(name == keymap, name),
              onSelected: () => _changeKeyboardLayout(name),
            ),
        ],
      ),
      if (isVial)
        PlatformMenu(
          label: 'Security',
          menus: [
            PlatformMenuItem(
              label: 'Unlock',
              shortcut: _shortcut(LogicalKeyboardKey.keyU),
              onSelected: locked ? null : _unlock,
            ),
            PlatformMenuItem(
              label: 'Lock',
              shortcut: _shortcut(LogicalKeyboardKey.keyL),
              onSelected: locked ? null : _lock,
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Reboot to Bootloader',
                  shortcut: _shortcut(LogicalKeyboardKey.keyB),
                  onSelected: locked ? null : _rebootToBootloader,
                ),
              ],
            ),
          ],
        ),
      PlatformMenu(
        label: 'Theme',
        menus: [
          for (final name in ['System', ...themes.map((t) => t.$1)])
            PlatformMenuItem(
              label: _check(name == theme, name),
              onSelected: () => _setTheme(name),
            ),
        ],
      ),
    ];
  }

  Widget _radio(bool on) =>
      Icon(on ? Icons.radio_button_checked : Icons.radio_button_off, size: 15);

  /// In-window menu bar for the web and non-macOS desktops.
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
                leadingIcon: _radio(name == keymap),
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
                leadingIcon: _radio(name == theme),
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

  Widget _buildDevicePicker(VialPalette p) {
    final locked = UiLock.instance.locked;
    final hasSelection =
        _selectedDevice >= 0 && _selectedDevice < _devices.length;
    final selected = hasSelection ? _devices[_selectedDevice] : null;
    final textTheme = Theme.of(context).textTheme;
    return MenuAnchor(
      builder: (ctx, controller, _) => _BarChip(
        enabled: !locked && _devices.isNotEmpty,
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DeviceDot(device: selected, palette: p),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                selected?.title ?? 'No keyboard',
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelLarge!.copyWith(
                  color: selected == null ? p.muted : p.ink,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.expand_more, size: 16, color: p.muted),
          ],
        ),
      ),
      menuChildren: [
        for (var i = 0; i < _devices.length; i++)
          MenuItemButton(
            onPressed: () => onDeviceSelected(i),
            leadingIcon: _DeviceDot(device: _devices[i], palette: p),
            trailingIcon: i == _selectedDevice
                ? Icon(Icons.check, size: 15, color: p.ink)
                : const SizedBox(width: 15),
            child: Text(_devices[i].title),
          ),
      ],
    );
  }

  Widget _buildTopBar() {
    final p = context.palette;
    final locked = UiLock.instance.locked;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: p.bar,
        border: Border(bottom: BorderSide(color: p.hairline)),
      ),
      child: Row(
        children: [
          const _BrandMark(),
          const SizedBox(width: 8),
          Text('Vial', style: textTheme.titleSmall),
          const SizedBox(width: 16),
          Container(width: 1, height: 18, color: p.hairline),
          const SizedBox(width: 16),
          _buildDevicePicker(p),
          const SizedBox(width: 6),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (autorefresh.pollsAutomatically)
            IconButton(
              tooltip: 'Refresh',
              onPressed: locked ? null : onClickRefresh,
              icon: const Icon(Icons.refresh),
            )
          else
            FilledButton.icon(
              onPressed: locked ? null : _onConnect,
              icon: const Icon(Icons.usb, size: 16),
              label: const Text('Connect device'),
            ),
          const Spacer(),
          if (!_isMac) _buildMenuBar(),
        ],
      ),
    );
  }

  Widget _buildNoDevices() {
    final p = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final locked = UiLock.instance.locked;
    final polls = autorefresh.pollsAutomatically;
    final hint = polls
        ? 'Plug in a Vial-compatible keyboard and refresh. VIA-only '
              'keyboards need File › Download VIA definitions first.'
        : 'Plug in a Vial-compatible keyboard, then let Chrome open it.';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.keyboard_outlined, size: 40, color: p.muted),
            const SizedBox(height: 16),
            Text('No keyboard detected', style: textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(hint, textAlign: TextAlign.center, style: textTheme.bodySmall),
            const SizedBox(height: 20),
            if (polls)
              OutlinedButton.icon(
                onPressed: locked ? null : onClickRefresh,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              )
            else
              FilledButton.icon(
                onPressed: locked ? null : _onConnect,
                icon: const Icon(Icons.usb, size: 16),
                label: const Text('Connect device'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabStrip() {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.hairline)),
      ),
      child: TabStrip(
        labels: [for (final e in _tabs) e.label],
        current: _current == null ? -1 : _tabs.indexOf(_current!),
        enabled: !UiLock.instance.locked,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onSelected: (i) => _switchTab(_tabs[i]),
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
    Widget body = Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(),
            if (_devices.isEmpty)
              Expanded(child: _buildNoDevices())
            else ...[
              _buildTabStrip(),
              Expanded(
                child: cur == null
                    ? const SizedBox.shrink()
                    : _buildEditor(cur),
              ),
            ],
            KeycodeTrayWidget(
              height: keycodePickerHeight(constraints.maxHeight),
            ),
          ],
        ),
      ),
    );
    if (_isMac) {
      body = PlatformMenuBar(menus: _buildPlatformMenus(), child: body);
    }
    return body;
  }
}

/// Miniature keycap used as the app mark in the top bar.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: 20,
      height: 20,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.lerp(p.accent, Colors.black, 0.28),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: p.accent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Center(
              child: Text(
                'V',
                style: TextStyle(
                  color: p.onAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Status dot next to a device name: accent for a live keyboard, muted for
/// dummies and bootloaders, hollow when nothing is selected.
class _DeviceDot extends StatelessWidget {
  const _DeviceDot({required this.device, required this.palette});

  final VialDevice? device;
  final VialPalette palette;

  @override
  Widget build(BuildContext context) {
    final d = device;
    final live = d is VialKeyboard && d is! VialDummyKeyboard;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: d == null
            ? Colors.transparent
            : live
            ? palette.accent
            : palette.muted,
        border: d == null ? Border.all(color: palette.muted, width: 1.5) : null,
      ),
    );
  }
}

/// Quiet outlined chip used for top-bar pickers.
class _BarChip extends StatefulWidget {
  const _BarChip({
    required this.child,
    required this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<_BarChip> createState() => _BarChipState();
}

class _BarChipState extends State<_BarChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: Container(
          height: 30,
          padding: const EdgeInsets.fromLTRB(10, 0, 8, 0),
          decoration: BoxDecoration(
            color: _hover && widget.enabled
                ? Color.alphaBlend(p.hover, p.base)
                : p.base,
            borderRadius: BorderRadius.circular(VialRadius.control),
            border: Border.all(color: p.hairline),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Exposed for tests and for the unlocker preview so the keycode helpers are
/// initialised before any editor renders.
void ensureKeycodesInitialized() => Keycode.ensureInitialized();
