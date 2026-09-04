import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

const _viaStackUrl =
    'https://github.com/vial-kb/via-keymap-precompiled/raw/main/via_keyboard_stack.json';

Future<File> _cacheFile() async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}${Platform.pathSeparator}via_keyboards.json');
}

Future<String?> loadCachedViaStack() async {
  final f = await _cacheFile();
  if (!f.existsSync()) return null;
  return f.readAsString();
}

Future<void> saveCachedViaStack(String data) async {
  final f = await _cacheFile();
  await f.parent.create(recursive: true);
  await f.writeAsString(data);
}

Future<String> downloadViaStack() async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse(_viaStackUrl));
    req.followRedirects = true;
    final resp = await req.close();
    if (resp.statusCode != 200) {
      throw HttpException('HTTP ${resp.statusCode}');
    }
    return resp.transform(utf8.decoder).join();
  } finally {
    client.close();
  }
}

void exitApp() => exit(0);

Future<String?> readLocalFile(String path) async {
  final f = File(path);
  return f.existsSync() ? f.readAsString() : null;
}
