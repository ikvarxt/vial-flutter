// SPDX-License-Identifier: GPL-2.0-or-later
import 'any_keycode.dart';
import 'keycode_defs.dart';
import 'keycodes_v5.dart';
import 'keycodes_v6.dart';

/// The subset of keyboard state needed to build the keycode tables.
abstract class KeycodeKeyboardInfo {
  int get vialProtocol;
  int get layers;
  int get macroCount;
  int get tapDanceCount;
  List<Map<String, dynamic>>? get customKeycodes;
  String? get midi;
  Set<String> get supportedFeatures;
}

const String resetKeycode = 'QK_BOOT';

class Keycode {
  static final Set<String> maskedKeycodes = {};
  static final Map<String, Keycode> recorderAliasToKeycode = {};
  static final Map<String, Keycode> qmkIdToKeycode = {};
  static int protocol = 0;
  static bool _initialized = false;

  /// Bumped every time the global tables are rebuilt so that caches keyed on
  /// the table contents (see [AnyKeycode]) can invalidate themselves.
  static int generation = 0;

  final String qmkId;
  final String label;
  final String? tooltip;

  /// Whether this keycode requires another sub-keycode, e.g. `LCTL(kc)`.
  final bool masked;

  /// For printable keycodes, the character normally output (non-shifted).
  final String? printable;
  final List<String> alias;
  final String? requiresFeature;
  bool hidden = false;

  Keycode(
    this.qmkId,
    this.label, {
    this.tooltip,
    this.masked = false,
    this.printable,
    List<String>? recorderAlias,
    List<String>? alias,
    this.requiresFeature,
  }) : alias = [qmkId, ...?alias] {
    qmkIdToKeycode[qmkId] = this;
    if (recorderAlias != null) {
      for (final a in recorderAlias) {
        if (recorderAliasToKeycode.containsKey(a)) {
          throw StateError(
            'Misconfigured: two keycodes claim the same alias $a',
          );
        }
        recorderAliasToKeycode[a] = this;
      }
    }
    if (masked) {
      assert(qmkId.endsWith('(kc)'));
      maskedKeycodes.add(qmkId.replaceAll('(kc)', ''));
    }
  }

  @override
  String toString() => 'Keycode<$qmkId>';

