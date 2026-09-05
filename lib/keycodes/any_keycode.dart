// SPDX-License-Identifier: GPL-2.0-or-later
import 'keycode.dart';
import 'keycode_defs.dart';

/// Evaluates QMK-style keycode expressions such as `LCTL(KC_A)`,
/// `LT(2, KC_SPC)` or `0x1234 | 5`, mirroring the Python `simpleeval` based
/// implementation. Names and functions resolve against the current
/// [Keycode.protocol] tables.
class AnyKeycode {
  AnyKeycode._();

  static final AnyKeycode shared = AnyKeycode._();

  Map<String, int>? _names;
  int _namesGeneration = -1;
  int _namesProtocol = -1;

  Map<String, int> get names {
    if (_names == null ||
        _namesGeneration != Keycode.generation ||
        _namesProtocol != Keycode.protocol) {
      _names = _prepareNames();
      _namesGeneration = Keycode.generation;
      _namesProtocol = Keycode.protocol;
    }
    return _names!;
  }

  static Map<String, int> _prepareNames() {
    Keycode.ensureInitialized();
    final names = <String, int>{};
    for (final kc in [
      ...keycodesSpecial,
      ...keycodesBasic,
      ...keycodesShifted,
      ...keycodesIso,
      ...keycodesBacklight,
      ...keycodesMedia,
      ...keycodesUser,
    ]) {
      for (final qmkId in kc.alias) {
        names[qmkId] = Keycode.resolve(kc.qmkId);
      }
    }
    for (final s in const [
      'MOD_LCTL',
      'MOD_LSFT',
      'MOD_LALT',
      'MOD_LGUI',
      'MOD_RCTL',
      'MOD_RSFT',
      'MOD_RALT',
      'MOD_RGUI',
      'MOD_MEH',
      'MOD_HYPR',
    ]) {
      names[s] = Keycode.resolve(s);
    }
    return names;
  }

  int decode(String s) => _Parser(s, names).parse();
}

typedef _Fn = int Function(List<int> args);

int _r(String name) => Keycode.resolve(name);

int _mt(int mod, int kc) =>
    _r('QK_MOD_TAP') | ((mod & 0x1F) << 8) | (kc & 0xFF);

int _lt(int layer, int kc) =>
    _r('QK_LAYER_TAP') | ((layer & 0xF) << 8) | (kc & 0xFF);

_Fn _mods(List<String> qks) => (a) {
  _arity(a, 1);
  var v = a[0];
  for (final q in qks) {
    v |= _r(q);
  }
  return v;
};

_Fn _modTap(List<String> mods) => (a) {
  _arity(a, 1);
  var m = 0;
  for (final q in mods) {
    m |= _r(q);
  }
  return _mt(m, a[0]);
};

_Fn _layer(String qk) => (a) {
  _arity(a, 1);
  return _r(qk) | (a[0] & 0xFF);
};

void _arity(List<int> a, int n) {
  if (a.length != n) {
    throw ArgumentError('expected $n argument(s), got ${a.length}');
  }
}

