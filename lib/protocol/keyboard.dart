import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../hid/hid_device.dart';
import '../keycodes/keycode.dart';
import '../kle/kle_serial.dart';
import '../macro/macro_action.dart';
import '../settings/qmk_settings.dart';
import '../util/bytes.dart';
import 'constants.dart';
import 'dynamic_entries.dart';

const List<int> supportedViaProtocol = [-1, 9];
const List<int> supportedVialProtocol = [-1, 0, 1, 2, 3, 4, 5, 6];

class ProtocolError implements Exception {
  @override
  String toString() => 'ProtocolError';
}

/// Called before writing a "dangerous" keycode (QK_BOOT) or macros; the UI
/// installs a handler that walks the user through the unlock procedure.
typedef UnlockHandler = Future<void> Function(Keyboard keyboard);

/// Low-level communication with a vial-enabled keyboard.
class Keyboard implements KeycodeKeyboardInfo {
  Keyboard(this.dev, {UsbSend? usbSend})
    : usbSend =
          usbSend ??
          ((Uint8List msg, {int retries = 1}) =>
              hidSend(dev!, msg, retries: retries));

  static UnlockHandler unlocker = (_) async {};

  final HidDevice? dev;
  final UsbSend usbSend;

  Map<String, dynamic>? definition;
  bool sideload = false;

  // Insertion-ordered so that the sequence of layout requests is stable.
  LinkedHashSet<(int, int)> rowcol = LinkedHashSet();
  LinkedHashSet<int> encoderpos = LinkedHashSet();
  int encoderCount = 0;
  Map<(int, int, int), String> layout = {};
  Map<(int, int, int), String> encoderLayout = {};
  int rows = 0;
  int cols = 0;
  @override
  int layers = 0;
  List<dynamic>? layoutLabels;
  int layoutOptions = -1;
  List<KleKey> keys = [];
  List<KleKey> encoders = [];
  bool vibl = false;
  @override
  List<Map<String, dynamic>>? customKeycodes;
  @override
  String? midi;

  bool lightingQmkRgblight = false;
  bool lightingQmkBacklight = false;
  bool lightingVialrgb = false;

  // underglow
  int underglowBrightness = -1;
  int underglowEffect = -1;
  int underglowEffectSpeed = -1;
  (int, int) underglowColor = (0, 0);
  // backlight
  int backlightBrightness = -1;
  int backlightEffect = -1;
  // vialrgb
  int rgbMode = -1;
  int rgbSpeed = -1;
  int rgbVersion = -1;
  int rgbMaximumBrightness = -1;
  (int, int, int) rgbHsv = (0, 0, 0);
  Set<int> rgbSupportedEffects = {};

  int viaProtocol = -1;
  @override
  int vialProtocol = -1;
  BigInt keyboardId = BigInt.from(-1);

  // macros
  @override
  int macroCount = 0;
  int macroMemory = 0;
  Uint8List macro = Uint8List(0);

  // qmk settings
  Map<int, int> settings = {};
  Set<int> supportedSettings = {};

  // dynamic entries
  @override
  Set<String> supportedFeatures = {};
  @override
  int tapDanceCount = 0;
  List<TapDanceEntry> tapDanceEntries = [];
  int comboCount = 0;
  List<ComboEntry> comboEntries = [];
  int keyOverrideCount = 0;
  List<KeyOverrideEntry> keyOverrideEntries = [];
  int altRepeatKeyCount = 0;
  List<AltRepeatKeyEntry> altRepeatKeyEntries = [];

  Future<Uint8List> _send(List<int> msg, {int retries = 1}) =>
      usbSend(Uint8List.fromList(msg), retries: retries);

  Future<void> unlock() => unlocker(this);

  /// Load information about the keyboard: number of layers, physical key
  /// layout.
  Future<void> reload([Map<String, dynamic>? sideloadJson]) async {
    rowcol = LinkedHashSet();
    encoderpos = LinkedHashSet();
    layout = {};
    encoderLayout = {};

    await reloadLayout(sideloadJson);
    await reloadLayers();

    await reloadMacrosEarly();
    await reloadPersistentRgb();
    await reloadRgb();
    await reloadSettings();

    await reloadDynamic();

    // based on the number of macros, tapdance, etc, this will generate
    // global keycode arrays
    recreateKeyboardKeycodes(this);

    // at this stage we have correct keycode info and can reload everything
    // that depends on keycodes
    await reloadKeymap();
    await reloadMacrosLate();
    await reloadTapDance();
    await reloadCombo();
    await reloadKeyOverride();
    await reloadAltRepeatKey();
  }

  /// Get how many layers the keyboard has.
  Future<void> reloadLayers() async {
    final data = await _send([cmdViaGetLayerCount], retries: 20);
    layers = data[1];
  }

  Future<void> reloadViaProtocol() async {
    final data = await _send([cmdViaGetProtocolVersion], retries: 20);
    viaProtocol = readU16be(data, 1);
  }

