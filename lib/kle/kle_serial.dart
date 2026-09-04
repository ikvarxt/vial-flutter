// Based on https://github.com/ijprest/kle-serial
// & see https://github.com/ijprest/kle-serial/pull/1

class KleKeyDefaults {
  String textColor = '#000000';
  num textSize = 3;

  KleKeyDefaults copy() => KleKeyDefaults()
    ..textColor = textColor
    ..textSize = textSize;
}

class KleKey {
  String color = '#cccccc';
  List<String?> labels = [];
  List<String?> textColor = List<String?>.filled(12, null);
  List<num?> textSize = [];
  KleKeyDefaults defaults = KleKeyDefaults();
  num x = 0;
  num y = 0;
  num width = 1;
  num height = 1;
  num x2 = 0;
  num y2 = 0;
  num width2 = 1;
  num height2 = 1;
  num rotationX = 0;
  num rotationY = 0;
  num rotationAngle = 0;
  bool decal = false;
  bool ghost = false;
  bool stepped = false;
  bool nub = false;
  String profile = '';
  String sm = '';
  String sb = '';
  String st = '';

  // Vial-specific annotations filled in by the keyboard loader.
  int? row;
  int? col;
  int? encoderIdx;
  int? encoderDir;
  int layoutIndex = -1;
  int layoutOption = -1;

  KleKey copy() => KleKey()
    ..color = color
    ..labels = List.of(labels)
    ..textColor = List.of(textColor)
    ..textSize = List.of(textSize)
    ..defaults = defaults
    ..x = x
    ..y = y
    ..width = width
    ..height = height
    ..x2 = x2
    ..y2 = y2
    ..width2 = width2
    ..height2 = height2
    ..rotationX = rotationX
    ..rotationY = rotationY
    ..rotationAngle = rotationAngle
    ..decal = decal
    ..ghost = ghost
    ..stepped = stepped
    ..nub = nub
    ..profile = profile
    ..sm = sm
    ..sb = sb
    ..st = st;
}

class KleKeyboardMetadata {
  String author = '';
  String backcolor = '#eeeeee';
  String? background;
  String name = '';
  String notes = '';
  String radii = '';
  String switchBrand = '';
  String switchMount = '';
  String switchType = '';
}

class KleKeyboard {
  final KleKeyboardMetadata meta = KleKeyboardMetadata();
  final List<KleKey> keys = [];
}

class KleDeserializeError implements Exception {
  KleDeserializeError(this.message);

  final String message;

  @override
  String toString() => 'Error: $message';
}

class KleSerial {
  static const List<List<int>> labelMap = [
    // 0  1  2  3  4  5  6  7  8  9 10 11   # align flags
    [0, 6, 2, 8, 9, 11, 3, 5, 1, 4, 7, 10], // 0 = no centering
    [1, 7, -1, -1, 9, 11, 4, -1, -1, -1, -1, 10], // 1 = center x
    [3, -1, 5, -1, 9, 11, -1, -1, 4, -1, -1, 10], // 2 = center y
    [4, -1, -1, -1, 9, 11, -1, -1, -1, -1, -1, 10], // 3 = center x & y
    [0, 6, 2, 8, 10, -1, 3, 5, 1, 4, 7, -1], // 4 = center front (default)
    [1, 7, -1, -1, 10, -1, 4, -1, -1, -1, -1, -1], // 5 = center front & x
    [3, -1, 5, -1, 10, -1, -1, -1, 4, -1, -1, -1], // 6 = center front & y
    [4, -1, -1, -1, 10, -1, -1, -1, -1, -1, -1, -1], // 7 = center front & x & y
  ];

  List<T?> reorderLabelsIn<T>(List<T?> labels, int align) {
    final ret = List<T?>.filled(12, null);
    for (var i = 0; i < labels.length && i < 12; i++) {
      final v = labels[i];
      if (v != null && v != '' && v != 0) {
        final target = labelMap[align][i];
        if (target >= 0) ret[target] = v;
      }
    }
    return ret;
  }

  Never _error(String msg, Object? data) =>
      throw KleDeserializeError('$msg $data');

