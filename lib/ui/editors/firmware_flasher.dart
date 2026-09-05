// SPDX-License-Identifier: GPL-2.0-or-later
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import '../../hid/hid_device.dart';
import '../../hid/vial_device.dart';
import '../autorefresh.dart';
import '../dialogs/unlocker_dialog.dart';
import '../file_io.dart';
import 'basic_editor.dart';
import '../theme.dart';

const int _chunk = 64;

class FirmwareFlasher extends BasicEditor {
  FirmwareFlasher({required this.onDone});

  /// Invoked after flashing so the main window can rescan devices.
  final Future<void> Function() onDone;

  String _fileName = '';
  Uint8List? _firmware;
  final List<String> _log = [];
  bool _restoreLayout = true;
  bool _flashing = false;
  double _progress = 0;
  final ScrollController _scroll = ScrollController();

  @override
  String get label => 'Firmware updater';

  @override
  bool valid() {
    final d = device;
    return d is VialBootloader ||
        (d is VialKeyboard && d.keyboard != null && d.keyboard!.vibl);
  }

  void _logLine(String line) {
    final now = DateTime.now().toString().split('.').first;
    _log.add('[$now] $line');
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _selectFile() async {
    final picked = await pickFile(
      extension: 'vfw',
      dialogTitle: 'Select firmware',
    );
    if (picked == null) return;
    _fileName = picked.name;
    _firmware = picked.bytes;
    notifyListeners();
  }

  Future<void> _flash() async {
    final fw = _firmware;
    if (fw == null || _flashing) return;
    _flashing = true;
    _progress = 0;
    notifyListeners();
    final autorefresh = Autorefresh.instance;
    autorefresh.lock();
    try {
      await _doFlash(fw);
    } catch (e) {
      _logLine('Error: $e');
    } finally {
      autorefresh.unlock();
      _flashing = false;
      notifyListeners();
    }
  }

  static String _hex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

  Future<void> _doFlash(Uint8List fw) async {
    final autorefresh = Autorefresh.instance;
    if (fw.length > 10 * 1024 * 1024) {
      _logLine('Error: Firmware is too large (>10MB)');
      return;
    }
    if (fw.length < 64) {
      _logLine('Error: Firmware file is too small');
      return;
    }
    final magic = String.fromCharCodes(fw.sublist(0, 8));
    if (magic != 'VIALFW00' && magic != 'VIALFW01') {
      _logLine('Error: Invalid signature');
      return;
    }
    final uid = fw.sublist(8, 16);
    final ts = ByteData.sublistView(fw, 16, 24).getUint64(0, Endian.little);
    _logLine(
      '* Firmware build date: '
      '${DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true).toString().split('.').first} (UTC)',
    );
    final expectedHash = fw.sublist(32, 64);
    final payload = fw.sublist(64);
    final gotHash = sha256.convert(payload).bytes;
    if (!_listEq(expectedHash, gotHash)) {
      _logLine(
        'Error: Firmware failed integrity check\n'
        '\texpected=${_hex(expectedHash)}\n'
        '\tgot=${_hex(gotHash)}',
      );
      return;
    }

    _logLine('Preparing to flash...');
    Uint8List? layout;
    final d = device;
    if (d is VialKeyboard) {
      final kb = d.keyboard!;
      final kbUid = _uidBytes(kb.keyboardId);
      if (!_listEq(kbUid, uid)) {
        _logLine(
          'Error: Firmware UID does not match keyboard UID. '
          'Check that you have the correct file',
        );
        return;
      }
      if (_restoreLayout) layout = kb.saveLayout();
      await Unlocker.unlock(kb);
      _logLine('Restarting in bootloader mode...');
      await kb.reset();
    } else if (d is VialBootloader && !_listEq(await d.getUid(), uid)) {
      _logLine(
        'Error: Firmware UID does not match keyboard UID. '
        'Check that you have the correct file',
      );
      return;
    }

    VialBootloader? bl;
    while (bl == null) {
      _logLine('Looking for devices...');
      await Future<void>.delayed(const Duration(seconds: 1));
      final devices = await findVialDevices(
        autorefresh.backend,
        autorefresh.viaStackJson,
      );
      for (final dev in devices) {
        if (dev is VialBootloader && _listEq(await dev.getUid(), uid)) {
          bl = dev;
          break;
        }
      }
    }
    _logLine('Found Vial Bootloader device at ${bl.desc.path}');
    await bl.open();
    try {
      await bl.send(padForVibl([0x56, 0x43, 0x00])); // b"VC\x00"
      final ver = await bl.recv(8, timeoutMs: 500);
      if (ver.isEmpty || (ver[0] != 0 && ver[0] != 1)) {
        _logLine('Error: Unsupported bootloader version');
        return;
      }
      await bl.send(padForVibl([0x56, 0x43, 0x01])); // b"VC\x01"
      final blUid = await bl.recv(8, timeoutMs: 500);
      if (blUid.every((b) => b == 0xFF)) {
        _logLine(
          'Warning: Bootloader UID is not set, firmware UID check skipped',
        );
      }

      _logLine('Flashing...');
      final chunks = (payload.length + _chunk - 1) ~/ _chunk;
      await bl.send(
        padForVibl([0x56, 0x43, 0x02, chunks & 0xFF, (chunks >> 8) & 0xFF]),
      );
      for (var part = 0; part < chunks; part++) {
        final start = part * _chunk;
        final end = (start + _chunk).clamp(0, payload.length);
        final data = Uint8List(_chunk)..setAll(0, payload.sublist(start, end));
        var sent = false;
        for (var retry = 0; retry < 200 && !sent; retry++) {
          try {
            await bl.send(data);
            sent = true;
          } catch (_) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        }
        if (!sent) {
          _logLine('Error: Failed to send firmware chunk $part');
          return;
        }
        _progress = (part + 1) / chunks;
        notifyListeners();
      }

      _logLine('Rebooting...');
      if (layout != null) {
        await bl.send(padForVibl([0x56, 0x43, 0x04])); // b"VC\x04"
      }
      await bl.send(padForVibl([0x56, 0x43, 0x03])); // b"VC\x03"
      _logLine('Done!');
    } finally {
      await bl.close();
    }

    if (layout != null) {
      await _restoreAfterFlash(layout, uid);
    }
    await onDone();
  }

  Future<void> _restoreAfterFlash(Uint8List layout, Uint8List uid) async {
    _logLine('Waiting for the keyboard to come back...');
    final autorefresh = Autorefresh.instance;
    for (var attempt = 0; attempt < 30; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final devices = await findVialDevices(
        autorefresh.backend,
        autorefresh.viaStackJson,
      );
      for (final dev in devices) {
        if (dev is! VialKeyboard) continue;
        final devUid = await dev.getUid();
        if (!_listEq(devUid, uid)) continue;
        try {
          await dev.open();
          _logLine('Restoring layout...');
          await dev.keyboard!.restoreLayout(layout);
          _logLine('Layout restored');
        } finally {
          await dev.close();
        }
        return;
      }
    }
    _logLine('Warning: keyboard did not reappear, layout not restored');
  }

  static Uint8List _uidBytes(BigInt id) {
    final out = Uint8List(8);
    var v = id;
    for (var i = 0; i < 8; i++) {
      out[i] = (v & BigInt.from(0xFF)).toInt();
      v >>= 8;
    }
    return out;
  }

  static bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  child: Text(_fileName.isEmpty ? ' ' : _fileName),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _flashing ? null : _selectFile,
                child: const Text('Select file...'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              padding: const EdgeInsets.all(6),
              child: SingleChildScrollView(
                controller: _scroll,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SelectableText(
                    _log.join('\n'),
                    style: const TextStyle(fontFamily: monoFontFamily),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _restoreLayout,
                onChanged: _flashing
                    ? null
                    : (v) {
                        _restoreLayout = v ?? true;
                        notifyListeners();
                      },
              ),
              const Text('Restore current layout after flashing'),
              const Spacer(),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(value: _progress),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _firmware == null || _flashing ? null : _flash,
                child: const Text('Flash'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
