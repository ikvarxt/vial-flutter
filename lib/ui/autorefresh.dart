import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../hid/hid_backend.dart';
import '../hid/hid_device.dart';
import '../hid/vial_device.dart';

typedef DevicesUpdated = void Function(List<VialDevice> devices, bool hard);

/// Device discovery mirroring the reference `Autorefresh` + thread pair.
///
/// On desktop the HID bus is polled every second; on the web the browser only
/// exposes devices the user granted through [requestDevices], so the caller
/// has to trigger [update] explicitly after that.
class Autorefresh {
  Autorefresh._();

  static final Autorefresh instance = Autorefresh._();

  /// Replaceable so tests can plug in a virtual keyboard.
  HidBackend backend = createHidBackend();

  List<VialDevice> devices = [];
  VialDevice? currentDevice;
  DevicesUpdated? onDevicesUpdated;

  Map<String, dynamic>? sideloadJson;
  int? _sideloadVid;
  int? _sideloadPid;
  Map<String, dynamic> viaStackJson = {'definitions': <String, dynamic>{}};

  bool _locked = false;
  bool _updating = false;
  Timer? _timer;

  bool get pollsAutomatically => !backend.needsUserGesture;

  void start() {
    if (!pollsAutomatically || _timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => update());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void lock() => _locked = true;

  void unlock() => _locked = false;

  Future<void> update({bool quiet = true, bool hard = false}) async {
    if (_locked || _updating) return;
    _updating = true;
    try {
      List<VialDevice> newDevices;
      try {
        newDevices = await findVialDevices(
          backend,
          viaStackJson,
          sideloadVid: _sideloadVid,
          sideloadPid: _sideloadPid,
        );
      } catch (e) {
        if (!quiet) rethrow;
        return;
      }
      if (_locked) return;

      final oldPaths = devices.map((d) => d.desc.path).toSet();
      final newPaths = newDevices.map((d) => d.desc.path).toSet();
      if (!hard && setEquals(oldPaths, newPaths)) return;

      devices = newDevices;
      final oldPath = currentDevice?.desc.path ?? 'blank';
      onDevicesUpdated?.call(newDevices, !newPaths.contains(oldPath) || hard);
    } finally {
      _updating = false;
    }
  }

  /// Web only: asks the browser for access to a device, then rescans.
  Future<void> requestDevices() async {
    await backend.requestDevices();
    await update(quiet: false, hard: true);
  }

  Future<void> loadDummy(String data) async {
    sideloadJson = jsonDecode(data) as Map<String, dynamic>;
    _sideloadVid = 0;
    _sideloadPid = 0;
    await update(quiet: false);
  }

  Future<void> sideloadViaJson(String data) async {
    final json = jsonDecode(data) as Map<String, dynamic>;
    sideloadJson = json;
    _sideloadVid = int.parse(json['vendorId'] as String, radix: 16);
    _sideloadPid = int.parse(json['productId'] as String, radix: 16);
    await update(quiet: false);
  }

  void loadViaStack(String data) {
    viaStackJson = jsonDecode(data) as Map<String, dynamic>;
  }

  Future<void> selectDevice(int idx) async {
    await currentDevice?.close();
    currentDevice = null;
    if (idx < 0 || idx >= devices.length) return;
    final dev = devices[idx];
    currentDevice = dev;
    try {
      if (dev.sideload) {
        await dev.open(sideloadJson);
      } else if (dev is VialKeyboard && dev.viaStack) {
        final defs = viaStackJson['definitions'] as Map<String, dynamic>;
        await dev.open(defs[dev.viaId] as Map<String, dynamic>?);
      } else {
        await dev.open();
      }
    } catch (_) {
      currentDevice = null;
      rethrow;
    }
  }
}