  KleKeyboard deserialize(List<dynamic> rows) {
    var current = KleKey();
    num clusterX = 0;
    num clusterY = 0;
    final kbd = KleKeyboard();
    var align = 4;

    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      if (row is List) {
        for (var k = 0; k < row.length; k++) {
          final item = row[k];
          if (item is String) {
            final newKey = current.copy();

            newKey.width2 = newKey.width2 == 0 ? current.width : current.width2;
            newKey.height2 = newKey.height2 == 0
                ? current.height
                : current.height2;
            newKey.labels = reorderLabelsIn(item.split('\n'), align);
            newKey.textSize = reorderLabelsIn(newKey.textSize, align);

            for (var i = 0; i < 12; i++) {
              if (newKey.labels[i] == null) {
                newKey.textSize[i] = null;
                newKey.textColor[i] = null;
              }
              if (newKey.textSize[i] == newKey.defaults.textSize) {
                newKey.textSize[i] = null;
              }
              if (newKey.textColor[i] == newKey.defaults.textColor) {
                newKey.textColor[i] = null;
              }
            }

            kbd.keys.add(newKey);

            current.x += current.width;
            current.width = current.height = 1;
            current.x2 = current.y2 = current.width2 = current.height2 = 0;
            current.nub = current.stepped = current.decal = false;
          } else if (item is Map) {
            if (k != 0 &&
                (item.containsKey('r') ||
                    item.containsKey('rx') ||
                    item.containsKey('ry'))) {
              _error(
                'rotation can only be specified on the first key in a row',
                item,
              );
            }
            if (item.containsKey('r')) {
              current.rotationAngle = item['r'] as num;
            }
            if (item.containsKey('rx')) {
              current.rotationX = clusterX = item['rx'] as num;
              current.x = clusterX;
              current.y = clusterY;
            }
            if (item.containsKey('ry')) {
              current.rotationY = clusterY = item['ry'] as num;
              current.x = clusterX;
              current.y = clusterY;
            }
            if (item.containsKey('a')) align = (item['a'] as num).toInt();
            if (item.containsKey('f')) {
              current.defaults = current.defaults.copy()
                ..textSize = item['f'] as num;
              current.textSize = [];
            }
            if (item.containsKey('f2')) {
              while (current.textSize.length < 12) {
                current.textSize.add(null);
              }
              for (var i = 1; i < 12; i++) {
                current.textSize[i] = item['f2'] as num;
              }
            }
            if (item.containsKey('fa')) {
              current.textSize = List<num?>.from(item['fa'] as List);
            }
            if (item.containsKey('p')) current.profile = item['p'] as String;
            if (item.containsKey('c')) current.color = item['c'] as String;
            if (item.containsKey('t')) {
              final split = (item['t'] as String).split('\n');
              if (split[0] != '') {
                current.defaults = current.defaults.copy()
                  ..textColor = split[0];
              }
              current.textColor = reorderLabelsIn(split, align);
            }
            if (item.containsKey('x')) current.x += item['x'] as num;
            if (item.containsKey('y')) current.y += item['y'] as num;
            if (item.containsKey('w')) {
              current.width = current.width2 = item['w'] as num;
            }
            if (item.containsKey('h')) {
              current.height = current.height2 = item['h'] as num;
            }
            if (item.containsKey('x2')) current.x2 = item['x2'] as num;
            if (item.containsKey('y2')) current.y2 = item['y2'] as num;
            if (item.containsKey('w2')) current.width2 = item['w2'] as num;
            if (item.containsKey('h2')) current.height2 = item['h2'] as num;
            if (item.containsKey('n')) current.nub = item['n'] == true;
            if (item.containsKey('l')) current.stepped = item['l'] == true;
            if (item.containsKey('d')) current.decal = item['d'] == true;
            if (item['g'] == true) current.ghost = true;
            if (item.containsKey('sm')) current.sm = item['sm'] as String;
            if (item.containsKey('sb')) current.sb = item['sb'] as String;
            if (item.containsKey('st')) current.st = item['st'] as String;
          }
        }

        current.y += 1;
        current.x = current.rotationX;
      } else if (row is Map) {
        if (r != 0) {
          _error('keyboard metadata must the be first element', row);
        }
        final name = row['name'];
        if (name is String) kbd.meta.name = name;
      }
    }
    return kbd;
  }
}