  void checkProtocolVersion() {
    if (!supportedViaProtocol.contains(viaProtocol) ||
        !supportedVialProtocol.contains(vialProtocol)) {
      throw ProtocolError();
    }
  }

  /// Requests layout data from the current device.
  Future<void> reloadLayout([Map<String, dynamic>? sideloadJson]) async {
    await reloadViaProtocol();

    sideload = false;
    Map<String, dynamic> payload;
    if (sideloadJson != null) {
      sideload = true;
      payload = sideloadJson;
    } else {
      // get keyboard identification
      var data = await _send([
        cmdViaVialPrefix,
        cmdVialGetKeyboardId,
      ], retries: 20);
      vialProtocol = readU32le(data, 0);
      keyboardId = readU64leBig(data, 4);

      // get the size
      data = await _send([cmdViaVialPrefix, cmdVialGetSize], retries: 20);
      var sz = readU32le(data, 0);

      // get the payload
      final compressed = BytesBuilder(copy: false);
      var block = 0;
      while (sz > 0) {
        data = await _send(
          ByteWriter()
              .u8(cmdViaVialPrefix)
              .u8(cmdVialGetDefinition)
              .u32le(block)
              .build(),
          retries: 20,
        );
        if (sz < msgLen) data = Uint8List.sublistView(data, 0, sz);
        compressed.add(data);
        block += 1;
        sz -= msgLen;
      }

      final raw = XZDecoder().decodeBytes(compressed.toBytes());
      payload = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
    }

    checkProtocolVersion();

    definition = payload;

    final vial = payload['vial'];
    if (vial is Map) {
      vibl = vial['vibl'] == true;
      midi = vial['midi'] as String?;
    }

    final layouts = payload['layouts'] as Map<String, dynamic>;
    layoutLabels = layouts['labels'] as List<dynamic>?;

    final matrix = payload['matrix'] as Map<String, dynamic>;
    rows = matrix['rows'] as int;
    cols = matrix['cols'] as int;

    final custom = payload['customKeycodes'];
    customKeycodes = custom is List
        ? [for (final c in custom) Map<String, dynamic>.from(c as Map)]
        : null;

    final kb = KleSerial().deserialize(layouts['keymap'] as List<dynamic>);

    keys = [];
    encoders = [];

    for (final key in kb.keys) {
      key.row = key.col = null;
      key.encoderIdx = key.encoderDir = null;
      final label0 = key.labels[0];
      if (key.labels[4] == 'e') {
        final parts = label0!.split(',');
        final idx = int.parse(parts[0]);
        final direction = int.parse(parts[1]);
        key.encoderIdx = idx;
        key.encoderDir = direction;
        encoderpos.add(idx);
        encoderCount = encoderCount > idx + 1 ? encoderCount : idx + 1;
        encoders.add(key);
      } else if (key.decal || (label0 != null && label0.contains(','))) {
        var row = 0;
        var col = 0;
        if (label0 != null && label0.contains(',')) {
          final parts = label0.split(',');
          row = int.parse(parts[0]);
          col = int.parse(parts[1]);
        }
        key.row = row;
        key.col = col;
        rowcol.add((row, col));
        keys.add(key);
      }

      // bottom right corner determines layout index and option in this layout
      key.layoutIndex = -1;
      key.layoutOption = -1;
      final label8 = key.labels[8];
      if (label8 != null && label8.isNotEmpty) {
        final parts = label8.split(',');
        key.layoutIndex = int.parse(parts[0]);
        key.layoutOption = int.parse(parts[1]);
      }
    }
  }

  /// Load current key mapping from the keyboard.
  Future<void> reloadKeymap() async {
    final keymap = BytesBuilder(copy: false);
    // calculate what the size of keymap will be and retrieve the entire
    // binary buffer
    final size = layers * rows * cols * 2;
    for (var x = 0; x < size; x += bufferFetchChunk) {
      final offset = x;
      final sz = (size - offset) < bufferFetchChunk
          ? size - offset
          : bufferFetchChunk;
      final data = await _send(
        ByteWriter().u8(cmdViaKeymapGetBuffer).u16be(offset).u8(sz).build(),
        retries: 20,
      );
      keymap.add(Uint8List.sublistView(data, 4, 4 + sz));
    }
    final buf = keymap.toBytes();

    for (var layer = 0; layer < layers; layer++) {
      for (final (row, col) in rowcol) {
        if (row >= rows || col >= cols) {
          throw StateError(
            'malformed vial.json, key references $row,$col but matrix '
            'declares rows=$rows cols=$cols',
          );
        }
        // determine where this (layer, row, col) will be located in keymap
        // array
        final offset = layer * rows * cols * 2 + row * cols * 2 + col * 2;
        layout[(layer, row, col)] = Keycode.serialize(readU16be(buf, offset));
      }
    }

    for (var layer = 0; layer < layers; layer++) {
      for (final idx in encoderpos) {
        final data = await _send([
          cmdViaVialPrefix,
          cmdVialGetEncoder,
          layer,
          idx,
        ], retries: 20);
        encoderLayout[(layer, idx, 0)] = Keycode.serialize(readU16be(data, 0));
        encoderLayout[(layer, idx, 1)] = Keycode.serialize(readU16be(data, 2));
      }
    }

    if (layoutLabels != null && layoutLabels!.isNotEmpty) {
      final data = await _send([
        cmdViaGetKeyboardValue,
        viaLayoutOptions,
      ], retries: 20);
      layoutOptions = readU32be(data, 2);
    }
  }