final Map<String, _Fn> _functions = () {
  final lctl = _mods(['QK_LCTL']);
  final lsft = _mods(['QK_LSFT']);
  final lalt = _mods(['QK_LALT']);
  final lgui = _mods(['QK_LGUI']);
  final rctl = _mods(['QK_RCTL']);
  final rsft = _mods(['QK_RSFT']);
  final ralt = _mods(['QK_RALT']);
  final rgui = _mods(['QK_RGUI']);
  final cS = _mods(['QK_LCTL', 'QK_LSFT']);
  final hypr = _mods(['QK_LCTL', 'QK_LSFT', 'QK_LALT', 'QK_LGUI']);
  final meh = _mods(['QK_LCTL', 'QK_LSFT', 'QK_LALT']);
  final lcag = _mods(['QK_LCTL', 'QK_LALT', 'QK_LGUI']);
  final sgui = _mods(['QK_LGUI', 'QK_LSFT']);
  final lca = _mods(['QK_LCTL', 'QK_LALT']);
  final lsa = _mods(['QK_LSFT', 'QK_LALT']);
  final lag = _mods(['QK_LALT', 'QK_LGUI']);
  final rsa = _mods(['QK_RSFT', 'QK_RALT']);
  final rcs = _mods(['QK_RCTL', 'QK_RSFT']);
  final lcg = _mods(['QK_LCTL', 'QK_LGUI']);
  final rcg = _mods(['QK_RCTL', 'QK_RGUI']);

  final lctlT = _modTap(['MOD_LCTL']);
  final rctlT = _modTap(['MOD_RCTL']);
  final lsftT = _modTap(['MOD_LSFT']);
  final rsftT = _modTap(['MOD_RSFT']);
  final laltT = _modTap(['MOD_LALT']);
  final raltT = _modTap(['MOD_RALT']);
  final lguiT = _modTap(['MOD_LGUI']);
  final rguiT = _modTap(['MOD_RGUI']);
  final cST = _modTap(['MOD_LCTL', 'MOD_LSFT']);
  final mehT = _modTap(['MOD_LCTL', 'MOD_LSFT', 'MOD_LALT']);
  final lcagT = _modTap(['MOD_LCTL', 'MOD_LALT', 'MOD_LGUI']);
  final rcagT = _modTap(['MOD_RCTL', 'MOD_RALT', 'MOD_RGUI']);
  final hyprT = _modTap(['MOD_LCTL', 'MOD_LSFT', 'MOD_LALT', 'MOD_LGUI']);
  final sguiT = _modTap(['MOD_LGUI', 'MOD_LSFT']);
  final lcaT = _modTap(['MOD_LCTL', 'MOD_LALT']);
  final lsaT = _modTap(['MOD_LSFT', 'MOD_LALT']);
  final lagT = _modTap(['MOD_LALT', 'MOD_LGUI']);
  final rsaT = _modTap(['MOD_RSFT', 'MOD_RALT']);
  final rcsT = _modTap(['MOD_RCTL', 'MOD_RSFT']);
  final lcgT = _modTap(['MOD_LCTL', 'MOD_LGUI']);
  final rcgT = _modTap(['MOD_RCTL', 'MOD_RGUI']);

  final m = <String, _Fn>{
    'LCTL': lctl,
    'LSFT': lsft,
    'LALT': lalt,
    'LGUI': lgui,
    'LOPT': lalt,
    'LCMD': lgui,
    'LWIN': lgui,
    'RCTL': rctl,
    'RSFT': rsft,
    'RALT': ralt,
    'RGUI': rgui,
    'ALGR': ralt,
    'ROPT': ralt,
    'RCMD': rgui,
    'RWIN': rgui,
    'HYPR': hypr,
    'MEH': meh,
    'LCAG': lcag,
    'SGUI': sgui,
    'SCMD': sgui,
    'SWIN': sgui,
    'LSG': sgui,
    'C_S': cS,
    'LCA': lca,
    'LSA': lsa,
    'LAG': lag,
    'RSA': rsa,
    'RCS': rcs,
    'SAGR': rsa,
    'C': lctl,
    'S': lsft,
    'A': lalt,
    'G': lgui,
    'LT': (a) {
      _arity(a, 2);
      return _lt(a[0], a[1]);
    },
    'TO': (a) {
      _arity(a, 1);
      return _r('QK_TO') | (_r('ON_PRESS') << 0x4) | (a[0] & 0xFF);
    },
    'MO': _layer('QK_MOMENTARY'),
    'DF': _layer('QK_DEF_LAYER'),
    'TG': _layer('QK_TOGGLE_LAYER'),
    'OSL': _layer('QK_ONE_SHOT_LAYER'),
    'LM': (a) {
      _arity(a, 2);
      return _r('QK_LAYER_MOD') |
          ((a[0] & 0xF) << _r('QMK_LM_SHIFT')) |
          (a[1] & _r('QMK_LM_MASK'));
    },
    'OSM': _layer('QK_ONE_SHOT_MOD'),
    'TT': _layer('QK_LAYER_TAP_TOGGLE'),
    'MT': (a) {
      _arity(a, 2);
      return _mt(a[0], a[1]);
    },
    'LCTL_T': lctlT,
    'RCTL_T': rctlT,
    'CTL_T': lctlT,
    'LSFT_T': lsftT,
    'RSFT_T': rsftT,
    'SFT_T': lsftT,
    'LALT_T': laltT,
    'RALT_T': raltT,
    'LOPT_T': laltT,
    'ROPT_T': raltT,
    'ALGR_T': raltT,
    'ALT_T': laltT,
    'OPT_T': laltT,
    'LGUI_T': lguiT,
    'RGUI_T': rguiT,
    'LCMD_T': lguiT,
    'LWIN_T': lguiT,
    'RCMD_T': rguiT,
    'RWIN_T': rguiT,
    'GUI_T': lguiT,
    'CMD_T': lguiT,
    'WIN_T': lguiT,
    'C_S_T': cST,
    'MEH_T': mehT,
    'LCAG_T': lcagT,
    'RCAG_T': rcagT,
    'HYPR_T': hyprT,
    'SGUI_T': sguiT,
    'SCMD_T': sguiT,
    'SWIN_T': sguiT,
    'LSG_T': sguiT,
    'LCA_T': lcaT,
    'LSA_T': lsaT,
    'LAG_T': lagT,
    'RSA_T': rsaT,
    'RCS_T': rcsT,
    'SAGR_T': rsaT,
    'ALL_T': hyprT,
    'TD': _layer('QK_TAP_DANCE'),
    'LCG': lcg,
    'RCG': rcg,
    'LCG_T': lcgT,
    'RCG_T': rcgT,
  };
  for (var x = 0; x < 16; x++) {
    final layer = x;
    m['LT$x'] = (a) {
      _arity(a, 1);
      return _lt(layer, a[0]);
    };
  }
  return m;
}();

