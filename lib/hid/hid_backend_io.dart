import 'package:flutter/services.dart';

import 'hid_device.dart';

HidBackend createHidBackend() => ChannelHidBackend();

/// Desktop backend: IOHIDManager (see macos/Runner/HidPlugin.swift) behind a
/// method channel.
class ChannelHidBackend implements HidBackend {
  static const MethodChannel _channel = MethodChannel('vial/hid');

  @override
  bool get needsUserGesture => false;

  @override
  bool get exposesSerialNumber => true;

  @override
  Future<List<HidDeviceInfo>> enumerate() async {
    final raw = await _channel.invokeListMethod<Object?>('enumerate') ?? [];
    return [
      for (final e in raw)
        _fromMap(Map<String, dynamic>.from(e as Map<Object?, Object?>)),
    ];
  }

  HidDeviceInfo _fromMap(Map<String, dynamic> m) => HidDeviceInfo(
    path: m['path'] as String,
    vendorId: m['vendorId'] as int,
    productId: m['productId'] as int,
    serialNumber: (m['serialNumber'] as String?) ?? '',
    manufacturer: (m['manufacturer'] as String?) ?? '',
    product: (m['product'] as String?) ?? '',
    usagePage: (m['usagePage'] as int?) ?? 0,
    usage: (m['usage'] as int?) ?? 0,
  );

  @override
  Future<HidDevice> open(HidDeviceInfo info) async {
    final handle = await _channel.invokeMethod<int>('open', {
      'path': info.path,
    });
    return _ChannelDevice(info, handle!);
  }

  @override
  Future<List<HidDeviceInfo>> requestDevices() async => const [];
}

class _ChannelDevice implements HidDevice {
  _ChannelDevice(this.info, this.handle);

  @override
  final HidDeviceInfo info;
  final int handle;

  @override
  Future<void> write(Uint8List data) => ChannelHidBackend._channel
      .invokeMethod<void>('write', {'handle': handle, 'data': data});

  @override
  Future<Uint8List> read(int length, {int timeoutMs = 0}) async {
    final data = await ChannelHidBackend._channel.invokeMethod<Uint8List>(
      'read',
      {'handle': handle, 'length': length, 'timeoutMs': timeoutMs},
    );
    return data ?? Uint8List(0);
  }

  @override
  Future<void> close() => ChannelHidBackend._channel.invokeMethod<void>(
    'close',
    {'handle': handle},
  );
}