  /// Mirrors the import-time construction of the Python module: all static
  /// tables are instantiated (and therefore registered) in source order.
  static void ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    keycodesSpecial;
    keycodesBasic;
    keycodesShifted;
    keycodesIso;
    keycodesBoot;
    keycodesModifiers;
    keycodesQuantum;
    keycodesBacklight;
    keycodesMedia;
    keycodesMacroBase;
    keycodesMidiBasic;
    keycodesMidiAdvanced;
    keycodesHidden;
    recreateKeycodes();
  }

  static Keycode? find(String qmkId) {
    ensureInitialized();
    // handles cases of qmk_id LCTL(kc) propagated here from findInnerKeycode
    if (qmkId == 'kc') qmkId = 'KC_NO';
    return keycodesMap[qmkId];
  }

  /// Finds outer keycode, i.e. if it is masked like 0x5Fxx, just return the
  /// 0x5F00 portion.
  static Keycode? findOuterKeycode(String qmkId) {
    if (isMask(qmkId)) qmkId = qmkId.substring(0, qmkId.indexOf('('));
    return find(qmkId);
  }

  /// Finds inner keycode, i.e. if it is masked like 0x5F12, just return the
  /// 0x12 portion.
  static Keycode? findInnerKeycode(String qmkId) {
    if (isMask(qmkId)) {
      qmkId = qmkId.substring(qmkId.indexOf('(') + 1, qmkId.length - 1);
    }
    return find(qmkId);
  }

  static Keycode? findByRecorderAlias(String alias) {
    ensureInitialized();
    return recorderAliasToKeycode[alias];
  }

  static Keycode? findByQmkId(String qmkId) {
    ensureInitialized();
    return qmkIdToKeycode[qmkId];
  }

  static bool isMask(String qmkId) {
    ensureInitialized();
    final p = qmkId.indexOf('(');
    return p >= 0 && maskedKeycodes.contains(qmkId.substring(0, p));
  }

  static bool isBasic(String qmkId) => deserialize(qmkId) < 0x00FF;

  static String labelOf(String qmkId) {
    final keycode = findOuterKeycode(qmkId);
    if (keycode == null) return qmkId;
    return keycode.label;
  }

  static String? tooltipOf(String qmkId) {
    final keycode = findOuterKeycode(qmkId);
    if (keycode == null) return null;
    var tooltip = keycode.qmkId;
    if (keycode.tooltip != null) tooltip = '$tooltip: ${keycode.tooltip}';
    return tooltip;
  }

  static Set<int> get _masked => protocol == 6 ? v6Masked : v5Masked;

  static Map<String, int> get _kc => protocol == 6 ? v6Kc : v5Kc;

  /// Converts integer keycode to string.
  static String serialize(int code) {
    ensureInitialized();
    if (!_masked.contains(code & 0xFF00)) {
      final kc = rawcodesMap[code];
      if (kc != null) return kc.qmkId;
    } else {
      final outer = rawcodesMap[code & 0xFF00];
      final inner = rawcodesMap[code & 0x00FF];
      if (outer != null && inner != null) {
        return outer.qmkId.replaceFirst('kc', inner.qmkId);
      }
    }
    return hexOf(code);
  }

  /// Python's `hex()` formatting: lowercase, `0x` prefixed, no padding.
  static String hexOf(int code) => '0x${code.toRadixString(16)}';

  /// Converts string keycode to integer. Accepts an [int] as passthrough.
  static int deserialize(Object val, {bool reraise = false}) {
    ensureInitialized();
    if (val is int) return val;
    final s = val as String;
    final known = qmkIdToKeycode[s];
    if (known != null) return resolve(known.qmkId);
    try {
      return AnyKeycode.shared.decode(s);
    } catch (_) {
      if (reraise) rethrow;
      return 0;
    }
  }

  /// Changes e.g. KC_PERC to LSFT(KC_5).
  static String normalize(Object code) => serialize(deserialize(code));

  /// Translates a qmk constant into a firmware-specific integer keycode.
  static int resolve(String qmkConstant) {
    final v = _kc[qmkConstant];
    if (v == null) throw StateError('unable to resolve qmk_id=$qmkConstant');
    return v;
  }

  bool isSupportedBy(KeycodeKeyboardInfo keyboard) {
    if (requiresFeature == null) return true;
    return keyboard.supportedFeatures.contains(requiresFeature);
  }
}

final List<Keycode> keycodesLayers = [];
final List<Keycode> keycodesTapDance = [];
final List<Keycode> keycodesUser = [];
final List<Keycode> keycodesMacro = [];
final List<Keycode> keycodesMidi = [];
final List<Keycode> keycodesHidden = [
  for (var x = 0; x < 256; x++) Keycode('TD($x)', 'TD($x)'),
];

final List<Keycode> keycodes = [];
final Map<String, Keycode> keycodesMap = {};
final Map<int, Keycode> rawcodesMap = {};

/// Regenerates the global [keycodes] array.
void recreateKeycodes() {
  keycodes
    ..clear()
    ..addAll(keycodesSpecial)
    ..addAll(keycodesBasic)
    ..addAll(keycodesShifted)
    ..addAll(keycodesIso)
    ..addAll(keycodesLayers)
    ..addAll(keycodesBoot)
    ..addAll(keycodesModifiers)
    ..addAll(keycodesQuantum)
    ..addAll(keycodesBacklight)
    ..addAll(keycodesMedia)
    ..addAll(keycodesTapDance)
    ..addAll(keycodesMacro)
    ..addAll(keycodesUser)
    ..addAll(keycodesHidden)
    ..addAll(keycodesMidi);
  keycodesMap.clear();
  rawcodesMap.clear();
  Keycode.generation++;
  for (final keycode in keycodes) {
    keycodesMap[keycode.qmkId.replaceAll('(kc)', '')] = keycode;
    rawcodesMap[Keycode.deserialize(keycode.qmkId)] = keycode;
  }
  Keycode.generation++;
}

String _user2(int x) => 'USER${x.toString().padLeft(2, '0')}';

void createUserKeycodes() {
  keycodesUser.clear();
  for (var x = 0; x < 16; x++) {
    keycodesUser.add(Keycode(_user2(x), 'User $x', tooltip: 'User keycode $x'));
  }
}