enum _Tok { num, name, op, lparen, rparen, comma, end }

class _Token {
  _Token(this.type, this.text, [this.value = 0]);

  final _Tok type;
  final String text;
  final int value;
}

/// Recursive-descent evaluator for the Python expression subset that the
/// reference implementation accepts: integer literals (decimal/hex/binary/
/// octal), names, calls, parentheses and the operators
/// `| ^ & << >> + - * / // %` plus unary `- + ~`.
class _Parser {
  _Parser(String source, this._names) : _tokens = _lex(source);

  final Map<String, int> _names;
  final List<_Token> _tokens;
  int _pos = 0;

  _Token get _cur => _tokens[_pos];

  int parse() {
    if (_cur.type == _Tok.end) throw const FormatException('empty expression');
    final v = _bitOr();
    if (_cur.type != _Tok.end) {
      throw FormatException('unexpected token ${_cur.text}');
    }
    return v;
  }

  bool _acceptOp(String op) {
    if (_cur.type == _Tok.op && _cur.text == op) {
      _pos++;
      return true;
    }
    return false;
  }

  int _bitOr() {
    var v = _bitXor();
    while (_acceptOp('|')) {
      v |= _bitXor();
    }
    return v;
  }

  int _bitXor() {
    var v = _bitAnd();
    while (_acceptOp('^')) {
      v ^= _bitAnd();
    }
    return v;
  }

  int _bitAnd() {
    var v = _shift();
    while (_acceptOp('&')) {
      v &= _shift();
    }
    return v;
  }

  int _shift() {
    var v = _additive();
    while (true) {
      if (_acceptOp('<<')) {
        v <<= _additive();
      } else if (_acceptOp('>>')) {
        v >>= _additive();
      } else {
        return v;
      }
    }
  }

  int _additive() {
    var v = _multiplicative();
    while (true) {
      if (_acceptOp('+')) {
        v += _multiplicative();
      } else if (_acceptOp('-')) {
        v -= _multiplicative();
      } else {
        return v;
      }
    }
  }

  int _multiplicative() {
    var v = _unary();
    while (true) {
      if (_acceptOp('*')) {
        v *= _unary();
      } else if (_acceptOp('//') || _acceptOp('/')) {
        final d = _unary();
        if (d == 0) throw const FormatException('division by zero');
        v = (v / d).floor();
      } else if (_acceptOp('%')) {
        final d = _unary();
        if (d == 0) throw const FormatException('modulo by zero');
        // Python semantics: result takes the sign of the divisor.
        v = v - d * (v / d).floor();
      } else {
        return v;
      }
    }
  }