  void _loadLightingFlags() {
    final lighting = definition?['lighting'];
    if (lighting != null) {
      lightingQmkRgblight =
          lighting == 'qmk_rgblight' || lighting == 'qmk_backlight_rgblight';
      lightingQmkBacklight =
          lighting == 'qmk_backlight' || lighting == 'qmk_backlight_rgblight';
      lightingVialrgb = lighting == 'vialrgb';
    }
  }

  /// Reload RGB properties which are slow, and do not change while keyboard
  /// is plugged in, e.g. VialRGB supported effects list.
  Future<void> reloadPersistentRgb() async {
    _loadLightingFlags();

    if (lightingVialrgb) {
      var data = (await _send([
        cmdViaLightingGetValue,
        vialrgbGetInfo,
      ], retries: 20)).sublist(2);
      rgbVersion = data[0] | (data[1] << 8);
      if (rgbVersion != 1) {
        throw StateError(
          'Unsupported VialRGB protocol ($rgbVersion), update your Vial '
          'version to latest',
        );
      }
      rgbMaximumBrightness = data[2];

      rgbSupportedEffects = {0};
      var maxEffect = 0;
      while (maxEffect < 0xFFFF) {
        data = (await _send(
          ByteWriter()
              .u8(cmdViaLightingGetValue)
              .u8(vialrgbGetSupported)
              .u16le(maxEffect)
              .build(),
        )).sublist(2);
        for (var x = 0; x + 1 < data.length; x += 2) {
          final value = readU16le(data, x);
          if (value != 0xFFFF) rgbSupportedEffects.add(value);
          if (value > maxEffect) maxEffect = value;
        }
      }
    }
  }

  Future<int> _lightingGet(int id) async =>
      (await _send([cmdViaLightingGetValue, id], retries: 20))[2];

  Future<void> reloadRgb() async {
    if (lightingQmkRgblight) {
      underglowBrightness = await _lightingGet(qmkRgblightBrightness);
      underglowEffect = await _lightingGet(qmkRgblightEffect);
      underglowEffectSpeed = await _lightingGet(qmkRgblightEffectSpeed);
      final color = await _send([
        cmdViaLightingGetValue,
        qmkRgblightColor,
      ], retries: 20);
      // hue, sat
      underglowColor = (color[2], color[3]);
    }

    if (lightingQmkBacklight) {
      backlightBrightness = await _lightingGet(qmkBacklightBrightness);
      backlightEffect = await _lightingGet(qmkBacklightEffect);
    }

    if (lightingVialrgb) {
      final data = (await _send([
        cmdViaLightingGetValue,
        vialrgbGetMode,
      ], retries: 20)).sublist(2);
      rgbMode = readU16le(data, 0);
      rgbSpeed = data[2];
      rgbHsv = (data[3], data[4], data[5]);
    }
  }

  Future<void> reloadSettings() async {
    settings = {};
    supportedSettings = {};
    if (vialProtocol < vialProtocolQmkSettings) return;
    var cur = 0;
    while (cur != 0xFFFF) {
      final data = await _send(
        ByteWriter()
            .u8(cmdViaVialPrefix)
            .u8(cmdVialQmkSettingsQuery)
            .u16le(cur)
            .build(),
        retries: 20,
      );
      for (var x = 0; x + 1 < data.length; x += 2) {
        final qsid = readU16le(data, x);
        if (qsid > cur) cur = qsid;
        if (qsid != 0xFFFF) supportedSettings.add(qsid);
      }
    }

    for (final qsid in supportedSettings) {
      if (!QmkSettings.isQsidSupported(qsid)) continue;

      final data = await _send(
        ByteWriter()
            .u8(cmdViaVialPrefix)
            .u8(cmdVialQmkSettingsGet)
            .u16le(qsid)
            .build(),
        retries: 20,
      );
      if (data[0] == 0) {
        settings[qsid] = QmkSettings.qsidDeserialize(qsid, data.sublist(1));
      }
    }
  }

  Future<void> setKey(int layer, int row, int col, String code) async {
    final key = (layer, row, col);
    if (layout[key] != code) {
      if (code == resetKeycode) await unlock();

      await _send(
        ByteWriter()
            .u8(cmdViaSetKeycode)
            .u8(layer)
            .u8(row)
            .u8(col)
            .u16be(Keycode.deserialize(code))
            .build(),
        retries: 20,
      );
      layout[key] = code;
    }
  }

