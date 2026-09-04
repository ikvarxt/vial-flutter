import 'dart:typed_data';

import '../util/bytes.dart';

const int msgLen = 32;

/// Static description of an enumerated HID interface, as reported by the
/// platform (hidapi on desktop, WebHID in the browser).
class HidDeviceInfo {
  const HidDeviceInfo({
    required this.path,
    required this.vendorId,
    required this.productId,
    this.serialNumber = '',
    this.manufacturer = '',
    this.product = '',
    this.usagePage = 0,
    this.usage = 0,
  });

  final String path;
  final int vendorId;
  final int productId;
  final String serialNumber;
  final String manufacturer;
  final String product;
  final int usagePage;
  final int usage;

  @override
  String toString() =>
      'HidDeviceInfo(${vendorId.toRadixString(16)}:'
      '${productId.toRadixString(16)} $path)';
}

/// An opened HID interface.
abstract class HidDevice {
  HidDeviceInfo get info;

  /// Sends one output report. Throws on failure.
  Future<void> write(Uint8List data);

  /// Reads one input report of up to [length] bytes. Returns an empty list
  /// when nothing arrives within [timeoutMs].
  Future<Uint8List> read(int length, {int timeoutMs = 0});

  Future<void> close();
}

abstract class HidBackend {
  Future<List<HidDeviceInfo>> enumerate();

  Future<HidDevice> open(HidDeviceInfo info);

  /// WebHID needs a user gesture to grant access to new devices; desktop
  /// backends see everything and return an empty list here.
  Future<List<HidDeviceInfo>> requestDevices() async => const [];
}

class HidCommunicationError implements Exception {
  HidCommunicationError(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef UsbSend = Future<Uint8List> Function(Uint8List msg, {int retries});

Future<Uint8List> hidSend(
  HidDevice dev,
  Uint8List msg, {
  int retries = 1,
}) async {
  if (msg.length > msgLen) {
    throw HidCommunicationError('message must be less than 32 bytes');
  }
  final padded = padTo(msg, msgLen);

  var data = Uint8List(0);
  var first = true;

  while (retries > 0) {
    retries -= 1;
    if (!first) await Future<void>.delayed(const Duration(milliseconds: 500));
    first = false;
    try {
      await dev.write(padded);
      data = await dev.read(msgLen, timeoutMs: 500);
      if (data.isEmpty) continue;
    } catch (_) {
      continue;
    }
    break;
  }

  if (data.isEmpty) {
    throw HidCommunicationError('failed to communicate with the device');
  }
  return data;
}

bool isRawHid(HidDeviceInfo desc) =>
    desc.usagePage == 0xFF60 && desc.usage == 0x61;

/// Pads message to vibl fixed 64-byte length.
Uint8List padForVibl(List<int> msg) {
  if (msg.length > 64) throw HidCommunicationError('vibl message too long');
  return padTo(msg, 64);
}
