// SPDX-License-Identifier: GPL-2.0-or-later
import 'dart:convert';
import 'dart:typed_data';

import 'qmk_settings_json.dart';

class QmkSettingField {
  QmkSettingField(this.raw);

  final Map<String, dynamic> raw;

  String get type => raw['type'] as String;

  String get title => raw['title'] as String;

  int get qsid => raw['qsid'] as int;

  int get width => (raw['width'] as int?) ?? 1;

  int get bit => (raw['bit'] as int?) ?? 0;

  int get min => (raw['min'] as int?) ?? 0;

  int get max => (raw['max'] as int?) ?? 0;
}

class QmkSettingTab {
  QmkSettingTab(this.name, this.fields);

  final String name;
  final List<QmkSettingField> fields;
}

/// Static description of the QMK settings the firmware may expose, indexed by
/// settings id (qsid).
class QmkSettings {
  QmkSettings._();

  static List<QmkSettingTab>? _tabs;
  static final Map<int, List<QmkSettingField>> _qsidFields = {};

  static List<QmkSettingTab> get tabs {
    initialize();
    return _tabs!;
  }

  static void initialize() {
    if (_tabs != null) return;
    final settings = jsonDecode(qmkSettingsJson) as Map<String, dynamic>;
    final tabs = <QmkSettingTab>[];
    for (final tab in settings['tabs'] as List) {
      final t = tab as Map<String, dynamic>;
      final fields = [
        for (final f in t['fields'] as List)
          QmkSettingField(f as Map<String, dynamic>),
      ];
      tabs.add(QmkSettingTab(t['name'] as String, fields));
      for (final f in fields) {
        _qsidFields.putIfAbsent(f.qsid, () => []).add(f);
      }
    }
    _tabs = tabs;
  }

  static bool isQsidSupported(int qsid) {
    initialize();
    return _qsidFields.containsKey(qsid);
  }

  static Uint8List qsidSerialize(int qsid, int data) {
    initialize();
    final field = _qsidFields[qsid]![0];
    if (field.type == 'boolean' || field.type == 'integer') {
      return _toBytesLe(data, field.width);
    }
    throw StateError('unsupported field');
  }

  static int qsidDeserialize(int qsid, List<int> data) {
    initialize();
    final field = _qsidFields[qsid]![0];
    if (field.type == 'boolean' || field.type == 'integer') {
      return _fromBytesLe(data.sublist(0, field.width));
    }
    throw StateError('unsupported field');
  }

  static Uint8List _toBytesLe(int v, int width) {
    final out = Uint8List(width);
    for (var i = 0; i < width; i++) {
      out[i] = (v >> (8 * i)) & 0xFF;
    }
    return out;
  }

  static int _fromBytesLe(List<int> d) {
    var v = 0;
    for (var i = d.length - 1; i >= 0; i--) {
      v = (v << 8) | d[i];
    }
    return v;
  }
}