void createCustomUserKeycodes(List<Map<String, dynamic>> customKeycodes) {
  keycodesUser.clear();
  for (var x = 0; x < customKeycodes.length; x++) {
    final c = customKeycodes[x];
    keycodesUser.add(
      Keycode(
        _user2(x),
        (c['shortName'] as String?) ?? _user2(x),
        tooltip: (c['title'] as String?) ?? _user2(x),
        alias: [(c['name'] as String?) ?? _user2(x)],
      ),
    );
  }
}

void createMidiKeycodes(String? midiSettingLevel) {
  keycodesMidi.clear();
  if (midiSettingLevel == 'basic' || midiSettingLevel == 'advanced') {
    keycodesMidi.addAll(keycodesMidiBasic);
  }
  if (midiSettingLevel == 'advanced') {
    keycodesMidi.addAll(keycodesMidiAdvanced);
  }
}

/// Generates keycodes based on information the keyboard provides
/// (e.g. layer keycodes, macros).
void recreateKeyboardKeycodes(KeycodeKeyboardInfo keyboard) {
  Keycode.ensureInitialized();
  Keycode.protocol = keyboard.vialProtocol;

  final layers = keyboard.layers;

  List<Keycode> generateKeycodesForMask(
    String label,
    String description, {
    String? requiresFeature,
  }) {
    return [
      for (var layer = 0; layer < layers; layer++)
        Keycode(
          '$label($layer)',
          '$label($layer)',
          tooltip: description,
          requiresFeature: requiresFeature,
        ),
    ];
  }

  keycodesLayers.clear();
  keycodesLayers.add(
    Keycode(
      'QK_LAYER_LOCK',
      'Layer\nLock',
      tooltip: 'Locks the current layer',
      alias: ['QK_LLCK'],
      requiresFeature: 'layer_lock',
    ),
  );

  if (layers >= 4) {
    keycodesLayers.add(Keycode('FN_MO13', 'Fn1\n(Fn3)'));
    keycodesLayers.add(Keycode('FN_MO23', 'Fn2\n(Fn3)'));
  }

  keycodesLayers.addAll(
    generateKeycodesForMask(
      'MO',
      'Momentarily turn on layer when pressed '
          '(requires KC_TRNS on destination layer)',
    ),
  );
  keycodesLayers.addAll(
    generateKeycodesForMask('DF', 'Set the base (default) layer'),
  );
  keycodesLayers.addAll(
    generateKeycodesForMask(
      'PDF',
      'Persistently set the base (default) layer',
      requiresFeature: 'persistent_default_layer',
    ),
  );
  keycodesLayers.addAll(
    generateKeycodesForMask('TG', 'Toggle layer on or off'),
  );
  keycodesLayers.addAll(
    generateKeycodesForMask(
      'TT',
      "Normally acts like MO unless it's tapped multiple times, "
          'which toggles layer on',
    ),
  );
  keycodesLayers.addAll(
    generateKeycodesForMask(
      'OSL',
      'Momentarily activates layer until a key is pressed',
    ),
  );
  keycodesLayers.addAll(
    generateKeycodesForMask(
      'TO',
      'Turns on layer and turns off all other layers, '
          'except the default layer',
    ),
  );

  final ltCount = layers < 16 ? layers : 16;
  for (var x = 0; x < ltCount; x++) {
    keycodesLayers.add(
      Keycode(
        'LT$x(kc)',
        'LT $x\n(kc)',
        tooltip: 'kc on tap, switch to layer $x while held',
        masked: true,
      ),
    );
  }

  keycodesMacro.clear();
  for (var x = 0; x < keyboard.macroCount; x++) {
    keycodesMacro.add(Keycode('M$x', 'M$x'));
  }
  keycodesMacro.addAll(keycodesMacroBase);

  keycodesTapDance.clear();
  for (var x = 0; x < keyboard.tapDanceCount; x++) {
    keycodesTapDance.add(
      Keycode('TD($x)', 'TD($x)', tooltip: 'Tap dance keycode'),
    );
  }

  final custom = keyboard.customKeycodes;
  if (custom != null && custom.isNotEmpty) {
    createCustomUserKeycodes(custom);
  } else {
    createUserKeycodes();
  }

  createMidiKeycodes(keyboard.midi);

  recreateKeycodes();

  // Hide keycodes where requiresFeature isn't supported by the keyboard.
  for (final kc in keycodes) {
    kc.hidden = !kc.isSupportedBy(keyboard);
  }
}
