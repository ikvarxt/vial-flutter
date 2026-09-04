import 'dart:typed_data';

/// Little helper mirroring Python's struct.pack for the fixed layouts the
/// Vial protocol uses.
class ByteWriter {
  final BytesBuilder _b = BytesBuilder(copy: false);

  ByteWriter u8(int v) {
    _b.addByte(v & 0xFF);
    return this;
  }

  ByteWriter u16be(int v) {
    _b.addByte((v >> 8) & 0xFF);
    _b.addByte(v & 0xFF);
    return this;
  }

  ByteWriter u16le(int v) {
    _b.addByte(v & 0xFF);
    _b.addByte((v >> 8) & 0xFF);
    return this;
  }

  ByteWriter u32be(int v) {
    _b.addByte((v >> 24) & 0xFF);
    _b.addByte((v >> 16) & 0xFF);
    _b.addByte((v >> 8) & 0xFF);
    _b.addByte(v & 0xFF);
    return this;
  }

  ByteWriter u32le(int v) {
    _b.addByte(v & 0xFF);
    _b.addByte((v >> 8) & 0xFF);
    _b.addByte((v >> 16) & 0xFF);
    _b.addByte((v >> 24) & 0xFF);
    return this;
  }

  ByteWriter u64le(int v) {
    for (var i = 0; i < 8; i++) {
      _b.addByte((v >> (8 * i)) & 0xFF);
    }
    return this;
  }

  ByteWriter bytes(List<int> data) {
    _b.add(data);
    return this;
  }

  Uint8List build() => _b.toBytes();
}

Uint8List packBytes(List<int> values) => Uint8List.fromList(values);

int readU16be(List<int> d, int off) => (d[off] << 8) | d[off + 1];

int readU16le(List<int> d, int off) => d[off] | (d[off + 1] << 8);

int readU32be(List<int> d, int off) =>
    (d[off] << 24) | (d[off + 1] << 16) | (d[off + 2] << 8) | d[off + 3];

int readU32le(List<int> d, int off) =>
    d[off] | (d[off + 1] << 8) | (d[off + 2] << 16) | (d[off + 3] << 24);

int readU64le(List<int> d, int off) {
  var v = 0;
  for (var i = 7; i >= 0; i--) {
    v = (v << 8) | d[off + i];
  }
  return v;
}

/// Splits [data] into consecutive slices of at most [size] elements.
Iterable<List<int>> chunks(List<int> data, int size) sync* {
  for (var i = 0; i < data.length; i += size) {
    yield data.sublist(i, i + size > data.length ? data.length : i + size);
  }
}

Uint8List padTo(List<int> data, int length, [int fill = 0]) {
  final out = Uint8List(length)..fillRange(0, length, fill);
  out.setRange(0, data.length > length ? length : data.length, data);
  return out;
}

BigInt readU64leBig(List<int> d, int off) {
  var v = BigInt.zero;
  for (var i = 7; i >= 0; i--) {
    v = (v << 8) | BigInt.from(d[off + i]);
  }
  return v;
}

int _sizeOf(String c) => switch (c) {
  'B' => 1,
  'H' => 2,
  'I' => 4,
  'Q' => 8,
  _ => throw ArgumentError('unsupported struct code $c'),
};

/// Size in bytes of a Python-style struct format made of `B`/`H`/`I`/`Q`.
int calcsize(String fmt) =>
    fmt.codeUnits.fold(0, (n, c) => n + _sizeOf(String.fromCharCode(c)));

/// Little-endian unpack of a struct format made of `B`/`H`/`I`/`Q`.
List<int> unpackLe(String fmt, List<int> data, [int offset = 0]) {
  final out = <int>[];
  var off = offset;
  for (final c in fmt.split('')) {
    switch (c) {
      case 'B':
        out.add(data[off]);
      case 'H':
        out.add(readU16le(data, off));
      case 'I':
        out.add(readU32le(data, off));
      case 'Q':
        out.add(readU64le(data, off));
      default:
        throw ArgumentError('unsupported struct code $c');
    }
    off += _sizeOf(c);
  }
  return out;
}

/// Little-endian pack of a struct format made of `B`/`H`/`I`/`Q`.
Uint8List packLe(String fmt, List<int> values) {
  if (fmt.length != values.length) {
    throw ArgumentError('format $fmt expects ${fmt.length} values');
  }
  final w = ByteWriter();
  for (var i = 0; i < fmt.length; i++) {
    switch (fmt[i]) {
      case 'B':
        w.u8(values[i]);
      case 'H':
        w.u16le(values[i]);
      case 'I':
        w.u32le(values[i]);
      case 'Q':
        w.u64le(values[i]);
      default:
        throw ArgumentError('unsupported struct code ${fmt[i]}');
    }
  }
  return w.build();
}