  Future<void> setEncoder(
    int layer,
    int index,
    int direction,
    String code,
  ) async {
    final key = (layer, index, direction);
    if (encoderLayout[key] != code) {
      if (code == resetKeycode) await unlock();

      await _send(
        ByteWriter()
            .u8(cmdViaVialPrefix)
            .u8(cmdVialSetEncoder)
            .u8(layer)
            .u8(index)
            .u8(direction)
            .u16be(Keycode.deserialize(code))
            .build(),
        retries: 20,
      );
      encoderLayout[key] = code;
    }
  }

  Future<void> setLayoutOptions(int options) async {
    if (layoutOptions != -1 && layoutOptions != options) {
      layoutOptions = options;
      await _send(
        ByteWriter()
            .u8(cmdViaSetKeyboardValue)
            .u8(viaLayoutOptions)
            .u32be(options)
            .build(),
        retries: 20,
      );
    }
  }

  Future<void> setQmkRgblightBrightness(int value) async {
    underglowBrightness = value;
    await _send([
      cmdViaLightingSetValue,
      qmkRgblightBrightness,
      value,
    ], retries: 20);
  }

  Future<void> setQmkRgblightEffect(int index) async {
    underglowEffect = index;
    await _send([
      cmdViaLightingSetValue,
      qmkRgblightEffect,
      index,
    ], retries: 20);
  }

  Future<void> setQmkRgblightEffectSpeed(int value) async {
    underglowEffectSpeed = value;
    await _send([
      cmdViaLightingSetValue,
      qmkRgblightEffectSpeed,
      value,
    ], retries: 20);
  }

  Future<void> setQmkRgblightColor(int h, int s, int v) async {
    await setQmkRgblightBrightness(v);
    underglowColor = (h, s);
    await _send([cmdViaLightingSetValue, qmkRgblightColor, h, s]);
  }

  Future<void> setQmkBacklightBrightness(int value) async {
    backlightBrightness = value;
    await _send([cmdViaLightingSetValue, qmkBacklightBrightness, value]);
  }

  Future<void> setQmkBacklightEffect(int value) async {
    backlightEffect = value;
    await _send([cmdViaLightingSetValue, qmkBacklightEffect, value]);
  }

  Future<void> saveRgb() async {
    await _send([cmdViaLightingSave], retries: 20);
  }

  static const String _uidPlaceholder = '__VIAL_UID__';

  /// Serializes current layout to a binary (UTF-8 JSON).
  Uint8List saveLayout() {
    final data = <String, dynamic>{'version': 1, 'uid': _uidPlaceholder};

    final layoutOut = <List<List<Object>>>[];
    for (var l = 0; l < layers; l++) {
      final layer = <List<Object>>[];
      layoutOut.add(layer);
      for (var r = 0; r < rows; r++) {
        final row = <Object>[];
        layer.add(row);
        for (var c = 0; c < cols; c++) {
          row.add(layout[(l, r, c)] ?? -1);
        }
      }
    }

    final encoderOut = <List<List<Object>>>[];
    for (var l = 0; l < layers; l++) {
      final layer = <List<Object>>[];
      for (var e = 0; e < encoderCount; e++) {
        layer.add([
          encoderLayout[(l, e, 0)] ?? -1,
          encoderLayout[(l, e, 1)] ?? -1,
        ]);
      }
      encoderOut.add(layer);
    }

    data['layout'] = layoutOut;
    data['encoder_layout'] = encoderOut;
    data['layout_options'] = layoutOptions;
    data['macro'] = saveMacro();
    data['vial_protocol'] = vialProtocol;
    data['via_protocol'] = viaProtocol;
    data['tap_dance'] = saveTapDance();
    data['combo'] = saveCombo();
    data['key_override'] = saveKeyOverride();
    data['alt_repeat_key'] = saveAltRepeatKey();
    data['settings'] = {
      for (final e in settings.entries) e.key.toString(): e.value,
    };

    final json = jsonEncode(
      data,
    ).replaceFirst('"$_uidPlaceholder"', keyboardId.toString());
    return Uint8List.fromList(utf8.encode(json));
  }

  /// Extracts the `uid` field of a saved layout without losing 64-bit
  /// precision (JSON numbers would otherwise be parsed as doubles on web).
  static BigInt? parseLayoutUid(Uint8List data) {
    final m = RegExp(r'"uid"\s*:\s*(-?\d+)').firstMatch(utf8.decode(data));
    return m == null ? null : BigInt.parse(m.group(1)!);
  }

