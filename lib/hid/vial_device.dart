import 'dart:typed_data';

import '../protocol/dummy_keyboard.dart';
import '../protocol/keyboard.dart';
import 'hid_device.dart';

// For Vial keyboard
const String vialSerialNumberMagic = 'vial:f64c2b3c';

// For bootloader
const String viblSerialNumberMagic = 'vibl:d4f8159c';

abstract class VialDevice {
  VialDevice(this.desc, this.backend);

  final HidDeviceInfo desc;
  final HidBackend backend;
  HidDevice? dev;
  bool sideload = false;
  bool viaStack = false;

  String get title;

  Future<void> open([Map<String, dynamic>? overrideJson]) async {
    for (var x = 0; x < 10; x++) {
      try {
        dev = await backend.open(desc);
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    throw StateError('unable to open the device');
  }

  Future<void> send(List<int> data) => dev!.write(Uint8List.fromList(data));

  Future<Uint8List> recv(int length, {int timeoutMs = 0}) =>
      dev!.read(length, timeoutMs: timeoutMs);

  Future<void> close() async {
    await dev?.close();
    dev = null;
  }

  Future<Uint8List> getUid();
}

class VialKeyboard extends VialDevice {
  VialKeyboard(
    super.desc,
    super.backend, {
    bool sideload = false,
    bool viaStack = false,
  }) : viaId = (desc.vendorId * 65536 + desc.productId).toString() {
    this.sideload = sideload;
    this.viaStack = viaStack;
  }

  final String viaId;
  Keyboard? keyboard;

  @override
  Future<void> open([Map<String, dynamic>? overrideJson]) async {
    await super.open(overrideJson);
    keyboard = Keyboard(dev);
    await keyboard!.reload(overrideJson);
  }

  @override
  String get title {
    var s = '${desc.manufacturer} ${desc.product}'.trim();
    if (sideload) {
      s += ' [sideload]';
    } else if (viaStack) {
      s += ' [VIA]';
    }
    return s;
  }

  @override
  Future<Uint8List> getUid() async {
    try {
      await super.open();
    } catch (_) {
      return Uint8List(0);
    }
    await send([0xFE, 0x00, ...List.filled(30, 0)]);
    final data = await recv(msgLen, timeoutMs: 500);
    await super.close();
    return data.length >= 12 ? Uint8List.sublistView(data, 4, 12) : data;
  }
}

class VialBootloader extends VialDevice {
  VialBootloader(super.desc, super.backend);

  @override
  String get title =>
      'Vial Bootloader [${_hex4(desc.vendorId)}:${_hex4(desc.productId)}]';

  @override
  Future<Uint8List> getUid() async {
    try {
      await super.open();
    } catch (_) {
      return Uint8List(0);
    }
    await send(padForVibl([0x56, 0x43, 0x01])); // b"VC\x01"
    final data = await recv(8, timeoutMs: 500);
    await super.close();
    return data;
  }
}

class VialDummyKeyboard extends VialKeyboard {
  VialDummyKeyboard()
    : super(
        const HidDeviceInfo(path: '/dummy/keyboard', vendorId: 0, productId: 0),
        const _NoBackend(),
        sideload: true,
      );

  @override
  Future<void> open([Map<String, dynamic>? overrideJson]) async {
    keyboard = DummyKeyboard(usbSend: _raiseUsbSend);
    await keyboard!.reload(overrideJson);
  }

  @override
  String get title => '[Dummy Keyboard]';

  static Future<Uint8List> _raiseUsbSend(Uint8List msg, {int retries = 1}) {
    throw StateError('usb_send - should not be called!');
  }

  @override
  Future<void> close() async {}
}

class _NoBackend implements HidBackend {
  const _NoBackend();

  @override
  bool get needsUserGesture => false;

  @override
  bool get exposesSerialNumber => true;

  @override
  Future<List<HidDeviceInfo>> enumerate() async => const [];

  @override
  Future<HidDevice> open(HidDeviceInfo info) =>
      throw StateError('no backend for the dummy keyboard');

  @override
  Future<List<HidDeviceInfo>> requestDevices() async => const [];
}

String _hex4(int v) => v.toRadixString(16).toUpperCase().padLeft(4, '0');

/// Enumerates HID devices and wraps the ones that look like Vial keyboards,
/// Vial bootloaders or VIA-stack keyboards.
Future<List<VialDevice>> findVialDevices(
  HidBackend backend,
  Map<String, dynamic> viaStackJson, {
  int? sideloadVid,
  int? sideloadPid,
}) async {
  final definitions = viaStackJson['definitions'] as Map<String, dynamic>?;
  final filtered = <VialDevice>[];
  for (final dev in await backend.enumerate()) {
    final serial = dev.serialNumber;
    if (dev.vendorId == sideloadVid && dev.productId == sideloadPid) {
      if (isRawHid(dev)) {
        filtered.add(VialKeyboard(dev, backend, sideload: true));
      }
    } else if (serial.contains(vialSerialNumberMagic) ||
        (!backend.exposesSerialNumber && isRawHid(dev))) {
      if (isRawHid(dev)) filtered.add(VialKeyboard(dev, backend));
    } else if (serial.contains(viblSerialNumberMagic)) {
      filtered.add(VialBootloader(dev, backend));
    } else if (definitions != null &&
        definitions.containsKey(
          (dev.vendorId * 65536 + dev.productId).toString(),
        )) {
      if (isRawHid(dev)) {
        filtered.add(VialKeyboard(dev, backend, viaStack: true));
      }
    }
  }

  if (sideloadVid == 0 && sideloadPid == 0) filtered.add(VialDummyKeyboard());

  return filtered;
}
