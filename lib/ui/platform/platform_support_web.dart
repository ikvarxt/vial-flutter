// SPDX-License-Identifier: GPL-2.0-or-later
import 'dart:js_interop';

Future<String?> loadCachedViaStack() async => null;

Future<void> saveCachedViaStack(String data) async {}

Future<String> downloadViaStack() async =>
    throw UnsupportedError('not available on the web');

void exitApp() {}

@JS('fetch')
external JSPromise<_Response> _fetch(JSString url);

extension type _Response._(JSObject _) implements JSObject {
  external JSBoolean get ok;
  external JSPromise<JSString> text();
}

/// On the web "local file" means a same-origin URL (see `?dummy=` in
/// MainWindow); the browser sandbox has no file system access.
Future<String?> readLocalFile(String path) async {
  try {
    final resp = await _fetch(path.toJS).toDart;
    if (!resp.ok.toDart) return null;
    return (await resp.text().toDart).toDart;
  } catch (_) {
    return null;
  }
}