  /// Restores saved layout.
  Future<void> restoreLayout(Uint8List raw) async {
    final data = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;

    // restore keymap
    final layoutIn = data['layout'] as List;
    for (var l = 0; l < layoutIn.length; l++) {
      final layer = layoutIn[l] as List;
      for (var r = 0; r < layer.length; r++) {
        final row = layer[r] as List;
        for (var c = 0; c < row.length; c++) {
          if (layout.containsKey((l, r, c))) {
            await setKey(l, r, c, Keycode.normalize(_jsonCode(row[c])));
          }
        }
      }
    }

    // restore encoders
    final encodersIn = (data['encoder_layout'] as List?) ?? const [];
    for (var l = 0; l < encodersIn.length; l++) {
      final layer = encodersIn[l] as List;
      for (var e = 0; e < layer.length; e++) {
        final encoder = layer[e] as List;
        await setEncoder(l, e, 0, Keycode.normalize(_jsonCode(encoder[0])));
        await setEncoder(l, e, 1, Keycode.normalize(_jsonCode(encoder[1])));
      }
    }

    await setLayoutOptions((data['layout_options'] as num).toInt());
    await restoreMacros(data['macro']);

    await restoreTapDance((data['tap_dance'] as List?) ?? const []);
    await restoreCombo((data['combo'] as List?) ?? const []);
    await restoreKeyOverride((data['key_override'] as List?) ?? const []);
    await restoreAltRepeatKey((data['alt_repeat_key'] as List?) ?? const []);

    final settingsIn = (data['settings'] as Map?) ?? const {};
    for (final entry in settingsIn.entries) {
      final qsid = int.parse(entry.key as String);
      if (QmkSettings.isQsidSupported(qsid)) {
        await qmkSettingsSet(qsid, (entry.value as num).toInt());
      }
    }
  }

  static Object _jsonCode(Object? v) => v is num ? v.toInt() : v as String;

  Future<void> reset() async {
    await _send([0x0B]);
    await dev?.close();
  }

  /// Retrieve UID from the keyboard, explicitly sending a query packet.
  Future<Uint8List> getUid() async {
    final data = await _send([
      cmdViaVialPrefix,
      cmdVialGetKeyboardId,
    ], retries: 20);
    return Uint8List.sublistView(data, 4, 12);
  }

  Future<int> getUnlockStatus({int retries = 20}) async {
    // VIA keyboards are always unlocked
    if (vialProtocol < 0) return 1;

    final data = await _send([
      cmdViaVialPrefix,
      cmdVialGetUnlockStatus,
    ], retries: retries);
    return data[0];
  }

  Future<int> getUnlockInProgress() async {
    // VIA keyboards are never being unlocked
    if (vialProtocol < 0) return 0;

    final data = await _send([
      cmdViaVialPrefix,
      cmdVialGetUnlockStatus,
    ], retries: 20);
    return data[1];
  }

  /// Return keys users have to hold to unlock the keyboard as a list of
  /// rowcols.
  Future<List<(int, int)>> getUnlockKeys() async {
    // VIA keyboards don't have unlock keys
    if (vialProtocol < 0) return [];

    final data = await _send([
      cmdViaVialPrefix,
      cmdVialGetUnlockStatus,
    ], retries: 20);
    final out = <(int, int)>[];
    for (var x = 0; x < 15; x++) {
      final row = data[2 + x * 2];
      final col = data[3 + x * 2];
      if (row != 255 && col != 255) out.add((row, col));
    }
    return out;
  }

  Future<void> unlockStart() async {
    if (vialProtocol < 0) return;
    await _send([cmdViaVialPrefix, cmdVialUnlockStart], retries: 20);
  }

  Future<Uint8List> unlockPoll() async {
    if (vialProtocol < 0) return Uint8List(0);
    return _send([cmdViaVialPrefix, cmdVialUnlockPoll], retries: 20);
  }

  Future<void> lock() async {
    if (vialProtocol < 0) return;
    await _send([cmdViaVialPrefix, cmdVialLock], retries: 20);
  }

  Future<Uint8List?> matrixPoll() async {
    if (viaProtocol < 0) return null;
    return _send([cmdViaGetKeyboardValue, viaSwitchMatrixState], retries: 3);
  }

  Future<int> qmkSettingsSet(int qsid, int value) async {
    settings[qsid] = value;
    final data = await _send(
      ByteWriter()
          .u8(cmdViaVialPrefix)
          .u8(cmdVialQmkSettingsSet)
          .u16le(qsid)
          .bytes(QmkSettings.qsidSerialize(qsid, value))
          .build(),
      retries: 20,
    );
    return data[0];
  }

  Future<void> qmkSettingsReset() async {
    await _send([cmdViaVialPrefix, cmdVialQmkSettingsReset]);
  }

  Future<void> _vialrgbSetMode() async {
    await _send(
      ByteWriter()
          .u8(cmdViaLightingSetValue)
          .u8(vialrgbSetMode)
          .u16le(rgbMode)
          .u8(rgbSpeed)
          .u8(rgbHsv.$1)
          .u8(rgbHsv.$2)
          .u8(rgbHsv.$3)
          .build(),
    );
  }

  Future<void> setVialrgbBrightness(int value) async {
    rgbHsv = (rgbHsv.$1, rgbHsv.$2, value);
    await _vialrgbSetMode();
  }

  Future<void> setVialrgbSpeed(int value) async {
    rgbSpeed = value;
    await _vialrgbSetMode();
  }

