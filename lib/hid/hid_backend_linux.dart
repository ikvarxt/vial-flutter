// SPDX-License-Identifier: GPL-2.0-or-later
import 'dart:io';
import 'dart:typed_data';

import 'hid_device.dart';
import 'hid_report_descriptor.dart';
import 'hidraw_worker.dart';

/// Linux backend talking to `/dev/hidrawN` directly, the way hidapi's hidraw
/// backend does for vial-gui. Enumeration is pure sysfs reading so it can be
/// unit-tested against a fake tree; I/O goes through [HidrawWorker].
class LinuxHidrawBackend implements HidBackend {
  LinuxHidrawBackend({
    this.sysClassHidraw = '/sys/class/hidraw',
    this.devDir = '/dev',
    Future<HidrawWorker> Function()? spawnWorker,
  }) : _spawnWorker = spawnWorker ?? HidrawWorker.spawn;

  final String sysClassHidraw;
  final String devDir;
  final Future<HidrawWorker> Function() _spawnWorker;
  Future<HidrawWorker>? _worker;

  Future<HidrawWorker> get worker => _worker ??= _spawnWorker();

  @override
  bool get needsUserGesture => false;

  @override
  bool get exposesSerialNumber => true;

  @override
  Future<List<HidDeviceInfo>> enumerate() async {
    final root = Directory(sysClassHidraw);
    if (!root.existsSync()) return const [];
    final out = <HidDeviceInfo>[];
    final nodes = root.listSync().map((e) => e.path).toList()..sort();
    for (final node in nodes) {
      try {
        out.addAll(_describe(node));
      } catch (_) {
        // A node that vanished mid-enumeration or has unreadable sysfs
        // attributes is simply skipped, like hidapi does.
      }
    }
    return out;
  }

  List<HidDeviceInfo> _describe(String node) {
    final name = node.split('/').last;
    final hidDir = '$node/device';
    final uevent = _parseUevent(File('$hidDir/uevent').readAsStringSync());
    final hidId = (uevent['HID_ID'] ?? '').split(':');
    if (hidId.length != 3) return const [];
    final vendorId = int.parse(hidId[1], radix: 16);
    final productId = int.parse(hidId[2], radix: 16);

    final usb = _usbStrings(hidDir);
    final product = usb?['product'] ?? uevent['HID_NAME'] ?? '';
    final manufacturer = usb?['manufacturer'] ?? '';
    final serial = usb?['serial'] ?? uevent['HID_UNIQ'] ?? '';

    final descFile = File('$hidDir/report_descriptor');
    var usages = descFile.existsSync()
        ? topLevelUsages(descFile.readAsBytesSync())
        : const <(int, int)>[];
    if (usages.isEmpty) usages = const [(0, 0)];

    return [
      for (final (page, usage) in usages)
        HidDeviceInfo(
          path: '$devDir/$name',
          vendorId: vendorId,
          productId: productId,
          serialNumber: serial,
          manufacturer: manufacturer,
          product: product,
          usagePage: page,
          usage: usage,
        ),
    ];
  }

  static Map<String, String> _parseUevent(String text) {
    final out = <String, String>{};
    for (final line in text.split('\n')) {
      final eq = line.indexOf('=');
      if (eq > 0) out[line.substring(0, eq)] = line.substring(eq + 1).trim();
    }
    return out;
  }

  /// Walks up from the HID device to the USB device node (the first ancestor
  /// carrying `idVendor`) and reads its string descriptors. Returns null for
  /// non-USB transports such as Bluetooth.
  static Map<String, String>? _usbStrings(String hidDir) {
    var dir = Directory(hidDir);
    try {
      dir = Directory(dir.resolveSymbolicLinksSync());
    } on FileSystemException {
      return null;
    }
    for (var depth = 0; depth < 6; depth++) {
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
      if (File('${dir.path}/idVendor').existsSync()) {
        return {
          for (final key in ['manufacturer', 'product', 'serial'])
            key: _readAttr('${dir.path}/$key'),
        };
      }
    }
    return null;
  }

  static String _readAttr(String path) {
    final f = File(path);
    return f.existsSync() ? f.readAsStringSync().trim() : '';
  }

  @override
  Future<HidDevice> open(HidDeviceInfo info) async {
    final w = await worker;
    final fd = await w.open(info.path);
    return _HidrawDevice(info, w, fd);
  }

  @override
  Future<List<HidDeviceInfo>> requestDevices() async => const [];
}

class _HidrawDevice implements HidDevice {
  _HidrawDevice(this.info, this._worker, this._fd);

  @override
  final HidDeviceInfo info;
  final HidrawWorker _worker;
  final int _fd;
  var _closed = false;

  @override
  Future<void> write(Uint8List data) {
    if (_closed) throw HidCommunicationError('device is not open');
    return _worker.write(_fd, data);
  }

  @override
  Future<Uint8List> read(int length, {int timeoutMs = 0}) {
    if (_closed) throw HidCommunicationError('device is not open');
    return _worker.read(_fd, length, timeoutMs);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _worker.close(_fd);
  }
}
