// SPDX-License-Identifier: GPL-2.0-or-later
import 'dart:typed_data';

/// Returns the (usage page, usage) pair of every top-level Application
/// collection in a HID report descriptor, in declaration order.
///
/// This mirrors hidapi's `get_next_hid_usage` so that a hidraw node exposing
/// several collections yields one device entry per collection, the same way
/// IOHIDManager and WebHID report them.
List<(int, int)> topLevelUsages(Uint8List descriptor) {
  final result = <(int, int)>[];
  var usagePage = 0;
  int? usage;
  var depth = 0;
  var i = 0;

  while (i < descriptor.length) {
    final key = descriptor[i];
    if (key == 0xFE) {
      // Long item: 0xFE, bDataSize, bLongItemTag, data...
      if (i + 1 >= descriptor.length) break;
      i += 3 + descriptor[i + 1];
      continue;
    }
    var size = key & 0x03;
    if (size == 3) size = 4;
    final type = (key >> 2) & 0x03;
    final tag = key >> 4;
    if (i + 1 + size > descriptor.length) break;
    var data = 0;
    for (var k = 0; k < size; k++) {
      data |= descriptor[i + 1 + k] << (8 * k);
    }
    i += 1 + size;

    switch (type) {
      case 1: // global
        if (tag == 0) usagePage = data;
      case 2: // local
        if (tag == 0) {
          if (size == 4) {
            // Extended usage carries its own page in the upper 16 bits.
            usagePage = data >> 16;
            usage = data & 0xFFFF;
          } else {
            usage = data;
          }
        }
      case 0: // main
        if (tag == 0x0A) {
          if (depth == 0 && usage != null) result.add((usagePage, usage));
          depth++;
        } else if (tag == 0x0C) {
          if (depth > 0) depth--;
        }
        // Local items only apply up to the next main item.
        usage = null;
    }
  }
  return result;
}
