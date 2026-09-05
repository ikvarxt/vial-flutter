// SPDX-License-Identifier: GPL-2.0-or-later
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vial_flutter/hid/hid_backend_linux.dart';
import 'package:vial_flutter/hid/hid_device.dart';
import 'package:vial_flutter/hid/hid_report_descriptor.dart';

/// QMK raw HID interface: usage page 0xFF60, usage 0x61, one collection.
final rawHidDescriptor = Uint8List.fromList([
  0x06, 0x60, 0xFF, // Usage Page (Vendor 0xFF60)
  0x09, 0x61, //       Usage (0x61)
  0xA1, 0x01, //       Collection (Application)
  0x09, 0x62, //         Usage (0x62)
  0x15, 0x00, 0x26, 0xFF, 0x00, 0x95, 0x20, 0x75, 0x08, 0x81, 0x02,
  0x09, 0x63, //         Usage (0x63)
  0x15, 0x00, 0x26, 0xFF, 0x00, 0x95, 0x20, 0x75, 0x08, 0x91, 0x02,
  0xC0, //             End Collection
]);

/// Keyboard + consumer control on one interface, as QMK's shared endpoint.
final sharedDescriptor = Uint8List.fromList([
  0x05, 0x01, 0x09, 0x06, 0xA1, 0x01, // Generic Desktop / Keyboard
  0x85, 0x01, 0x05, 0x07, 0x19, 0xE0, 0x29, 0xE7, 0x15, 0x00, 0x25, 0x01,
  0x95, 0x08, 0x75, 0x01, 0x81, 0x02,
  0xA1, 0x02, 0xC0, // nested collection must not count
  0xC0,
  0x05, 0x0C, 0x09, 0x01, 0xA1, 0x01, // Consumer / Consumer Control
  0x85, 0x02, 0x19, 0x01, 0x2A, 0x9C, 0x02, 0x15, 0x01, 0x26, 0x9C, 0x02,
  0x95, 0x01, 0x75, 0x10, 0x81, 0x00,
  0xC0,
]);

void main() {
  group('topLevelUsages', () {
    test('finds the raw HID collection', () {
      expect(topLevelUsages(rawHidDescriptor), [(0xFF60, 0x61)]);
    });

    test('reports every top-level collection and skips nested ones', () {
      expect(topLevelUsages(sharedDescriptor), [(0x01, 0x06), (0x0C, 0x01)]);
    });

    test('understands extended (4-byte) usages and long items', () {
      final d = Uint8List.fromList([
        0xFE, 0x02, 0x00, 0xAA, 0xBB, // long item, skipped
        0x0B, 0x61, 0x00, 0x60, 0xFF, // Usage (page 0xFF60, id 0x61)
        0xA1, 0x01, 0xC0,
      ]);
      expect(topLevelUsages(d), [(0xFF60, 0x61)]);
    });

    test('tolerates truncated descriptors', () {
      expect(topLevelUsages(Uint8List.fromList([0x06, 0x60])), isEmpty);
      expect(topLevelUsages(Uint8List(0)), isEmpty);
    });
  });

  group('LinuxHidrawBackend.enumerate', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('vial_hidraw_');
    });

    tearDown(() {
      root.deleteSync(recursive: true);
    });

    /// Builds the slice of sysfs hidapi walks: the USB device directory
    /// holding the string descriptors, its interface, the HID device with
    /// uevent/report_descriptor, and the /sys/class/hidraw symlink to it.
    void addUsbNode({
      required String name,
      required Uint8List descriptor,
      String vid = '0000FEED',
      String pid = '00006060',
    }) {
      final usbDev = Directory('${root.path}/devices/usb1/1-2')
        ..createSync(recursive: true);
      File('${usbDev.path}/idVendor').writeAsStringSync('feed\n');
      File('${usbDev.path}/manufacturer').writeAsStringSync('Acme\n');
      File('${usbDev.path}/product').writeAsStringSync('Cornix\n');
      File('${usbDev.path}/serial').writeAsStringSync('vial:f64c2b3c\n');
      final hid = Directory('${usbDev.path}/1-2:1.1/0003:$vid:$pid.0005')
        ..createSync(recursive: true);
      File('${hid.path}/uevent').writeAsStringSync(
        'DRIVER=hid-generic\n'
        'HID_ID=0003:$vid:$pid\n'
        'HID_NAME=Acme Cornix\n'
        'HID_PHYS=usb-0000:00:14.0-2/input1\n'
        'HID_UNIQ=vial:f64c2b3c\n'
        'MODALIAS=hid:b0003g0001v0000FEEDp00006060\n',
      );
      File('${hid.path}/report_descriptor').writeAsBytesSync(descriptor);
      final node = Directory('${root.path}/class/hidraw/$name')
        ..createSync(recursive: true);
      Link('${node.path}/device').createSync(hid.path);
    }

    void addBluetoothNode({required String name}) {
      final hid = Directory('${root.path}/devices/bt/0005:1234:5678.0002')
        ..createSync(recursive: true);
      File('${hid.path}/uevent').writeAsStringSync(
        'HID_ID=0005:00001234:00005678\n'
        'HID_NAME=BT Board\n'
        'HID_UNIQ=aa:bb:cc:dd:ee:ff\n',
      );
      File('${hid.path}/report_descriptor').writeAsBytesSync(sharedDescriptor);
      final node = Directory('${root.path}/class/hidraw/$name')
        ..createSync(recursive: true);
      Link('${node.path}/device').createSync(hid.path);
    }

    LinuxHidrawBackend backend() => LinuxHidrawBackend(
      sysClassHidraw: '${root.path}/class/hidraw',
      devDir: '/dev',
      spawnWorker: () => throw StateError('no I/O in this test'),
    );

    test('returns an empty list when sysfs has no hidraw class', () async {
      expect(await backend().enumerate(), isEmpty);
    });

    test('describes a USB raw HID interface like hidapi', () async {
      addUsbNode(name: 'hidraw3', descriptor: rawHidDescriptor);
      final devices = await backend().enumerate();
      expect(devices, hasLength(1));
      final d = devices.single;
      expect(d.path, '/dev/hidraw3');
      expect(d.vendorId, 0xFEED);
      expect(d.productId, 0x6060);
      expect(d.manufacturer, 'Acme');
      expect(d.product, 'Cornix');
      expect(d.serialNumber, 'vial:f64c2b3c');
      expect(isRawHid(d), isTrue);
    });

    test('emits one entry per top-level collection', () async {
      addUsbNode(name: 'hidraw0', descriptor: sharedDescriptor);
      final devices = await backend().enumerate();
      expect(devices.map((d) => (d.usagePage, d.usage)), [
        (0x01, 0x06),
        (0x0C, 0x01),
      ]);
      expect(devices.every((d) => d.path == '/dev/hidraw0'), isTrue);
      expect(devices.any(isRawHid), isFalse);
    });

    test('falls back to uevent strings for non-USB transports', () async {
      addBluetoothNode(name: 'hidraw1');
      final d = (await backend().enumerate()).first;
      expect(d.vendorId, 0x1234);
      expect(d.productId, 0x5678);
      expect(d.product, 'BT Board');
      expect(d.manufacturer, '');
      expect(d.serialNumber, 'aa:bb:cc:dd:ee:ff');
    });

    test('skips nodes with unreadable attributes', () async {
      addUsbNode(name: 'hidraw0', descriptor: rawHidDescriptor);
      Directory('${root.path}/class/hidraw/hidraw9').createSync();
      final devices = await backend().enumerate();
      expect(devices.map((d) => d.path), ['/dev/hidraw0']);
    });
  });
}
