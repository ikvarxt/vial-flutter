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

## Running

macOS:

```bash
flutter run -d macos
```

Chrome:

```bash
flutter run -d chrome
```

The web build needs a user gesture before the browser exposes devices: click
**Connect device** in the toolbar and pick the keyboard in the browser's
WebHID chooser. On macOS devices are polled automatically.

## Development aids

Both targets can start with a dummy keyboard so the UI can be exercised
without hardware:

```bash
flutter run -d macos --dart-define=VIAL_DUMMY_JSON=$PWD/test/fixtures/dummy_60.json
```

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
| `lib/hid/` | HID abstraction: method-channel backend (macOS), WebHID backend (web) |
| `lib/protocol/` | Vial/VIA protocol: `Keyboard`, dynamic entries, dummy keyboard |
| `lib/keycodes/` | Keycode tables (protocol v5/v6), Any-key parser |
| `lib/keymaps/`, `lib/kle/`, `lib/macro/` | Keymap display overrides, KLE deserializer, macro (de)serialisation |
| `lib/ui/editors/` | One file per editor tab |
| `lib/ui/dialogs/` | Unlock, Any key, About keyboard, colour and text-box dialogs |
| `lib/ui/widgets/` | Keyboard renderer, keycode picker, tab strips, buttons |
| `macos/Runner/HidPlugin.swift` | IOHIDManager bridge |

## License

GPL-2.0-or-later, same as vial-gui.
