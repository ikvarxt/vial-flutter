// SPDX-License-Identifier: GPL-2.0-or-later
import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'hid_device.dart';

/// Blocking hidraw I/O (open / poll / read / write / close through libc) run
/// on a dedicated isolate so a 500 ms read timeout never stalls the UI.
///
/// File descriptors are process-wide, so they can be handed back to the main
/// isolate as plain ints and reused across calls.
class HidrawWorker {
  HidrawWorker._(this._port, this._replies);

  final SendPort _port;
  final ReceivePort _replies;
  final Map<int, Completer<Object?>> _pending = {};
  var _nextId = 0;

  static Future<HidrawWorker> spawn() async {
    final replies = ReceivePort();
    await Isolate.spawn(_workerMain, replies.sendPort);
    final port = await replies.first as SendPort;
    final worker = HidrawWorker._(port, ReceivePort());
    worker._replies.listen(worker._onReply);
    return worker;
  }

  void _onReply(Object? message) {
    final (id, ok, payload) = message as (int, bool, Object?);
    final completer = _pending.remove(id);
    if (completer == null) return;
    if (ok) {
      completer.complete(payload);
    } else {
      completer.completeError(HidCommunicationError(payload as String));
    }
  }

  Future<T> _call<T>(String op, List<Object?> args) {
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _port.send((id, op, args, _replies.sendPort));
    return completer.future.then((v) => v as T);
  }

  Future<int> open(String path) => _call<int>('open', [path]);

  Future<void> write(int fd, Uint8List data) =>
      _call<void>('write', [fd, data]);

  Future<Uint8List> read(int fd, int length, int timeoutMs) =>
      _call<Uint8List>('read', [fd, length, timeoutMs]);

  Future<void> close(int fd) => _call<void>('close', [fd]);
}

// ---------------------------------------------------------------------------
// Worker isolate
// ---------------------------------------------------------------------------

void _workerMain(SendPort handshake) {
  final inbox = ReceivePort();
  handshake.send(inbox.sendPort);
  final libc = _Libc();
  inbox.listen((message) {
    final (id, op, args, reply) =
        message as (int, String, List<Object?>, SendPort);
    try {
      final result = switch (op) {
        'open' => libc.openDevice(args[0] as String),
        'write' => libc.writeReport(args[0] as int, args[1] as Uint8List),
        'read' => libc.readReport(
          args[0] as int,
          args[1] as int,
          args[2] as int,
        ),
        'close' => libc.closeDevice(args[0] as int),
        _ => throw ArgumentError('unknown op $op'),
      };
      reply.send((id, true, result));
    } catch (e) {
      reply.send((id, false, e.toString()));
    }
  });
}

final class _PollFd extends Struct {
  @Int32()
  external int fd;
  @Int16()
  external int events;
  @Int16()
  external int revents;
}

typedef _OpenC = Int Function(Pointer<Utf8>, Int, VarArgs<(Int,)>);
typedef _OpenDart = int Function(Pointer<Utf8>, int, int);
typedef _RwC = IntPtr Function(Int, Pointer<Uint8>, Size);
typedef _RwDart = int Function(int, Pointer<Uint8>, int);
typedef _PollC = Int Function(Pointer<_PollFd>, UnsignedLong, Int);
typedef _PollDart = int Function(Pointer<_PollFd>, int, int);
typedef _CloseC = Int Function(Int);
typedef _CloseDart = int Function(int);
typedef _ErrnoC = Pointer<Int32> Function();
typedef _ErrnoDart = Pointer<Int32> Function();

class _Libc {
  _Libc() : _lib = DynamicLibrary.process() {
    _open = _lib.lookupFunction<_OpenC, _OpenDart>('open');
    _read = _lib.lookupFunction<_RwC, _RwDart>('read');
    _write = _lib.lookupFunction<_RwC, _RwDart>('write');
    _poll = _lib.lookupFunction<_PollC, _PollDart>('poll');
    _close = _lib.lookupFunction<_CloseC, _CloseDart>('close');
    try {
      _errno = _lib.lookupFunction<_ErrnoC, _ErrnoDart>('__errno_location');
    } catch (_) {
      _errno = null;
    }
  }

  static const _oRdwr = 0x2;
  static const _pollIn = 0x1;
  static const _pollErr = 0x8;
  static const _pollHup = 0x10;
  static const _pollNval = 0x20;
  // Larger than any report Vial firmware emits; the kernel truncates to the
  // report length anyway.
  static const _readBuffer = 4096;

  final DynamicLibrary _lib;
  late final _OpenDart _open;
  late final _RwDart _read;
  late final _RwDart _write;
  late final _PollDart _poll;
  late final _CloseDart _close;
  _ErrnoDart? _errno;

  String _err(String what) {
    final code = _errno?.call().value;
    return code == null ? '$what failed' : '$what failed (errno $code)';
  }

  int openDevice(String path) {
    final cPath = path.toNativeUtf8();
    try {
      final fd = _open(cPath, _oRdwr, 0);
      if (fd < 0) throw HidCommunicationError(_err('open $path'));
      return fd;
    } finally {
      malloc.free(cPath);
    }
  }

  Object? writeReport(int fd, Uint8List data) {
    // hidraw expects the report id as the first byte; Vial uses id 0, which
    // hidapi callers express by prepending a zero the same way.
    final buf = malloc<Uint8>(data.length + 1);
    try {
      buf[0] = 0;
      buf.asTypedList(data.length + 1).setRange(1, data.length + 1, data);
      final n = _write(fd, buf, data.length + 1);
      if (n != data.length + 1) throw HidCommunicationError(_err('write'));
      return null;
    } finally {
      malloc.free(buf);
    }
  }

  Uint8List readReport(int fd, int length, int timeoutMs) {
    final pfd = malloc<_PollFd>();
    final buf = malloc<Uint8>(_readBuffer);
    try {
      pfd.ref.fd = fd;
      pfd.ref.events = _pollIn;
      pfd.ref.revents = 0;
      final ready = _poll(pfd, 1, timeoutMs > 0 ? timeoutMs : -1);
      if (ready == 0) return Uint8List(0);
      if (ready < 0) throw HidCommunicationError(_err('poll'));
      if (pfd.ref.revents & (_pollErr | _pollHup | _pollNval) != 0) {
        throw HidCommunicationError('device was unplugged');
      }
      final n = _read(fd, buf, _readBuffer);
      if (n < 0) throw HidCommunicationError(_err('read'));
      final out = Uint8List(n < length ? n : length);
      out.setAll(0, buf.asTypedList(out.length));
      return out;
    } finally {
      malloc.free(buf);
      malloc.free(pfd);
    }
  }

  Object? closeDevice(int fd) {
    _close(fd);
    return null;
  }
}