  Future<void> setVialrgbMode(int value) async {
    rgbMode = value;
    await _vialrgbSetMode();
  }

  Future<void> setVialrgbColor(int h, int s, int v) async {
    rgbHsv = (h, s, v);
    await _vialrgbSetMode();
  }

  // ---------------------------------------------------------------- macros

  /// Reload macro information that doesn't require any info about keycodes,
  /// i.e. number of macros.
  Future<void> reloadMacrosEarly() async {
    var data = await _send([cmdViaMacroGetCount], retries: 20);
    macroCount = data[1];
    data = await _send([cmdViaMacroGetBufferSize], retries: 20);
    macroMemory = readU16be(data, 1);
  }

  /// Load actual keycodes.
  Future<void> reloadMacrosLate() async {
    macro = Uint8List(0);
    if (macroMemory > 0) {
      // now retrieve the entire buffer, MACRO_CHUNK bytes at a time, as that
      // is what fits into a packet
      final buf = BytesBuilder(copy: false);
      var nulCount = 0;
      for (var x = 0; x < macroMemory; x += bufferFetchChunk) {
        final sz = (macroMemory - x) < bufferFetchChunk
            ? macroMemory - x
            : bufferFetchChunk;
        final data = await _send(
          ByteWriter().u8(cmdViaMacroGetBuffer).u16be(x).u8(sz).build(),
          retries: 20,
        );
        final chunk = Uint8List.sublistView(data, 4, 4 + sz);
        buf.add(chunk);
        nulCount += chunk.where((b) => b == 0).length;
        if (nulCount > macroCount) break;
      }
      // macros are stored as NUL-separated strings, so let's clean up the
      // buffer ensuring we only get macro_count strings after we split by NUL
      final macros = _splitNul(buf.toBytes());
      while (macros.length < macroCount) {
        macros.add(Uint8List(0));
      }
      macro = _joinNul(macros.sublist(0, macroCount));
    }
  }

  /// Loads macro information from the keyboard.
  Future<void> reloadMacros() async {
    await reloadMacrosEarly();
    await reloadMacrosLate();
  }

  Future<void> setMacro(Uint8List data) async {
    if (data.length > macroMemory) {
      throw StateError(
        'the macro is too big: got ${data.length} max $macroMemory',
      );
    }

    var x = 0;
    for (final chunk in chunks(data, bufferFetchChunk)) {
      final off = x * bufferFetchChunk;
      await _send(
        ByteWriter()
            .u8(cmdViaMacroSetBuffer)
            .u16be(off)
            .u8(chunk.length)
            .bytes(chunk)
            .build(),
        retries: 20,
      );
      x += 1;
    }
    macro = data;
  }

  List<List<List<Object>>> saveMacro() {
    final macros = macrosDeserialize(macro);
    return [
      for (final m in macros) [for (final act in m) act.save()],
    ];
  }

  Future<void> restoreMacros(Object? macros) async {
    if (macros is! List) return;

    final fullMacro = <List<BasicAction>>[];
    for (final m in macros) {
      final actions = <BasicAction>[];
      for (final act in m as List) {
        final a = act as List;
        final ctor = tagToAction[a[0]];
        if (ctor != null) {
          final obj = ctor();
          obj.restore(a.cast<Object?>());
          actions.add(obj);
        }
      }
      fullMacro.add(actions);
    }
    while (fullMacro.length < macroCount) {
      fullMacro.add([]);
    }
    final trimmed = fullMacro.sublist(0, macroCount);
    var data = macrosSerialize(trimmed);
    if (data.length > macroMemory) {
      data = Uint8List.sublistView(data, 0, macroMemory);
    }
    if (!_bytesEq(data, macro)) {
      await unlock();
      await setMacro(data);
    }
  }

  /// Serialize a single macro, a macro is made out of macro actions.
  Uint8List macroSerialize(List<BasicAction> m) {
    final out = BytesBuilder(copy: false);
    for (final action in m) {
      out.add(action.serialize(vialProtocol));
    }
    return out.toBytes();
  }

  /// Deserialize a single macro.
  List<BasicAction> macroDeserialize(List<int> data) {
    if (vialProtocol >= vialProtocolAdvancedMacros) {
      return macroDeserializeV2(data);
    }
    return macroDeserializeV1(data);
  }

  /// Serialize a list of macros, the list must contain all macros
  /// (macro_count).
  Uint8List macrosSerialize(List<List<BasicAction>> macros) {
    if (macros.length != macroCount) {
      throw StateError(
        'expected array with $macroCount macros, got ${macros.length} macros',
      );
    }
    return _joinNul([for (final m in macros) macroSerialize(m)]);
  }

  /// Deserialize a list of macros.
  List<List<BasicAction>> macrosDeserialize(Uint8List data) {
    final macros = _splitNul(data);
    while (macros.length < macroCount) {
      macros.add(Uint8List(0));
    }
    return [for (final m in macros.sublist(0, macroCount)) macroDeserialize(m)];
  }

