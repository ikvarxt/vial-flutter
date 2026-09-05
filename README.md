# vial-flutter

A Flutter port of [vial-gui](https://github.com/vial-kb/vial-gui), the
configurator for keyboards running [Vial](https://get.vial.today/) firmware.
It speaks the same raw-HID protocol as the reference Python/Qt application and
keeps its editors, dialogs and behaviour, but runs as a native macOS app and
as a web app in Chrome (WebHID).

## Features

- Keymap editor with layers, masked keycodes (`LCTL(kc)`), encoders and the
  full keycode picker (Basic / ISO-JIS / Layers / Quantum / Backlight /
  App-Media-Mouse / MIDI / Tap Dance / User / Macro), including the "Any" key
  dialog.
- Layout editor (KLE layout options), Macros (recorder + text editor),
  Lighting (backlight / RGB / VialRGB), Tap Dance, Combos, Key Overrides,
  Alt Repeat Key, QMK Settings, Matrix tester, firmware flasher UI.
- Layout save/load, sideloading VIA JSON definitions, dummy keyboards, VIA
  keyboard-stack download, unlock flow, keymap display overrides and theming.
- Works with a real device or, for development, with a dummy keyboard loaded
  from a VIA/Vial JSON definition (see below).

## Requirements

- Flutter 3.44.x / Dart 3.12.x
- macOS 11+ for the desktop target (HID access goes through IOHIDManager in
  `macos/Runner/HidPlugin.swift`; the sandbox entitlement
  `com.apple.security.device.usb` is already set)
- Chrome / Edge (any browser with WebHID) for the web target; WebHID only works
  in a secure context, so serve over `https://` or from `localhost`
- Linux: the usual Flutter desktop toolchain (`clang cmake ninja-build
  pkg-config libgtk-3-dev`) plus `zenity` for the file dialogs. HID access
  reads `/dev/hidraw*` directly (no libhidapi needed), so the device nodes must
  be accessible to your user, see below

## Running

macOS:

```bash
flutter run -d macos
```

Chrome:

```bash
flutter run -d chrome
```

Linux:

```bash
flutter run -d linux
```

Keyboards are found through sysfs/hidraw, the same path vial-gui uses. Without
a udev rule only root can open the nodes; install the bundled rule once:

```bash
sudo cp linux/udev/99-vial.rules /etc/udev/rules.d/
sudo udevadm control --reload && sudo udevadm trigger
```

then re-plug the keyboard. The rule matches on the Vial serial-number magic, so
a board still running plain VIA firmware (used through *Sideload VIA JSON* or
the downloaded definitions) needs its own line keyed by vendor/product id, e.g.
for a Lily58:

```
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="04d8", ATTRS{idProduct}=="eb2d", MODE="0660", TAG+="uaccess"
```

"unable to open the device ... errno 13" means exactly this: the node exists
but your user may not open it.

The web build needs a user gesture before the browser exposes devices: click
**Connect device** in the toolbar and pick the keyboard in the browser's
WebHID chooser. On macOS devices are polled automatically.

## Development aids

Both targets can start with a dummy keyboard so the UI can be exercised
without hardware:

```bash
flutter run -d macos --dart-define=VIAL_DUMMY_JSON=$PWD/test/fixtures/dummy_60.json
```

On desktop the same name also works as an environment variable, so a prebuilt
binary can be started against a dummy too:

```bash
VIAL_DUMMY_JSON=$PWD/test/fixtures/dummy_60.json build/linux/x64/debug/bundle/vial_flutter
```

Alternatively use **File > Load Dummy JSON…** at any time.

On the web, pass a same-origin URL with the `dummy` query parameter, e.g.
`http://localhost:8080/?dummy=dummy_60.json` after copying the JSON next to
the built `index.html`.

## Tests

```bash
flutter test
```

The suite is a port of the reference project's tests: keycode/macro/keyboard
protocol tests plus the GUI tests (`test/gui_test.dart`), which drive the
whole app against a virtual keyboard that answers the Vial protocol in
memory.

Before committing run `dart format .` and `dart analyze` (the latter must
report no issues).

## Layout

| Path | Contents |
|---|---|
| `lib/hid/` | HID abstraction: method-channel backend (macOS), hidraw backend (Linux), WebHID backend (web) |
| `lib/protocol/` | Vial/VIA protocol: `Keyboard`, dynamic entries, dummy keyboard |
| `lib/keycodes/` | Keycode tables (protocol v5/v6), Any-key parser |
| `lib/keymaps/`, `lib/kle/`, `lib/macro/` | Keymap display overrides, KLE deserializer, macro (de)serialisation |
| `lib/ui/editors/` | One file per editor tab |
| `lib/ui/dialogs/` | Unlock, Any key, About keyboard, colour and text-box dialogs |
| `lib/ui/widgets/` | Keyboard renderer, keycode picker, tab strips, buttons |
| `macos/Runner/HidPlugin.swift` | IOHIDManager bridge |
| `linux/udev/99-vial.rules` | udev rule granting users access to Vial keyboards |

## License

vial-flutter is a port of [vial-gui](https://github.com/vial-kb/vial-gui)
(Copyright Ilya Zhuravlev and contributors) and is therefore distributed under
the same terms: GNU General Public License, version 2 or (at your option) any
later version. See [COPYING](COPYING). Every source file carries an
`SPDX-License-Identifier: GPL-2.0-or-later` header.

The protocol layer, keycode tables and GUI tests were translated from the
Python sources; `lib/keycodes/keycodes_v*.dart`, `lib/keycodes/keycode_defs.dart`
and `lib/keymaps/keymap_tables.dart` are generated from them by
`tool/gen_tables.py`. The Flutter UI, the HID backends and everything else in
this repository were written for this port.

This is an unofficial port and is not affiliated with the Vial project.

Bundled IBM Plex fonts are licensed under the SIL Open Font License 1.1, see
[assets/fonts/LICENSE.txt](assets/fonts/LICENSE.txt).