  int _unary() {
    if (_acceptOp('-')) return -_unary();
    if (_acceptOp('+')) return _unary();
    if (_acceptOp('~')) return ~_unary();
    return _primary();
  }

  int _primary() {
    final t = _cur;
    switch (t.type) {
      case _Tok.num:
        _pos++;
        return t.value;
      case _Tok.lparen:
        _pos++;
        final v = _bitOr();
        _expect(_Tok.rparen);
        return v;
      case _Tok.name:
        _pos++;
        if (_cur.type == _Tok.lparen) {
          _pos++;
          final args = <int>[];
          if (_cur.type != _Tok.rparen) {
            args.add(_bitOr());
            while (_cur.type == _Tok.comma) {
              _pos++;
              args.add(_bitOr());
            }
          }
          _expect(_Tok.rparen);
          final fn = _functions[t.text];
          if (fn == null) throw FormatException('unknown function ${t.text}');
          return fn(args);
        }
        final v = _names[t.text];
        if (v == null) throw FormatException('unknown name ${t.text}');
        return v;
      default:
        throw FormatException('unexpected token ${t.text}');
    }
  }

  void _expect(_Tok type) {
    if (_cur.type != type) {
      throw FormatException('unexpected token ${_cur.text}');
    }
    _pos++;
  }

  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

  static bool _isNameStart(int c) =>
      (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c == 0x5F;

  static bool _isNameChar(int c) => _isNameStart(c) || _isDigit(c);

  static List<_Token> _lex(String s) {
    final out = <_Token>[];
    var i = 0;
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D) {
        i++;
        continue;
      }
      if (_isDigit(c)) {
        final start = i;
        var radix = 10;
        if (c == 0x30 && i + 1 < s.length) {
          final n = s[i + 1].toLowerCase();
          if (n == 'x') {
            radix = 16;
          } else if (n == 'b') {
            radix = 2;
          } else if (n == 'o') {
            radix = 8;
          }
          if (radix != 10) i += 2;
        }
        final digitsStart = i;
        while (i < s.length && (_isNameChar(s.codeUnitAt(i)) || s[i] == '_')) {
          i++;
        }
        final digits = s.substring(digitsStart, i).replaceAll('_', '');
        final v = int.tryParse(digits, radix: radix);
        if (v == null) {
          throw FormatException('bad number ${s.substring(start, i)}');
        }
        out.add(_Token(_Tok.num, s.substring(start, i), v));
        continue;
      }
      if (_isNameStart(c)) {
        final start = i;
        while (i < s.length && _isNameChar(s.codeUnitAt(i))) {
          i++;
        }
        out.add(_Token(_Tok.name, s.substring(start, i)));
        continue;
      }
      switch (s[i]) {
        case '(':
          out.add(_Token(_Tok.lparen, '('));
          i++;
        case ')':
          out.add(_Token(_Tok.rparen, ')'));
          i++;
        case ',':
          out.add(_Token(_Tok.comma, ','));
          i++;
        case '<':
        case '>':
          if (i + 1 < s.length && s[i + 1] == s[i]) {
            out.add(_Token(_Tok.op, s[i] + s[i]));
            i += 2;
          } else {
            throw FormatException('unexpected character ${s[i]}');
          }
        case '/':
          if (i + 1 < s.length && s[i + 1] == '/') {
            out.add(_Token(_Tok.op, '//'));
            i += 2;
          } else {
            out.add(_Token(_Tok.op, '/'));
            i++;
          }
        case '|':
        case '^':
        case '&':
        case '+':
        case '-':
        case '*':
        case '%':
        case '~':
          out.add(_Token(_Tok.op, s[i]));
          i++;
        default:
          throw FormatException('unexpected character ${s[i]}');
      }
    }
    out.add(_Token(_Tok.end, '<end>'));
    return out;
  }
}