  // ------------------------------------------------------- dynamic entries

  Future<void> reloadDynamic() async {
    supportedFeatures = {};

    if (vialProtocol < vialProtocolDynamic) {
      tapDanceCount = 0;
      tapDanceEntries = [];
      comboCount = 0;
      comboEntries = [];
      keyOverrideCount = 0;
      keyOverrideEntries = [];
      altRepeatKeyCount = 0;
      altRepeatKeyEntries = [];
      return;
    }
    final data = await _send([
      cmdViaVialPrefix,
      cmdVialDynamicEntryOp,
      dynamicVialGetNumberOfEntries,
    ], retries: 20);
    tapDanceCount = data[0];
    comboCount = data[1];
    keyOverrideCount = data[2];
    altRepeatKeyCount = data[3];

    // Bits of data[-1] indicate optionally supported features.
    const featureBits = [(0, 'caps_word'), (1, 'layer_lock')];
    for (final (bit, feature) in featureBits) {
      if (data.last & (1 << bit) != 0) supportedFeatures.add(feature);
    }

    if (vialProtocol >= vialProtocolKeyOverride) {
      // Persistent Default Layers isn't present in older QMK builds, but is
      // unconditionally enabled in recent QMK builds.
      supportedFeatures.add('persistent_default_layer');
    }

    if (altRepeatKeyCount > 0) supportedFeatures.add('repeat_key');
  }

  Future<List<List<int>>> _retrieveDynamicEntries(
    int cmd,
    int count,
    String fmt,
  ) async {
    final out = <List<int>>[];
    for (var x = 0; x < count; x++) {
      final data = await _send([
        cmdViaVialPrefix,
        cmdVialDynamicEntryOp,
        cmd,
        x,
      ], retries: 20);
      if (data[0] != 0) {
        throw StateError(
          'failed retrieving dynamic=$cmd entry $x from the device',
        );
      }
      out.add(unpackLe(fmt, data, 1));
    }
    return out;
  }

  Future<void> reloadTapDance() async {
    final entries = await _retrieveDynamicEntries(
      dynamicVialTapDanceGet,
      tapDanceCount,
      'HHHHH',
    );
    tapDanceEntries = [
      for (final e in entries)
        (
          Keycode.serialize(e[0]),
          Keycode.serialize(e[1]),
          Keycode.serialize(e[2]),
          Keycode.serialize(e[3]),
          e[4],
        ),
    ];
  }

  TapDanceEntry tapDanceGet(int idx) => tapDanceEntries[idx];

  Future<void> tapDanceSet(int idx, TapDanceEntry entry) async {
    if (tapDanceEntries[idx] == entry) return;
    for (final kc in [entry.$1, entry.$2, entry.$3, entry.$4]) {
      if (kc == resetKeycode) await unlock();
    }
    tapDanceEntries[idx] = entry;
    final serialized = packLe('HHHHH', [
      Keycode.deserialize(entry.$1),
      Keycode.deserialize(entry.$2),
      Keycode.deserialize(entry.$3),
      Keycode.deserialize(entry.$4),
      entry.$5,
    ]);
    await _send(
      ByteWriter()
          .u8(cmdViaVialPrefix)
          .u8(cmdVialDynamicEntryOp)
          .u8(dynamicVialTapDanceSet)
          .u8(idx)
          .bytes(serialized)
          .build(),
      retries: 20,
    );
  }

  List<List<Object>> saveTapDance() => [
    for (final e in tapDanceEntries) [e.$1, e.$2, e.$3, e.$4, e.$5],
  ];

  Future<void> restoreTapDance(List<dynamic> data) async {
    for (var x = 0; x < data.length; x++) {
      if (x < tapDanceCount) {
        final e = data[x] as List;
        await tapDanceSet(x, (
          _kcStr(e[0]),
          _kcStr(e[1]),
          _kcStr(e[2]),
          _kcStr(e[3]),
          (e[4] as num).toInt(),
        ));
      }
    }
  }

  Future<void> reloadCombo() async {
    final entries = await _retrieveDynamicEntries(
      dynamicVialComboGet,
      comboCount,
      'HHHHH',
    );
    comboEntries = [
      for (final e in entries)
        (
          Keycode.serialize(e[0]),
          Keycode.serialize(e[1]),
          Keycode.serialize(e[2]),
          Keycode.serialize(e[3]),
          Keycode.serialize(e[4]),
        ),
    ];
  }

  ComboEntry comboGet(int idx) => comboEntries[idx];

  Future<void> comboSet(int idx, ComboEntry entry) async {
    if (comboEntries[idx] == entry) return;
    // for the replacement key
    if (entry.$5 == resetKeycode) await unlock();
    comboEntries[idx] = entry;
    final serialized = packLe('HHHHH', [
      Keycode.deserialize(entry.$1),
      Keycode.deserialize(entry.$2),
      Keycode.deserialize(entry.$3),
      Keycode.deserialize(entry.$4),
      Keycode.deserialize(entry.$5),
    ]);
    await _send(
      ByteWriter()
          .u8(cmdViaVialPrefix)
          .u8(cmdVialDynamicEntryOp)
          .u8(dynamicVialComboSet)
          .u8(idx)
          .bytes(serialized)
          .build(),
      retries: 20,
    );
  }

