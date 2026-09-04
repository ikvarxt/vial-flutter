import 'dart:async';
import 'dart:collection';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'hid_device.dart';

HidBackend createHidBackend() => WebHidBackend();

extension type _Navigator(JSObject _) implements JSObject {
  external _Hid? get hid;
}

extension type _Hid(JSObject _) implements JSObject {
  external JSPromise<JSArray<_HidDevice>> getDevices();
  external JSPromise<JSArray<_HidDevice>> requestDevice(JSObject options);
}

extension type _HidCollectionInfo(JSObject _) implements JSObject {
  external int get usagePage;
  external int get usage;
}

extension type _HidDevice(JSObject _) implements JSObject {
  external bool get opened;
  external int get vendorId;
  external int get productId;
  external String get productName;
  external JSArray<_HidCollectionInfo> get collections;
  external JSPromise<JSAny?> open();
  external JSPromise<JSAny?> close();
  external JSPromise<JSAny?> sendReport(int reportId, JSUint8Array data);
  external set oninputreport(JSFunction? handler);
}

extension type _HidInputReportEvent(JSObject _) implements JSObject {
  external JSDataView get data;
  external int get reportId;
}

extension type _DataView(JSObject _) implements JSObject {
  external JSArrayBuffer get buffer;
  external int get byteOffset;
  external int get byteLength;
}

/// WebHID backend. Chrome only exposes devices the user has granted through
/// the picker, so [requestDevices] must be called from a click handler before
/// [enumerate] returns anything.
class WebHidBackend implements HidBackend {
  static const String _idKey = '__vialHidId';
  final Map<String, _HidDevice> _known = {};
  int _nextId = 1;

  _Hid? get _hid => (globalContext['navigator'] as _Navigator?)?.hid;

  bool get isSupported => _hid != null;

  @override
  bool get needsUserGesture => true;

  @override
  bool get exposesSerialNumber => false;

  String _idOf(_HidDevice dev) {
    final existing = dev[_idKey];
    if (existing != null && !existing.isUndefinedOrNull) {
      return (existing as JSString).toDart;
    }
    final id = 'webhid:${_nextId++}';
    dev[_idKey] = id.toJS;
    return id;
  }

  List<HidDeviceInfo> _describe(List<_HidDevice> devices) {
    final out = <HidDeviceInfo>[];
    for (final dev in devices) {
      final id = _idOf(dev);
      _known[id] = dev;
      final collections = dev.collections.toDart;
      if (collections.isEmpty) {
        out.add(
          HidDeviceInfo(
            path: id,
            vendorId: dev.vendorId,
            productId: dev.productId,
            product: dev.productName,
          ),
        );
        continue;
      }
      for (final c in collections) {
        out.add(
          HidDeviceInfo(
            path: id,
            vendorId: dev.vendorId,
            productId: dev.productId,
            product: dev.productName,
            usagePage: c.usagePage,
            usage: c.usage,
          ),
        );
      }
    }
    return out;
  }

  @override
  Future<List<HidDeviceInfo>> enumerate() async {
    final hid = _hid;
    if (hid == null) return const [];
    final devices = (await hid.getDevices().toDart).toDart;
    return _describe(devices);
  }

  @override
  Future<List<HidDeviceInfo>> requestDevices() async {
    final hid = _hid;
    if (hid == null) return const [];
    final filters = [
      // Vial / VIA raw HID interface
      {'usagePage': 0xFF60, 'usage': 0x61},
    ].map((f) => f.jsify()).toList().toJS;
    final options = JSObject()..['filters'] = filters;
    try {
      final devices = (await hid.requestDevice(options).toDart).toDart;
      return _describe(devices);
    } catch (_) {
      // the user dismissed the picker
      return const [];
    }
  }

  @override
  Future<HidDevice> open(HidDeviceInfo info) async {
    final dev = _known[info.path];
    if (dev == null) throw StateError('device ${info.path} is not known');
    if (!dev.opened) await dev.open().toDart;
    return _WebHidDevice(info, dev);
  }
}

class _WebHidDevice implements HidDevice {
  _WebHidDevice(this.info, this._dev) {
    _dev.oninputreport = _onInputReport.toJS;
  }

  @override
  final HidDeviceInfo info;
  final _HidDevice _dev;
  final Queue<Uint8List> _queue = Queue();
  Completer<Uint8List>? _pending;

  void _onInputReport(_HidInputReportEvent event) {
    final view = event.data as _DataView;
    final bytes = Uint8List.fromList(
      view.buffer.toDart.asUint8List(view.byteOffset, view.byteLength),
    );
    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      _pending = null;
      pending.complete(bytes);
    } else {
      _queue.add(bytes);
    }
  }

  @override
  Future<void> write(Uint8List data) => _dev.sendReport(0, data.toJS).toDart;

  @override
  Future<Uint8List> read(int length, {int timeoutMs = 0}) async {
    if (_queue.isNotEmpty) return _trim(_queue.removeFirst(), length);
    final completer = Completer<Uint8List>();
    _pending?.complete(Uint8List(0));
    _pending = completer;
    Timer? timer;
    if (timeoutMs > 0) {
      timer = Timer(Duration(milliseconds: timeoutMs), () {
        if (!completer.isCompleted) {
          _pending = null;
          completer.complete(Uint8List(0));
        }
      });
    }
    final data = await completer.future;
    timer?.cancel();
    return _trim(data, length);
  }

  Uint8List _trim(Uint8List d, int length) =>
      d.length > length ? Uint8List.sublistView(d, 0, length) : d;

  @override
  Future<void> close() async {
    _dev.oninputreport = null;
    _pending?.complete(Uint8List(0));
    _pending = null;
    await _dev.close().toDart;
  }
}
