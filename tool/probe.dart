// SPDX-License-Identifier: GPL-2.0-or-later
// ignore_for_file: avoid_print
// Command-line client for the debug UI probe extensions.
//
//   dart run tool/probe.dart <vm-service-url> screenshot <out.png> [ratio]
//   dart run tool/probe.dart <vm-service-url> tap <x> <y>
//   dart run tool/probe.dart <vm-service-url> text [filter]
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final url = args[0];
  final cmd = args[1];
  final ws = await WebSocket.connect(
    url.replaceFirst(RegExp('^http'), 'ws').replaceFirst(RegExp(r'/?$'), '/ws'),
  );
  var id = 0;
  final pending = <int, Completer<Map<String, dynamic>>>{};
  ws.listen((msg) {
    final m = jsonDecode(msg as String) as Map<String, dynamic>;
    final c = pending.remove(
      m['id'] is int ? m['id'] : int.tryParse('${m['id']}'),
    );
    c?.complete(m);
  });
  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, Object?> params = const {},
  ]) {
    final c = Completer<Map<String, dynamic>>();
    final myId = ++id;
    pending[myId] = c;
    ws.add(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': myId,
        'method': method,
        'params': params,
      }),
    );
    return c.future;
  }

  final vm = await call('getVM');
  final isolates = (vm['result']['isolates'] as List)
      .cast<Map<String, dynamic>>();
  final isolateId = isolates.first['id'] as String;

  switch (cmd) {
    case 'screenshot':
      final r = await call('ext.vial.screenshot', {
        'isolateId': isolateId,
        if (args.length > 3) 'ratio': args[3],
      });
      final res = r['result'] ?? r['error'];
      if (res is Map && res['png'] != null) {
        File(args[2]).writeAsBytesSync(base64Decode(res['png'] as String));
        print('wrote ${args[2]} ${res['width']}x${res['height']}');
      } else {
        print(res);
      }
    case 'tap':
      final r = await call('ext.vial.tap', {
        'isolateId': isolateId,
        'x': args[2],
        'y': args[3],
      });
      print(r['result'] ?? r['error']);
    case 'text':
      final r = await call('ext.vial.text', {
        'isolateId': isolateId,
        'text': args.length > 2 ? args[2] : '',
      });
      final res = r['result'] ?? r['error'];
      if (res is Map && res['texts'] != null) {
        for (final t in res['texts'] as List) {
          print(t);
        }
      } else {
        print(res);
      }
    case 'raw':
      final extra = args.length > 3
          ? (jsonDecode(args[3]) as Map).cast<String, Object?>()
          : <String, Object?>{};
      final r = await call(args[2], {'isolateId': isolateId, ...extra});
      print(jsonEncode(r['result'] ?? r['error']));
    default:
      print('unknown command');
  }
  await ws.close();
}