  List<List<Object>> saveCombo() => [
    for (final e in comboEntries) [e.$1, e.$2, e.$3, e.$4, e.$5],
  ];

  Future<void> restoreCombo(List<dynamic> data) async {
    for (var x = 0; x < data.length; x++) {
      if (x < comboCount) {
        final e = data[x] as List;
        await comboSet(x, (
          _kcStr(e[0]),
          _kcStr(e[1]),
          _kcStr(e[2]),
          _kcStr(e[3]),
          _kcStr(e[4]),
        ));
      }
    }
  }

  Future<void> reloadKeyOverride() async {
    final entries = await _retrieveDynamicEntries(
      dynamicVialKeyOverrideGet,
      keyOverrideCount,
      'HHHBBBB',
    );
    keyOverrideEntries = [
      for (final e in entries)
        KeyOverrideEntry(
          trigger: Keycode.serialize(e[0]),
          replacement: Keycode.serialize(e[1]),
          layers: e[2],
          triggerMods: e[3],
          negativeModMask: e[4],
          suppressedMods: e[5],
          options: e[6],
        ),
    ];
  }

  KeyOverrideEntry keyOverrideGet(int idx) => keyOverrideEntries[idx];

  Future<void> keyOverrideSet(int idx, KeyOverrideEntry entry) async {
    if (entry != keyOverrideEntries[idx]) {
      if (entry.replacement == resetKeycode) await unlock();

      keyOverrideEntries[idx] = entry;
      await _send(
        ByteWriter()
            .u8(cmdViaVialPrefix)
            .u8(cmdVialDynamicEntryOp)
            .u8(dynamicVialKeyOverrideSet)
            .u8(idx)
            .bytes(entry.serialize())
            .build(),
      );
    }
  }

  List<Map<String, dynamic>> saveKeyOverride() => [
    for (final e in keyOverrideEntries) e.save(),
  ];

  Future<void> restoreKeyOverride(List<dynamic> data) async {
    for (var x = 0; x < data.length; x++) {
      if (x < keyOverrideCount) {
        final ko = KeyOverrideEntry.empty()
          ..restore(Map<String, dynamic>.from(data[x] as Map));
        await keyOverrideSet(x, ko);
      }
    }
  }

  Future<void> reloadAltRepeatKey() async {
    final entries = await _retrieveDynamicEntries(
      dynamicVialAltRepeatKeyGet,
      altRepeatKeyCount,
      'HHBB',
    );
    altRepeatKeyEntries = [
      for (final e in entries)
        AltRepeatKeyEntry(
          keycode: Keycode.serialize(e[0]),
          altKeycode: Keycode.serialize(e[1]),
          allowedMods: e[2],
          options: e[3],
        ),
    ];
  }

  AltRepeatKeyEntry altRepeatKeyGet(int idx) => altRepeatKeyEntries[idx];

  Future<void> altRepeatKeySet(int idx, AltRepeatKeyEntry entry) async {
    if (entry != altRepeatKeyEntries[idx]) {
      if (entry.keycode == resetKeycode || entry.altKeycode == resetKeycode) {
        await unlock();
      }

      altRepeatKeyEntries[idx] = entry;
      await _send(
        ByteWriter()
            .u8(cmdViaVialPrefix)
            .u8(cmdVialDynamicEntryOp)
            .u8(dynamicVialAltRepeatKeySet)
            .u8(idx)
            .bytes(entry.serialize())
            .build(),
      );
    }
  }

  List<Map<String, dynamic>> saveAltRepeatKey() => [
    for (final e in altRepeatKeyEntries) e.save(),
  ];

  Future<void> restoreAltRepeatKey(List<dynamic> data) async {
    for (var x = 0; x < data.length; x++) {
      if (x < altRepeatKeyCount) {
        final e = AltRepeatKeyEntry.empty()
          ..restore(Map<String, dynamic>.from(data[x] as Map));
        await altRepeatKeySet(x, e);
      }
    }
  }
}

String _kcStr(Object? v) =>
    v is num ? Keycode.serialize(v.toInt()) : v as String;

List<Uint8List> _splitNul(Uint8List data) {
  final out = <Uint8List>[];
  var start = 0;
  for (var i = 0; i < data.length; i++) {
    if (data[i] == 0) {
      out.add(Uint8List.sublistView(data, start, i));
      start = i + 1;
    }
  }
  out.add(Uint8List.sublistView(data, start));
  return out;
}

Uint8List _joinNul(List<Uint8List> parts) {
  final out = BytesBuilder(copy: false);
  for (final p in parts) {
    out.add(p);
    out.addByte(0);
  }
  return out.toBytes();
}

bool _bytesEq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
